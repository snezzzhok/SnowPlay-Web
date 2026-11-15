import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
/// Isolated preferences, real production scene graph and AppKit renderers.
final class ChristmasStoryFixture {
 let w:WinterCoordinator,d:DisplayOverlay,s:DecorationState,view:SKView
 var now=ProcessInfo.processInfo.systemUptime
 let width=1000.0,height=650.0
 init(_ id:ChristmasStoryID,keep:Bool=true){
  w=WinterCoordinator();w.config=Configuration.preset(.play);w.config.snow=false;w.config.maxParticles=0;w.config.intensity=0;w.config.placements=[:];w.config.stories.allowSnowmanCreation=true;w.config.stories.keepDecorations=keep;w.config.stories.pauseOnBattery=false;w.config.treeGarland="multi";w.rebuildDisplays();w.interactionWindowSource={[]}
  d=w.displays[0];s=w.decorations.states[d.id]!;d.hide(true);d.rect=Rect(0,0,width,height);d.engine.bounds=d.rect;d.decorationScene.size=CGSize(width:width,height:height);d.canvas.frame=NSRect(x:0,y:0,width:width,height:height);d.desktopCanvas.frame=d.canvas.frame;d.canvas.clearsBeforeDraw=false;d.desktopCanvas.clearsBeforeDraw=false
  view=SKView(frame:d.canvas.frame);view.allowsTransparency=true;view.presentScene(d.decorationScene)
  let groundKey="ground-"+d.id;w.surfaces.surfaces[groundKey]=SnowSurface(id:groundKey,screenID:d.id,frame:Rect(0,height-2,width,1),maxHeight:42);w.surfaces.surfaces[groundKey]?.add(volume:23000)
  if id.needsTree {w.config.tree=true;w.config.placements[d.id]=Placement(tree:Vec(0.5,0.9))}
  if id.needsSnowman {s.snowballs.balls=StorySnowmanRecipe.radii.map{Snowball(position:Vec(500,600),radius:$0)};_=s.snowballs.assemblePrepared(at:Vec(500,600));s.snowmanFloating=true}
  if id == .garlandRemoval {w.config.garland=true;w.config.placements[d.id]=Placement(garland:[Vec(0.15,0.22),Vec(0.85,0.22)])}
  for _ in 0..<180 {step()}
  if id == .garlandRemoval {w.decorations.stories.removalTarget=w.garlandRemoval.targets().first}
  if id.needsSnowman {w.saveSnowman(d.id)}
  if id == .presentTheft || id == .santaDrop {w.decorations.addTreePresents(display:d,surfaces:w.surfaces,now:now-2)}
  if id == .treeShake {for key in w.decorations.stories.branchKeys(d.id,surfaces:w.surfaces){w.surfaces.surfaces[key]?.add(volume:100)}}
 }
 @discardableResult func start(_ id:ChristmasStoryID,_ variant:Int=0)->String? {w.decorations.stories.start(id,manager:w.decorations,displays:[d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces,variant:variant)}
 func step(_ windows:[TrackedWindow]=[]) {
  now+=1.0/60;w.director.tick(1.0/60);w.flushSnowEvents();d.engine.step(dt:1.0/60,config:w.config)
  d.render(config:w.config,windows:windows,surfaces:w.surfaces,active:nil)
  w.decorations.update(dt:1.0/60,now:now,displays:[d],config:w.config,windows:windows,dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec());d.presentDesktopObjects()
 }
 func bitmap(scale:Int=1,zoomed:Bool=false)->NSBitmapImageRep {
  let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(width)*scale,pixelsHigh:Int(height)*scale,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bitmapFormat:[],bytesPerRow:Int(width)*scale*4,bitsPerPixel:32)!
  NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
  let c=NSGraphicsContext.current!.cgContext;c.scaleBy(x:CGFloat(scale),y:CGFloat(scale));c.setFillColor(CGColor(red:0.07,green:0.15,blue:0.22,alpha:1));c.fill(d.canvas.bounds)
  if zoomed,let area=w.decorations.stories.active?.stage.area {let zoom=min((width-70)/area.width,(height-120)/area.height);c.translateBy(x:35-area.x*zoom,y:0);c.scaleBy(x:zoom,y:zoom)}
  let nativeCanvas=SnowCanvas(frame:d.canvas.frame);nativeCanvas.clearsBeforeDraw=false
  w.decorations.appendSprites(from:s.root,reference:s.root,to:nativeCanvas);nativeCanvas.draw(nativeCanvas.bounds)
  d.desktopCanvas.draw(d.desktopCanvas.bounds);d.canvas.draw(d.canvas.bounds)
  NSGraphicsContext.restoreGraphicsState();return bitmap
 }
 func picture(_ file:URL) throws {try bitmap(scale:2).representation(using:.png,properties:[:])!.write(to:file)}
 func close(){w.stop();view.presentScene(nil)}
}
