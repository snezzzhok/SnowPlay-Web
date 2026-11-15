import AppKit
import SpriteKit
import SnowCore
struct GarlandRemovalTarget {
 var target="desktop"
 var display:String,id:String,points:[Vec],palette:String,bulbSize:Double,owner:String?
 var key:String {display+":"+id}
 var hitPoint:Vec {points[points.count/2]}
 func raster()->(CGImage,Rect)? {
  guard points.count>=2 else{return nil};let pad=bulbSize*3,minX=points.map(\.x).min()!-pad,minY=points.map(\.y).min()!-pad,width=points.map(\.x).max()!-minX+pad,height=points.map(\.y).max()!-minY+pad
  let scale=min(2,4096/max(width,height));guard let c=CGContext(data:nil,width:Int(ceil(width*scale)),height:Int(ceil(height*scale)),bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil};c.scaleBy(x:scale,y:scale)
  func local(_ p:Vec)->CGPoint {CGPoint(x:p.x-minX,y:height-(p.y-minY))}
  c.setStrokeColor(NSColor(calibratedRed:0.24,green:0.39,blue:0.31,alpha:1).cgColor);c.setLineWidth(2.2);c.move(to:local(points[0]));for p in points.dropFirst(){c.addLine(to:local(p))};c.strokePath()
  let colors=palette=="warm" ? ["gold"]:palette=="ice" ? ["blue","purple"]:["red","green","gold","blue"],spacing=max(24,bulbSize*2.5);var travelled=0.0,index=0
  for pair in zip(points,points.dropFirst()) {let delta=pair.1-pair.0,length=delta.length;var along=spacing-travelled;while along<=length {let p=local(pair.0+delta*(along/max(0.001,length)));if let image=AssetManager.shared.image("fairy_bulb_"+colors[index%colors.count]){let h=bulbSize*2.2;c.draw(image,in:CGRect(x:p.x-h*0.46,y:p.y-h*0.9,width:h*0.92,height:h))};index+=1;along+=spacing};travelled=(travelled+length).truncatingRemainder(dividingBy:spacing)}
  guard let image=c.makeImage() else{return nil};return (image,Rect(minX,minY,width,height))
 }
}
final class GarlandRemovalController {
 weak var owner:WinterCoordinator?
 var queue:[GarlandRemovalTarget]=[],reserved=Set<String>(),panels:[InputPanel]=[],hover:String?,selecting=false
 init(_ owner:WinterCoordinator){self.owner=owner}
 func targets()->[GarlandRemovalTarget]{guard let w=owner,w.config.garland else{return []};var result:[GarlandRemovalTarget]=[]
  for d in w.displays {guard let s=w.decorations.states[d.id],let p=w.config.placements[d.id] else{continue}
   if p.garland.count>=2,s.garlandPhysics.points.count>=2,(p.garlandTarget != "window" || w.interactionWindows.contains{$0.id==p.garlandWindow && $0.isVisible}),(p.garlandTarget != "tree" || w.config.tree) {result.append(GarlandRemovalTarget(target:p.garlandTarget ?? "desktop",display:d.id,id:"active",points:s.garlandPhysics.points,palette:w.config.bulbColor,bulbSize:w.config.bulbSize,owner:p.garlandWindow))}
   for strand in p.extraGarlands ?? [] {if strand.target=="window" && !w.interactionWindows.contains(where:{$0.id==strand.window && $0.isVisible}){continue};if strand.target=="tree" && !w.config.tree{continue};if let physics=s.extraGarlandPhysics[strand.id],physics.points.count>=2{result.append(GarlandRemovalTarget(target:strand.target,display:d.id,id:strand.id,points:physics.points,palette:strand.palette,bulbSize:w.config.bulbSize,owner:strand.window))}}
  };return result
 }
 func endPicker(){panels.forEach{$0.close()};panels=[];selecting=false;hover=nil;if owner?.input.mode == .garlandDelete {owner?.input.stop()};NSCursor.arrow.set()}
 func pickMode(){guard let w=owner,!w.paused,!w.sleeping,!w.decorations.livingBusy,!targets().isEmpty else{owner?.diagnostic="Place a garland and finish the current activity first.";return};endPicker();w.beginEditor(.garlandDelete);guard w.input.mode == .garlandDelete else{return};selecting=true
  for d in w.displays {var frame=d.screen.frame;frame.size.height-=max(32,d.screen.frame.maxY-d.screen.visibleFrame.maxY);let p=InputPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false);p.placement=true;p.isOpaque=false;p.backgroundColor = .clear;p.hasShadow=false;p.isReleasedWhenClosed=false;p.hidesOnDeactivate=false;p.level = .floating;p.acceptsMouseMovedEvents=true;p.collectionBehavior=[.canJoinAllSpaces,.stationary,.ignoresCycle];let v=GarlandPickerView(frame:NSRect(origin:.zero,size:frame.size));v.controller=self;v.display=d;p.contentView=v;p.orderFrontRegardless();p.makeFirstResponder(v);p.makeKey();panels.append(p)}
 }
 func at(_ point:Vec,display:String)->GarlandRemovalTarget? {
  var best:GarlandRemovalTarget?,distance=Double.infinity
  for target in targets() where target.display==display {
   var nearest=Double.infinity
   for (a,b) in zip(target.points,target.points.dropFirst()){nearest=min(nearest,StoryGait.pointSegmentDistance(point,a,b))}
   if nearest<max(18,target.bulbSize*1.5) && nearest<distance {best=target;distance=nearest}
  };return best
 }
 func add(_ target:GarlandRemovalTarget){guard reserved.insert(target.key).inserted else{return};queue.append(target)}
 func deleteAll(){
  guard let w=owner else{return}
  cancel()
  if w.decorations.stories.active?.id == .garlandRemoval {w.decorations.stories.stop(immediately:true,reason:"All garlands removed")}
  if [.garland,.garlandWindow,.garlandDelete].contains(w.input.mode) {w.input.stop()}
  for id in Array(w.config.placements.keys) {
   w.config.placements[id]?.garland=[];w.config.placements[id]?.extraGarlands=[]
   w.config.placements[id]?.garlandWindow=nil;w.config.placements[id]?.garlandTarget=nil
  }
  w.decorations.stories.removalTarget=nil
  w.config.garland=false
  for s in w.decorations.states.values {s.garlandPhysics.reset();s.extraGarlandPhysics=[:];s.garlandPaths=[];s.garlandBulbs=[];s.garland.removeAllChildren()}
  for d in w.displays {d.canvas.garlandPaths=[];d.canvas.garlandArt=[];d.canvas.garlandGlows=[];d.canvas.storyEffects=[];d.canvas.needsDisplay=true}
  w.persist();w.diagnostic="All garlands removed.";w.statusChanged?()
 }
 func update(){guard let w=owner else{return};if selecting && (w.input.mode != .garlandDelete || w.paused || w.sleeping || w.observer.fullscreen){endPicker()}
  guard !queue.isEmpty,w.decorations.stories.active==nil,w.input.mode == .none,!w.paused,!w.sleeping else{return}
  let requested=queue.removeFirst();guard let current=targets().first(where:{$0.key==requested.key}) else{reserved.remove(requested.key);return}
  w.decorations.stories.removalTarget=current
  if !w.playChristmasStory(.garlandRemoval){queue=[];reserved=[];w.decorations.stories.removalTarget=nil}
 }
 func finished(_ run:ChristmasStoryRuntime){guard run.id == .garlandRemoval,let t=run.garlandTarget,let w=owner else{return};reserved.remove(t.key)
  if run.succeeded {if t.id=="active"{w.config.placements[t.display]?.garland=[]}else{w.config.placements[t.display]?.extraGarlands?.removeAll{$0.id==t.id}};if targets().isEmpty {w.config.garland=false};w.persist()}else{queue=[];reserved=[]}
  w.decorations.stories.removalTarget=nil
 }
 func cancel(){endPicker();queue=[];reserved=[]}
}
final class GarlandPickerView:NSView {
 weak var controller:GarlandRemovalController?,display:DisplayOverlay?
 var tracking:NSTrackingArea?
 override var acceptsFirstResponder:Bool{true}
 override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
 override func resetCursorRects(){addCursorRect(bounds,cursor:.crosshair)}
 override func updateTrackingAreas(){if let tracking{removeTrackingArea(tracking)};let a=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseMoved,.inVisibleRect],owner:self,userInfo:nil);addTrackingArea(a);tracking=a;super.updateTrackingAreas()}
 func target(_ e:NSEvent)->GarlandRemovalTarget?{guard let c=controller,let w=c.owner,let d=display,let window else{return nil};let p=window.convertPoint(toScreen:e.locationInWindow);return c.at(Vec(p.x,w.input.primaryHeight-p.y),display:d.id)}
 override func mouseMoved(with e:NSEvent){controller?.hover=target(e)?.key;needsDisplay=true}
 override func mouseDown(with e:NSEvent){guard let t=target(e),let c=controller else{return};c.add(t);c.endPicker()}
 override func keyDown(with e:NSEvent){if e.keyCode==53{controller?.endPicker()}else{super.keyDown(with:e)}}
 override func draw(_ dirtyRect:NSRect){NSColor(calibratedWhite:1,alpha:0.01).setFill();bounds.fill();guard let d=display,let c=controller else{return}
  for t in c.targets() where t.display==d.id && t.key==c.hover {let path=NSBezierPath();path.move(to:d.local(t.points[0]));for p in t.points.dropFirst(){path.line(to:d.local(p))};path.lineWidth=6;NSColor(calibratedRed:1,green:0.78,blue:0.3,alpha:0.85).setStroke();path.stroke()}
  let text="Choose a whole garland · Esc to cancel" as NSString;let a:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:13,weight:.semibold),.foregroundColor:NSColor.white],size=text.size(withAttributes:a),box=NSRect(x:(bounds.width-size.width)/2-12,y:bounds.height-52,width:size.width+24,height:30);NSColor(calibratedRed:0.1,green:0.22,blue:0.27,alpha:0.97).setFill();NSBezierPath(roundedRect:box,xRadius:8,yRadius:8).fill();text.draw(at:NSPoint(x:box.minX+12,y:box.minY+8),withAttributes:a)
 }
}
extension WinterCoordinator {func garlandStoryFinished(_ run:ChristmasStoryRuntime){garlandRemoval.finished(run)}}
extension ChristmasStoryRuntime {
 func planGarlandRemoval(){
  guard let target=garlandTarget,let raster=target.raster() else{fail("Garland unavailable");return}
  spawn("yeti",yeti:true,at:spot(180));walk("under-the-garland",2.6,goals:["yeti":spot(90)],pose:.walk)
  beat("look-up-and-pack-a-snowball",1.9,enter:{$0.pose("yeti",.makeSnowball)})
  beat("a-high-aim",1.2,enter:{$0.pose("yeti",.aim)},leave:{r in r.pose("yeti",.throwBall);r.throwBall(from:r.actorHand("yeti"),to:target.hitPoint,duration:1.8)})
  beat("snowball-meets-the-wire",1.9,leave:{r in r.custom["released"]=1;r.contact("garland-unhooked",prop:target.key,actor:"yeti")})
  beat("the-whole-garland-falls",3.0,enter:{$0.pose("yeti",.surprised)},update:{r,t in
   let centre=raster.1.center+Vec(18*t,110*t*t),p=r.display.local(centre),angle=sin(t*2)*0.18,transform=CGAffineTransform(translationX:p.x,y:p.y).rotated(by:angle),rect=CGRect(x:-raster.1.width/2,y:-raster.1.height/2,width:raster.1.width,height:raster.1.height)
   let b=rect.applying(transform),world=Rect(r.display.rect.x+b.minX,r.display.rect.maxY-b.maxY,b.width,b.height),owner=r.currentWindows.first{$0.id==target.owner},blocked=r.currentWindows.filter{$0.isVisible && (owner==nil || $0.z<owner!.z)}.map(\.frame),pieces=StickerGeometry.visiblePieces(world,blocking:blocked)
   guard !pieces.isEmpty else{return};let drawing=StickerDrawing(id:"falling-garland",image:raster.0,transform:transform,rect:rect,clips:pieces.map{CGRect(x:$0.x-r.display.rect.x,y:r.display.rect.maxY-$0.maxY,width:$0.width,height:$0.height)},alpha:1,bounds:world,window:true)
   r.display.canvas.storyEffects.append(drawing)
  },leave:{$0.outcome="Garland unhooked and removed after the fall"})
  beat("one-last-brush-off",1.0,enter:{$0.pose("yeti",.brush)});leaveTogether(["yeti"],duration:2.0)
 }
}
