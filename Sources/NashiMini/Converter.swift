import Foundation
import NashiCore

/// Runs one job at a time and always writes into Downloads. Originals stay put.
@MainActor final class Converter {
    private(set) var working=false
    /// Tools that turn the whole selection into one result; the rest run file by file.
    nonisolated private static let combining:Set<ToolKind>=[.createPDF,.mergePDF,.createCollage,.joinVideos,.readQRCode]

    nonisolated private static func baseOptions(format:String="",destination:URL)->OperationOptions {
        var options=OperationOptions()
        options.quality=format.lowercased() == "mov" ? 0.95:0.8
        options.outputDirectory=destination
        options.revealInFinder=false
        return options
    }
    nonisolated static func execute(_ action:WheelEntry.Action,inputs:[URL],destination:URL) throws -> [URL] {
        switch action {
        case .convert(let format):
            return try ConversionEngine.run(ConversionRequest(inputs:inputs,operation:.convert(format),options:baseOptions(format:format,destination:destination)))
        case .run(let tool,let preset):
            let groups=combining.contains(tool) ? [inputs]:inputs.map{[$0]}
            return try groups.flatMap { group in
                var options=baseOptions(destination:destination)
                try preset(&options,group[0])
                return try ConversionEngine.run(ConversionRequest(inputs:group,operation:.tool(tool),options:options))
            }
        case .menu: return []
        }
    }
    func run(_ entry:WheelEntry,inputs:[URL]) {
        guard !working else { return }
        working=true
        Toast.shared.show("Working on \(entry.title)…",duration:nil)
        let action=entry.action,downloads=FileManager.default.urls(for:.downloadsDirectory,in:.userDomainMask)[0]
        Task {
            defer { working=false }
            do {
                let result=try await Task.detached(priority:.userInitiated) { try Self.execute(action,inputs:inputs,destination:downloads) }.value
                Toast.shared.show(result.count == 1 ? "Saved to Downloads: \(result[0].lastPathComponent)":"\(result.count) files saved to Downloads")
            } catch { Toast.shared.show(error.localizedDescription,duration:6) }
        }
    }
}
