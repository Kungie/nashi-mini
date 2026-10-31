import AppKit

/// A small status line at the bottom of the screen; it never takes focus or clicks.
@MainActor final class Toast {
    static let shared=Toast()
    private var panel:NSPanel?
    private let label=NSTextField(labelWithString:"")
    private var hide:DispatchWorkItem?

    /// A nil duration keeps the message up until the next one replaces it.
    func show(_ text:String,duration:TimeInterval?=2.5) {
        hide?.cancel()
        if panel == nil { build() }
        label.stringValue=text;label.sizeToFit()
        let size=NSSize(width:min(label.frame.width+36,560),height:38)
        let screen=NSScreen.screens.first{$0.frame.contains(NSEvent.mouseLocation)} ?? NSScreen.main
        let visible=screen?.visibleFrame ?? .zero
        panel?.setFrame(NSRect(x:visible.midX-size.width/2,y:visible.minY+48,width:size.width,height:size.height),display:true)
        label.frame=NSRect(x:18,y:(size.height-label.frame.height)/2,width:size.width-36,height:label.frame.height)
        panel?.orderFrontRegardless()
        guard let duration else { return }
        let work=DispatchWorkItem { [weak self] in self?.panel?.orderOut(nil) }
        hide=work;DispatchQueue.main.asyncAfter(deadline:.now()+duration,execute:work)
    }
    private func build() {
        let p=NSPanel(contentRect:.zero,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        p.isOpaque=false;p.backgroundColor = .clear;p.hasShadow=true;p.level = .statusBar;p.ignoresMouseEvents=true
        p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
        let effect=NSVisualEffectView();effect.material = .hudWindow;effect.state = .active;effect.wantsLayer=true;effect.layer?.cornerRadius=14;effect.layer?.masksToBounds=true
        label.font = .systemFont(ofSize:13,weight:.medium);label.lineBreakMode = .byTruncatingMiddle
        effect.addSubview(label);p.contentView=effect;panel=p
    }
}
