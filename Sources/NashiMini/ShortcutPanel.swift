import AppKit

/// Nashi Mini's only window. It appears on first launch and whenever the app is opened
/// again, so the shortcut can be changed or the agent quit without a menu bar item.
@MainActor final class ShortcutPanel:NSObject,NSWindowDelegate {
    var onClose:(()->Void)?
    var onOpenSettings:(()->Void)?
    var onDownloadTools:(()->Void)?
    private var window:NSWindow?
    private let titleLabel=NSTextField(labelWithString:"")
    private let detailLabel=NSTextField(wrappingLabelWithString:"")
    private let settingsButton=NSButton(title:"Open Accessibility Settings",target:nil,action:nil)
    private let toolsButton=NSButton(title:"Download Media & Office Tools",target:nil,action:nil)

    func show(needsAccess:Bool,needsTools:Bool,current:Shortcut?) {
        if window == nil { build() }
        settingsButton.isHidden = !needsAccess
        toolsButton.isHidden=needsAccess || !needsTools
        titleLabel.stringValue=needsAccess ? "Allow Nashi Mini":"Press your mouse button"
        detailLabel.stringValue=needsAccess ? "Turn on Nashi Mini in Privacy & Security › Accessibility so it can hear your button.":"Or press a key combination. Current: \(current?.label ?? "none"). Esc cancels."
        NSApp.activate(ignoringOtherApps:true)
        window?.center();window?.makeKeyAndOrderFront(nil)
    }
    func saved(_ shortcut:Shortcut) {
        titleLabel.stringValue="Saved"
        detailLabel.stringValue="\(shortcut.label) opens the wheel."
        DispatchQueue.main.asyncAfter(deadline:.now()+1) { [weak self] in self?.window?.close() }
    }
    func rejected() { detailLabel.stringValue="Add ⌘, ⌥, ⌃ or ⇧, or use a function key." }
    func close() { window?.close() }
    private func build() {
        let panel=NSWindow(contentRect:NSRect(x:0,y:0,width:380,height:150),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        panel.title="Nashi Mini";panel.isReleasedWhenClosed=false;panel.level = .floating;panel.delegate=self
        titleLabel.font = .systemFont(ofSize:15,weight:.semibold)
        detailLabel.font = .systemFont(ofSize:12);detailLabel.textColor = .secondaryLabelColor
        settingsButton.target=self;settingsButton.action=#selector(openSettings)
        toolsButton.target=self;toolsButton.action=#selector(downloadTools)
        let quit=NSButton(title:"Quit Nashi Mini",target:NSApp,action:#selector(NSApplication.terminate(_:)))
        let buttons=NSStackView(views:[settingsButton,toolsButton,NSView(),quit]);buttons.orientation = .horizontal
        let stack=NSStackView(views:[titleLabel,detailLabel,buttons]);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=10
        stack.edgeInsets=NSEdgeInsets(top:18,left:20,bottom:18,right:20);stack.translatesAutoresizingMaskIntoConstraints=false
        let content=panel.contentView!;content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:content.leadingAnchor),stack.trailingAnchor.constraint(equalTo:content.trailingAnchor),
                                     stack.topAnchor.constraint(equalTo:content.topAnchor),stack.bottomAnchor.constraint(equalTo:content.bottomAnchor),
                                     buttons.widthAnchor.constraint(equalTo:stack.widthAnchor,constant:-40)])
        window=panel
    }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func downloadTools() { toolsButton.isEnabled=false;onDownloadTools?() }
    func windowWillClose(_ notification:Notification) { onClose?() }
}
