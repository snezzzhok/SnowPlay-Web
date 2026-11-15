import AppKit
import SnowCore

enum EditorMode: String { case garlandDelete, decorations, none, tree, ornaments, garland, garlandWindow, snow, snowballPlay, snowmen, hat }
final class InputPanel: NSPanel {
    var placement=false
    override var canBecomeKey: Bool { placement }
    override var canBecomeMain: Bool { false }
}
final class InputView: NSView {
    var anchorEditor=false,addingAnchor=false
    var anchorPoints:(()->[NSPoint])?
    private var anchorDrag:Int?
    var showsAnchor=false
    var singleAnchor=false
    var glove=false,branchAnchors=false,playSnow=false,editSnowmen=false
    private var gloveTracking:NSTrackingArea?
    private lazy var mitten:NSCursor? = {
        guard let cg=AssetManager.shared.image("shovel_cursor") else{return nil}
        return NSCursor(image:NSImage(cgImage:cg,size:NSSize(width:36,height:36)),hotSpot:NSPoint(x:13,y:29))
    }()
    override func updateTrackingAreas() {
        if let area=gloveTracking {removeTrackingArea(area)}
        if glove || placing || playSnow || anchorEditor {let area=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseEnteredAndExited,.mouseMoved,.inVisibleRect],owner:self,userInfo:nil);addTrackingArea(area);gloveTracking=area}
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event:NSEvent) {if anchorEditor {previewPoint=convert(event.locationInWindow,from:nil);NSCursor.crosshair.set();needsDisplay=true}else if placing {movePreview(convert(event.locationInWindow,from:nil))}else if glove {mitten?.set()}}
    override func mouseExited(with event:NSEvent) {if glove || placing || playSnow || anchorEditor {NSCursor.arrow.set()}}
    override func mouseMoved(with event:NSEvent) {if anchorEditor {previewPoint=convert(event.locationInWindow,from:nil);NSCursor.crosshair.set();needsDisplay=true};if playSnow {eventHandler?("hover",event)};if placing {movePreview(convert(event.locationInWindow,from:nil))}else if glove {mitten?.set()}}
    override func resetCursorRects() {
        if anchorEditor {addCursorRect(bounds,cursor:.crosshair)}
        else if placing {addCursorRect(bounds,cursor:placementCursor)}
        else if glove,let cg=AssetManager.shared.image("shovel_cursor") {let image=NSImage(cgImage:cg,size:NSSize(width:36,height:36));addCursorRect(bounds,cursor:NSCursor(image:image,hotSpot:NSPoint(x:13,y:29)))}
        else if playSnow {addCursorRect(bounds,cursor:.crosshair)}else{super.resetCursorRects()}
    }
    var placementAsset:String?,placementTitle="",placementHeight=80.0
    var sculptCount=0
    var sculptBalls:(()->[Snowball])?,sculptGround:(()->SnowSurface?)?,sculptLocal:((Vec)->NSPoint)?
    var landing:((NSPoint)->NSPoint)?,cancel:(()->Void)?
    private var previewPoint:NSPoint?
    private var placing:Bool {placementAsset != nil}
    private lazy var placementCursor:NSCursor = {
        let image=NSImage(size:NSSize(width:48,height:48));image.lockFocus()
        NSColor.white.setStroke();let ring=NSBezierPath(ovalIn:NSRect(x:1,y:37,width:10,height:10));ring.lineWidth=2;ring.stroke()
        if let id=placementAsset,let cg=AssetManager.shared.image(id){NSImage(cgImage:cg,size:.zero).draw(in:NSRect(x:12,y:0,width:34,height:42))}
        image.unlockFocus();return NSCursor(image:image,hotSpot:NSPoint(x:6,y:6))
    }()
    func showPlacementCursor(){if placing {movePreview(convert(window?.mouseLocationOutsideOfEventStream ?? .zero,from:nil))}}
    private func movePreview(_ point:NSPoint){previewPoint=point;placementCursor.set();needsDisplay=true}
    override var acceptsFirstResponder:Bool {placing || glove || playSnow || editSnowmen || anchorEditor}
    override func keyDown(with event:NSEvent){if placing || glove || playSnow || editSnowmen || anchorEditor,event.keyCode==53 {cancel?()}else{super.keyDown(with:event)}}
    var eventHandler: ((String, NSEvent)->Void)?
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        if anchorEditor {
            let point=convert(event.locationInWindow,from:nil),anchors=anchorPoints?() ?? []
            anchorDrag=anchors.indices.first{hypot(anchors[$0].x-point.x,anchors[$0].y-point.y)<16}
        }
        if glove {mitten?.set()};eventHandler?("down",event) }
    override func mouseDragged(with event: NSEvent) { if anchorEditor {previewPoint=convert(event.locationInWindow,from:nil);needsDisplay=true};if glove {mitten?.set()};eventHandler?("drag",event) }
    override func mouseUp(with event: NSEvent) { eventHandler?("up",event);anchorDrag=nil }
    func anchorEventKind()->String? {if let index=anchorDrag{return "garland-anchor@\(index)"};return addingAnchor ? "garland-place":nil}
    override func draw(_ dirtyRect: NSRect) {
        // WindowServer may pass clicks through completely transparent pixels.
        // These windows already have tightly bounded, intentional hit regions.
        NSColor(calibratedWhite:1,alpha:0.01).setFill();bounds.fill()
        if anchorEditor {
            let points=anchorPoints?() ?? [],mint=NSColor(calibratedRed:0.4,green:0.95,blue:0.83,alpha:1)
            for (i,p) in points.enumerated() {
                let ring=NSBezierPath(ovalIn:NSRect(x:p.x-12,y:p.y-12,width:24,height:24));NSColor(calibratedRed:0.08,green:0.2,blue:0.25,alpha:0.96).setFill();ring.fill();mint.setStroke();ring.lineWidth=2;ring.stroke()
                let text="\(i+1)" as NSString,attributes:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:12,weight:.bold),.foregroundColor:NSColor.white],size=text.size(withAttributes:attributes)
                text.draw(at:NSPoint(x:p.x-size.width/2,y:p.y-size.height/2),withAttributes:attributes)
            }
            if addingAnchor,let point=previewPoint {
                mint.setStroke();let ring=NSBezierPath(ovalIn:NSRect(x:point.x-7,y:point.y-7,width:14,height:14));ring.lineWidth=2;ring.stroke()
                if let last=points.last {let line=NSBezierPath();line.move(to:last);line.line(to:point);line.setLineDash([4,5],count:2,phase:0);line.stroke()}
                let text="Anchor \(points.count+1) · Click to attach" as NSString
                let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:12,weight:.semibold),.foregroundColor:NSColor.white],size=text.size(withAttributes:attrs)
                let label=NSRect(x:clamp(point.x+18,8,max(8,bounds.width-size.width-24)),y:clamp(point.y+20,8,max(8,bounds.height-34)),width:size.width+16,height:27)
                NSColor(calibratedRed:0.08,green:0.2,blue:0.25,alpha:0.96).setFill();NSBezierPath(roundedRect:label,xRadius:7,yRadius:7).fill();text.draw(at:NSPoint(x:label.minX+8,y:label.minY+6),withAttributes:attrs)
            };return
        }
        if placing {
            NSColor(calibratedRed:0.18,green:0.55,blue:0.57,alpha:0.09).setFill();NSRect(x:0,y:0,width:bounds.width,height:110).fill()
            let point=previewPoint ?? convert(window?.mouseLocationOutsideOfEventStream ?? .zero,from:nil),base=landing?(point) ?? NSPoint(x:point.x,y:16),h=CGFloat(placementHeight)
            NSColor(calibratedRed:0.5,green:1,blue:0.82,alpha:0.85).setStroke();let marker=NSBezierPath(ovalIn:NSRect(x:base.x-25,y:base.y-3,width:50,height:10));marker.lineWidth=2;marker.stroke()
            if let id=placementAsset,let cg=AssetManager.shared.image(id) {
                let width=h*CGFloat(cg.width)/CGFloat(cg.height)
                NSImage(cgImage:cg,size:.zero).draw(in:NSRect(x:base.x-width/2,y:base.y,width:width,height:h),from:.zero,operation:.sourceOver,fraction:0.65)
            }
            let text=placementTitle+" · Click to place · Esc to cancel",font=NSFont.systemFont(ofSize:14,weight:.semibold)
            let attributes:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:NSColor.white],size=(text as NSString).size(withAttributes:attributes)
            let label=NSRect(x:max(10,min(bounds.width-size.width-34,base.x-size.width/2-12)),y:min(bounds.height-48,base.y+h+14),width:min(size.width+24,bounds.width-20),height:34)
            NSColor(calibratedRed:0.08,green:0.19,blue:0.23,alpha:0.97).setFill();NSBezierPath(roundedRect:label,xRadius:10,yRadius:10).fill()
            (text as NSString).draw(at:NSPoint(x:label.minX+12,y:label.minY+8),withAttributes:attributes);return
        }
        NSColor(calibratedRed:0.65,green:0.85,blue:1,alpha:showsAnchor ? 0.14:0.01).setFill(); bounds.fill()
        if glove || playSnow {
            if let ground=sculptGround?(),let local=sculptLocal {NSColor(calibratedRed:0.89,green:0.96,blue:1,alpha:0.98).setFill();for path in SnowCapGeometry.paths(surface:ground,blocked:[],local:{CGPoint(x:local($0).x,y:local($0).y)}) {if let context=NSGraphicsContext.current?.cgContext {context.addPath(path);context.fillPath()}}}
            if let cg=AssetManager.shared.image("snowball_medium"),let local=sculptLocal {
                for ball in sculptBalls?() ?? [] {let p=local(ball.position),size=ball.radius*2.4
                    NSGraphicsContext.saveGraphicsState();let transform=NSAffineTransform();transform.translateX(by:p.x,yBy:p.y);transform.rotate(byRadians:-ball.rotation);transform.concat();NSImage(cgImage:cg,size:.zero).draw(in:NSRect(x:-size/2,y:-size/2,width:size,height:size));NSGraphicsContext.restoreGraphicsState()
                }
            }

        }
        if branchAnchors {NSColor(calibratedRed:1,green:0.88,blue:0.45,alpha:0.8).setStroke();for p in TreeOrnament.branchAnchors {let ring=NSBezierPath(ovalIn:NSRect(x:bounds.width*CGFloat(p.x)-7,y:bounds.height*(1-CGFloat(p.y))-7,width:14,height:14));ring.lineWidth=1.5;ring.stroke()}}
        if singleAnchor {NSColor(calibratedRed:0.65,green:0.9,blue:1,alpha:0.9).setFill();NSBezierPath(ovalIn:bounds.insetBy(dx:4,dy:4)).fill();return}
        if showsAnchor,let image=AssetManager.shared.image("bulb_gold") {
            for f in [0.08,0.5,0.92] { NSImage(cgImage:image,size:NSSize(width:12,height:14)).draw(in:NSRect(x:bounds.width*f-6,y:(bounds.height-14)/2,width:12,height:14)) }
        }
    }
}
final class InteractionController {
    var hatColor="red", mode=EditorMode.none
    var addingGarlandAnchor=false
    var panels: [InputPanel]=[]
    var onEvent: ((String,Vec,String)->Void)?
    var primaryHeight=0.0
    private var dragging=false
    private var placementSignature=""
    var automaticSnowman=true
    var placementModelHeight=80.0
    var sculptSurface:((String)->SnowSurface?)?
    var groundForPlacement:((Double,DisplayOverlay)->Double)?
    var onCancel:(()->Void)?
    func stop() { NSCursor.arrow.set();panels.forEach { $0.close() }; panels=[]; mode = .none; addingGarlandAnchor=false;dragging=false;placementSignature="" }
    func rebuild(displays: [DisplayOverlay], windows: [TrackedWindow], dock: DockGeometry?, decorations: DecorationManager, focus: Bool, icons: [DockIcon]) {
        guard !dragging else { return }
        let placementMode=mode == .tree || (mode == .snow && automaticSnowman)
        let floorMode=mode == .snow || mode == .snowballPlay
        let garlandMode=mode == .garland
        let signature=(placementMode || floorMode || garlandMode) && !focus && !decorations.duelActive ? "\(mode.rawValue)|\(displays.map{String(describing:$0.rect)}.joined())|\(placementModelHeight)|\(addingGarlandAnchor)|\(garlandMode ? String(describing:decorations.placementsForInput):"")|\(garlandMode ? windows.map{"\($0.id):\($0.frame):\($0.isVisible)"}.joined():"")":""
        if !signature.isEmpty,signature==placementSignature,!panels.isEmpty{return}
        placementSignature=signature
        panels.forEach { $0.close() };panels=[]
        guard !focus,!decorations.duelActive,decorations.stories.active == nil else { return }
        for d in displays {
            let occupied=windows.filter(\.isVisible).map { $0.frame.expanded(3) }
            var zones: [(Rect,String)]=[]
            if placementMode {
                zones=[(Rect(d.rect.x,d.rect.y+28,d.rect.width,d.rect.height-28),mode == .tree ? "tree":"snow")]
            } else if mode == .hat, dock?.screenID == d.id, dock?.isVisible == true {
                zones=icons.map { ($0.frame,"hat") }
            } else if mode == .tree {
                zones=[(Rect(d.rect.x+8,d.rect.y+40,d.rect.width-16,d.rect.height-60),"tree")]
            } else if mode == .ornaments,let tree=decorations.states[d.id]?.tree,!tree.isHidden {
                let p=Vec(d.rect.x+tree.position.x,d.rect.maxY-tree.position.y)
                let h=decorations.states[d.id]?.treeHeight ?? 132
                zones=[(Rect(p.x-h/2,p.y-h/2,h,h),"ornaments")]
            } else if mode == .garlandWindow {
                for w in windows where w.isVisible && w.frame.intersects(d.rect){zones.append((Rect(w.frame.x+76,w.frame.y+3,max(1,w.frame.width-88),18),"garland@"+w.id))}
            } else if mode == .garland {
                zones=[(Rect(d.rect.x,d.rect.y+28,d.rect.width,d.rect.height-28),"garland-editor")]
            } else if mode == .snowmen,let s=decorations.states[d.id] {
                zones=s.snowballs.snowmen.map{($0.hitbox.expanded(12),"move-snowman@"+$0.id.uuidString)}
            } else if mode == .snowballPlay {
                zones=[(Rect(d.rect.x,d.rect.maxY-180,d.rect.width,180),"snowball-play")]
            } else if mode == .snow,let area=decorations.states[d.id]?.sculptArea {
                zones=[(area,"snow")]
            } else if mode == .snow, let dock, dock.screenID == d.id {
                switch dock.axis {
                case .horizontal: zones=[(Rect(dock.frame.x,dock.frame.y-48,dock.frame.width,45),"snow")]
                case .verticalLeft: zones=[(Rect(dock.frame.maxX+3,dock.frame.y,45,dock.frame.height),"snow")]
                case .verticalRight: zones=[(Rect(dock.frame.x-48,dock.frame.y,45,dock.frame.height),"snow")]
                }
            }
            if mode == .none, let state=decorations.states[d.id] {
                if state.living.activity=="feed",let ball=state.living.activityBall,state.living.feedCaughtAt==nil {
                    let p=Vec(d.rect.x+ball.position.x,d.rect.maxY-ball.position.y);zones.append((Rect(p.x-15,p.y-15,30,30),"feed-snow"))
                }
                zones += state.snowballs.balls.map { (Rect($0.position.x-$0.radius-8,$0.position.y-$0.radius-8,$0.radius*2+16,$0.radius*2+16),"ball") }
                if state.character == nil,!state.living.busy {zones += state.snowballs.snowmen.map{($0.hitbox.expanded(8),"move-snowman@"+$0.id.uuidString)}}
                if let tree=state.tree,!tree.isHidden,!state.treeRemoving,!state.living.busy {
                    let p=Vec(d.rect.x+tree.position.x,d.rect.maxY-tree.position.y)
                    let h=state.treeHeight;zones.append((Rect(p.x-h*0.35,p.y-h*0.45,h*0.7,h*0.85),"move-tree"))
                }
                zones += state.treePresents.filter{$0.openedAt==nil}.map{(Rect($0.position.x-15,$0.position.y-16,30,32),"tree-gift@"+$0.id)}
                if let p=state.giftPosition,state.giftLanded,state.gift != nil,state.giftOpenedAt==nil { zones.append((Rect(p.x-22,p.y-5,44,44),"gift")) }
            }
            for (zone,kind) in zones {
                let blockers: [Rect]
                if placementMode || floorMode || mode == .snowmen || garlandMode || kind == "hat" {blockers=[]}
                else if kind.hasPrefix("garland-anchor@"),let p=decorations.placementsForInput[d.id],let target=windows.first(where:{$0.id==p.garlandWindow && $0.isVisible}) {blockers=windows.filter{$0.isVisible && $0.z<target.z}.map(\.frame)}
                else if kind.hasPrefix("garland@"),let target=windows.first(where: { $0.id == String(kind.dropFirst(8)) }) {
                    blockers=windows.filter { $0.isVisible && $0.z<target.z }.map { $0.frame.expanded(2) }
                } else { blockers=occupied+(dock?.isVisible == true ? [dock!.frame]:[]) }
                for safe in subtract(zone,blockers:blockers).prefix(48) where safe.width>6 && safe.height>6 {
                    let frame=NSRect(x:safe.x,y:primaryHeight-safe.maxY,width:safe.width,height:safe.height)
                    let panel=InputPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
                    panel.acceptsMouseMovedEvents=true;panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false;panel.isReleasedWhenClosed=false;panel.hidesOnDeactivate=false
                    if placementMode || garlandMode {panel.placement=true;panel.level = .floating}
                    else if kind == "hat" || floorMode || mode == .snowmen {
                        panel.level=NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.dockWindow))+2)
                    } else if kind.hasPrefix("garland@") || (kind.hasPrefix("garland-anchor@") && decorations.placementsForInput[d.id]?.garlandTarget=="window") {
                        panel.level = .floating // Explicit window-decoration editor only.
                    } else {
                        panel.level=NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.desktopIconWindow))+4)
                    }
                    panel.collectionBehavior=[.canJoinAllSpaces,.stationary,.ignoresCycle]
                    let view=InputView(frame:NSRect(origin:.zero,size:frame.size));view.glove=mode == .snow;view.playSnow=mode == .snowballPlay;view.editSnowmen=mode == .snowmen;view.branchAnchors=kind == "ornaments";view.showsAnchor=kind.hasPrefix("garland@");view.singleAnchor=kind.hasPrefix("garland-anchor@");view.identifier=NSUserInterfaceItemIdentifier(kind)
                    if garlandMode {
                        view.anchorEditor=true;view.addingAnchor=addingGarlandAnchor || (decorations.placementsForInput[d.id]?.garland.count ?? 0)<2
                        view.cancel={ [weak self] in self?.onCancel?() }
                        view.anchorPoints={ [weak decorations,weak panel,weak self] in
                            guard let self,let panel,let p=decorations?.placementsForInput[d.id] else{return []}
                            let window=windows.first{$0.id==p.garlandWindow && $0.isVisible},tree=p.tree.map{Vec(d.rect.x+$0.x*d.rect.width,d.rect.y+$0.y*d.rect.height)}
                            return GarlandAttachment.resolve(p,bounds:d.rect,window:window?.frame,tree:tree,treeSize:decorations?.states[d.id]?.treeHeight ?? 132).map{panel.convertPoint(fromScreen:NSPoint(x:$0.x,y:self.primaryHeight-$0.y))}
                        }
                    }
                    if floorMode || mode == .snowmen {
                        view.cancel={ [weak self] in self?.onCancel?() };view.sculptCount=decorations.states[d.id]?.snowballs.balls.count ?? 0;panel.placement=true
                        let playing=mode == .snowballPlay
                        view.sculptBalls={ [weak decorations] in guard let s=decorations?.states[d.id] else{return []};return playing ? s.snowballPlay.balls.map{Snowball(position:$0.position,radius:$0.radius)}:s.snowballs.balls }
                        view.sculptGround={ [weak self] in self?.sculptSurface?(d.id) }
                        view.sculptLocal={ [weak panel,weak self] p in guard let panel,let self else{return .zero};return panel.convertPoint(fromScreen:NSPoint(x:p.x,y:self.primaryHeight-p.y)) }
                    }
                    if placementMode {
                        view.setAccessibilityElement(true);view.setAccessibilityRole(.button);view.setAccessibilityLabel(mode == .tree ? "Choose a tree spot. Click to place, Escape to cancel.":"Choose a snowman spot. Click to place, Escape to cancel.")
                        view.placementAsset=mode == .tree ? "tree_bare":"snowman_complete";view.placementTitle=mode == .tree ? "Your tree goes here":"Your snowman goes here";view.placementHeight=mode == .tree ? placementModelHeight:48
                        view.landing={ [weak panel,weak self] point in
                            guard let panel,let self else{return point};let screen=panel.convertPoint(toScreen:point),margin=self.mode == .tree ? self.placementModelHeight*0.42:40,x=clamp(screen.x,d.rect.x+margin,d.rect.maxX-margin)
                            let ground=self.groundForPlacement?(x,d) ?? d.rect.maxY-12
                            return panel.convertPoint(fromScreen:NSPoint(x:x,y:self.primaryHeight-ground))
                        }
                        view.cancel={ [weak self] in self?.onCancel?() }
                    }
                    view.eventHandler={ [weak self,weak panel,weak decorations] event,e in
                        guard let self,let panel else { return }
                        let ns=panel.convertPoint(toScreen:e.locationInWindow),p=Vec(ns.x,self.primaryHeight-ns.y)
                        if event == "down" { self.dragging=true }
                        let eventKind=kind == "garland-editor" ? (panel.contentView as? InputView)?.anchorEventKind():kind
                        if let eventKind {self.onEvent?(eventKind+":"+event,p,d.id)}
                        if self.mode == .snow || self.mode == .snowballPlay {let v=panel.contentView as? InputView;v?.sculptCount=decorations?.states[d.id]?.snowballs.balls.count ?? 0;v?.needsDisplay=true}
                        if event == "up" { self.dragging=false }
                    }
                    panel.contentView=view;panel.orderFrontRegardless();panels.append(panel)
                    if placementMode || floorMode || mode == .snowmen || garlandMode {panel.makeFirstResponder(view);panel.makeKey();panel.invalidateCursorRects(for:view);if placementMode,panel.frame.contains(NSEvent.mouseLocation){view.showPlacementCursor()}}
                }
            }
        }
    }
    private func subtract(_ source: Rect,blockers: [Rect])->[Rect] {
        var pieces=[source]
        for b in blockers {
            var next: [Rect]=[]
            for r in pieces {
                if !r.intersects(b) { next.append(r);continue }
                let l=max(r.x,b.x),right=min(r.maxX,b.maxX),t=max(r.y,b.y),bottom=min(r.maxY,b.maxY)
                if l>r.x {next.append(Rect(r.x,r.y,l-r.x,r.height))}
                if right<r.maxX {next.append(Rect(right,r.y,r.maxX-right,r.height))}
                if t>r.y {next.append(Rect(l,r.y,right-l,t-r.y))}
                if bottom<r.maxY {next.append(Rect(l,bottom,right-l,r.maxY-bottom))}
            };pieces=next
        };return pieces
    }
}
