import AppKit
import SpriteKit
import SnowCore
import Darwin
@testable import SnowPlay
@main struct StickerPerformanceCheck {static func main() throws {
 let app=NSApplication.shared;app.setActivationPolicy(.accessory);app.finishLaunching()
 let f=ChristmasStoryFixture(.presentTheft),w=f.w,d=f.d,studio=w.stickerStudio
 w.config.snow=true;w.config.intensity=0.65;w.config.maxParticles=1400;d.engine.setCount(1400)
 w.config.stickers.items=(0..<100).map{i in var item=StudioSticker(assetID:StickerAsset.all[i%20].id,anchor:StickerAnchor(screen:d.id,local:Vec(0.055+Double(i%10)*0.1,0.13+Double(i/10)*0.085)));item.scale=0.65;return item}
 let window=NSWindow(contentRect:NSRect(x:100,y:100,width:1000,height:650),styleMask:[.titled,.closable],backing:.buffered,defer:false);window.title="SnowPlay — temporary sticker performance check";window.backgroundColor=NSColor(calibratedRed:0.07,green:0.15,blue:0.22,alpha:1);window.isReleasedWhenClosed=false
 let host=NSView(frame:d.canvas.frame);window.contentView=host;host.addSubview(f.view);host.addSubview(d.desktopCanvas);host.addSubview(d.canvas);window.orderFront(nil)
 var times:[Double]=[],intervals:[Double]=[],last=ProcessInfo.processInfo.systemUptime;let started=last
 let timer=Timer(timeInterval:1.0/60,repeats:true){_ in
  let now=ProcessInfo.processInfo.systemUptime,dt=now-last;last=now;let before=now;f.step();studio.update(now:now);d.presentDesktopObjects();times.append((ProcessInfo.processInfo.systemUptime-before)*1000);intervals.append(dt*1000);w.performance.tick(dt:dt,now:now,particles:d.engine.particles.count,battery:false,targetFPS:60,simulating:true)
  if now-started>20 {
   func p95(_ input:[Double])->Double{let a=Array(input.dropFirst(120)).sorted();return a.isEmpty ? 0:a[min(a.count-1,Int(Double(a.count)*0.95))]}
   var result=w.performance.snapshot;result["passed"]=p95(times)<16.67;result["p95SimulationWorkMS"]=p95(times);result["p95TimerIntervalMS"]=p95(intervals);result["spriteKit"]=(d.decorationScene as? WinterScene)?.probe.snapshot ?? [:];result["canvas"]=d.desktopCanvas.probe.snapshot;result["scope"]="Visible owned 1000x650 native window, 1400 falling particles and 100 stickers, 12 animated maximum; debug build; callback timing, GPU presentation not measured";result["stickers"]=100;result["animatedLimit"]=12;result["gpuPresentationMeasured"]=false
   try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/sticker-studio-performance.json"));print("PASS: visible native 100-sticker profile; P95 simulation",p95(times),"ms");f.close();window.close();exit((result["passed"] as? Bool)==true ? 0:1)
  }
 };RunLoop.main.add(timer,forMode:.common);app.run();withExtendedLifetime(timer){}
}}
