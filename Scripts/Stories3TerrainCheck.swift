import AppKit
import SnowCore
@testable import SnowPlay
@main struct Stories3TerrainCheck {static func main() throws {
 _=NSApplication.shared;var results:[[String:Any]]=[]
 for id in [ChristmasStoryID.snowmanBuild,.giftConveyor,.lightRepair,.presentTheft,.treeShake,.snowmanParty,.starHat] {for level in [8.0,65.0] {
  let f=ChristmasStoryFixture(id),d=f.d,key="ground-"+d.id;var ground=SnowSurface(id:key,screenID:d.id,frame:Rect(0,648,1000,1),maxHeight:level)
  ground.add(volume:level*550);f.w.surfaces.surfaces[key]=ground;f.w.config.groundHeight=level
  let x=level<10 ? 0.3:0.7
  if id.needsTree {let old=f.w.config.placements[d.id]!.tree!.x;f.w.config.placements[d.id]?.tree?.x=x;for i in f.s.treePresents.indices {f.s.treePresents[i].position.x+=(x-old)*1000}}
  if id.needsSnowman {f.s.snowballs.snowman?.x=x*1000}
  for _ in 0..<120 {f.step()}
  precondition(f.start(id)==nil,"Terrain start \(id)");let r=f.w.decorations.stories.active!;var ticks=0
  while !r.finished && ticks<12000 {f.step();ticks+=1;if ticks%180==0{RunLoop.main.run(until:Date().addingTimeInterval(0.001))}}
  print("TERRAIN",id.rawValue,level,r.succeeded,r.interruption,r.timeline.current?.id ?? "done");fflush(stdout);precondition(r.succeeded,"Terrain scene stuck")
  results.append(["id":id.rawValue,"snowHeightLimit":level,"objectNormalizedX":x,"passed":true,"elapsed":r.elapsed]);f.close()
 }}
 try JSONSerialization.data(withJSONObject:["passed":true,"cases":results,"scope":"Production native scene controllers with low/high ground snow and objects on both sides of the display; edge rejection tested separately"],options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/stories3-terrain-result.json"));print("PASS: 14 terrain and mirrored layout runs")
}}
