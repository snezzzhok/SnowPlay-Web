import AppKit
import SnowCore
import Darwin
@testable import SnowPlay
@main struct StoryMemoryCheck {static func main() throws {
 _=NSApplication.shared
 func resident()->Double {var info=mach_task_basic_info(),count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4;let result=withUnsafeMutablePointer(to:&info){p in p.withMemoryRebound(to:integer_t.self,capacity:Int(count)){task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)}};return result==KERN_SUCCESS ? Double(info.resident_size)/1048576:0}
 var baseline=0.0,samples:[Double]=[],runs:[String:Int]=[:]
 for i in 0..<42 {
  let id=ChristmasStoryID.allCases[i%7]
  autoreleasepool {
   let f=ChristmasStoryFixture(id,keep:false);precondition(f.start(id,(i/7)%2)==nil);let run=f.w.decorations.stories.active!
   while !run.finished {f.step()}
   precondition(run.succeeded && run.root.parent==nil && run.root.children.isEmpty && run.actors.isEmpty && run.props.isEmpty && run.footprints.isEmpty && f.w.decorations.stories.reservations.owners.isEmpty)
   f.close()
  }
  runs[id.rawValue,default:0]+=1;RunLoop.main.run(until:Date().addingTimeInterval(0.003));let value=resident();samples.append(value);if i==13 {baseline=value}
 }
 let end=resident(),growth=end-baseline;precondition(growth<16,"Unbounded memory growth after all-story warmup: \(growth) MB")
 try JSONSerialization.data(withJSONObject:["passed":true,"scope":"Six loops of each of seven production stories after two-cycle texture warmup; resident high-water measurements are not an Instruments leaks scan","loops":42,"perStory":runs,"warmResidentMB":baseline,"finalResidentMB":end,"growthAfterWarmupMB":growth,"allLeasesAndStoryNodesReleased":true,"samplesMB":samples],options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/christmas-stories-memory.json"))
 print("PASS: 42 native story loops (six per story), no retained story nodes/leases; RSS after warmup changed",growth,"MB")
}}
