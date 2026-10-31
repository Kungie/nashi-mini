import AppKit
import NashiCore

final class WheelPanel:NSPanel { override var canBecomeKey:Bool { true } }
private enum WheelColors {
    static let gold=NSColor(srgbRed:0.89,green:0.72,blue:0.35,alpha:1)
    static let goldEnd=NSColor(srgbRed:0.96,green:0.82,blue:0.49,alpha:1)
    static let ink=NSColor(srgbRed:0.20,green:0.25,blue:0.14,alpha:1)
}

/// The wheel has three levels: formats, tools, and a tool's presets.
/// Clicking the center moves between them, so one button reaches everything.
@MainActor final class WheelController {
    private enum Level { case formats,tools,presets([WheelEntry]) }
    var onAction:((WheelEntry,[URL])->Void)?
    private var panel:NSPanel?
    private var wheel:WheelView?
    private var inputs:[URL]=[]
    private var level=Level.formats
    private var clickMode=false
    var isVisible:Bool { panel?.isVisible == true }

    static func fileURLs(from board:NSPasteboard)->[URL] {
        board.readObjects(forClasses:[NSURL.self],options:[.urlReadingFileURLsOnly:true]) as? [URL] ?? []
    }
    func show(inputs:[URL],at point:NSPoint,keyboard:Bool) {
        guard !inputs.isEmpty else { return }
        WheelFeedback.shared.prepare()
        self.inputs=inputs;clickMode=keyboard
        if panel == nil { build() }
        present(ToolMenu.formats(for:inputs).isEmpty ? .tools:.formats)
        if let p=panel,!p.isVisible {
            let screen=NSScreen.screens.first(where:{$0.frame.contains(point)}) ?? NSScreen.main
            let visible=screen?.visibleFrame ?? NSRect(x:0,y:0,width:1440,height:900)
            let x=min(max(visible.minX+4,point.x-p.frame.width/2),visible.maxX-p.frame.width-4)
            let y=min(max(visible.minY+4,point.y-p.frame.height/2),visible.maxY-p.frame.height-4)
            p.setFrameOrigin(NSPoint(x:x,y:y))
        }
        panel?.orderFrontRegardless()
    }
    private func build() {
        let size:CGFloat=320
        let p=WheelPanel(contentRect:NSRect(x:0,y:0,width:size,height:size),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        p.backgroundColor = .clear;p.isOpaque=false;p.hasShadow=false;p.level = .statusBar;p.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary];p.hidesOnDeactivate=false
        let effect=NSVisualEffectView(frame:NSRect(x:0,y:0,width:size,height:size));effect.material = .popover;effect.blendingMode = .behindWindow;effect.state = .active;effect.wantsLayer=true;effect.layer?.cornerRadius=size/2;effect.layer?.masksToBounds=true
        let view=WheelView(frame:effect.bounds);view.autoresizingMask=[.width,.height];effect.addSubview(view);p.contentView=effect
        view.onSelect = { [weak self] entry in self?.choose(entry) };view.onCancel = { [weak self] in self?.hide() };view.onCenter = { [weak self] in self?.center() }
        view.onDragInputs = { [weak self] urls in guard let self else { return };self.inputs=urls;self.present(ToolMenu.formats(for:urls).isEmpty ? .tools:.formats) }
        panel=p;wheel=view
    }
    private func present(_ next:Level) {
        level=next
        let formats=ToolMenu.formats(for:inputs),tools=ToolMenu.tools(for:inputs)
        switch next {
        case .formats: wheel?.configure(formats,center:tools.isEmpty ? "Convert":"Tools ›")
        case .tools: wheel?.configure(tools,center:formats.isEmpty ? "Tools":"‹ Convert")
        case .presets(let entries): wheel?.configure(entries,center:"‹ Back")
        }
    }
    /// Finder keeps focus while the wheel is open, so its keys arrive from the event tap.
    func handleKey(_ code:Int64)->Bool {
        guard isVisible,[53,48,123,124,125,126,115,119,36,49].contains(code) else { return false }
        wheel?.press(UInt16(code));return true
    }
    private func center() {
        // A file dropped on the center keeps the wheel open for clicking.
        clickMode=true
        switch level {
        case .formats: if !ToolMenu.tools(for:inputs).isEmpty { present(.tools) }
        case .tools: if !ToolMenu.formats(for:inputs).isEmpty { present(.formats) }
        case .presets: present(.tools)
        }
    }
    private func choose(_ entry:WheelEntry) {
        if case .menu(let entries)=entry.action { present(.presets(entries));return }
        let chosen=inputs;hide();onAction?(entry,chosen)
    }
    #if DEBUG
    func showToolsLevel() { present(.tools) }
    #endif
    func hide() { clickMode=false;panel?.orderOut(nil) }
    func endDrag() { if !clickMode { hide() } }
    func hideIfOutside(_ point:NSPoint) { if isVisible,panel?.frame.contains(point) == false { hide() } }
}

final class WheelView:NSView {
    private(set) var items:[WheelEntry]=[]
    private var centerTitle=""
    private var centerHovered=false { didSet { if oldValue != centerHovered { needsDisplay=true } } }
    private var labelLayouts:[Int:WheelLabelLayout.Content]=[:]
    private var labelBounds=NSRect.zero
    var selected:Int? {
        didSet {
            guard oldValue != selected else { return }
            needsDisplay=true
            if selected != nil { WheelFeedback.shared.selectionChanged() }
        }
    }
    var onSelect:((WheelEntry)->Void)?
    var onCancel:(()->Void)?
    var onCenter:(()->Void)?
    var onDragInputs:(([URL])->Void)?
    private var tracking:NSTrackingArea?
    override var acceptsFirstResponder:Bool { true }
    override init(frame:NSRect) { super.init(frame:frame);registerForDraggedTypes([.fileURL]);setAccessibilityRole(.group);setAccessibilityLabel("Nashi Mini conversion wheel") }
    required init?(coder:NSCoder) { fatalError() }
    override func updateTrackingAreas() { if let tracking { removeTrackingArea(tracking) };tracking=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseMoved,.mouseEnteredAndExited,.inVisibleRect],owner:self);addTrackingArea(tracking!);super.updateTrackingAreas() }
    func configure(_ entries:[WheelEntry],center:String) {
        items=entries;centerTitle=center;labelLayouts.removeAll();selected=nil;needsDisplay=true;updateAccessibility()
    }
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
            let source=item.symbol.flatMap { NSImage(systemSymbolName:$0,accessibilityDescription:item.title) }
            let baseFont=NSFont.systemFont(ofSize:(source == nil ? 13:9.5)*scale,weight:.semibold)
            let font=baseFont.fontDescriptor.withDesign(.rounded).flatMap{NSFont(descriptor:$0,size:baseFont.pointSize)} ?? baseFont
            let layout:WheelLabelLayout.Content
            if let cached=labelLayouts[i] { layout=cached }
            else {
                layout=WheelLabelLayout.fitted(source == nil ? item.title:item.title.uppercased(),font:font,color:.labelColor,
                                               inside:path,centers:geometry.labelCenters(i),
                                               maximumWidth:84*scale,iconSize:source == nil ? nil:20*scale,scale:scale)
                labelLayouts[i]=layout
            }
            if let source,let slot=layout.iconRect {
                let image=source.withSymbolConfiguration(.init(paletteColors:[foreground])) ?? source
                image.isTemplate=false
                let fit=min(slot.width/max(1,image.size.width),slot.height/max(1,image.size.height))
                let size=NSSize(width:image.size.width*fit,height:image.size.height*fit)
                image.draw(in:NSRect(x:slot.midX-size.width/2,y:slot.midY-size.height/2,width:size.width,height:size.height))
            }
            WheelLabelLayout.draw(layout,color:foreground)
        }
        let disc=geometry.disc;(centerHovered ? WheelColors.gold.withAlphaComponent(0.35):NSColor.controlBackgroundColor).setFill();disc.fill()
        let title=selected.flatMap{items.indices.contains($0) ? items[$0].title:nil} ?? (items.isEmpty ? "No actions":centerTitle)
        let layout=WheelLabelLayout.fitted(title,font:NSFont.systemFont(ofSize:(items.isEmpty ? 10:11)*geometry.scale,weight:.semibold),
                                           color:.labelColor,inside:disc,centers:[center],
                                           maximumWidth:inner*2-16*geometry.scale,scale:geometry.scale)
        WheelLabelLayout.draw(layout)
    }
    func updateSelection(_ point:NSPoint) { selected=items.indices.first{petal($0).contains(point)};centerHovered=geometry.disc.contains(point) }
    func updateAccessibility() {
        let children=items.enumerated().map { index,item -> WheelAccessibilityItem in
            let child=WheelAccessibilityItem();child.setAccessibilityRole(.button);child.setAccessibilityEnabled(true);child.setAccessibilityLabel(item.title);child.setAccessibilityParent(self)
            if let window { child.setAccessibilityFrame(window.convertToScreen(convert(petal(index).bounds,to:nil))) }
            child.activate = { [weak self] in guard let self else { return false };self.onSelect?(item);return true };return child
        }
        setAccessibilityChildren(children)
    }
    override func mouseMoved(with event:NSEvent) { updateSelection(convert(event.locationInWindow,from:nil)) }
    override func mouseExited(with event:NSEvent) { selected=nil;centerHovered=false }
    override func mouseDown(with event:NSEvent) { updateSelection(convert(event.locationInWindow,from:nil));if centerHovered { onCenter?() } else if let selected { onSelect?(items[selected]) } else { onCancel?() } }
    override func acceptsFirstMouse(for event:NSEvent?)->Bool { true }
    func press(_ code:UInt16) {
        switch code {
        case 53: onCancel?()
        case 48: onCenter?()
        case 123,126: if !items.isEmpty { selected=((selected ?? 0)-1+items.count)%items.count }
        case 124,125: if !items.isEmpty { selected=((selected ?? -1)+1)%items.count }
        case 115: selected=items.isEmpty ? nil:0
        case 119: selected=items.isEmpty ? nil:items.count-1
        case 36,49: if let selected { onSelect?(items[selected]) }
        default: break
        }
    }
    private var draggedInputs:[URL]=[]
    private func incoming(_ sender:NSDraggingInfo)->Bool {
        let urls=MainActor.assumeIsolated { WheelController.fileURLs(from:sender.draggingPasteboard) }
        guard !urls.isEmpty else { return false }
        if urls != draggedInputs { draggedInputs=urls;onDragInputs?(urls) }
        updateSelection(convert(sender.draggingLocation,from:nil));return true
    }
    override func draggingEntered(_ sender:NSDraggingInfo)->NSDragOperation { incoming(sender) ? .copy:[] }
    override func draggingUpdated(_ sender:NSDraggingInfo)->NSDragOperation { incoming(sender) ? .copy:[] }
    override func draggingExited(_ sender:NSDraggingInfo?) { selected=nil;centerHovered=false }
    override func prepareForDragOperation(_ sender:NSDraggingInfo)->Bool { selected != nil || centerHovered }
    override func performDragOperation(_ sender:NSDraggingInfo)->Bool {
        guard incoming(sender) else { onCancel?();return false }
        if centerHovered { onCenter?();return true }
        guard let selected,items.indices.contains(selected) else { onCancel?();return false }
        onSelect?(items[selected]);return true
    }
}
final class WheelAccessibilityItem:NSAccessibilityElement {
    var activate:(()->Bool)?
    override func accessibilityPerformPress()->Bool { activate?() ?? false }
}
