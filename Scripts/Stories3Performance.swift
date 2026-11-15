import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
@main struct Stories3Performance {static func main() throws {
 let app=NSApplication.shared;app.setActivationPolicy(.accessory);app.finishLaunching()
 let f=ChristmasStoryFixture(.snowballExchange),w=f.w,d=f.d;precondition(f.start(.snowballExchange)==nil);let r=w.decorations.stories.active!
 var seek=0;while r.peakActors<17 && !r.finished {f.step();seek+=1;if seek%180==0 {RunLoop.main.run(until:Date().addingTimeInterval(0.002))}}
 precondition(r.peakActors==17)
 let hold=StoryBeat("peak-load-harness",60);r.actions=[ChristmasStoryAction(beat:hold,enter:{run in for (name,a) in run.actors {a.target=a.position;run.pose(name,.aim)}},update:{run,t in
  if t-(run.custom["benchmark-shot"] ?? -1)>0.8 {run.custom["benchmark-shot"]=t;run.launchTeamShot("elf0","yeti0",duration:1.8);run.launchTeamShot("yeti1","elf1",duration:1.8);run.launchTeamShot("giantYeti","bigElf",size:68,duration:2.2)}
 },leave:nil)];r.timeline=StoryTimeline([hold]);r.entered = -1;r.elapsed=0;r.actors["giantYeti"]?.actor.held.size=CGSize(width:29,height:29)
 w.config.snow=true;w.config.intensity=0.65;w.config.maxParticles=1400;d.engine.setCount(1400)
 let window=NSWindow(contentRect:NSRect(x:100,y:100,width:1000,height:650),styleMask:[.titled,.closable],backing:.buffered,defer:false);window.title="SnowPlay — temporary 17-character performance check";window.backgroundColor=NSColor(calibratedRed:0.07,green:0.15,blue:0.22,alpha:1);window.isReleasedWhenClosed=false
 let host=NSView(frame:d.canvas.frame);window.contentView=host;host.addSubview(f.view);host.addSubview(d.desktopCanvas);host.addSubview(d.canvas);window.orderFront(nil)
 var times:[Double]=[],intervals:[Double]=[],last=ProcessInfo.processInfo.systemUptime;let started=last
 let timer=Timer(timeInterval:1.0/60,repeats:true){_ in
  let now=ProcessInfo.processInfo.systemUptime,dt=now-last;last=now;let before=now;f.step();times.append((ProcessInfo.processInfo.systemUptime-before)*1000);intervals.append(dt*1000);w.performance.tick(dt:dt,now:now,particles:d.engine.particles.count,battery:false,targetFPS:60,simulating:true)
  if now-started>20 {
   func p95(_ input:[Double])->Double{let a=Array(input.dropFirst(120)).sorted();return a.isEmpty ? 0:a[min(a.count-1,Int(Double(a.count)*0.95))]}
   var result=w.performance.snapshot;result["passed"]=p95(times)<16.67;result["p95SimulationWorkMS"]=p95(times);result["p95TimerIntervalMS"]=p95(intervals);result["spriteKit"]=(d.decorationScene as? WinterScene)?.probe.snapshot ?? [:];result["scope"]="Owned visible native 1000x650 scene; production rig/controller held at peak battle load: 5 elves, 10 Yetis, 2 giants, 1400 snowflakes and at most 3 analytic snowballs; release (-O); callbacks, not GPU presentation";result["actors"]=r.actors.count;result["peakShots"]=r.peakShots;result["gpuPresentationMeasured"]=false
   try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/stories3-performance.json"));print("PASS: 17-character native benchmark; P95",p95(times),"ms");f.close();window.close();exit((result["passed"] as? Bool)==true ? 0:1)
  }
 };RunLoop.main.add(timer,forMode:.common);app.run();withExtendedLifetime(timer){}
}}
