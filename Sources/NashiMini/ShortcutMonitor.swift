import AppKit
import ApplicationServices

/// One session event tap: it fires the saved shortcut, swallows that event so the
/// button keeps no other meaning, and captures the next press while recording.
@MainActor final class ShortcutMonitor {
    enum Capture { case recorded(Shortcut),rejected,cancelled }
    var shortcut:Shortcut?
    var capturing=false
    var onTrigger:(()->Void)?
    var onCapture:((Capture)->Void)?
    var onLeftDown:(()->Void)?
    var onLeftUp:(()->Void)?
    var onReady:(()->Void)?
    private var tap:CFMachPort?
    private var retry:Timer?
    private var heldButton:Int64?

    var isReady:Bool { tap != nil }
    func start() {
        let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary
        _=AXIsProcessTrustedWithOptions(options)
        guard !install() else { return }
        retry=Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in
            Task { @MainActor in
                guard let self,AXIsProcessTrusted(),self.install() else { return }
                self.retry?.invalidate();self.retry=nil;self.onReady?()
            }
        }
    }
    private func install()->Bool {
        guard tap == nil,AXIsProcessTrusted() else { return tap != nil }
        let types:[CGEventType]=[.keyDown,.otherMouseDown,.otherMouseUp,.leftMouseDown,.leftMouseUp]
        let mask=types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let context=Unmanaged.passUnretained(self).toOpaque()
        guard let port=CGEvent.tapCreate(tap:.cgSessionEventTap,place:.headInsertEventTap,options:.defaultTap,eventsOfInterest:mask,callback:{ _,type,event,context in
            guard let context else { return Unmanaged.passUnretained(event) }
            let monitor=Unmanaged<ShortcutMonitor>.fromOpaque(context).takeUnretainedValue()
            let swallow=MainActor.assumeIsolated { monitor.handle(type,event) }
            return swallow ? nil:Unmanaged.passUnretained(event)
        },userInfo:context) else { return false }
        CFRunLoopAddSource(CFRunLoopGetMain(),CFMachPortCreateRunLoopSource(nil,port,0),.commonModes)
        CGEvent.tapEnable(tap:port,enable:true)
        tap=port;return true
    }
    private func handle(_ type:CGEventType,_ event:CGEvent)->Bool {
        switch type {
        case .tapDisabledByTimeout,.tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap:tap,enable:true) }
            return false
        case .leftMouseDown: onLeftDown?();return false
        case .leftMouseUp: onLeftUp?();return false
        case .otherMouseUp:
            guard heldButton == event.getIntegerValueField(.mouseEventButtonNumber) else { return false }
            heldButton=nil;return true
        case .otherMouseDown:
            let button=event.getIntegerValueField(.mouseEventButtonNumber),modifiers=Shortcut.modifiers(of:event)
            if capturing {
                heldButton=button;finishCapture(.recorded(.mouse(button:button,modifiers:modifiers)));return true
            }
            guard shortcut?.matches(kind:.mouse,code:button,modifiers:modifiers) == true else { return false }
            heldButton=button;onTrigger?();return true
        case .keyDown:
            let code=event.getIntegerValueField(.keyboardEventKeycode),modifiers=Shortcut.modifiers(of:event)
            if capturing {
                if code == 53,modifiers == 0 { finishCapture(.cancelled) }
                else if modifiers != 0 || Shortcut.functionKeyCodes.contains(code) { finishCapture(.recorded(.key(event:event,code:code,modifiers:modifiers))) }
                else { onCapture?(.rejected) }
                return true
            }
            guard shortcut?.matches(kind:.key,code:code,modifiers:modifiers) == true else { return false }
            if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 { onTrigger?() }
            return true
        default: return false
        }
    }
    private func finishCapture(_ result:Capture) { capturing=false;onCapture?(result) }
}
