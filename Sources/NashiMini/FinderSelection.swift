import AppKit

enum FinderSelection {
    enum Result { case files([URL]),empty,denied }
    private static let source="""
    tell application "Finder" to set theSelection to selection as alias list
    set thePaths to {}
    repeat with theItem in theSelection
        set end of thePaths to POSIX path of theItem
    end repeat
    return thePaths
    """
    /// Only the frontmost Finder counts, so a stale selection never answers a press made in another app.
    @MainActor static func read()->Result {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder" else { return .empty }
        var failure:NSDictionary?
        guard let list=NSAppleScript(source:source)?.executeAndReturnError(&failure),failure == nil else {
            return failure?[NSAppleScript.errorNumber] as? Int == -1743 ? .denied:.empty
        }
        let urls=list.numberOfItems>0 ? (1...list.numberOfItems).compactMap{list.atIndex($0)?.stringValue}.map{URL(fileURLWithPath:$0)}:[]
        return urls.isEmpty ? .empty:.files(urls)
    }
}
