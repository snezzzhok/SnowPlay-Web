import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
@main struct StoryPerformanceCheck {
 static func main() throws {
  let app=NSApplication.shared;app.setActivationPolicy(.accessory)
  let f=ChristmasStoryFixture(.presentTheft,keep:false);f.w.config.snow=true;f.w.config.intensity=0.65;f.w.config.maxParticles=1400;f.d.engine.setCount(1400)
  let window=NSWindow(contentRect:NSRect(x:120,y:120,width:1000,height:650),styleMask:[.titled,.closable],backing:.buffered,defer:false);window.title="SnowPlay — temporary native performance check";window.backgroundColor=NSColor(calibratedRed:0.07,green:0.15,blue:0.22,alpha:1);window.isReleasedWhenClosed=false
  let host=NSView(frame:f.d.canvas.frame);window.contentView=host;host.addSubview(f.view);host.addSubview(f.d.desktopCanvas);host.addSubview(f.d.canvas);window.orderFront(nil)
  if !CommandLine.arguments.contains("--without-story"){precondition(f.start(.presentTheft)==nil)}
  var intervals:[Double]=[],work:[Double]=[],last=ProcessInfo.processInfo.systemUptime,ticks=0
  let started=last
  func finish(){
  func percentile(_ a:[Double])->Double {let sorted=Array(a.dropFirst(120)).sorted();return sorted.isEmpty ? 0:sorted[min(sorted.count-1,Int(Double(sorted.count)*0.95))]}
  var result=f.w.performance.snapshot;result["scope"]="Real visible owned native AppKit/SpriteKit window, 1400 falling particles and an optional production three-actor story; callbacks are not a GPU presentation benchmark"
  result["build"]=ProcessInfo.processInfo.environment["SNOWPLAY_PROFILE_OPTIMIZED"]=="1" ? "release (-O)":"debug";result["withStory"] = !CommandLine.arguments.contains("--without-story");result["targetFPS"]=60;result["storyTicks"]=ticks;result["p95SimulationWorkMS"]=percentile(work);result["p95TimerIntervalMS"]=percentile(intervals);result["spriteKit"]=(f.d.decorationScene as? WinterScene)?.probe.snapshot ?? [:];result["canvas"]=f.d.desktopCanvas.probe.snapshot
  result["passed"]=percentile(work)<16.67;result["gpuPresentationMeasured"]=false
  try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments.contains("--without-story") ? "Docs/christmas-stories-performance-baseline.json":"Docs/christmas-stories-performance.json"))
  print(String(data:try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
  f.close();window.close();exit(0)
  }
  let timer=Timer(timeInterval:1.0/60,repeats:true){_ in
   let now=ProcessInfo.processInfo.systemUptime,dt=now-last;last=now
   let before=now;f.step();work.append((ProcessInfo.processInfo.systemUptime-before)*1000);intervals.append(dt*1000);ticks+=1
   f.w.performance.tick(dt:dt,now:now,particles:f.d.engine.particles.count,battery:false,targetFPS:60,simulating:true)
   if now-started>22 {
    finish()
   }
  };RunLoop.main.add(timer,forMode:.common);app.run();timer.invalidate()

  f.close();window.close()
 }
}
