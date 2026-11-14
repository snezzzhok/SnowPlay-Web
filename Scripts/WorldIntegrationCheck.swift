import AppKit
import SpriteKit
import SnowCore
@main struct WorldIntegrationCheck {
 static func main() throws {
  _=NSApplication.shared
  let w=WinterCoordinator();w.config=Configuration.preset(.play);w.config.snow=false;w.config.automaticCleaning=0;w.config.yetiEnabled=false;w.rebuildDisplays()
  guard let d=w.displays.first,let s=w.decorations.states[d.id] else{fatalError("No display")};defer{w.stop()}
  d.hide(true);d.rect=Rect(0,0,900,540);d.engine.bounds=d.rect;d.canvas.frame=NSRect(x:0,y:0,width:900,height:540);d.decorationScene.size=d.canvas.frame.size
  let view=SKView(frame:d.canvas.frame);view.allowsTransparency=true;view.presentScene(d.decorationScene)
  let ground="ground-"+d.id;w.surfaces.surfaces[ground]=SnowSurface(id:ground,screenID:d.id,frame:Rect(0,538,900,1),maxHeight:18)
  var now=ProcessInfo.processInfo.systemUptime,stepNumber=0,frame=0,title="",chapters:[String:Int]=[:],record=true
  let folder=URL(fileURLWithPath:".build/floor-frames");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  var visualWindow:TrackedWindow?=TrackedWindow(number:991,pid:9999,frame:Rect(150,175,480,230),z:0,now:now)
  w.interactionWindowSource={visualWindow.map{[$0]} ?? []}
  func render() throws {
   guard record,let scene=view.texture(from:d.decorationScene) else{return}
   if chapters[title]==nil{chapters[title]=frame}
   let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:900,pixelsHigh:540,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
   NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap);let c=NSGraphicsContext.current!.cgContext
   d.canvas.draw(d.canvas.bounds);c.setBlendMode(.destinationOver)
   if let window=visualWindow {let p=d.local(Vec(window.frame.x,window.frame.maxY));let rect=CGRect(x:p.x,y:p.y,width:window.frame.width,height:window.frame.height);c.setFillColor(CGColor(red:0.25,green:0.34,blue:0.4,alpha:1));c.addPath(CGPath(roundedRect:rect,cornerWidth:10,cornerHeight:10,transform:nil));c.fillPath()}
   c.draw(scene.cgImage(),in:d.canvas.bounds);c.setFillColor(CGColor(red:0.08,green:0.16,blue:0.22,alpha:1));c.fill(d.canvas.bounds);c.setBlendMode(.normal)
   ("SnowPlay · "+title as NSString).draw(at:NSPoint(x:25,y:500),withAttributes:[.font:NSFont.systemFont(ofSize:18,weight:.medium),.foregroundColor:NSColor.white])
   NSGraphicsContext.restoreGraphicsState();try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent(String(format:"frame-%04d.png",frame)));frame+=1
  }
  func step(_ count:Int=1) throws {
   for _ in 0..<count {
    RunLoop.main.run(until:Date().addingTimeInterval(1.0/60));now+=1.0/30
    w.director.tick(1.0/30);w.stepCleaning(dt:1.0/30,now:now);w.flushSnowEvents();d.engine.step(dt:1.0/30,config:w.config)
    d.render(config:w.config,windows:w.interactionWindows,surfaces:w.surfaces,active:nil)
    w.decorations.update(dt:1.0/30,now:now,displays:[d],config:w.config,windows:w.interactionWindows,dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec())
    stepNumber+=1;if stepNumber%3==0{try render()}
   }
  }
  func actorFinished() throws {
   var n=0
   while s.character != nil && n<700 {
    try step();n+=1
    if let actor=s.actor,let character=s.character {
     let feet=d.rect.maxY-actor.position.y+18,expected=w.decorations.groundY(clamp(character.position.x,0,900),display:d,surfaces:w.surfaces)
     precondition(abs(feet-expected)<3,"Yeti feet left the ground")
    }
   };precondition(s.character==nil,"Yeti did not exit")
  }
  title="Window drag · tight support, vertical shedding, local mound"
  w.syncSurfaces(now:now);let window=visualWindow!;_=w.surfaces.surfaces[window.id]?.add(volume:1400)
  try step(12)
  for _ in 0..<20 {
   let old=window.frame;window.frame.x+=4;window.state.send(.move,now:now);w.windowGeometry(window,old:old,dt:1.0/30);w.syncSurfaces(now:now)
   precondition(abs(w.surfaces.surfaces[window.id]!.frame.y-window.frame.y-0.5)<0.001)
   precondition(abs(w.surfaces.surfaces[window.id]!.frame.x-window.frame.x-2)<0.001)
   try step()
  }
  precondition(d.engine.particles.contains{$0.fallsToGround && $0.velocity.x==0},"Visible vertical chunks missing")
  try step(70);precondition(w.surfaces.surfaces[ground]!.volume>100 && !w.surfaces.surfaces[ground]!.impactMounds.isEmpty)
  visualWindow=nil;w.surfaces.surfaces.removeValue(forKey:window.id)
  title="Ground sculpting · glove gesture, real snow, automatic stack"
  _=w.surfaces.surfaces[ground]?.add(volume:6500);let stock=w.surfaces.surfaces[ground]!.volume
  w.beginEditor(.snow);precondition(s.sculptArea!.maxY==d.rect.maxY && !w.surfaces.surfaces.keys.contains(where:{$0.hasPrefix("sculpt-")}))
  for (i,start) in [230.0,430,650].enumerated() {
   w.handleInput("snow:down",p:Vec(start,520),id:d.id)
   for distance in stride(from:0.0,through:95.0,by:5) {w.handleInput("snow:drag",p:Vec(start+distance,520),id:d.id);try step()}
   w.handleInput("snow:up",p:Vec(start+95,520),id:d.id);if i<2 {precondition(s.snowballs.balls.count==i+1)}
  }
  precondition(s.snowballs.snowman != nil && s.snowmanFloating && d.canvas.workbench==nil)
  let used=s.snowballs.assemblyBalls.reduce(0){$0+Double.pi*$1.radius*$1.radius};precondition(abs(stock-w.surfaces.surfaces[ground]!.volume-used)<0.001)
  try step(85);w.finishSculpting();precondition(s.snowballs.snowman != nil);w.persist()
  precondition(Configuration.load(from:w.configURL).placements[d.id]?.snowmanRadii?.count==3)
  w.config.tree=true;w.config.placements[d.id]=Placement(tree:Vec(0.73,0.8),ornaments:TreeOrnament.defaults)
  title="Bare evergreen · three sizes, no built-in ornaments"
  for size in ["small","medium","large"] {w.config.treeSize=size;try step(12);precondition(s.tree?.children.count==2)}
  title="Decorated tree · three hooks, stars, baubles, lights"
  w.config.treeStar="gold";w.config.treeBalls="red";w.config.treeGarland="multi";w.config.treeToy1="bauble";w.config.treeToy2="candy";w.config.treeToy3="flake"
  try step(24);precondition(s.toyNodes.count==3 && s.tree!.children.count==8)
  w.config.garland=true;w.config.placements[d.id]?.garland=[Vec(0.1,0.28),Vec(0.5,0.2),Vec(0.9,0.28)];w.config.placements[d.id]?.garlandTarget="desktop"
  try step(25);precondition(d.canvas.garlandArt.count>8 && d.canvas.garlandGlows.count==d.canvas.garlandArt.count)
  w.persist();let saved=Configuration.load(from:w.configURL);precondition(saved.treeGarland=="multi" && saved.treeSize=="large")
  title="Tree presents · first click releases three colored bursts"
  w.decorations.addTreePresents(display:d,surfaces:w.surfaces);precondition(s.treePresents.count==3)
  let present=s.treePresents[0];w.handleInput("tree-gift@"+present.id+":down",p:present.position,id:d.id)
  precondition(s.treePresents[0].openedAt != nil && present.node.children.filter{$0.name=="firework"}.count==3)
  // Controlled fixture clock follows the production controller's timestamps.
  let real=ProcessInfo.processInfo.systemUptime;s.treePresents[0].openedAt=now
  for n in present.node.children where n.name=="firework" {if let born=n.userData?["born"] as? Double {n.userData?["born"]=now+(born-real)}}
  try step(95);precondition(s.treePresents.count==2)
  title="Yeti game A · ground run, random-direction snowball"
  precondition(w.decorations.requestCharacter(.playWithSnow,display:d,target:Vec(400,520),windows:[],surfaces:w.surfaces,config:w.config));try actorFinished();try step(35)
  title="Yeti game B · two tiny snow clumps"
  _=w.surfaces.surfaces[ground]?.add(volume:5000)
  precondition(w.decorations.requestCharacter(.buildCastle,display:d,target:Vec(450,520),windows:[],surfaces:w.surfaces,config:w.config));try actorFinished()
  precondition(s.castleBase != nil && s.castleProgress==1 && s.castleMass>0 && d.canvas.reveals.count==2 && d.canvas.reveals.allSatisfy{$0.rect.height<16})
  title="Remove tree · approach, blade contact, falling tree, exit"
  let centre=Vec(d.rect.x+s.tree!.position.x,d.rect.maxY-s.tree!.position.y)
  precondition(w.decorations.requestCharacter(.chopTree,display:d,target:centre,windows:[],surfaces:w.surfaces,config:w.config));w.config.tree=false
  var contact=false,fall=false
  for _ in 0..<700 {
   try step();fall = fall || s.treeFalling
   if let actor=s.character,actor.localTime>0.18,actor.localTime<0.24,let axe=s.actor?.childNode(withName:"yeti_arm_right/held-axe") {
    let p=axe.convert(CGPoint(x:-4.6875,y:8.125),to:s.root),target=d.local(centre+Vec(0,s.treeHeight*0.38-6));precondition(hypot(p.x-target.x,p.y-target.y)<4,"Axe contact missed");contact=true
   };if s.character==nil {break}
  };precondition(contact && fall && s.tree==nil)
  title="Snowplow · eased travel, wheel distance, moving loaded blade"
  w.surfaces.surfaces[ground]?.clear();_=w.surfaces.surfaces[ground]?.add(volume:2400);let before=w.surfaces.surfaces[ground]!.volume
  w.clean();try step(75);precondition(w.plowLoad.mass>0 && w.surfaces.surfaces[ground]!.volume<before);w.cancelCleaning()
  let pending=(w.stateJSON()["snowWorld"] as! [String:Any])["pendingMass"] as! Double
  precondition(abs(w.surfaces.surfaces[ground]!.volume+pending-before)<0.001)
  w.flushSnowEvents();try step(200);w.surfaces.surfaces[ground]?.clear();_=w.surfaces.surfaces[ground]?.add(volume:2200);let exported=w.surfaces.surfaces[ground]!.volume;w.clean();try step(185)
  precondition(w.plowLoad.mass==0 && abs(w.plowLoad.exported-exported)<0.001)
  let result:[String:Any]=["passed":true,"scope":"exact app controllers/resources in an owned native scene; no user desktop capture","windowAnchorAndVerticalFall":true,"localizedImpactMound":true,"groundSculptAndMass":true,"threeBareTreeSizes":true,"decoratedTreeAndThreeHooks":true,"glowingModelBulbs":true,"threeGiftFireworksFirstClick":true,"yetiGroundFeetAndBothGames":true,"axeContactAndFallingTree":true,"plowMassAndCancellation":true,"framesRendered":frame,"chapterStartFrames":chapters,"multiplePhysicalScreensTested":false]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/floor-native-result.json"))
  print("PASS: floor world, tight cap/vertical fall/local mound, ground sculpt/mass, tree variants, three bursts, two Yeti games/feet, axe contact, glowing lamps, plow; \(frame) owned frames")
 }
}
