import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
@main struct MechanicsCheck {
 static func main() throws {
  precondition(CommandLine.arguments.contains("--config"));_=NSApplication.shared
  let w=WinterCoordinator();w.config=Configuration.preset(.play);w.config.placements=[:];w.config.tree=false;w.config.garland=false;w.config.automaticCleaning=0;w.rebuildDisplays();defer{w.stop()}
  let d=w.displays[0],s=w.decorations.states[d.id]!;d.hide(true);d.rect=Rect(0,0,900,540);d.engine.bounds=d.rect;d.decorationScene.size=CGSize(width:900,height:540);d.canvas.frame=NSRect(x:0,y:0,width:900,height:540);d.desktopCanvas.frame=d.canvas.frame;d.actionCanvas.frame=d.canvas.frame;w.interactionWindowSource={[]};d.canvas.clearsBeforeDraw=false;d.desktopCanvas.clearsBeforeDraw=false;d.actionCanvas.clearsBeforeDraw=false
  let key="ground-"+d.id;var ground=SnowSurface(id:key,screenID:d.id,frame:Rect(0,538,900,1),maxHeight:42);ground.add(volume:34000);w.surfaces.surfaces[key]=ground
  let sceneView=SKView(frame:d.canvas.frame);sceneView.allowsTransparency=true;sceneView.presentScene(d.decorationScene)
  var now=ProcessInfo.processInfo.systemUptime
  func step(_ windows:[TrackedWindow]=[]){now+=1.0/60;w.director.tick(1.0/60);w.flushSnowEvents();d.engine.step(dt:1.0/60,config:w.config);for id in Array(w.surfaces.surfaces.keys){w.surfaces.surfaces[id]?.relax(dt:1.0/60)};d.render(config:w.config,windows:windows,surfaces:w.surfaces,active:nil);w.decorations.update(dt:1.0/60,now:now,displays:[d],config:w.config,windows:windows,dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec(300,300));d.presentDesktopObjects()}
  let frames=URL(fileURLWithPath:"Docs/Mechanics-Frames");try FileManager.default.createDirectory(at:frames,withIntermediateDirectories:true)
  func picture(_ name:String) throws {
   let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1800,pixelsHigh:1080,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
   NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap);let c=NSGraphicsContext.current!.cgContext;c.scaleBy(x:2,y:2);c.setFillColor(CGColor(red:0.08,green:0.17,blue:0.21,alpha:1));c.fill(d.canvas.bounds);d.desktopCanvas.draw(d.canvas.bounds)
   if let texture=sceneView.texture(from:d.decorationScene){c.draw(texture.cgImage(),in:d.canvas.bounds)}
   d.canvas.draw(d.canvas.bounds);d.actionCanvas.draw(d.canvas.bounds);NSGraphicsContext.restoreGraphicsState();try bitmap.representation(using:.png,properties:[:])!.write(to:frames.appendingPathComponent(name+".png"))
  }
  step()
  for n in 0..<5 {
   w.beginEditor(.snow);precondition(w.input.mode == .snow && !w.config.automaticSnowman)
   let panel=w.input.panels.first!,view=panel.contentView as! InputView
   func event(_ type:NSEvent.EventType,_ x:Double){let p=panel.convertPoint(fromScreen:NSPoint(x:x,y:w.input.primaryHeight-515));let e=NSEvent.mouseEvent(with:type,location:p,modifierFlags:[],timestamp:now,windowNumber:panel.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:type == .leftMouseUp ? 0:1)!;switch type{case .leftMouseDown:view.mouseDown(with:e);case .leftMouseDragged:view.mouseDragged(with:e);default:view.mouseUp(with:e)}}
   for x in [100.0,350,600]{event(.leftMouseDown,x);event(.leftMouseDragged,x+85);event(.leftMouseUp,x+85)}
   precondition(s.snowballs.snowmen.count==n+1,"Manual creation did not retain earlier snowmen")
   precondition(w.input.mode == .none && s.sculptArea==nil,"Sculpt overlay remained open")
   for _ in 0..<160{step()}
  }
  precondition(w.config.placements[d.id]?.snowmen?.count==5);let ids=s.snowballs.snowmen.map(\.id)
  w.beginEditor(.snow);precondition(w.input.mode == .none,"Sixth snowman was allowed")
  let moved=ids[1],before=s.snowballs.snowmen.first{$0.id==moved}!.position
  w.handleInput("move-snowman@\(moved):down",p:before,id:d.id);w.handleInput("move-snowman@\(moved):drag",p:before+Vec(-16,0),id:d.id);w.handleInput("move-snowman@\(moved):up",p:before+Vec(-16,0),id:d.id);step()
  precondition(abs(s.snowballs.snowmen.first{$0.id==moved}!.position.x-before.x+16)<0.01,"Wrong snowman moved")
  try picture("five-snowmen")
  let decoded=try Configuration.decodeCompatible(JSONEncoder().encode(w.config));precondition(decoded.placements[d.id]?.snowmen?.count==5)
  let restored=DecorationManager();restored.update(dt:0,now:now,displays:[d],config:decoded,windows:[],dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec())
  precondition(restored.states[d.id]?.snowballs.snowmen.count==5 && Set(restored.states[d.id]!.snowballs.snowmen.map(\.id))==Set(ids),"Restoration duplicated or lost a model")
  for state in restored.states.values {state.root.removeFromParent()}
  w.beginEditor(.snowmen);precondition(w.input.panels.count==5 && w.input.panels.allSatisfy{$0.level.rawValue>0});w.input.stop()
  // Every bounded editor must paint a hit-testable pixel even with no artwork there.
  let hitView=InputView(frame:NSRect(x:0,y:0,width:80,height:40));hitView.editSnowmen=true
  let hitBitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:80,pixelsHigh:40,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:hitBitmap);hitView.draw(hitView.bounds);NSGraphicsContext.restoreGraphicsState()
  precondition((hitBitmap.colorAt(x:40,y:20)?.alphaComponent ?? 0)>0,"Editor is completely transparent to WindowServer")
  // Same view/window class used by the real duel. A mouseDown must aim then fire once.
  precondition(w.decorations.startDuel(display:d,area:Rect(100,180,660,210)));for _ in 0..<90{step()}
  let game=s.living.duel!,target=game.hand(0)+Vec(165,-165);var attempts=0,accepted=0
  let duelPanel=DuelInputPanel(area:game.area,primaryHeight:w.input.primaryHeight,aim:{w.decorations.aimDuel(at:$0)},fire:{attempts+=1;if w.decorations.fireDuel(){accepted+=1}},exit:{w.endLivingDuel()})
  precondition(duelPanel.level == .floating && !duelPanel.ignoresMouseEvents)
  let v=duelPanel.contentView as! DuelInputView,p=duelPanel.convertPoint(fromScreen:NSPoint(x:target.x,y:w.input.primaryHeight-target.y)),e=NSEvent.mouseEvent(with:.leftMouseDown,location:p,modifierFlags:[],timestamp:now,windowNumber:duelPanel.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)!
  v.mouseDown(with:e);precondition(attempts==1 && accepted==1 && s.living.duel?.phase == .playerFlight)
  v.mouseDragged(with:e);precondition(attempts==1,"Drag fired a second shot")
  for _ in 0..<160{step();if s.living.duel?.yetiHP==4{break}}
  precondition(s.living.duel?.yetiHP==4,"Aimed duel shot did not hit")
  duelPanel.close();w.endLivingDuel()
  // Gnome carry spacing and contact are measured throughout delivery.
  var gripError=0.0,bodyClearance=1000.0,armError=0.0
  for size in ["small","medium","large"] {
   w.config.treeSize=size;w.config.placements[d.id]?.tree=Vec(0.13,0.86);precondition(w.decorations.deliverTree(display:d,feet:Vec(110,500),config:w.config));w.config.tree=true
   for i in 0..<420 {step();if i==145 {try picture("gnome-carry-"+size)}
    if let story=s.living.delivery,story.elapsed>1.85 && story.elapsed<2.85,let payload=s.living.treePayload,let actor=s.living.gnome {
     let grip=payload.convert(CGPoint(x:story.gripOffset.x,y:story.gripOffset.y),to:s.root),hand=actor.hand(in:s.root)
     gripError=max(gripError,hypot(grip.x-hand.x,grip.y-hand.y));bodyClearance=min(bodyClearance,abs(grip.x-actor.node.position.x))
     let arm=actor.model.childNode(withName:"gnome_arm_right")!,tip=arm.convert(CGPoint(x:0,y:-17.0/128*48),to:s.root)
     armError=max(armError,hypot(tip.x-hand.x,tip.y-hand.y))
    }
   }
   if size != "large" {s.tree?.removeFromParent();s.tree=nil;s.builtTree=false;w.config.tree=false}
  }
  try JSONSerialization.data(withJSONObject:["grip":gripError,"arm":armError,"offset":bodyClearance],options:.prettyPrinted).write(to:URL(fileURLWithPath:".build/gnome-contact-debug.json"))
  precondition(gripError<0.1 && armError<0.1 && bodyClearance>=15.9,"Carrier body/hand spacing drifted")
  let cover=TrackedWindow(number:77,pid:999,frame:d.rect,z:0,now:now)
  w.beginSnowballPlay();s.snowballPlay.gather(at:Vec(100,520),extract:{$0});s.snowballPlay.gather(at:Vec(110,520),extract:{$0})
  precondition(!s.snowballPlay.balls.isEmpty);w.removeLivingTree()
  precondition(s.character != nil && w.input.mode == .none && s.snowballPlay.balls.isEmpty && !w.config.interaction,"Tree action left a conflicting mouse mode")
  var visibleChop=0,peakOverlaySprites=0
  for i in 0..<1100 {step([cover]);if s.character != nil && !d.actionCanvas.composites.isEmpty{visibleChop+=1};peakOverlaySprites=max(peakOverlaySprites,d.actionCanvas.composites.count);if i==220{try picture("visible-yeti-chop")};if s.character==nil{break}}
  precondition(visibleChop>250 && s.tree==nil && s.character==nil && d.actionWindow.ignoresMouseEvents,"Chopping is invisible or stalled")
  let victim=ids[2];s.snowballs.select(victim);let origin=s.snowballs.snowman!
  precondition(w.decorations.requestCharacter(.throwSnowball,display:d,target:origin,windows:[],surfaces:w.surfaces,config:w.config))
  var projectileDuration=0.0,shownFlight=0
  for _ in 0..<1100 {step();if let path=s.projectilePath,s.projectile != nil{projectileDuration=path.duration;shownFlight+=1};if s.character==nil{break}}
  precondition(projectileDuration>=1.29 && shownFlight>65 && s.snowballs.snowmen.count==4 && !s.snowballs.snowmen.contains{$0.id==victim},"Yeti throw removed wrong target or remained too fast")
  // Real shared projectile collision removes exactly one of the remaining models.
  let second=s.snowballs.snowmen.min(by:{$0.position.x<$1.position.x})!;w.beginSnowballPlay()
  let gatherPanel=w.input.panels.first!,gatherView=gatherPanel.contentView as! InputView
  for i in 0..<30 {let point=Vec(second.position.x-180+Double(i)*2,d.rect.maxY-22),local=gatherPanel.convertPoint(fromScreen:NSPoint(x:point.x,y:w.input.primaryHeight-point.y)),e=NSEvent.mouseEvent(with:.mouseMoved,location:local,modifierFlags:[],timestamp:now,windowNumber:gatherPanel.windowNumber,context:nil,eventNumber:i,clickCount:0,pressure:0)!;gatherView.mouseMoved(with:e)}
  var play=s.snowballPlay;precondition(!play.balls.isEmpty,"Hover did not gather snow through the real active input view")
  let p0=play.balls[0].position,p2=second.position+Vec(-80,-25),wanted=Vec(200,-10),p1=(p2-p0*0.3-wanted/3.5)/0.7
  precondition(play.grab(at:p0,now:0));play.drag(to:p1,now:0.2);play.drag(to:p2,now:0.4);play.release(at:p2,now:0.4);s.snowballPlay=play
  for _ in 0..<180 {step();if s.snowballPlay.balls.isEmpty{break}}
  precondition(s.snowballs.snowmen.count==3 && !s.snowballs.snowmen.contains{$0.id==second.id},"Flick did not destroy only its collided snowman")
  w.finishSculpting();w.input.stop();for _ in 0..<240 {step()};try picture("after-hits")
  // Both endings contain two helpers; the right helper boards first so paths never cross.
  var helperGap=Double.infinity
  for win in [true,false] {
   precondition(w.decorations.startDuel(display:d,area:Rect(100,180,660,210)));var ended=false,frames=0
   while s.living.duel != nil && frames<12000 {
    if win,s.living.duel?.phase == .playerAim {s.living.duel?.aim(0.5);_ = s.living.duel?.fire()}
    step();frames+=1
    if let game=s.living.duel,game.ended {
     ended=true;let visible=s.living.helpers.filter{!$0.node.isHidden && $0.node.alpha>0.1}
     if visible.count==2 {let a=visible[0].node.convert(.zero,to:s.root),b=visible[1].node.convert(.zero,to:s.root);helperGap=min(helperGap,abs(a.x-b.x));precondition(abs(a.x-b.x)>=42,"Rescue helpers overlap while boarding")}
    }
   }
   precondition(ended && s.living.duel==nil && s.living.gameRoot==nil,"Duel rescue did not finish")
  }
  let result:[String:Any]=["passed":true,"scope":"Owned Cocoa input and actual controllers/physics/renderer with controlled time; no physical desktop click or presented GPU FPS claim","fiveIndependentSnowmen":true,"savedAndNormalizedFive":true,"restoredFiveWithStableIDs":true,"sixthRejected":true,"independentDrag":true,"duelMouseDownExactlyOneShotAndHit":true,"duelPanelFloatingAndHittable":true,"boundedEditorPaintsHitPixels":true,"visibleChopFrames":visibleChop,"peakActionSprites":peakOverlaySprites,"gnomeGripErrorPt":gripError,"gnomeArmErrorPt":armError,"allTreeSizesCarryChecked":true,"gnomeBodyOffsetPt":bodyClearance,"yetiProjectileDuration":projectileDuration,"yetiTargetsExactlyOne":true,"hoverThroughInputViewGathersRealSnow":true,"playerFlickTargetsExactlyOne":true,"actionWindowClickThrough":d.actionWindow.ignoresMouseEvents,"storySwitchClearsMouseModeAndLooseBalls":true,"bothDuelRescuesChecked":true,"minimumVisibleHelperGapPt":helperGap]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/mechanics-result.json"));print("PASS: five models, independent drag/persistence, duel click/hit, visible slower Yeti, spaced carrier, flick collision and cleanup")
 }
}
