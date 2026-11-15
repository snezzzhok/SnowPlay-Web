import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
@main struct StickerStudioCheck {
 static func main() throws {
  _=NSApplication.shared;NSApp.setActivationPolicy(.accessory)
  let f=ChristmasStoryFixture(.presentTheft),w=f.w,studio=w.stickerStudio,d=f.d
  w.config.stickers.autoSnap=false
  for (i,a) in StickerAsset.all.enumerated(){
   studio.placing=a.id;studio.pointer("down",at:Vec(100+Double(i%5)*175,100+Double(i/5)*125),display:d);studio.pointer("up",at:Vec(),display:d)
   precondition(AssetManager.shared.image(a.id) != nil)
  };studio.update(now:f.now);precondition(w.config.stickers.items.count==20 && studio.drawings.count==20)
  let selected=studio.selected!;_=studio.apply("transform",["scale":1.8,"rotation":35.0,"flipX":true,"flipY":true]);_=studio.apply("duplicate");precondition(w.config.stickers.items.count==21);_=studio.apply("delete");precondition(w.config.stickers.items.count==20);_=studio.apply("undo");precondition(w.config.stickers.items.count==21);_=studio.apply("redo");precondition(w.config.stickers.items.count==20)
  studio.selected=selected;_=studio.apply("transform",["locked":true]);precondition(!studio.apply("delete"));_=studio.apply("transform",["locked":false])
  // Actual production attachment resolution uses one frame sample for window position/size.
  var windows=[TrackedWindow(number:912345,pid:2222,frame:Rect(100,100,500,300),z:1,now:0)];w.interactionWindowSource={windows};w.config.stickers.autoSnap=true
  var wreath=studio.attachment("sticker_wreath",at:Vec(580,112),display:d);precondition(wreath.anchor.kind == .window);w.config.stickers.items.append(wreath)
  let before=studio.resolve(wreath)!.point;windows[0].frame=Rect(200,150,700,450);let after=studio.resolve(wreath)!.point
  precondition(abs(after.x-(200+700*wreath.anchor.local.x))<0.001 && after != before)
  studio.update(now:f.now+1);precondition(studio.drawings[wreath.id] != nil)
  let front=TrackedWindow(number:5,pid:3333,frame:Rect(0,0,1000,650),z:0,now:0);windows.append(front);studio.update(now:f.now+2);precondition(studio.drawings[wreath.id]==nil);windows.removeLast()
  let original=windows[0];windows=[TrackedWindow(number:original.number,pid:original.pid,frame:original.frame,z:1,now:0)];precondition(studio.resolve(wreath)==nil)
  windows=[original];let restarted=StickerStudio(w);precondition(restarted.resolve(wreath)==nil)
  windows=[];studio.placing=wreath.assetID;studio.reattaching=wreath.id;studio.pointer("down",at:Vec(80,600),display:d);precondition(w.config.stickers.items.first(where:{$0.id==wreath.id})?.anchor.kind != .window)
  windows=[];w.config.stickers.autoSnap=true
  let treePoint=f.s.tree!.convert(CGPoint(x:0,y:f.s.treeHeight*0.4),to:f.s.root),point=Vec(treePoint.x,d.rect.maxY-treePoint.y)
  let star=studio.attachment("sticker_star",at:point,display:d);precondition(star.anchor.kind == .tree);w.config.stickers.items.append(star);let p=studio.resolve(star)!.point;f.s.tree!.position.x+=25;precondition(abs(studio.resolve(star)!.point.x-p.x-25)<0.001)
  f.s.snowballs.balls=StorySnowmanRecipe.radii.map{Snowball(position:Vec(750,600),radius:$0)};_=f.s.snowballs.assemblePrepared(at:Vec(750,600));for _ in 0..<160 {f.step()}
  let m=f.s.snowballs.snowmen[0],hat=StudioSticker(assetID:"sticker_hat",anchor:StickerAnchor(kind:.snowman,screen:d.id,local:Vec(0.5,0.09),parent:m.id.uuidString));w.config.stickers.items.append(hat);precondition(studio.resolve(hat) != nil);studio.prepareAccessories();precondition(f.s.snowmanNode?.childNode(withName:"snowman_hat")?.isHidden==true)
  w.config.stickers.items.removeAll{$0.id==hat.id};studio.prepareAccessories();precondition(f.s.snowmanNode?.childNode(withName:"snowman_hat")?.isHidden==false)
  let identity=w.config.placements[d.id]!.treeIdentity!;w.persist();let loaded=Configuration.load(from:w.configURL);precondition(loaded.placements[d.id]?.treeIdentity==identity && loaded.stickers.items==w.config.stickers.items)
  w.config.tree=false;precondition(studio.resolve(star)==nil);w.config.tree=true
  wreath.anchor.session="another-app-launch";precondition(studio.resolve(wreath)==nil)
  // Static scenes reuse cached transforms; size/rotation are not recalculated at 60 Hz.
  w.config.stickers.items=StickerAsset.all.enumerated().map{i,a in StudioSticker(assetID:a.id,anchor:StickerAnchor(screen:d.id,local:Vec(0.08+Double(i%5)*0.2,0.18+Double(i/5)*0.2)))};w.config.stickers.animations=false;studio.update(now:100);for drawing in studio.drawings.values {precondition(drawing.bounds.x>=d.rect.x && drawing.bounds.maxX<=d.rect.maxX && drawing.bounds.y>=d.rect.y && drawing.bounds.maxY<=d.rect.maxY,"Complete rotated desktop image must stay on display")}
  let passes=studio.renderPasses
  for i in 0..<120 {studio.update(now:100+Double(i)/60)};precondition(studio.renderPasses==passes)
  let folder=URL(fileURLWithPath:"Docs");try f.bitmap(scale:2).representation(using:.png,properties:[:])!.write(to:folder.appendingPathComponent("Sticker-Studio-Native.png"))
  var times:[Double]=[];w.config.stickers.items=(0..<100).map{i in StudioSticker(assetID:StickerAsset.all[i%20].id,anchor:StickerAnchor(screen:d.id,local:Vec(0.05+Double(i%10)*0.1,0.1+Double(i/10)*0.09)))};w.config.stickers.animations=true
  for i in 0..<600 {let start=ProcessInfo.processInfo.systemUptime;studio.update(now:200+Double(i)/60);times.append((ProcessInfo.processInfo.systemUptime-start)*1000)}
  times.sort();let p95=times[Int(Double(times.count)*0.95)];precondition(p95<16.67)
  precondition(w.displays.allSatisfy{$0.foreground.ignoresMouseEvents && $0.desktopSnow.ignoresMouseEvents})
  let metadata=try JSONEncoder().encode(StickerAsset.all);try metadata.write(to:Resources.root.appendingPathComponent("SnowPlayAssets/Stickers/sticker-metadata.json"))
  try JSONSerialization.data(withJSONObject:["passed":true,"models":20,"windowMoveResize":true,"windowIDReuseRejected":true,"restartWindowAnchorInactive":true,"occlusion":true,"treeMovement":true,"snowmanAccessories":true,"undoRedo":true,"staticTransformCache":true,"qualityRetainsSavedItems":true,"clickThrough":true,"profileScope":"100 stickers, 600 production update calls in an owned native fixture; simulation work, not GPU-presented FPS","p95UpdateMS":p95],options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("sticker-studio-native-result.json"))
  let preserved=w.config.stickers;w.applyPreset(.focus);precondition(w.config.stickers==preserved);w.applyPreset(.balanced);precondition(w.config.stickers==preserved);w.applyPreset(.play);precondition(w.config.stickers==preserved)
  f.close();print("PASS: 20 models, transforms, Undo/Redo, windows, occlusion, parent poses, persistence, static cache, 100-object P95",p95,"ms")
 }
}
