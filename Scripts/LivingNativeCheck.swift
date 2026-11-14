import AppKit
import SpriteKit
import SnowCore
@main struct LivingNativeCheck {
 static func main() throws {
  _=NSApplication.shared
  let w=WinterCoordinator();w.config=Configuration.preset(.play);w.config.snow=false;w.config.automaticCleaning=0;w.rebuildDisplays();defer{w.stop()}
  guard let d=w.displays.first,let s=w.decorations.states[d.id] else{fatalError("No macOS display")}
  d.hide(true);d.rect=Rect(0,0,900,540);d.engine.bounds=d.rect
  d.canvas.frame=NSRect(x:0,y:0,width:900,height:540);d.desktopCanvas.frame=d.canvas.frame;d.decorationScene.size=d.canvas.frame.size
  d.canvas.clearsBeforeDraw=false;d.desktopCanvas.clearsBeforeDraw=false
  let view=SKView(frame:d.canvas.frame);view.allowsTransparency=true;view.presentScene(d.decorationScene)
  let ground="ground-"+d.id
  w.surfaces.surfaces[ground]=SnowSurface(id:ground,screenID:d.id,frame:Rect(0,538,900,1),maxHeight:42);w.surfaces.surfaces[ground]?.add(volume:18000)
  var now=ProcessInfo.processInfo.systemUptime
  let folder=URL(fileURLWithPath:"Docs/Living-Frames");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
  func step(){
   now+=1.0/60;w.director.tick(1.0/60);w.flushSnowEvents();d.engine.step(dt:1.0/60,config:w.config)
   d.render(config:w.config,windows:[],surfaces:w.surfaces,active:nil)
   w.decorations.update(dt:1.0/60,now:now,displays:[d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec(600,200));d.presentDesktopObjects()
   RunLoop.main.run(until:Date().addingTimeInterval(0.001))
  }
  func picture(_ name:String) throws {
   let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1800,pixelsHigh:1080,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
   NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
   let c=NSGraphicsContext.current!.cgContext;c.scaleBy(x:2,y:2);c.setFillColor(CGColor(red:0.08,green:0.17,blue:0.21,alpha:1));c.fill(d.canvas.bounds)
   d.desktopCanvas.draw(d.desktopCanvas.bounds)
   if let texture=view.texture(from:d.decorationScene){c.draw(texture.cgImage(),in:d.canvas.bounds)}else{fatalError("SpriteKit cannot render: active macOS graphics session required")}
   d.canvas.draw(d.canvas.bounds)
   ("SnowPlay · "+name as NSString).draw(at:NSPoint(x:20,y:505),withAttributes:[.font:NSFont.systemFont(ofSize:15,weight:.medium),.foregroundColor:NSColor.white])
   NSGraphicsContext.restoreGraphicsState();try bitmap.representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent(name+".png"))
  }
  precondition(d.desktopSnow.level.rawValue<NSWindow.Level.normal.rawValue && d.background.level.rawValue<0)
  precondition(d.desktopSnow.ignoresMouseEvents && d.foreground.ignoresMouseEvents)
  for id in ["snowplow_complete","truck_body","gnome_head","yeti_head","snow_clump_0","snowman_face_closed"] {precondition(AssetManager.shared.image(id) != nil,id)}
  precondition(AssetManager.shared.preview("snowplow") != nil && AssetManager.shared.preview("snowplow_complete") != nil)
  for yeti in [false,true] {
   let actor=LivingActor(yeti:yeti);s.root.addChild(actor.node)
   for (pose,time) in [(LivingPose.makeSnowball,0.4),(.aim,0.0),(.throwBall,0.0),(.carry,0.5),(.run,0.4),(.celebrate,0.0)] {
    actor.pose(pose,time:time,facing:-1)
    let arm=actor.model.childNode(withName:(yeti ? "yeti_":"gnome_")+"arm_right")!,tip=arm.convert(CGPoint(x:yeti ? 3.5:0,y:yeti ? -8:-17.0/128*48),to:s.root),hand=actor.hand(in:s.root)
    precondition(hypot(tip.x-hand.x,tip.y-hand.y)<0.1,"Arm detached in pose \(pose)")
   }
   actor.node.removeFromParent()
  }
  var gripError=0.0,maxNodes=0
  for cycle in 0..<20 {
   let feet=Vec(420,w.decorations.groundY(420,display:d,surfaces:w.surfaces))
   w.config.tree=false;w.config.placements[d.id]=Placement(tree:Vec(feet.x/900,(feet.y-132*0.38)/540),ornaments:TreeOrnament.defaults)
   precondition(w.decorations.deliverTree(display:d,feet:feet,config:w.config));w.config.tree=true
   for i in 0..<420 {
    step();maxNodes=max(maxNodes,s.root.children.count)
    if let story=s.living.delivery,story.elapsed>1.85 && story.elapsed<2.85,let payload=s.living.treePayload,let actor=s.living.gnome {
     let grip=payload.convert(CGPoint(x:story.gripOffset.x,y:story.gripOffset.y),to:s.root),hand=actor.hand(in:s.root)
     gripError=max(gripError,hypot(grip.x-hand.x,grip.y-hand.y))
    }
    if cycle==0 && [50,130,190].contains(i){try picture("tree-\(i)")}
   }
   precondition(s.tree != nil && s.living.delivery==nil && s.living.vehicle==nil)
   if cycle==0 {w.decorations.addTreePresents(display:d,surfaces:w.surfaces,now:now);precondition(s.treePresents.count==3 && s.treePresents.allSatisfy{$0.node.alpha==0});for _ in 0..<60{step()};precondition(s.treePresents.allSatisfy{$0.node.alpha==1});try picture("tree-gifts")}
   let tree=s.tree!,point=Vec(tree.position.x,540-tree.position.y)
   precondition(w.decorations.requestCharacter(.chopTree,display:d,target:point,windows:[],surfaces:w.surfaces,config:w.config));w.config.tree=false
   precondition(!w.decorations.deliverTree(display:d,feet:feet,config:w.config))
   var n=0
   while s.character != nil && n<1000 {step();n+=1;if cycle==0 && n==100 {try picture("yeti-chop")}}
   precondition(s.character==nil && s.tree==nil && s.root.childNode(withName:"tree-fall")==nil && s.treePresents.isEmpty)
  }
  precondition(gripError<0.1,"Tree grip detached from gnome hand: \(gripError)")
  let stock=w.surfaces.surfaces[ground]!.volume
  precondition(w.decorations.automaticSnowman(display:d,at:Vec(480,520)))
  for _ in 0..<310 {step()}
  precondition(s.snowballs.snowman != nil && s.snowballs.assemblyBalls.count==3)
  let mass=s.snowballs.assemblyBalls.reduce(0){$0+Double.pi*$1.radius*$1.radius}
  precondition(abs(stock-w.surfaces.surfaces[ground]!.volume-mass)<0.01)
  try picture("snowman-built")
  let point=s.snowballs.snowman!;precondition(w.decorations.requestCharacter(.throwSnowball,display:d,target:point,windows:[],surfaces:w.surfaces,config:w.config))
  var sawFlight=false,sawFragments=false
  for _ in 0..<450 {step();if s.projectile != nil && !sawFlight {try picture("snowman-throw");sawFlight=true};sawFragments = sawFragments || !s.fragments.isEmpty}
  precondition(sawFlight && sawFragments && s.snowballs.snowman==nil && s.character==nil)
  precondition(w.decorations.startParachuteGift(display:d,surfaces:w.surfaces))
  for i in 0..<600 {step();if i==110{try picture("gift-descent")};if i==260 {try picture("gift-countdown")}}
  precondition(s.gift==nil && s.santa==nil && s.deliveryElapsed==nil)
  for win in [true,false] {
   precondition(w.decorations.startDuel(display:d,area:Rect(100,280,660,210)))
   w.input.rebuild(displays:[d],windows:[],dock:nil,decorations:w.decorations,focus:false,icons:[]);precondition(w.input.panels.isEmpty,"Duel recreated ordinary object input zones")
   var ending=false,carried=false,pictured=false,n=0
   while s.living.duel != nil && n<12000 {
    if win,s.living.duel?.phase == .playerAim {s.living.duel?.aim(0.5);_ = s.living.duel?.fire()}
    step();n+=1
    if let game=s.living.duel,game.ended {
     ending=true;precondition((win ? game.yetiHP:game.playerHP)==0)
     if game.phaseTime>2.5 && !pictured {try picture(win ? "duel-win":"duel-lose");pictured=true}
     if let group=s.living.rescueRoot,let body=win ? s.living.enemy?.node:s.living.player?.node {carried = carried || body.parent === group || body.parent === s.living.duelVehicle?.node}
    }
   }
   precondition(ending && carried && s.living.duel==nil && s.living.gameRoot==nil)
  }
  for _ in 0..<20 {precondition(w.decorations.startDuel(display:d,area:Rect(100,280,660,210)));step();w.decorations.exitDuel();precondition(s.living.gameRoot==nil)}
  precondition(w.decorations.startYetiActivity("surprise",display:d,target:Vec(550,360),surfaces:w.surfaces))
  for _ in 0..<320{step()};precondition(s.living.activity==nil)
  precondition(w.decorations.startYetiActivity("feed",display:d,target:Vec(500,510),surfaces:w.surfaces))
  for _ in 0..<90{step()}
  w.input.rebuild(displays:[d],windows:[],dock:nil,decorations:w.decorations,focus:false,icons:[])
  precondition(w.input.panels.contains{$0.contentView?.identifier?.rawValue=="feed-snow" && $0.level.rawValue<NSWindow.Level.normal.rawValue},"Desktop input floats above application windows");w.input.stop()
  let h=s.living.activityActor!.hand(in:s.root),hp=Vec(h.x,540-h.y)
  w.decorations.feedInput("feed-snow:down",p:hp,display:d);w.decorations.feedInput("feed-snow:up",p:hp,display:d)
  for _ in 0..<320{step()};precondition(s.living.activity==nil && w.decorations.consumedSnowMass>0)
  func groundLedger()->Double {let pending=(w.stateJSON()["snowWorld"] as! [String:Any])["pendingMass"] as! Double;return w.surfaces.surfaces[ground]!.volume+d.engine.particles.reduce(0){$0+$1.snowVolume}+pending}
  let ledger=groundLedger();precondition(w.decorations.automaticSnowman(display:d,at:Vec(450,520)));step();precondition(s.living.automaticMass>0);w.decorations.cancelTransient();precondition(abs(groundLedger()-ledger)<0.01 && s.snowballs.balls.isEmpty)
  let feet=Vec(420,w.decorations.groundY(420,display:d,surfaces:w.surfaces));precondition(w.decorations.deliverTree(display:d,feet:feet,config:w.config));w.config.tree=true;step();w.decorations.cancelTransient();precondition(!w.config.tree && s.tree==nil && s.living.vehicle==nil)
  d.engine.setCount(1200);step();precondition(d.snowCloud.activeCount>900 && d.desktopCanvas.dots.allSatisfy{$0.clump || $0.size<3})
  try picture("snow-gpu")
  d.engine.setCount(20);step();precondition(d.snowCloud.pooledCount<=84)
  d.engine.setCount(0);step();precondition(d.snowCloud.activeCount==0 && d.snowCloud.pooledCount<=64)
  let result:[String:Any]=["passed":true,"scope":"Actual AppKit/SpriteKit/controllers in isolated own scene; these are controlled scene renders, not screenshots of user windows","treeCycles":20,"maxTreeGripErrorPt":gripError,"maximumRootChildren":maxNodes,"automaticSnowmanMass":mass,"snowmanFlightAndFragments":true,"passiveGiftWithoutSanta":true,"duelWinAndLose":true,"rescueUsesCarrierParent":true,"duelExitCycles":20,"feedAndSurprise":true,"desktopLayersBelowApps":true,"originalSnowplowAliasWorks":true,"pooledSpriteKitWeather":true,"storyCancellationMass":true,"desktopInputsBelowAppWindows":true,"duelExclusiveInput":true]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/living-native-result.json"))
  print("PASS: Living Winter native scene, 20 deliveries/chops, grip contact, automatic snowman/throw, gift, both duel endings, 20 exits, feeding and desktop layers")
 }
}
