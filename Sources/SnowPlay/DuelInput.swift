import AppKit
import SnowCore
final class DuelInputView:NSView {
    var aim:((Double)->Void)?,aimPoint:((Vec)->Void)?,fire:(()->Void)?,exit:(()->Void)?
    private var tracking:NSTrackingArea?
    override var acceptsFirstResponder:Bool {true}
    override func acceptsFirstMouse(for event:NSEvent?)->Bool {true}
    override func updateTrackingAreas(){
        if let area=tracking {removeTrackingArea(area)}
        let area=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseMoved,.inVisibleRect],owner:self,userInfo:nil);addTrackingArea(area);tracking=area;super.updateTrackingAreas()
    }
    override func draw(_ dirtyRect:NSRect){NSColor(calibratedWhite:1,alpha:0.01).setFill();bounds.fill()}
    override func resetCursorRects(){addCursorRect(bounds,cursor:.crosshair)}
    override func mouseMoved(with event:NSEvent){let p=convert(event.locationInWindow,from:nil);if let aimPoint {aimPoint(Vec(p.x,bounds.height-p.y))}else{aim?(clamp(p.x/max(1,bounds.width),0,1))}}
    override func mouseDragged(with event:NSEvent){mouseMoved(with:event)}
    override func mouseDown(with event:NSEvent){window?.makeFirstResponder(self);mouseMoved(with:event);fire?()}
    override func keyDown(with event:NSEvent){if event.keyCode==53 {exit?()}else if event.keyCode==49 {fire?()}else{super.keyDown(with:event)}}
}
final class DuelInputPanel:NSPanel {
    override var canBecomeKey:Bool {true}
    override var canBecomeMain:Bool {false}
    init(area:Rect,primaryHeight:Double,aim:@escaping(Vec)->Void,fire:@escaping()->Void,exit:@escaping()->Void){
        super.init(contentRect:NSRect(x:area.x,y:primaryHeight-area.maxY,width:area.width,height:area.height),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        isOpaque=false;backgroundColor = .clear;hasShadow=false;isReleasedWhenClosed=false;hidesOnDeactivate=false;acceptsMouseMovedEvents=true
        level = .floating;collectionBehavior=[.canJoinAllSpaces,.stationary,.ignoresCycle]
        let view=DuelInputView(frame:NSRect(origin:.zero,size:frame.size));view.aimPoint={aim(Vec(area.x+$0.x,area.y+$0.y))};view.fire=fire;view.exit=exit;contentView=view
        makeFirstResponder(view)
    }
}
