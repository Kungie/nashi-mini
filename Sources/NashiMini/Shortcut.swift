import AppKit

/// The one trigger Nashi Mini listens for: a mouse button or a key, with modifiers.
struct Shortcut:Codable,Equatable {
    enum Kind:String,Codable { case mouse,key }
    var kind:Kind
    var code:Int64
    var modifiers:UInt64
    var label:String

    static let modifierMask:CGEventFlags=[.maskShift,.maskControl,.maskAlternate,.maskCommand]
    static func modifiers(of event:CGEvent)->UInt64 { event.flags.intersection(modifierMask).rawValue }
    /// F1 to F20 in order. These work alone; any other key needs a modifier so typing never opens the wheel.
    static let functionKeyCodes:[Int64]=[122,120,99,118,96,97,98,100,101,109,103,111,105,107,113,106,64,79,80,90]

    func matches(kind:Kind,code:Int64,modifiers:UInt64)->Bool {
        self.kind == kind && self.code == code && self.modifiers == modifiers
    }
    static func symbols(_ modifiers:UInt64)->String {
        let flags=CGEventFlags(rawValue:modifiers)
        return (flags.contains(.maskControl) ? "⌃":"")+(flags.contains(.maskAlternate) ? "⌥":"")+(flags.contains(.maskShift) ? "⇧":"")+(flags.contains(.maskCommand) ? "⌘":"")
    }
    static func mouse(button:Int64,modifiers:UInt64)->Shortcut {
        let name=[2:"Middle button",3:"Back button",4:"Forward button"][Int(button)] ?? "Mouse button \(button+1)"
        return Shortcut(kind:.mouse,code:button,modifiers:modifiers,label:symbols(modifiers)+name)
    }
    static func key(event:CGEvent,code:Int64,modifiers:UInt64)->Shortcut {
        let name=functionKeyCodes.firstIndex(of:code).map{"F\($0+1)"} ?? NSEvent(cgEvent:event)?.charactersIgnoringModifiers?.uppercased() ?? "Key \(code)"
        return Shortcut(kind:.key,code:code,modifiers:modifiers,label:symbols(modifiers)+name)
    }
}

enum ShortcutStore {
    private static let key="shortcut"
    static func load()->Shortcut? {
        UserDefaults.standard.data(forKey:key).flatMap{try? JSONDecoder().decode(Shortcut.self,from:$0)}
    }
    static func save(_ shortcut:Shortcut) {
        if let data=try? JSONEncoder().encode(shortcut) { UserDefaults.standard.set(data,forKey:key) }
    }
}
