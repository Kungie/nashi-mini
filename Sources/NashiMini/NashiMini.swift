import AppKit
import NashiCore
import ServiceManagement

@main enum NashiMini {
    @MainActor static func main() {
        let app=NSApplication.shared
        let delegate=AppDelegate()
        app.delegate=delegate;app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

/// No Dock icon, no menu bar item: a press of the saved shortcut opens the wheel.
@MainActor final class AppDelegate:NSObject,NSApplicationDelegate {
    private let wheel=WheelController()
    private let converter=Converter()
    private let monitor=ShortcutMonitor()
    private let panel=ShortcutPanel()
    private var dragChangeAtMouseDown=NSPasteboard(name:.drag).changeCount
    private var leftDown=false

    func applicationDidFinishLaunching(_ notification:Notification) {
        wheel.onAction={ [weak self] in self?.converter.run($0,inputs:$1) }
        monitor.shortcut=ShortcutStore.load()
        monitor.onTrigger={ [weak self] in self?.trigger() }
        monitor.onCapture={ [weak self] in self?.captured($0) }
        monitor.onLeftDown={ [weak self] in self?.leftMouseDown() }
        monitor.onLeftUp={ [weak self] in self?.leftMouseUp() }
        monitor.onReady={ [weak self] in self?.promptForShortcut() }
        panel.onClose={ [weak self] in self?.monitor.capturing=false }
        panel.onDownloadTools={ [weak self] in self?.downloadTools() }
        panel.onOpenSettings={ NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }
        #if DEBUG
        if debugCommand() { return }
        #endif
        try? SMAppService.mainApp.register()
        monitor.start()
        if !monitor.isReady || monitor.shortcut == nil { promptForShortcut() }
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {
        promptForShortcut();return false
    }
    private func promptForShortcut() {
        monitor.capturing=monitor.isReady
        panel.show(needsAccess:!monitor.isReady,needsTools:!ExternalToolSetup.status.ready,current:monitor.shortcut)
    }
    /// Fetches the same hash-verified ffmpeg and LibreOffice builds Nashi uses.
    private func downloadTools() {
        let token=CancellationToken()
        let report:@Sendable (Double?,String)->Void={ _,label in Task { @MainActor in Toast.shared.show(label,duration:nil) } }
        Task {
            do {
                try await ExternalToolSetup.installMedia(token:token,progress:report)
                try await ExternalToolSetup.installOffice(token:token,progress:report)
                Toast.shared.show("Tools are ready")
            } catch { Toast.shared.show(error.localizedDescription,duration:6) }
        }
    }
    private func captured(_ result:ShortcutMonitor.Capture) {
        switch result {
        case .recorded(let shortcut):
            monitor.shortcut=shortcut;ShortcutStore.save(shortcut);panel.saved(shortcut)
        case .rejected: panel.rejected()
        case .cancelled: panel.close()
        }
    }
    private func trigger() {
        if wheel.isVisible { wheel.hide();return }
        if converter.working { Toast.shared.show("Still converting…");return }
        let board=NSPasteboard(name:.drag)
        if leftDown {
            guard board.changeCount != dragChangeAtMouseDown else { return }
            let files=WheelController.fileURLs(from:board)
            if !files.isEmpty { wheel.show(inputs:files,at:NSEvent.mouseLocation,keyboard:false) }
            return
        }
        switch FinderSelection.read() {
        case .files(let files): wheel.show(inputs:files,at:NSEvent.mouseLocation,keyboard:true)
        case .empty: Toast.shared.show("Select files in Finder first")
        case .denied: Toast.shared.show("Allow Nashi Mini to control Finder in Privacy & Security › Automation",duration:6)
        }
    }
    private func leftMouseDown() {
        leftDown=true;dragChangeAtMouseDown=NSPasteboard(name:.drag).changeCount
        wheel.hideIfOutside(NSEvent.mouseLocation)
    }
    private func leftMouseUp() {
        leftDown=false
        // The drop lands after mouse-up; a drop outside the wheel just closes it.
        DispatchQueue.main.asyncAfter(deadline:.now()+0.25) { [weak self] in self?.wheel.endDrag() }
    }
    #if DEBUG
    /// Exercises the wheel and the converter without the event tap's permission.
    private func debugCommand()->Bool {
        let arguments=CommandLine.arguments
        if let index=arguments.firstIndex(of:"--show-wheel") {
            wheel.show(inputs:arguments[(index+1)...].filter{$0 != "--tools"}.map{URL(fileURLWithPath:$0)},at:NSEvent.mouseLocation,keyboard:true)
            if arguments.contains("--tools") { wheel.showToolsLevel() }
            return true
        }
        if let index=arguments.firstIndex(of:"--test-all"),arguments.count>index+2 {
            let output=URL(fileURLWithPath:arguments[index+1],isDirectory:true)
            let groups=arguments[(index+2)...].map{$0.split(separator:",").map{URL(fileURLWithPath:String($0))}}
            Task.detached { ToolMenu.testAll(groups,output:output);exit(0) };return true
        }
        if arguments.contains("--show-panel") { panel.show(needsAccess:false,needsTools:true,current:nil);return true }
        return false
    }
    #endif
}
