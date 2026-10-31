import Foundation
import NashiCore

/// Runs one conversion at a time and always writes into Downloads. Originals stay put.
@MainActor final class Converter {
    private(set) var working=false
    private static var downloads:URL { FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask)[0] }

    private static func options(for format:String)->OperationOptions {
        var options=OperationOptions()
        options.quality=format.lowercased() == "mov" ? 0.95:0.8
        options.preserveMetadata=true
        options.audioBitrate=256
        options.audioSampleDepth="matchSource"
        options.videoMaxHeight=0
        options.gifFrameRate=15
        options.gifMaxWidth=960
        options.compressionPreset="balanced"
        options.epubLayout="reflowable"
        options.pdfOfficeLayout="editable"
        options.outputDirectory=downloads
        options.revealInFinder=false
        return options
    }
    func convert(_ inputs:[URL],to format:String) {
        guard !working else { return }
        working=true
        Toast.shared.show("Converting to \(format.uppercased())…",duration:nil)
        let request=ConversionRequest(inputs:inputs,operation:.convert(format),options:Self.options(for:format))
        Task {
            defer { working=false }
            do {
                let result=try await Task.detached(priority:.userInitiated) { try ConversionEngine.run(request) }.value
                Toast.shared.show(result.count == 1 ? "Saved to Downloads: \(result[0].lastPathComponent)":"\(result.count) files saved to Downloads")
            } catch {
                #if DEBUG
                fputs("Conversion failed: \(error)\n",stderr)
                #endif
                Toast.shared.show(error.localizedDescription,duration:6)
            }
        }
    }
}
