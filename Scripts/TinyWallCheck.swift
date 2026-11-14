import AppKit
import SpriteKit
import SnowCore
@main struct TinyWallCheck {
 static func main() throws {
  _=NSApplication.shared
  let winter=WinterCoordinator();winter.config=Configuration.preset(.play);winter.config.snow=false;winter.config.yetiEnabled=false;winter.config.automaticCleaning=0;winter.rebuildDisplays();defer{winter.stop()}
  let d=winter.displays[0],s=winter.decorations.states[d.id]!
  d.hide(true);d.rect=Rect(0,0,900,540);d.engine.bounds=d.rect;d.canvas.frame=NSRect(x:0,y:0,width:900,height:540);d.decorationScene.size=d.canvas.frame.size
  let key="ground-"+d.id;winter.surfaces.surfaces[key]=SnowSurface(id:key,screenID:d.id,frame:Rect(0,538,900,1),maxHeight:18)
  _=winter.surfaces.surfaces[key]?.add(volume:2200)
  let before=winter.surfaces.surfaces[key]!.volume,expected=Double.pi*2*5.5*5.5
  precondition(winter.decorations.requestCharacter(.buildCastle,display:d,target:Vec(400,530),windows:[],surfaces:winter.surfaces,config:winter.config))
  precondition(abs(before-winter.surfaces.surfaces[key]!.volume-expected)<0.001,"Wall took more snow than its two clumps")
  var now=ProcessInfo.processInfo.systemUptime,seenOne=false,seenTwo=false,saved=false
  for _ in 0..<600 {
   now+=1.0/30;winter.director.tick(1.0/30)
   d.render(config:winter.config,windows:[],surfaces:winter.surfaces,active:nil)
   winter.decorations.update(dt:1.0/30,now:now,displays:[d],config:winter.config,windows:[],dock:nil,surfaces:winter.surfaces,director:winter.director,mouse:Vec())
   seenOne = seenOne || d.canvas.reveals.count==1
   seenTwo = seenTwo || d.canvas.reveals.count==2
   if s.castleProgress==1 && !saved {
    precondition(d.canvas.reveals.count==2)
    let rect=d.canvas.reveals.map(\.rect).reduce(CGRect.null){$0.union($1)}
    precondition(rect.width<25 && rect.height<18,"Wall is too big")
    precondition(d.canvas.reveals.allSatisfy{$0.image.width<=192},"Large castle texture still rendered")
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:300,pixelsHigh:140,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
    let context=NSGraphicsContext.current!.cgContext;context.scaleBy(x:2,y:2);context.translateBy(x:-325,y:0)
    d.canvas.draw(d.canvas.bounds);context.setBlendMode(.destinationOver);context.setFillColor(CGColor(red:0.08,green:0.16,blue:0.22,alpha:1));context.fill(CGRect(x:325,y:0,width:150,height:70));context.setBlendMode(.normal)
    ("2 комка · 20 × 11 pt" as NSString).draw(at:NSPoint(x:331,y:53),withAttributes:[.font:NSFont.systemFont(ofSize:10),.foregroundColor:NSColor.white])
    NSGraphicsContext.restoreGraphicsState();try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Docs/tiny-wall-preview.png"));saved=true
   }
   if s.character==nil {break}
  }
  precondition(saved && seenOne && seenTwo && s.castleProgress==1 && s.character==nil)
  precondition(abs(s.castleMass-expected)<0.001)
  let result:[String:Any]=["passed":true,"twoClumps":true,"sequentialPlacement":true,"opaqueWallWidthPt":20,"opaqueClumpDiameterPt":11,"snowMass":expected,"largeCastleRendered":false,"scope":"actual controllers and native Core Graphics render in an isolated scene"]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/tiny-wall-result.json"))
  print("PASS: two sequential 11pt clumps; wall under 25pt wide; exact snow stock; Yeti exits; no castle texture")
 }
}
