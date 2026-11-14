import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
final class MechanicsLive:NSObject,NSApplicationDelegate,NSWindowDelegate {
 var w:WinterCoordinator!,d:DisplayOverlay!,window:NSWindow!,view:SKView!,panel:DuelInputPanel?,timer:Timer?
 let bank=SnowCanvas(),front=SnowCanvas(),action=SnowCanvas(),label=NSTextField(labelWithString:"")
 var last=0.0,start=0.0,saved=0.0,stage="stress",attempts=0,accepted=0,overlap=false,work:[Double]=[],heavyIntervals:[Double]=[],heavyCosts:[Double]=[],reports:[String:Any]=[:]
 func applicationDidFinishLaunching(_ n:Notification){
  w=WinterCoordinator();w.config=Configuration.preset(.play);w.config.placements=[:];w.config.automaticCleaning=0;w.rebuildDisplays();d=w.displays[0];d.hide(true)
  let height=w.input.primaryHeight;d.rect=Rect(160,height-730,1000,550);d.engine.bounds=d.rect;d.decorationScene.size=CGSize(width:1000,height:550)
  for c in [d.canvas,d.desktopCanvas,d.actionCanvas]{c.frame=NSRect(x:0,y:0,width:1000,height:550)}
  window=NSWindow(contentRect:NSRect(x:160,y:180,width:1000,height:600),styleMask:[.titled,.closable],backing:.buffered,defer:false);window.title="SnowPlay — mechanics check";window.level = .floating;window.delegate=self;window.isReleasedWhenClosed=false;window.backgroundColor=NSColor(calibratedRed:0.08,green:0.17,blue:0.21,alpha:1)
  let root=NSView(frame:NSRect(x:0,y:0,width:1000,height:600));window.contentView=root
  for c in [bank,front,action]{c.frame=NSRect(x:0,y:0,width:1000,height:550)};root.addSubview(bank)
  view=SKView(frame:bank.frame);view.allowsTransparency=true;view.preferredFramesPerSecond=60;view.showsFPS=true;view.presentScene(d.decorationScene);root.addSubview(view);root.addSubview(front);root.addSubview(action)
  for (title,selector,x) in [("Stress",#selector(stress),20.0),("Duel",#selector(duel),110),("Roll",#selector(snowballs),200),("Move",#selector(move),290),("Sculpt",#selector(sculpt),380),("Finish",#selector(finish),470)]{let b=NSButton(title:title,target:self,action:selector);b.frame=NSRect(x:x,y:562,width:80,height:28);root.addSubview(b)}
  label.frame=NSRect(x:560,y:564,width:430,height:22);label.textColor = .white;label.font=NSFont.systemFont(ofSize:12);root.addSubview(label)
  window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);stress();last=ProcessInfo.processInfo.systemUptime
  let t=Timer(timeInterval:1.0/60,repeats:true){[weak self]_ in self?.tick()};t.tolerance=0.0005;RunLoop.main.add(t,forMode:.common);timer=t
  DispatchQueue.main.asyncAfter(deadline:.now()+360){[weak self] in self?.finish()}
 }
 func reset(_ name:String){
  if start>0{save()};panel?.close();panel=nil;w.finishSculpting();w.input.stop();w.cancelCleaning();w.decorations.reset(preserveSnowman:false);w.director.cancelAll();d.engine.reset();w.config=Configuration.preset(.play);w.config.intensity=1;w.config.automaticCleaning=0;w.config.placements=[:]
  var g=SnowSurface(id:"ground-"+d.id,screenID:d.id,frame:Rect(d.rect.x,d.rect.maxY-2,d.rect.width,1),maxHeight:42);g.add(volume:30000);w.surfaces.surfaces=[g.id:g]
  let s=w.decorations.states[d.id]!
  if name != "sculpt" {for i in 0..<5{s.snowballs.balls=[26.0,20,12].map{Snowball(position:Vec(),radius:$0)};_=s.snowballs.assemblePrepared(at:Vec(d.rect.x+230+Double(i)*140,d.rect.maxY-50))}}
  stage=name;start=ProcessInfo.processInfo.systemUptime;work=[];heavyIntervals=[];heavyCosts=[];overlap=false;(d.decorationScene as? WinterScene)?.probe.reset();w.performance.resetTiming()
 }
 @objc func stress(){reset("stress");w.clean();w.decorations.pendingDelivery=true;w.config.tree=true;w.config.placements[d.id]=Placement(tree:Vec(0.07,0.85));w.decorations.update(dt:0,now:ProcessInfo.processInfo.systemUptime,displays:[d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec());let s=w.decorations.states[d.id]!;if let tree=s.tree{_=w.decorations.requestCharacter(.chopTree,display:d,target:Vec(d.rect.x+tree.position.x,d.rect.maxY-tree.position.y),windows:[],surfaces:w.surfaces,config:w.config);w.config.tree=false}}
 @objc func snowballs(){reset("snowballs");w.beginSnowballPlay()}
 @objc func move(){reset("move");w.beginEditor(.snowmen)}
 @objc func sculpt(){reset("sculpt");w.beginEditor(.snow)}
 @objc func duel(){reset("duel");let area=Rect(d.rect.x+170,d.rect.y+160,660,210);_=w.decorations.startDuel(display:d,area:area)
  panel=DuelInputPanel(area:area,primaryHeight:w.input.primaryHeight,aim:{[weak self] p in self?.w.decorations.aimDuel(at:p)},fire:{[weak self] in guard let self else{return};self.attempts+=1;if self.w.decorations.fireDuel(){self.accepted+=1}},exit:{[weak self] in guard let self else{return};self.w.endLivingDuel();self.panel?.close();self.panel=nil;self.window.makeKeyAndOrderFront(nil)})
  panel?.makeKeyAndOrderFront(nil)
 }
 func copy(_ from:SnowCanvas,_ to:SnowCanvas){to.caps=from.caps;to.dynamicCaps=from.dynamicCaps;to.dots=from.dots;to.composites=from.composites;to.snowballArt=from.snowballArt;to.artwork=from.artwork;to.hats=from.hats;to.garlandPaths=from.garlandPaths;to.garlandGlows=from.garlandGlows;to.garlandArt=from.garlandArt;to.reveals=from.reveals;to.invalidateFrame()}
 func tick(){let now=ProcessInfo.processInfo.systemUptime,dt=min(0.05,max(0,now-last));last=now;let begin=now
  w.director.tick(dt);w.flushSnowEvents();w.stepCleaning(dt:dt,now:now);d.engine.setCount(stage=="stress" ? 2400:168);d.engine.step(dt:dt,config:w.config);for id in Array(w.surfaces.surfaces.keys){w.surfaces.surfaces[id]?.relax(dt:dt)};d.render(config:w.config,windows:[],surfaces:w.surfaces,active:nil)
  w.updateSculpting();w.decorations.foregroundSnowmen=[EditorMode.snow,.snowballPlay,.snowmen].contains(w.input.mode)
  w.decorations.update(dt:dt,now:now,displays:[d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec());d.presentDesktopObjects();copy(d.canvas,front);copy(d.desktopCanvas,bank);copy(d.actionCanvas,action)
  let s=w.decorations.states[d.id]!;let heavy=s.santa != nil && s.plow != nil && s.character != nil;overlap = overlap || heavy;if heavy {heavyIntervals.append(dt*1000);heavyCosts.append((ProcessInfo.processInfo.systemUptime-begin)*1000)}
  if now-start>1{work.append((ProcessInfo.processInfo.systemUptime-begin)*1000)}
  w.performance.tick(dt:dt,now:now,particles:d.engine.particles.count,battery:false,targetFPS:60,simulating:true)
  if now-saved>0.5{saved=now;save();label.stringValue="\(stage) · \(String(format:"%.1f",((d.decorationScene as? WinterScene)?.probe.snapshot["callbackFPS"] as? Double) ?? 0)) callbacks/s · clicks \(accepted)/\(attempts)"}
 }
 func save(){guard d != nil,start>0 else{return};let s=w.decorations.states[d.id]!,a=work.sorted(),h=heavyIntervals.sorted(),hc=heavyCosts.sorted()
  reports[stage]=["seconds":ProcessInfo.processInfo.systemUptime-start,"scene":(d.decorationScene as? WinterScene)?.probe.snapshot ?? [:],"tickWorkP95MS":a.isEmpty ? 0:a[Int(Double(a.count-1)*0.95)],"performance":w.performance.snapshot,"santaPlowYetiOverlap":overlap,"overlapSamples":h.count,"overlapTickIntervalP95MS":h.isEmpty ? 0:h[Int(Double(h.count-1)*0.95)],"overlapTickWorkP95MS":hc.isEmpty ? 0:hc[Int(Double(hc.count-1)*0.95)],"drawCallbacks":["bank":bank.probe.snapshot,"front":front.probe.snapshot,"action":action.probe.snapshot],"snowmen":s.snowballs.snowmen.count,"models":s.snowballs.snowmen.map{["id":$0.id.uuidString,"x":$0.position.x,"y":$0.position.y]},"editor":w.input.mode.rawValue,"looseBalls":s.snowballPlay.balls.map{["x":$0.position.x,"y":$0.position.y,"radius":$0.radius]},"sculptBalls":s.snowballs.balls.map{$0.radius},"attempts":attempts,"accepted":accepted,"game":s.living.duel.map{["phase":$0.phase.rawValue,"yetiHP":$0.yetiHP,"playerHP":$0.playerHP,"angle":$0.angle,"power":$0.power,"ball":$0.ball != nil] as [String:Any]} ?? [:]]
  let result:[String:Any]=["scope":"Owned 1000x550pt window fixture; actual native controllers/renderer, five snowmen and 2400 weather sprites in stress. A separate CUA observation must confirm visibility and physical clicks. No desktop tracker/free-area or presented GPU timestamps measured here.","stages":reports]
  try? JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/mechanics-live-result.json"))
 }
 @objc func finish(){save();timer?.invalidate();panel?.close();w.stop();NSApp.terminate(nil)}
 func windowWillClose(_ n:Notification){finish()}
}
@main struct MechanicsLiveMain {static func main(){precondition(CommandLine.arguments.contains("--config"));let app=NSApplication.shared,delegate=MechanicsLive();app.setActivationPolicy(.regular);app.delegate=delegate;app.run();withExtendedLifetime(delegate){}}}
