// Controlled native AppKit/SpriteKit fixture using the production Story Engine.
import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
@main struct ChristmasStoriesCheck {
 static func main() throws {
  _=NSApplication.shared
  var reports:[[String:Any]]=[],failures:[String]=[]
  func check(_ condition:Bool,_ message:String){if !condition {failures.append(message);print("FAIL:",message)}}
  for id in ChristmasStoryID.allCases {for variant in 0...1 {
   let fixture=ChristmasStoryFixture(id),w=fixture.w,d=fixture.d,s=fixture.s
   func step(_ windows:[TrackedWindow]=[]) {fixture.step(windows)}
   let initialGifts=s.treePresents.count,initialSnowmen=w.decorations.snowmanCount
   let error=w.decorations.stories.start(id,manager:w.decorations,displays:[d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces,variant:variant)
   check(error==nil,"\(id) \(variant): start \(error ?? "")")
   guard let run=w.decorations.stories.active else{fixture.close();continue}
   if id == .santaDrop {check(run.props["santa"]?.alpha==0,"Santa flashed outside the stage before entry")}
   let overlap=w.decorations.stories.start(id,manager:w.decorations,displays:[d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces)
   check(overlap != nil,"\(id): concurrent story started")
   w.input.rebuild(displays:[d],windows:[],dock:nil,decorations:w.decorations,focus:false,icons:[]);check(w.input.panels.isEmpty,"\(id): story intercepted mouse")
   var steps=Set<String>(),n=0,peakNodes=0
   while w.decorations.stories.active != nil && n<12000 {
    if let name=run.timeline.current?.id {steps.insert(name)}
    step();n+=1
    if id == .santaDrop,run.elapsed>7.6 {check(run.props["santa"]?.parent==nil,"Santa stopped in midair instead of flying away")}
    if id == .presentTheft,!run.finished,let gift=run.selectedGift {check(!gift.node.isHidden,"Legacy floor renderer hid a story-owned gift")}
    if id == .snowballExchange,let node=run.snowmanNode,let model=run.snowman {check(abs(node.position.x-(model.position.x-d.rect.x))<40,"Snowman dodge accumulated displacement")}
    peakNodes=max(peakNodes,run.root.children.count)
    if n%120==0 {RunLoop.main.run(until:Date().addingTimeInterval(0.001))}
   }
   print("STORY",id.rawValue,variant,"duration",run.elapsed,"success",run.succeeded,"step",run.timeline.current?.id ?? "done",run.interruption)
   check(run.succeeded,"\(id) \(variant): \(run.interruption), stuck at \(run.timeline.current?.id ?? "done")")
   check(w.decorations.stories.reservations.owners.isEmpty && run.root.parent==nil,"\(id): lease/node leak")
   check(run.contacts.allSatisfy{($0["gripErrorPt"] as? Double ?? 0)<0.01},"\(id): detached prop")
   check(run.minimumActorGap>=(-0.1),"\(id): intersecting actor colliders \(run.minimumActorGap)")
   if id == .snowballExchange || id == .snowmanParty {check(w.decorations.snowmanCount==initialSnowmen,"\(id): snowman destroyed or duplicated")}
   if id == .snowmanBuild {check(w.decorations.snowmanCount==initialSnowmen+1,"Build did not add one actual snowman");check(run.takenMass>=StorySnowmanRecipe.mass-0.1,"Build used free snow");check((run.custom["rollingHandErrorPt"] ?? 100)<0.01,"Rolling hand lost contact with the ball")}
   if id == .presentTheft {check(s.treePresents.count==initialGifts+(variant==0 ? 2:1),"Theft gift count: \(s.treePresents.count)")}
   if id == .santaDrop {check(s.treePresents.count==initialGifts+1,"Santa duplicated/lost gift")}
   var report=run.snapshot;report["visitedBeats"]=steps.sorted();report["peakRootNodes"]=peakNodes;report["finalGifts"]=s.treePresents.count;reports.append(report)
   fixture.close()
  }}
  var cancellationRuns=0
  for id in ChristmasStoryID.allCases {for at in [1.0,10.0,18.0] {
   let f=ChristmasStoryFixture(id,keep:false),w=f.w,s=f.s
   let count=s.snowballs.snowmen.count,gifts=s.treePresents.count
   check(f.start(id)==nil,"Cancel fixture start \(id)")
   guard let run=w.decorations.stories.active else {f.close();continue}
   while run.elapsed<min(at,run.actions.reduce(0){$0+$1.beat.minimumDuration}*0.45) && !run.finished {f.step()}
   w.decorations.stories.stop(reason:"Cancellation test")
   for _ in 0..<60 {f.step()}
   check(run.finished && !run.succeeded,"Cancel \(id) did not finish")
   check(w.decorations.stories.reservations.owners.isEmpty && run.root.parent==nil,"Cancel \(id) left lease/node")
   check(s.snowballs.snowmen.count==count && s.treePresents.count==gifts,"Cancel \(id) changed persistent objects")
   check(s.treePresents.allSatisfy{$0.node.parent === s.root},"Cancel \(id) lost a borrowed gift")
   w.input.rebuild(displays:[f.d],windows:[],dock:nil,decorations:w.decorations,focus:false,icons:[])
   check(w.input.panels.allSatisfy{$0.level.rawValue<NSWindow.Level.normal.rawValue},"Cancel left an invisible foreground input")
   cancellationRuns+=1;f.close()
  }}
  var interruptionRuns=0
  for id in ChristmasStoryID.allCases {
   let f=ChristmasStoryFixture(id);_=f.start(id);let run=f.w.decorations.stories.active!
   for _ in 0..<120 {f.step()}
   let window=TrackedWindow(number:123,pid:999,frame:f.d.rect,z:0,now:f.now)
   for _ in 0..<70 {f.step([window])}
   check(run.finished && !run.succeeded && f.w.decorations.stories.reservations.owners.isEmpty,"Window covering \(id) did not clean up")
   interruptionRuns+=1;f.close()
  }
  var objectLossRuns=0
  for id in ChristmasStoryID.allCases {
   let f=ChristmasStoryFixture(id);_=f.start(id);let run=f.w.decorations.stories.active!
   for _ in 0..<240 {f.step()}
   if id.needsTree {f.w.config.tree=false;f.s.tree?.removeFromParent();f.s.tree=nil}
   else if let target=run.stage.snowmanID {_=f.s.snowballs.remove(target)}
   else if id == .snowmanBuild {f.w.config.stories.allowSnowmanCreation=false}else{f.w.config.mode = .focus}
   for _ in 0..<65 {f.step()}
   check(run.finished && !run.succeeded && f.w.decorations.stories.reservations.owners.isEmpty,"Object loss left a running story")
   if id.needsTree {check(f.s.treePresents.isEmpty,"Tree deletion resurrected presents")}
   objectLossRuns+=1;f.close()
  }
  let resized=ChristmasStoryFixture(.snowballExchange);_=resized.start(.snowballExchange);let resizingRun=resized.w.decorations.stories.active!;resized.d.rect.width+=100
  for _ in 0..<70 {resized.step()};check(resizingRun.finished && !resizingRun.succeeded,"Display resize left a running story");resized.close()
  for id in [ChristmasStoryID.presentTheft,.santaDrop,.snowmanParty] {
   let f=ChristmasStoryFixture(id,keep:false),gifts=f.s.treePresents.count;_=f.start(id,1);let run=f.w.decorations.stories.active!
   while !run.finished {f.step()}
   check(run.succeeded && f.s.treePresents.count==gifts,"Temporary decorations changed permanent gift inventory")
   if id == .snowmanParty {let node=f.s.snowmanNode;check(node?.childNode(withName:"story-party-hat")==nil && node?.childNode(withName:"snowman_hat")?.alpha==1,"Temporary party costume leaked")}
   f.close()
  }
  let party=ChristmasStoryFixture(.snowmanParty)
  for i in 0..<3 {check(party.start(.snowmanParty,i%2)==nil,"Repeat party unavailable");let run=party.w.decorations.stories.active!;while !run.finished {party.step()};let styles=party.s.snowmanNode!.children.filter{$0.name?.hasPrefix("story-party-")==true};check(styles.count==3,"Repeated party duplicated costume nodes")}
  let saved=try Configuration.decodeCompatible(JSONEncoder().encode(party.w.config))
  let restored=WinterCoordinator();restored.config=saved;restored.rebuildDisplays();let restoredDisplay=restored.displays[0]
  restored.decorations.update(dt:1.0/60,now:ProcessInfo.processInfo.systemUptime,displays:[restoredDisplay],config:restored.config,windows:[],dock:nil,surfaces:restored.surfaces,director:restored.director,mouse:Vec())
  let restoredModel=restored.decorations.states[restoredDisplay.id]?.snowmanNode
  check(restoredModel?.childNode(withName:"story-party-lights")?.children.count==5 && restoredModel?.childNode(withName:"story-party-hat") != nil,"Permanent party costume did not restore");restored.stop()
  check(party.start(.snowmanParty)==nil,"Party cancellation unavailable");let dressing=party.w.decorations.stories.active!;while dressing.elapsed<12 {party.step()};party.w.decorations.stories.stop();for _ in 0..<60 {party.step()}
  check(party.s.snowmanNode!.children.filter{$0.name?.hasPrefix("story-party-")==true}.count==3,"Cancelled party erased or duplicated the old outfit");party.close()
  let limit=ChristmasStoryFixture(.snowmanBuild)
  for i in 0..<5 {limit.s.snowballs.balls=StorySnowmanRecipe.radii.map{Snowball(position:Vec(Double(100+i*120),600),radius:$0)};_=limit.s.snowballs.assemblePrepared(at:Vec(Double(100+i*120),600))}
  check(limit.start(.snowmanBuild) != nil && limit.w.decorations.snowmanCount==5,"Created sixth snowman");limit.close()
  try JSONSerialization.data(withJSONObject:["passed":failures.isEmpty,"scope":"Production native controllers in isolated own macOS scene, no synthetic browser animation","runs":reports,"cancellationRuns":cancellationRuns,"windowInterruptionRuns":interruptionRuns,"objectLossRuns":objectLossRuns,"displayResizeCleanup":true,"partyOutfitRestoresAfterRestart":true,"partyIsIdempotentAndRollsBack":true,"failures":failures],options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/christmas-stories-native-result.json"))
  print("RESULT:",reports.count,"native runs,",failures.count,"failures");exit(failures.isEmpty ? 0:1)
 }
}
