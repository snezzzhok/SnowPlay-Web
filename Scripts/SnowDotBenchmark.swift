// Compares identical free-snow rendering approaches in one Retina bitmap context.
import AppKit
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:2880,pixelsHigh:1800,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
let c=NSGraphicsContext.current!.cgContext;c.scaleBy(x:2,y:2)
let glyphContext=CGContext(data:nil,width:24,height:24,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
glyphContext.setFillColor(CGColor(gray:1,alpha:1));glyphContext.fillEllipse(in:CGRect(x:1,y:1,width:22,height:22));let glyph=glyphContext.makeImage()!
var seed:UInt64=41
func unit()->Double{seed=seed &* 6364136223846793005 &+ 1;return Double(seed>>11)/9007199254740992}
let dots=(0..<2400).map{_ in (CGRect(x:unit()*1440,y:unit()*900,width:3+unit()*4.5,height:3+unit()*4.5),0.3+unit()*0.6)}
let colors=(0...255).map{CGColor(gray:1,alpha:Double($0)/255)}
func draw(_ mode:Int)->Double{
 let began=ProcessInfo.processInfo.systemUptime;c.clear(CGRect(x:0,y:0,width:1440,height:900))
 for (rect,alpha) in dots {
  if mode==2 {c.setAlpha(alpha);c.draw(glyph,in:rect)}
  else{c.setFillColor(mode==0 ? CGColor(gray:1,alpha:alpha):colors[Int(alpha*255)]);c.fillEllipse(in:rect)}
 };c.setAlpha(1)
 return (ProcessInfo.processInfo.systemUptime-began)*1000
}
var result:[String:Any]=[:]
for mode in 0..<3 {var a:[Double]=[];for i in 0..<45{let value=draw(mode);if i>=5{a.append(value)}};a.sort();result[["vector","cachedColorVector","cachedGlyph"][mode]]=["medianMS":a[a.count/2],"p95MS":a[Int(Double(a.count-1)*0.95)]]}
result["scope"]="2400 white snow dots at 2.5x-like sizes in 2880x1800 Retina bitmap; raster-work microbenchmark, not presented GPU FPS"
try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/living-dot-optimization.json"));print(result)
