// Own AppKit event fixture: point placement, wire rendering, and a manually opened gift.
import AppKit
import SpriteKit
import SnowCore
@testable import SnowPlay
@main struct DecorationControlsCheck {
 static func main() throws {
  _=NSApplication.shared
  let w=WinterCoordinator();w.config=Configuration.preset(.balanced);w.config.placements=[:];w.config.tree=false;w.config.garland=true;w.config.snow=false;w.config.automaticCleaning=0;w.rebuildDisplays();defer{w.stop()}
  let d=w.displays[0],s=w.decorations.states[d.id]!;d.hide(true);d.rect=Rect(0,0,900,540);d.engine.bounds=d.rect;d.decorationScene.size=CGSize(width:900,height:540);d.canvas.frame=NSRect(x:0,y:0,width:900,height:540);d.canvas.clearsBeforeDraw=false;w.interactionWindowSource={[]}
  let key="ground-"+d.id;var ground=SnowSurface(id:key,screenID:d.id,frame:Rect(0,538,900,1),maxHeight:42);ground.add(volume:24000);w.surfaces.surfaces[key]=ground
  let sceneView=SKView(frame:d.canvas.frame);sceneView.allowsTransparency=true;sceneView.presentScene(d.decorationScene)
  func picture(_ name:String) throws {
   let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1800,pixelsHigh:1080,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
   NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
   let c=NSGraphicsContext.current!.cgContext;c.scaleBy(x:2,y:2);c.setFillColor(CGColor(red:0.06,green:0.13,blue:0.2,alpha:1));c.fill(d.canvas.bounds)
   if let texture=sceneView.texture(from:d.decorationScene){c.draw(texture.cgImage(),in:d.canvas.bounds)}
   d.canvas.draw(d.canvas.bounds);NSGraphicsContext.restoreGraphicsState()
   try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:".build/"+name+".png"))
  }
  var now=ProcessInfo.processInfo.systemUptime
  func step(){now+=1.0/60;w.director.tick(1.0/60);d.render(config:w.config,windows:[],surfaces:w.surfaces,active:nil);w.decorations.update(dt:1.0/60,now:now,displays:[d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces,director:w.director,mouse:Vec())}
  func rebuild(){step();w.input.rebuild(displays:[d],windows:[],dock:nil,decorations:w.decorations,focus:false,icons:[])}
  func click(_ panel:InputPanel,_ point:Vec){
   let view=panel.contentView as! InputView,local=panel.convertPoint(fromScreen:NSPoint(x:point.x,y:w.input.primaryHeight-point.y))
   for type in [NSEvent.EventType.leftMouseDown,.leftMouseUp] {let e=NSEvent.mouseEvent(with:type,location:local,modifierFlags:[],timestamp:now,windowNumber:panel.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1)!;if type == .leftMouseDown {view.mouseDown(with:e)}else{view.mouseUp(with:e)}}
  }
  w.beginEditor(.garland,addingAnchor:true);rebuild();precondition(w.input.panels.count==1)
  click(w.input.panels[0],Vec(100,100));rebuild()
  precondition(w.config.placements[d.id]?.garland.count==1 && (w.input.panels[0].contentView as! InputView).addingAnchor)
  precondition((w.input.panels[0].contentView as! InputView).anchorPoints?().count==1)
  click(w.input.panels[0],Vec(800,100));rebuild()
  precondition(w.config.placements[d.id]?.garland.count==2 && !(w.input.panels[0].contentView as! InputView).addingAnchor)
  let anchors=w.config.placements[d.id]!.garland
  w.beginEditor(.garland,addingAnchor:true);rebuild();precondition(w.config.placements[d.id]!.garland==anchors,"Add anchor inserted an invisible point")
  click(w.input.panels[0],Vec(850,170));rebuild();precondition(w.config.placements[d.id]?.garland.count==3)
  precondition(abs(w.config.placements[d.id]!.garland[2].x-850/900.0)<0.001)
  // A click on an existing numbered pin must edit it, never add a duplicate.
  click(w.input.panels[0],Vec(100,100));rebuild();precondition(w.config.placements[d.id]?.garland.count==3)
  w.input.stop();precondition(w.input.panels.isEmpty)
  w.config.placements[d.id]?.garland=anchors;w.config.bulbSize=18;w.config.bulbBrightness=1
  for _ in 0..<120 {step()}
  precondition(d.canvas.garlandArt.count>20 && d.canvas.garlandArt.count<=120,"Wire did not get evenly spaced lamps")
  precondition(d.canvas.garlandGlows.count==d.canvas.garlandArt.count && d.canvas.garlandGlows.allSatisfy{$0.radius==54 && $0.alpha>0.4})
  try picture("garland-render")
  var targets=Set<Int>()
  for cycle in 0..<5 {
   precondition(w.decorations.startParachuteGift(display:d,surfaces:w.surfaces));targets.insert(Int(s.target.x))
   for _ in 0..<420 {step()}
   precondition(s.santa==nil && s.giftLanded && s.giftOpenedAt==nil && !s.countdown,"Gift opened before clicking")
   precondition(s.target.x>=100 && s.target.x<=800,"Celebration clipped at display edge")
   let anchor=AssetManager.shared.registry["gift_box"]?.anchor.y ?? 0.84
   let landing=Double(ArtScale.gift)*(0.17515625+0.53*(anchor-0.5))
   let expectedY=w.decorations.groundY(s.target.x,display:d,surfaces:w.surfaces)-landing
   precondition(abs(s.target.y-expectedY)<0.01)
   w.input.mode = .none;rebuild()
   guard let panel=w.input.panels.first(where:{($0.contentView as? InputView)?.identifier?.rawValue=="gift"}),let point=s.giftPosition else{fatalError("No clickable landed gift")}
   click(panel,point+Vec(0,10));precondition(s.giftOpenedAt != nil && s.countdown,"Single click did not open gift")
   precondition(w.decorations.fireworks.count==3,"Expected exactly three bursts in Balanced")
   let opened=s.giftOpenedAt;click(panel,point+Vec(0,10));precondition(s.giftOpenedAt==opened && w.decorations.fireworks.count==3)
   // Align synthetic time to the actual click event's monotonic time.
   now=s.giftOpenedAt!;for _ in 0..<30 {step()}
   let label=s.celebration.childNode(withName:"countdown") as? SKLabelNode
   if cycle==0 {try picture("gift-open-render")}
   precondition(label?.text?.contains("d") == true && label?.text?.contains("s") == true)
   for _ in 0..<800 {step()};precondition(s.gift==nil && !s.countdown && s.celebration.children.isEmpty,"Celebration leaked")
   if cycle==0 {print("PASS: actual AppKit single-click gift, three fireworks, countdown, repeated clicks, cleanup")}
  }
  precondition(targets.count>1,"All gifts used one position")
  print("PASS: numbered anchors placed at clicks, no implicit insertion, no duplicate pin, even lamps with bounded cached glows, five gift locations")
 }
}
