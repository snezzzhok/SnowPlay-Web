// Measures CPU simulation + actual Retina Core Graphics draws of our own scene.
// Deliberately does not present this as GPU/presented-frame FPS.
import AppKit
import SpriteKit
import SnowCore
@main struct LivingWorkBenchmark {
 static func main() throws {
  _=NSApplication.shared
  let w=WinterCoordinator();w.config=Configuration.preset(.play);w.rebuildDisplays();defer{w.stop()}
  guard let d=w.displays.first,let s=w.decorations.states[d.id] else{fatalError("No macOS display")}
  d.hide(true);d.rect=Rect(0,0,1440,900);d.engine.bounds=d.rect
  d.canvas.frame=NSRect(x:0,y:0,width:1440,height:900);d.desktopCanvas.frame=d.canvas.frame;d.decorationScene.size=d.canvas.frame.size
  let ground="ground-"+d.id
  w.surfaces.surfaces[ground]=SnowSurface(id:ground,screenID:d.id,frame:Rect(0,898,1440,1),maxHeight:42);w.surfaces.surfaces[ground]?.add(volume:16000)
  let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:2880,pixelsHigh:1800,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
  NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap);NSGraphicsContext.current!.cgContext.scaleBy(x:2,y:2)
  var now=ProcessInfo.processInfo.systemUptime,results:[String:Any]=[:]
  for mode in WinterMode.allCases {
   w.decorations.cancelTransient();w.config=Configuration.preset(mode);w.config.automaticCleaning=0;w.config.intensity=mode == .focus ? 0.12:mode == .balanced ? 0.35:1
   w.config.garland=mode != .focus
   w.config.placements[d.id]=Placement(garland:[Vec(0.12,0.12),Vec(0.5,0.12),Vec(0.88,0.12)],garlandTarget:"desktop")
   d.engine.setCount(SnowfallDensity.count(intensity:w.config.intensity,area:1440*900,mode:mode,limit:w.config.maxParticles))
   if mode == .play {w.decorations.pendingDelivery=true;s.plowSurface=w.surfaces.surfaces[ground];s.plowProgress=0.05;s.plowMass=700}
   var samples:[Double]=[],overlap=false
   for frame in 0..<480 {
    let began=ProcessInfo.processInfo.systemUptime
    now+=1.0/60;w.director.tick(1.0/60);w.flushSnowEvents();d.engine.step(dt:1.0/60,config:w.config)
    w.surfaces.surfaces[ground]?.relax(dt:1.0/60)
    d.render(config:w.config,windows:[],surfaces:w.surfaces,active:nil)
    if mode == .play {s.plowProgress=frame<360 ? Double(frame)/360:nil}
    w.decorations.update(dt:1.0/60,now:now,displays:[d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec(1200,700));d.presentDesktopObjects()
    d.desktopCanvas.draw(d.desktopCanvas.bounds);d.canvas.draw(d.canvas.bounds)
    overlap = overlap || (s.plow != nil && s.santa != nil)
    if frame>=60 {samples.append((ProcessInfo.processInfo.systemUptime-began)*1000)}
   }
   samples.sort();results[mode.rawValue]=["particles":d.engine.particles.count,"weatherSprites":d.snowCloud.activeCount,"measuredFrames":samples.count,"meanCPUWorkMS":samples.reduce(0,+)/Double(samples.count),"p95CPUWorkMS":samples[Int(Double(samples.count-1)*0.95)],"maxCPUWorkMS":samples.last!,"SantaAndPlowOverlapped":overlap]
  }
  let report:[String:Any]=["build":CommandLine.arguments.contains("--release") ? "Release":"Debug","scope":"Isolated own native scene, 1440x900 pt / 2880x1800 Retina bitmap. Simulation + weather SpriteKit node updates + remaining Core Graphics draws. Weather GPU drawing/presentation and other SpriteKit GPU drawing are excluded. No display wait, native live FPS, window tracker or WebKit CPU included.","modes":results,"gpuMeasured":false,"presentedFPSMeasured":false]
  try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/living-cpu-work-result.json"));print(report)
 }
}
