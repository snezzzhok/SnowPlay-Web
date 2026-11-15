import AppKit
import SnowCore
final class StickerToolButton:NSButton {
 var handler:(()->Void)?
 init(_ title:String,_ action:@escaping()->Void){super.init(frame:.zero);self.title=title;handler=action;target=self;self.action=#selector(run);bezelStyle = .rounded;controlSize = .small;font = .systemFont(ofSize:11,weight:.medium)}
 required init?(coder:NSCoder){fatalError()}
 @objc private func run(){handler?()}
}
final class StickerEditorView:NSView {
 weak var studio:StickerStudio?
 weak var display:DisplayOverlay?
 private var tracking:NSTrackingArea?
 private var tools:NSStackView?
 override var acceptsFirstResponder:Bool {true}
 override func viewDidMoveToWindow(){super.viewDidMoveToWindow();guard tools==nil else{return}
  let row=NSStackView();row.orientation = .horizontal;row.spacing=4;row.translatesAutoresizingMaskIntoConstraints=false
  func button(_ title:String,_ body:@escaping()->Void){row.addArrangedSubview(StickerToolButton(title,body))}
  button("−"){[weak self] in self?.scale(0.9)};button("+"){[weak self] in self?.scale(1.1)}
  button("Rotate"){[weak self] in self?.transform("rotation",delta:15)}
  button("Flip H"){[weak self] in guard let s=self?.studio,let item=s.settings.items.first(where:{$0.id==s.selected}) else{return};_=s.apply("transform",["flipX":!item.flipX])}
  button("Flip V"){[weak self] in guard let s=self?.studio,let item=s.settings.items.first(where:{$0.id==s.selected}) else{return};_=s.apply("transform",["flipY":!item.flipY])}
  for (label,op) in [("Copy","duplicate"),("Delete","delete"),("Undo","undo"),("Redo","redo")] {button(label){[weak self] in _=self?.studio?.apply(op)}}
  button("Lock"){[weak self] in guard let s=self?.studio,let item=s.settings.items.first(where:{$0.id==s.selected}) else{return};_=s.apply("transform",["locked":!item.locked])}
  button("Done"){[weak self] in self?.studio?.finish()}
  addSubview(row);NSLayoutConstraint.activate([row.centerXAnchor.constraint(equalTo:centerXAnchor),row.topAnchor.constraint(equalTo:topAnchor,constant:14)]);tools=row
 }
 func scale(_ factor:Double){guard let s=studio,let item=s.settings.items.first(where:{$0.id==s.selected}) else{return};_=s.apply("transform",["scale":item.scale*factor])}
 func transform(_ key:String,delta:Double){guard let s=studio,let item=s.settings.items.first(where:{$0.id==s.selected}) else{return};_=s.apply("transform",[key:item.rotation+delta])}
 override func updateTrackingAreas(){if let tracking{removeTrackingArea(tracking)};let area=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseEnteredAndExited,.mouseMoved,.inVisibleRect],owner:self,userInfo:nil);addTrackingArea(area);tracking=area;super.updateTrackingAreas()}
 override func resetCursorRects(){addCursorRect(bounds,cursor:studio?.placing == nil ? .openHand:.crosshair)}
 override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
 private func send(_ kind:String,_ e:NSEvent){guard let d=display,let s=studio,let window else{return};let p=window.convertPoint(toScreen:e.locationInWindow);s.pointer(kind,at:Vec(p.x,(s.owner?.input.primaryHeight ?? 0)-p.y),display:d,shift:e.modifierFlags.contains(.shift));needsDisplay=true}
 override func mouseMoved(with e:NSEvent){send("move",e)}
 override func mouseDown(with e:NSEvent){send("down",e)}
 override func mouseDragged(with e:NSEvent){send("drag",e)}
 override func mouseUp(with e:NSEvent){send("up",e)}
 override func scrollWheel(with e:NSEvent){if e.modifierFlags.contains(.shift){transform("rotation",delta:e.scrollingDeltaY)}else{scale(exp(Double(e.scrollingDeltaY)*0.015))}}
 override func keyDown(with e:NSEvent){
  if e.keyCode==53 {studio?.finish(cancelDrag:true);return}
  if [51,117].contains(e.keyCode){_=studio?.apply("delete");return}
  let key=e.charactersIgnoringModifiers?.lowercased() ?? ""
  if e.modifierFlags.contains(.command),key=="z" {_=studio?.apply(e.modifierFlags.contains(.shift) ? "redo":"undo");return}
  if e.modifierFlags.contains(.command),key=="d" {_=studio?.apply("duplicate");return}
  if key=="+" || key=="="{scale(1.1);return};if key=="-"{scale(0.9);return};if key=="r"{transform("rotation",delta:15);return}
  super.keyDown(with:e)
 }
 override func draw(_ dirtyRect:NSRect){
  NSColor(calibratedWhite:1,alpha:0.012).setFill();bounds.fill()
  guard let s=studio,let d=display,let c=NSGraphicsContext.current?.cgContext else{return}
  if let item=s.candidate,item.anchor.screen==d.id,let drawing=s.makeDrawing(item,now:0,animated:false,preview:true){drawing.draw(c);let point=d.local(s.resolve(item)?.point ?? s.lastMouse);NSColor(calibratedRed:0.3,green:0.95,blue:0.75,alpha:1).setStroke();let ring=NSBezierPath(ovalIn:NSRect(x:point.x-7,y:point.y-7,width:14,height:14));ring.lineWidth=2;ring.stroke()}
  if let selected=s.selected,let drawing=s.drawings[selected] {
   let b=drawing.bounds;NSColor(calibratedRed:0.3,green:0.95,blue:0.75,alpha:1).setStroke();let frame=NSBezierPath(rect:NSRect(x:b.x-d.rect.x-3,y:d.rect.maxY-b.maxY-3,width:b.width+6,height:b.height+6));frame.setLineDash([4,3],count:2,phase:0);frame.lineWidth=1.5;frame.stroke()
  }
  let text=s.placing == nil ? "Decorations Edit Mode · Drag · Scroll to resize · Shift: snap · Esc: done":"Choose a spot · Click to place · Green ring: anchor · Esc: cancel"
  let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:12,weight:.medium),.foregroundColor:NSColor.white]
  let size=(text as NSString).size(withAttributes:attrs),rect=NSRect(x:max(8,(bounds.width-size.width-24)/2),y:bounds.height-79,width:min(bounds.width-16,size.width+24),height:26)
  NSColor(calibratedRed:0.1,green:0.21,blue:0.25,alpha:0.95).setFill();NSBezierPath(roundedRect:rect,xRadius:8,yRadius:8).fill();(text as NSString).draw(at:NSPoint(x:rect.minX+12,y:rect.minY+6),withAttributes:attrs)
 }
}
