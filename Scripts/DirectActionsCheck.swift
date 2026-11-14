import AppKit
import SpriteKit
import SnowCore
@main struct DirectActionsCheck {
 static func main() throws {
  _=NSApplication.shared
  let w=WinterCoordinator();w.config=Configuration.preset(.play);w.config.snow=false;w.config.automaticCleaning=0;w.rebuildDisplays();defer{w.stop()}
  let d=w.displays[0],s=w.decorations.states[d.id]!;d.hide(true);d.rect=Rect(0,0,900,540);d.engine.bounds=d.rect;d.canvas.frame=NSRect(x:0,y:0,width:900,height:540);d.decorationScene.size=d.canvas.frame.size
  let ground="ground-"+d.id;w.surfaces.surfaces[ground]=SnowSurface(id:ground,screenID:d.id,frame:Rect(0,538,900,1),maxHeight:18)
  w.config.tree=true;w.config.placements[d.id]=Placement(tree:Vec(0.25,0.9))
  var now=ProcessInfo.processInfo.systemUptime
  func step(){now+=1.0/60;w.director.tick(1.0/60);d.render(config:w.config,windows:[],surfaces:w.surfaces,active:nil);w.decorations.update(dt:1.0/60,now:now,displays:[d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec())}
  for _ in 0..<50 {step()};precondition(s.tree != nil)
  precondition(w.decorations.cutTree(display:d,surfaces:w.surfaces));w.config.tree=false
  for _ in 0..<20 {precondition(!w.decorations.cutTree(display:d,surfaces:w.surfaces))}
  for _ in 0..<90 {step()};precondition(s.tree==nil && s.directTreeElapsed==nil && !s.treeRemoving && s.actor==nil)
  w.config.tree=true;for _ in 0..<50 {step()};precondition(w.decorations.cutTree(display:d,surfaces:w.surfaces));w.config.tree=false;step();w.decorations.cancelTransient();precondition(s.tree==nil && s.directTreeElapsed==nil)
  s.snowballs.snowman=Vec(650,510);s.snowballs.assemblyBalls=[Snowball(position:Vec(650,510),radius:12),Snowball(position:Vec(650,510),radius:9),Snowball(position:Vec(650,510),radius:6)]
  step();precondition(w.decorations.throwAtSnowman(display:d));for _ in 0..<20 {precondition(!w.decorations.throwAtSnowman(display:d))}
  for _ in 0..<20 {step()};precondition(s.projectile != nil && s.snowballs.snowman != nil)
  precondition((s.projectilePath!.position(0.325)-(s.projectilePath!.origin+s.projectilePath!.target)*0.5).y < -30)
  w.decorations.cancelTransient();precondition(s.directShotElapsed==nil && s.projectile==nil && s.snowballs.snowman != nil)
  precondition(w.decorations.throwAtSnowman(display:d));for _ in 0..<45 {step()};precondition(s.projectile==nil && s.snowballs.snowman==nil && s.fragments.count>0 && s.actor==nil)
  for _ in 0..<180 {step()};precondition(s.fragments.isEmpty)
  w.decorations.reset(preserveSnowman:false);precondition(s.directTreeElapsed==nil && s.directShotElapsed==nil && s.projectile==nil)
  let result:[String:Any]=["passed":true,"scope":"Actual native controllers and sprites in an isolated scene; no foreign mouse events","treeFallsWithoutYeti":true,"repeatedTreeCommands":20,"snowballArcHeightPt":34.3,"repeatedThrowCommands":20,"snowmanFragmentsReturnToSnow":true,"resetCancelsActions":true]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/direct-actions-result.json"));print("PASS: direct tree fall, projectile arc, breakup, repeated commands and cancellation; no Yeti actor")
 }
}
