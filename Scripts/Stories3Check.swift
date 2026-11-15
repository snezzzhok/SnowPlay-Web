import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
@main struct Stories3Check {static func main() throws {
 _=NSApplication.shared;var results:[[String:Any]]=[],errors:[String]=[]
 func check(_ ok:Bool,_ why:String){if !ok {errors.append(why);print("FAIL",why);fflush(stdout)}}
 for id in ChristmasStoryID.allCases {for variant in 0...1 {
  let f=ChristmasStoryFixture(id),w=f.w;guard f.start(id,variant)==nil,let r=w.decorations.stories.active else{check(false,"Cannot start \(id)");f.close();continue}
  var n=0,maximumFootError=0.0,maximumReach=0.0
  while !r.finished && n<12000 {
   f.step();n+=1
   for actor in r.actors.values where actor.active {check(actor.actor.node.alpha<=0.05 || !actor.actor.node.isHidden,"Active actor is hidden in \(id)");if let rig=actor.actor.storyRig {maximumReach=max(maximumReach,rig.maxReach)
    if [.walk,.run,.carry,.sneak].contains(actor.pose) && !actor.climbing {
     let expected=w.decorations.groundY(actor.position.x,display:f.d,surfaces:w.surfaces);maximumFootError=max(maximumFootError,abs(actor.position.y-expected))
    }
   }}
   if n%180==0 {RunLoop.main.run(until:Date().addingTimeInterval(0.001))}
  }
  check(r.succeeded,"\(id) \(variant) stuck: \(r.timeline.current?.id ?? "done") / \(r.interruption)");check(w.decorations.stories.reservations.owners.isEmpty && r.root.parent==nil,"Leaked \(id)");check(maximumFootError<0.5,"Floating actor \(id) \(maximumFootError)");check(maximumReach<=24.501,"Stretched arm \(id)")
  if id == .snowballExchange {check(r.peakActors==17,"Battle cast \(r.peakActors)");check(r.peakShots<=3 && r.shotImpacts==18,"Battle shots \(r.shotImpacts)")}
  if id == .snowmanBuild {check(w.decorations.snowmanCount==1,"No completed snowman");check((r.custom["rollingHandErrorPt"] ?? 999)<1,"Rolling grip \(r.custom["rollingHandErrorPt"] ?? 999)")}
  if id == .giftConveyor {check(r.contacts.filter{($0["event"] as? String)=="relay-hand-off"}.count==12,"Missing relay handoffs")}
  var item=r.snapshot;item["maximumFootErrorPt"]=maximumFootError;item["maximumArmReachPt"]=maximumReach;results.append(item);print("SCENE",id.rawValue,variant,r.elapsed,r.succeeded,r.timeline.current?.id ?? "done",r.interruption);fflush(stdout);f.close()
 }}
 var cancellations=0
 for id in ChristmasStoryID.allCases {
  let f=ChristmasStoryFixture(id);_=f.start(id);let r=f.w.decorations.stories.active!
  for _ in 0..<600 {f.step()};f.w.decorations.stories.stop(reason:"Test cancel");for _ in 0..<60{f.step()}
  check(r.finished && !r.succeeded && r.root.parent==nil && r.shots.isEmpty && f.w.decorations.stories.reservations.owners.isEmpty,"Cancellation \(id)");cancellations+=1;f.close()
 }
 let queueFixture=ChristmasStoryFixture(.garlandRemoval),w=queueFixture.w,d=queueFixture.d
 var p=w.config.placements[d.id]!;p.extraGarlands=[GarlandStrand(id:"second",anchors:[Vec(0.1,0.28),Vec(0.8,0.28)])];w.config.placements[d.id]=p
 for _ in 0..<60 {queueFixture.step()};check(w.garlandRemoval.targets().count==2,"Two garlands not registered")
 w.garlandRemoval.deleteAll();w.garlandRemoval.deleteAll();check(w.garlandRemoval.queue.count==2,"Duplicate delete queue")
 var guardTicks=0
 while (!w.garlandRemoval.queue.isEmpty || w.decorations.stories.active != nil) && guardTicks<8000 {w.garlandRemoval.update();queueFixture.step();guardTicks+=1}
 check(w.config.placements[d.id]?.garland.isEmpty==true && w.config.placements[d.id]?.extraGarlands?.isEmpty==true,"Delete all did not commit");check(w.garlandRemoval.reserved.isEmpty,"Deletion leases remained");queueFixture.close()
 let edge=ChristmasStoryFixture(.snowballExchange);edge.s.snowballs.snowman?.x=30;let available=edge.w.decorations.stories.availability(.snowballExchange,manager:edge.w.decorations,displays:[edge.d],config:edge.w.config,windows:[],dock:nil,surfaces:edge.w.surfaces);check(!available.available,"Battle allowed clipped edge staging");edge.close()
 let result:[String:Any]=["passed":errors.isEmpty,"runs":results,"failures":errors,"cancellations":cancellations,"garlandQueueNoDuplicates":true,"edgeStagingRejected":true,"scope":"Production native controllers, two endings of every scene; temporary preferences"]
 try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/stories3-native-result.json"));print("RESULT",results.count,"runs",errors.count,"failures");exit(errors.isEmpty ? 0:1)
}}
