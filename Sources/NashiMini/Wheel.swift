import AppKit
import NashiCore

final class WheelPanel:NSPanel { override var canBecomeKey:Bool { true } }
struct WheelItem {
    var title:String
    var format:String
}
private enum WheelColors {
    static let gold=NSColor(srgbRed:0.89,green:0.72,blue:0.35,alpha:1)
    static let goldEnd=NSColor(srgbRed:0.96,green:0.82,blue:0.49,alpha:1)
    static let ink=NSColor(srgbRed:0.20,green:0.25,blue:0.14,alpha:1)
}

@MainActor final class WheelController {
    var onConvert:(([URL],String)->Void)?
    private var panel:NSPanel?
    private var wheel:WheelView?
    private var inputs:[URL]=[]
    private var keyboardMode=false
    private var keyWindowObserver:NSObjectProtocol?
    var isVisible:Bool { panel?.isVisible == true }

    static func fileURLs(from board:NSPasteboard)->[URL] {
        board.readObjects(forClasses:[NSURL.self],options:[.urlReadingFileURLsOnly:true]) as? [URL] ?? []
    }
    func show(inputs:[URL],at point:NSPoint,keyboard:Bool) {
        guard !inputs.isEmpty else { return }
        WheelFeedback.shared.prepare()
        self.inputs=inputs;keyboardMode=keyboard
        let items=FeatureCatalog.formats(for:inputs).map{WheelItem(title:$0 == "gz" ? "GZIP":$0.uppercased(),format:$0)}
        let exists=isVisible
        if panel == nil {
            let size:CGFloat=320
            let p=WheelPanel(contentRect:NSRect(x:0,y:0,width:size,height:size),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            p.backgroundColor = .clear;p.isOpaque=false;p.hasShadow=false;p.level = .statusBar;p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];p.hidesOnDeactivate=false
            let effect=NSVisualEffectView(frame:NSRect(x:0,y:0,width:size,height:size));effect.material = .popover;effect.blendingMode = .behindWindow;effect.state = .active;effect.wantsLayer=true;effect.layer?.cornerRadius=size/2;effect.layer?.masksToBounds=true
            let view=WheelView(frame:effect.bounds);view.autoresizingMask=[.width,.height];effect.addSubview(view);p.contentView=effect
            view.onSelect = { [weak self] item in self?.apply(item) };view.onCancel = { [weak self] in self?.hide() }
            view.onDragInputs = { [weak self] urls in guard let self else { return };self.show(inputs:urls,at:NSEvent.mouseLocation,keyboard:self.keyboardMode) }
            self.panel=p;self.wheel=view
            keyWindowObserver=NotificationCenter.default.addObserver(forName:NSWindow.didResignKeyNotification,object:p,queue:.main) { [weak self] _ in Task { @MainActor in if self?.keyboardMode == true { self?.hide() } } }
        }
        wheel?.items=items;wheel?.inputs=inputs;wheel?.selected=keyboard ? (items.isEmpty ? nil:0):nil
        if !exists,let p=panel {
            let screen=NSScreen.screens.first(where:{$0.frame.contains(point)}) ?? NSScreen.main
            let visible=screen?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900)
            let x=min(max(visible.minX+4,point.x-p.frame.width/2),visible.maxX-p.frame.width-4)
            let y=min(max(visible.minY+4,point.y-p.frame.height/2),visible.maxY-p.frame.height-4)
            p.setFrameOrigin(NSPoint(x:x,y:y))
        }
        panel?.alphaValue=1;panel?.orderFrontRegardless()
        wheel?.needsDisplay=true;wheel?.updateAccessibility()
        if keyboard { panel?.makeKey();panel?.makeFirstResponder(wheel) }
    }
    private func apply(_ item:WheelItem) { hide();onConvert?(inputs,item.format) }
    func hide() { keyboardMode=false;panel?.orderOut(nil) }
    func endDrag() { if !keyboardMode { hide() } }
    func hideIfOutside(_ point:NSPoint) { if isVisible,panel?.frame.contains(point) == false { hide() } }
    deinit { if let keyWindowObserver { NotificationCenter.default.removeObserver(keyWindowObserver) } }
}

final class WheelView:NSView {
    var items:[WheelItem]=[] { didSet { labelLayouts.removeAll() } }
    private var labelLayouts:[Int:WheelLabelLayout.Content]=[:]
    private var labelBounds=NSRect.zero
    var inputs:[URL]=[]
    var selected:Int? {
        didSet {
            guard oldValue != selected else { return }
            needsDisplay=true
            if selected != nil { WheelFeedback.shared.selectionChanged() }
        }
    }
    var onSelect:((WheelItem)->Void)?
    var onCancel:(()->Void)?
    var onDragInputs:(([URL])->Void)?
    private var tracking:NSTrackingArea?
    override var acceptsFirstResponder:Bool { true }
    override init(frame:NSRect) { super.init(frame:frame);registerForDraggedTypes([.fileURL]);setAccessibilityRole(.group);setAccessibilityLabel("Nashi Mini conversion wheel") }
    required init?(coder:NSCoder) { fatalError() }
    override func updateTrackingAreas() { if let tracking { removeTrackingArea(tracking) };tracking=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseMoved,.mouseEnteredAndExited,.inVisibleRect],owner:self);addTrackingArea(tracking!);super.updateTrackingAreas() }
    var geometry:WheelGeometry { WheelGeometry(bounds:bounds,count:items.count) }
    var center:NSPoint { geometry.center }
    var radius:CGFloat { geometry.radius }
    var inner:CGFloat { geometry.inner }
    func petal(_ index:Int)->NSBezierPath { geometry.petal(index) }
    override func draw(_ dirtyRect:NSRect) {
        if labelBounds != bounds { labelLayouts.removeAll();labelBounds=bounds }
        let backdrop=NSBezierPath(ovalIn:bounds.insetBy(dx:bounds.width*0.035,dy:bounds.height*0.035));NSColor.windowBackgroundColor.withAlphaComponent(0.22).setFill();backdrop.fill()
        NSColor.gray.withAlphaComponent(0.17).setStroke();backdrop.lineWidth=0.7;backdrop.stroke()
        for (i,item) in items.enumerated() {
            let path=petal(i)
            if selected==i,let gradient=NSGradient(starting:WheelColors.gold,ending:WheelColors.goldEnd) { gradient.draw(in:path,angle:80) }
            else { NSColor.controlBackgroundColor.withAlphaComponent(0.88).setFill();path.fill() }
            NSColor.gray.withAlphaComponent(0.24).setStroke();path.lineWidth=0.7;path.stroke()
            let foreground=selected==i ? WheelColors.ink:NSColor.labelColor
            let scale=min(bounds.width,bounds.height)/320
            let baseFont=NSFont.systemFont(ofSize:13*scale,weight:.semibold)
            let font=baseFont.fontDescriptor.withDesign(.rounded).flatMap{NSFont(descriptor:$0,size:baseFont.pointSize)} ?? baseFont
            let layout:WheelLabelLayout.Content
            if let cached=labelLayouts[i] { layout=cached }
            else {
                layout=WheelLabelLayout.fitted(item.title,font:font,color:.labelColor,
                                               inside:path,centers:geometry.labelCenters(i),
                                               maximumWidth:84*scale,iconSize:nil,scale:scale)
                labelLayouts[i]=layout
            }
            WheelLabelLayout.draw(layout,color:foreground)
        }
        let disc=geometry.disc;NSColor.controlBackgroundColor.setFill();disc.fill()
        let title=selected.flatMap{items.indices.contains($0) ? items[$0].title:nil} ?? (items.isEmpty ? "No formats":"Convert")
        let layout=WheelLabelLayout.fitted(title,font:NSFont.systemFont(ofSize:(items.isEmpty ? 10:11)*geometry.scale,weight:.semibold),
                                           color:.labelColor,inside:disc,centers:[center],
                                           maximumWidth:inner*2-16*geometry.scale,scale:geometry.scale)
        WheelLabelLayout.draw(layout)
    }
    func updateSelection(_ point:NSPoint) { selected=items.indices.first{petal($0).contains(point)} }
    func updateAccessibility() {
        let children=items.enumerated().map { index,item -> WheelAccessibilityItem in
            let child=WheelAccessibilityItem();child.setAccessibilityRole(.button);child.setAccessibilityEnabled(true);child.setAccessibilityLabel(item.title);child.setAccessibilityParent(self)
            if let window { child.setAccessibilityFrame(window.convertToScreen(convert(petal(index).bounds,to:nil))) }
            child.activate = { [weak self] in guard let self else { return false };self.onSelect?(item);return true };return child
        }
        setAccessibilityChildren(children)
    }
    override func mouseMoved(with event:NSEvent) { updateSelection(convert(event.locationInWindow,from:nil)) }
    override func mouseExited(with event:NSEvent) { selected=nil }
    override func mouseDown(with event:NSEvent) { updateSelection(convert(event.locationInWindow,from:nil));if let selected { onSelect?(items[selected]) } else { onCancel?() } }
    override func keyDown(with event:NSEvent) {
        switch event.keyCode {
        case 53,48: onCancel?()
        case 123,126: if !items.isEmpty { selected=((selected ?? 0)-1+items.count)%items.count }
        case 124,125: if !items.isEmpty { selected=((selected ?? -1)+1)%items.count }
        case 115: selected=items.isEmpty ? nil:0
        case 119: selected=items.isEmpty ? nil:items.count-1
        case 36,49: if let selected { onSelect?(items[selected]) }
        default: break
        }
    }
    override func scrollWheel(with event:NSEvent) { onCancel?() }
    private func incoming(_ sender:NSDraggingInfo)->Bool {
        let urls=MainActor.assumeIsolated { WheelController.fileURLs(from:sender.draggingPasteboard) }
        guard !urls.isEmpty else { return false }
        if urls != inputs { onDragInputs?(urls) }
        // show() refuses new inputs while a job runs; the petals still belong to the old ones.
        guard urls == inputs else { selected=nil;return false }
        updateSelection(convert(sender.draggingLocation,from:nil));return true
    }
    override func draggingEntered(_ sender:NSDraggingInfo)->NSDragOperation { incoming(sender) ? .copy:[] }
    override func draggingUpdated(_ sender:NSDraggingInfo)->NSDragOperation { incoming(sender) ? .copy:[] }
    override func draggingExited(_ sender:NSDraggingInfo?) { selected=nil }
    override func prepareForDragOperation(_ sender:NSDraggingInfo)->Bool { selected != nil }
    override func performDragOperation(_ sender:NSDraggingInfo)->Bool { guard incoming(sender),let selected,items.indices.contains(selected) else { onCancel?();return false };onSelect?(items[selected]);return true }
    override func concludeDragOperation(_ sender:NSDraggingInfo?) { onCancel?() }
}
final class WheelAccessibilityItem:NSAccessibilityElement {
    var activate:(()->Bool)?
    override func accessibilityPerformPress()->Bool { activate?() ?? false }
}
