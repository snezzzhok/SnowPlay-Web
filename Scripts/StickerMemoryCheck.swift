import AppKit
import SnowCore
import Darwin
@testable import SnowPlay
@main struct StickerMemoryCheck {static func main() throws {
 _=NSApplication.shared;let f=ChristmasStoryFixture(.presentTheft),studio=f.w.stickerStudio
 func rss()->Double {var info=mach_task_basic_info(),count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4;let result=withUnsafeMutablePointer(to:&info){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)}};return result==KERN_SUCCESS ? Double(info.resident_size)/1048576:0}
 var baseline=0.0,samples:[Double]=[]
 for pass in 0..<50 {
  autoreleasepool {
   f.w.config.stickers.items=(0..<100).map{i in var item=StudioSticker(assetID:StickerAsset.all[i%20].id,anchor:StickerAnchor(screen:f.d.id,local:Vec(0.1+Double(i%10)*0.08,0.1+Double(i/10)*0.08)));item.segments=i%20==1 ? pass%12+1:1;item.scale=i%3==0 ? 2:1;if item.assetID=="sticker_sign"{item.text="Christmas "+String(pass)};return item}
   studio.update(now:Double(pass*2));f.w.config.stickers.items=[];studio.update(now:Double(pass*2+1));precondition(studio.drawings.isEmpty && f.d.canvas.stickers.isEmpty && f.d.desktopCanvas.stickers.isEmpty)
  }
  RunLoop.main.run(until:Date().addingTimeInterval(0.001));samples.append(rss());if pass==9{baseline=rss()}
 };let growth=rss()-baseline;precondition(growth<16,"Sticker memory grew after warmup: \(growth)")
 try JSONSerialization.data(withJSONObject:["passed":true,"cycles":50,"objectsPerCycle":100,"allDrawingsReleased":true,"warmResidentMB":baseline,"finalResidentMB":rss(),"growthAfterWarmupMB":growth,"samplesMB":samples,"scope":"Owned native scene, 50 add/remove cycles including repeated segments, large PNGs and custom sign text; RSS check, not Instruments Leaks"],options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/sticker-studio-memory-result.json"));f.close();print("PASS: 50 cycles of 100 stickers; RSS growth after warmup",growth,"MB")
}}
