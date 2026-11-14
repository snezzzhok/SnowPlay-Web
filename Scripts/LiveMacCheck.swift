// Live, isolated native UI qualification. Never reads or controls other apps' contents.
import AppKit
import SpriteKit
import SnowCore
final class PanelLiveCheck:NSObject,NSApplicationDelegate {
 let product=AppDelegate();var attempts=0;var opened=false
 func applicationDidFinishLaunching(_ notification:Notification){
  product.applicationDidFinishLaunching(notification)
  DispatchQueue.main.asyncAfter(deadline:.now()+1.5){self.product.status.button!.performClick(nil);self.opened=self.product.control!.popover.isShown;self.inspect()}
 }
 func inspect(){
  attempts+=1
  if !product.control!.popover.isShown {product.status.button!.performClick(nil)}
  product.control!.webView.evaluateJavaScript("({tabs:document.querySelectorAll('[role=tab]').length,images:[...document.images].every(i=>i.complete&&i.naturalWidth>0),loaded:typeof config!=='undefined'&&!!config,connected:document.getElementById('connection').textContent,message:document.getElementById('message').textContent})") { value,error in
   let values=value as? [String:Any] ?? [:]
   if self.attempts<20 && (values["loaded"] as? Bool != true || values["images"] as? Bool != true){DispatchQueue.main.asyncAfter(deadline:.now()+0.5){self.inspect()};return}
   let passed=error==nil && self.opened && values["tabs"] as? Int==5 && values["images"] as? Bool==true && values["loaded"] as? Bool==true
   self.product.control!.webView.takeSnapshot(with:nil){image,_ in
    if let tiff=image?.tiffRepresentation,let data=NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]){try? data.write(to:URL(fileURLWithPath:"Docs/living-popover-live.png"))}
    let result:[String:Any]=["passed":passed,"scope":"Actual product AppDelegate status-button action and NSPopover on unlocked macOS; own content snapshot only","popoverShown":self.opened,"observation":values,"attempts":self.attempts,"error":String(describing:error)]
    try? JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/living-popover-live.json"));print(passed ? "PASS: native menu-bar action opens connected NSPopover":"FAIL: native popover did not finish connecting",values);NSApp.terminate(nil)
   }
  }
 }
 func applicationWillTerminate(_ n:Notification){product.applicationWillTerminate(n)}
}
final class PreviewCursorView:NSView {
 var motion:((Vec)->Void)?;private var tracking:NSTrackingArea?
 override func updateTrackingAreas(){if let old=tracking{removeTrackingArea(old)};let a=NSTrackingArea(rect:bounds,options:[.activeAlways,.mouseMoved,.inVisibleRect],owner:self,userInfo:nil);tracking=a;addTrackingArea(a);super.updateTrackingAreas()}
 private func point(_ e:NSEvent){let p=convert(e.locationInWindow,from:nil);motion?(Vec(p.x,bounds.height-p.y))}
 override func mouseMoved(with e:NSEvent){point(e)}
 override func mouseDown(with e:NSEvent){point(e)}
 override func mouseDragged(with e:NSEvent){point(e)}
 override func acceptsFirstMouse(for event:NSEvent?)->Bool{true}
}
final class SceneLiveCheck:NSObject,NSApplicationDelegate,NSWindowDelegate {
 var window:NSWindow!,view:SKView!,coordinator:WinterCoordinator!,display:DisplayOverlay!,input:DuelInputView!
 let bank=SnowCanvas(),front=SnowCanvas(),info=NSTextField(labelWithString:"")
 var timer:Timer?,last=0.0,began=0.0,lastSave=0.0,stage="peak",pointerFires=0,acceptedFires=0,overlap=false
 var work:[Double]=[],reports:[String:Any]=[:]
 let path=URL(fileURLWithPath:"Docs/living-visible-preview.json")
 func applicationDidFinishLaunching(_ notification:Notification){
  coordinator=WinterCoordinator();coordinator.rebuildDisplays();display=coordinator.displays[0];display.hide(true);display.rect=Rect(0,0,900,540);display.engine.bounds=display.rect;display.decorationScene.size=CGSize(width:900,height:540)
  display.canvas.frame=NSRect(x:0,y:0,width:900,height:540);display.desktopCanvas.frame=display.canvas.frame
  window=NSWindow(contentRect:NSRect(x:20,y:120,width:900,height:594),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
  window.level = .floating;window.title="SnowPlay — живая проверка";window.isReleasedWhenClosed=false;window.delegate=self;window.backgroundColor=NSColor(calibratedRed:0.08,green:0.17,blue:0.21,alpha:1)
  let root=NSView(frame:NSRect(x:0,y:0,width:900,height:594));window.contentView=root
  for canvas in [bank,front]{canvas.frame=NSRect(x:0,y:0,width:900,height:540)};bank.groundLayer=true;root.addSubview(bank)
  view=SKView(frame:bank.frame);view.allowsTransparency=true;view.preferredFramesPerSecond=60;view.ignoresSiblingOrder=true;view.showsFPS=true;view.showsNodeCount=true;view.presentScene(display.decorationScene);root.addSubview(view);root.addSubview(front)
  for (title,action,x) in [("Дуэль",#selector(duel),20.0),("Санта + снегоуборщик",#selector(peak),130),("Завершить",#selector(finish),355)] {let b=NSButton(title:title,target:self,action:action);b.frame=NSRect(x:x,y:553,width:title=="Санта + снегоуборщик" ? 210:100,height:28);root.addSubview(b)}
  info.frame=NSRect(x:480,y:557,width:400,height:22);info.font=NSFont.systemFont(ofSize:11);info.textColor = .white;root.addSubview(info)
  input=DuelInputView(frame:NSRect(x:100,y:170,width:660,height:210));input.aimPoint={ [weak self] p in self?.coordinator.decorations.aimDuel(at:Vec(100+p.x,160+p.y))};input.fire={ [weak self] in guard let self else{return};self.pointerFires+=1;if self.coordinator.decorations.fireDuel(){self.acceptedFires+=1}};input.exit={ [weak self] in self?.coordinator.decorations.exitDuel()};root.addSubview(input);input.isHidden=true
  let cursor=PreviewCursorView(frame:bank.frame);cursor.motion={ [weak self] p in self?.coordinator.brushPointer(p,now:ProcessInfo.processInfo.systemUptime)};root.addSubview(cursor,positioned:.below,relativeTo:input);window.acceptsMouseMovedEvents=true
  window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);peak()
  last=ProcessInfo.processInfo.systemUptime
  let timer=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.tick()};timer.tolerance=0.002;RunLoop.main.add(timer,forMode:.common);self.timer=timer
  DispatchQueue.main.asyncAfter(deadline:.now()+120){[weak self] in self?.finish()}
 }
 func reset(_ next:String){
  save();coordinator.cancelCleaning();coordinator.director.cancelAll();coordinator.decorations.reset(preserveSnowman:false);display.engine.reset();coordinator.config=Configuration.preset(.play);coordinator.config.windowSnow=false;coordinator.config.intensity=1;coordinator.config.automaticCleaning=0
  var ground=SnowSurface(id:"ground-"+display.id,screenID:display.id,frame:Rect(0,538,900,1),maxHeight:42);ground.add(volume:12000);coordinator.surfaces.surfaces=[ground.id:ground]
  stage=next;began=ProcessInfo.processInfo.systemUptime;work=[];overlap=false;(display.decorationScene as? WinterScene)?.probe.reset();bank.probe.reset();front.probe.reset();coordinator.performance.resetTiming()
 }
 @objc func peak(){reset("peak");input.isHidden=true;coordinator.decorations.pendingDelivery=true;coordinator.clean()}
 @objc func duel(){reset("duel");_=coordinator.decorations.startDuel(display:display,area:Rect(100,160,660,210));input.isHidden=false;window.makeFirstResponder(input)}
 func copy(_ from:SnowCanvas,to canvas:SnowCanvas){
  canvas.dots=from.dots;canvas.caps=from.caps;canvas.dynamicCaps=from.dynamicCaps;canvas.composites=from.composites;canvas.snowballArt=from.snowballArt;canvas.reveals=from.reveals;canvas.garlandGlows=from.garlandGlows;canvas.garlandArt=from.garlandArt;canvas.garlandPaths=from.garlandPaths;canvas.artwork=from.artwork;canvas.hats=from.hats;canvas.frost=from.frost;canvas.needsDisplay=true
 }
 func tick(){
  let now=ProcessInfo.processInfo.systemUptime,dt=min(0.05,max(0,now-last));last=now;let start=now
  coordinator.director.tick(dt);coordinator.flushSnowEvents();coordinator.stepCleaning(dt:dt,now:now)
  let game=coordinator.decorations.duelActive;var c=coordinator.config;if game{c.snowSpeed=0.45}
  display.engine.setCount(SnowfallDensity.count(intensity:game ? 0.18:c.intensity,area:900*540,mode:c.mode,limit:c.maxParticles));display.engine.step(dt:dt,config:c)
  for key in coordinator.surfaces.surfaces.keys{coordinator.surfaces.surfaces[key]?.relax(dt:dt)}
  display.render(config:c,windows:[],surfaces:coordinator.surfaces,active:nil)
  coordinator.decorations.update(dt:dt,now:now,displays:[display],config:c,windows:[],dock:nil,surfaces:coordinator.surfaces,director:coordinator.director,mouse:Vec(450,300));display.presentDesktopObjects();copy(display.desktopCanvas,to:bank);copy(display.canvas,to:front)
  let state=coordinator.decorations.states[display.id]!
  overlap = overlap || (state.santa != nil && state.plow != nil)
  if CommandLine.arguments.contains("--auto"),state.living.duel?.phase == .playerAim {coordinator.decorations.aimDuel(0.5);_=coordinator.decorations.fireDuel()}
  if now-began>1{work.append((ProcessInfo.processInfo.systemUptime-start)*1000);if work.count>1800{work.removeFirst(60)}}
  coordinator.performance.tick(dt:dt,now:now,particles:display.engine.particles.count,battery:false,targetFPS:60,simulating:true)
  if now-lastSave>1{lastSave=now;save();info.stringValue="\(stage) · \(String(format:"%.1f",((display.decorationScene as? WinterScene)?.probe.snapshot["callbackFPS"] as? Double) ?? 0)) callbacks/s · Space / Escape"}
 }
 func save(){
  guard display != nil else{return};let sorted=work.sorted(),state=coordinator.decorations.states[display.id]!
  let report:[String:Any]=["seconds":max(0,ProcessInfo.processInfo.systemUptime-began),"scene":(display.decorationScene as? WinterScene)?.probe.snapshot ?? [:],"mainTickP95WorkMS":sorted.isEmpty ? 0:sorted[Int(Double(sorted.count-1)*0.95)],"performance":coordinator.performance.snapshot,"santaAndPlowOverlap":overlap,"brushedSnowMass":coordinator.stateJSON()["brushedSnowVolume"] ?? 0,"pointerFires":pointerFires,"acceptedFires":acceptedFires,"duel":state.living.duel.map{["phase":$0.phase.rawValue,"playerHP":$0.playerHP,"yetiHP":$0.yetiHP,"power":$0.power] as [String:Any]} ?? [:]]
  reports[stage]=report
  let result:[String:Any]=["scope":"Visible own 900x540pt test window on real macOS, same native SpriteKit/controllers/physics; window tracking and desktop free-area policy are not measured here. FPS values are native update callbacks, not GPU presentation timestamps.","presentedGPUFramesMeasured":false,"stages":reports]
  try? JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:path)
 }
 @objc func finish(){save();timer?.invalidate();coordinator.stop();NSApp.terminate(nil)}
 func windowWillClose(_ n:Notification){finish()}
}
@main struct LiveMacCheck {
 static func main(){
  precondition(CommandLine.arguments.contains("--config"),"An isolated configuration path is required")
  let app=NSApplication.shared;let fixture:NSApplicationDelegate
  if CommandLine.arguments.contains("--panel"){app.setActivationPolicy(.accessory);fixture=PanelLiveCheck()}
  else{app.setActivationPolicy(.regular);fixture=SceneLiveCheck()}
  app.delegate=fixture;app.run();withExtendedLifetime(fixture){}
 }
}
