import AppKit
import NashiCore
import PDFKit

/// Settings for one run. Size-dependent presets read the file they apply to.
typealias Preset=@Sendable (inout OperationOptions,URL) throws -> Void

/// One petal: a format, a tool with fixed settings, or a smaller wheel of presets.
struct WheelEntry {
    enum Action { case convert(String),run(ToolKind,Preset),menu([WheelEntry]) }
    var title:String
    var symbol:String?=nil
    var action:Action
}

/// Every Nashi tool that works without pointing at the file. Annotate and the redact
/// tools need a drawn region or time range, so they stay out of a windowless app.
enum ToolMenu {
    static func formats(for inputs:[URL])->[WheelEntry] {
        FeatureCatalog.formats(for:inputs).map{WheelEntry(title:$0 == "gz" ? "GZIP":$0.uppercased(),action:.convert($0))}
    }
    static func tools(for inputs:[URL])->[WheelEntry] {
        FeatureCatalog.tools(for:inputs).compactMap { tool in
            guard let action=action(for:tool) else { return nil }
            return WheelEntry(title:FeatureCatalog.toolNames[tool] ?? tool.title,symbol:FeatureCatalog.toolSymbols[tool],action:action)
        }
    }
    private static func action(for tool:ToolKind)->WheelEntry.Action? {
        func presets(_ items:[(String,Preset)])->WheelEntry.Action { .menu(items.map{WheelEntry(title:$0.0,action:.run(tool,$0.1))}) }
        switch tool {
        case .compress: return presets([("Balanced",{ o,_ in o.quality=0.8 }),("Strong",{ o,_ in o.quality=0.45 })])
        case .removeMetadata: return .run(tool) { o,_ in o.metadataRemoveAll=true }
        case .editImage: return presets(photoEdits)
        case .frameImage: return presets([
            ("White",{ o,_ in o.imageFrame=frame("#FFFFFF") }),("Black",{ o,_ in o.imageFrame=frame("#000000") }),
            ("Gradient",{ o,_ in var f=frame("#FFFFFF");f.backdrop = .gradient;o.imageFrame=f })])
        case .cropImage: return presets(aspectRatios { url in let i=try ImageEngine.load(url);return (Double(i.width),Double(i.height)) })
        case .cropVideo: return presets(aspectRatios { url in
            guard let v=try MediaEngine.inspect(url).video,let w=v.width,let h=v.height else { throw NashiError.invalidInput("The video has no readable dimensions.") }
            return (Double(w),Double(h)) })
        case .trimVideo: return presets(firstSeconds)
        case .trimAudio: return presets(firstSeconds+[("Trim Silence",{ o,_ in o.trimSilence=true })])
        case .changeVideoSpeed: return presets([0.5,1.5,2,4].map{speed in ("\(speed == speed.rounded() ? String(Int(speed)):String(speed))×",{ o,_ in o.speed=speed })})
        case .videoSnapshots: return presets([
            ("First Frame",{ o,_ in o.snapshotTimes=[0] }),
            ("Middle Frame",{ o,url in o.snapshotTimes=[try MediaEngine.inspect(url).duration/2] }),
            ("5 Frames",{ o,url in let d=try MediaEngine.inspect(url).duration;o.snapshotTimes=(1...5).map{d*Double($0)/6} })])
        case .splitVideo: return presets([2,3,4,5].map{count in ("\(count) Clips",{ o,_ in o.equalClips=count })})
        case .audioToVideo: return presets(["Waveform","Spectrum","Bars"].map{style in (style,{ o,_ in o.visualizationStyle=style })})
        case .audioChannels: return presets([("Mono",{ o,_ in o.channels=1 }),("Stereo",{ o,_ in o.channels=2 })])
        case .splitPDF: return presets([("Every Page",1),("Every 2 Pages",2),("Every 5 Pages",5),("Every 10 Pages",10)].map{item in (item.0,{ o,_ in o.pagesPerFile=item.1 })})
        case .organizePDF: return presets([("Reverse Pages",{ o,url in
            guard let count=PDFDocument(url:url)?.pageCount,count>0 else { throw NashiError.invalidInput("This PDF could not be opened.") }
            o.pdfPageOrder=Array((0..<count).reversed()) })])
        case .createCollage: return presets(CollageLayout.allCases.map{layout in (layout.rawValue.capitalized,{ o,_ in var c=CollageOptions();c.layout=layout;o.collage=c })})
        case .normalizeAudio,.muteVideo,.extractArchive,.createPDF,.mergePDF,.joinVideos,.readQRCode: return .run(tool) { _,_ in }
        case .annotateImage,.redactImage,.redactVideo,.redactAudio: return nil
        }
    }
    private static let photoEdits:[(String,Preset)]=[
        ("Rotate Left",{ o,_ in o.rotation=270 }),("Rotate Right",{ o,_ in o.rotation=90 }),("Flip",{ o,_ in o.flipHorizontal=true }),
        ("Half Size",{ o,url in o.width=max(1,try ImageEngine.load(url).width/2) }),
        ("Black & White",{ o,_ in o.imageAdjustments.saturation=0 }),("Vivid",{ o,_ in o.imageAdjustments.saturation=1.25;o.imageAdjustments.vibrance=0.3 }),
        ("Brighten",{ o,_ in o.imageAdjustments.exposure=0.4 }),("Sharpen",{ o,_ in o.imageAdjustments.sharpen=0.5 })]
    private static let firstSeconds:[(String,Preset)]=[10,30,60].map { seconds in
        ("First \(seconds)s",{ o,url in o.end=min(Double(seconds),try MediaEngine.inspect(url).duration) })
    }
    private static func frame(_ color:String)->ImageFrameOptions { var f=ImageFrameOptions();f.backgroundColor=color;return f }
    private static func aspectRatios(_ size:@escaping @Sendable (URL) throws -> (Double,Double))->[(String,Preset)] {
        [("1:1",1,1),("4:3",4,3),("3:4",3,4),("16:9",16,9),("9:16",9,16)].map { item in
            (item.0,{ o,url in
                let (width,height)=try size(url),ratio=Double(item.1)/Double(item.2)
                let w=min(width,height*ratio).rounded(.down),h=min(height,w/ratio).rounded(.down)
                o.crop=EditRect(x:((width-w)/2).rounded(.down),y:((height-h)/2).rounded(.down),width:w,height:h)
            })
        }
    }
}

#if DEBUG
extension ToolMenu {
    /// Runs every wheel action on each group of files and prints one result line per action.
    static func testAll(_ groups:[[URL]],output:URL) {
        setbuf(stdout,nil)
        func walk(_ entries:[WheelEntry],path:String,inputs:[URL]) {
            for entry in entries {
                let name=path+entry.title
                if case .menu(let children)=entry.action { walk(children,path:name+" › ",inputs:inputs);continue }
                do {
                    let results=try Converter.execute(entry.action,inputs:inputs,destination:output)
                    print("PASS \(inputs[0].lastPathComponent) | \(name) -> \(results.map(\.lastPathComponent).joined(separator:", "))")
                } catch { print("FAIL \(inputs[0].lastPathComponent) | \(name): \(error)") }
            }
        }
        for inputs in groups { walk(formats(for:inputs)+tools(for:inputs),path:"",inputs:inputs) }
    }
}
#endif
