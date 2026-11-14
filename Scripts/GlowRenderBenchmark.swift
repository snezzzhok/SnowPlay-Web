// Controlled same-process comparison of the local radial-light draw, Retina 2x.
import AppKit
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:2880,pixelsHigh:1800,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
let context=NSGraphicsContext.current!.cgContext;context.scaleBy(x:2,y:2)
let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[CGColor(red:1,green:0.4,blue:0.3,alpha:0.22),CGColor(red:1,green:0.4,blue:0.3,alpha:0)] as CFArray,locations:[0,1])!
let gc=CGContext(data:nil,width:128,height:128,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
gc.drawRadialGradient(gradient,startCenter:CGPoint(x:64,y:64),startRadius:0,endCenter:CGPoint(x:64,y:64),endRadius:64,options:[]);let cached=gc.makeImage()!
func draw(_ mode:Int)->Double {
 let began=ProcessInfo.processInfo.systemUptime
 context.clear(CGRect(x:0,y:0,width:1440,height:900))
 for i in 0..<50 {
  let point=CGPoint(x:100+Double(i)*24,y:800-Double(i%5)*5),r=20.0
  context.saveGState();context.setBlendMode(.plusLighter)
  if mode==1{context.clip(to:CGRect(x:point.x-r,y:point.y-r,width:r*2,height:r*2))}
  if mode==2{context.draw(cached,in:CGRect(x:point.x-r,y:point.y-r,width:r*2,height:r*2))}else{context.drawRadialGradient(gradient,startCenter:point,startRadius:0,endCenter:point,endRadius:r,options:[])}
  context.restoreGState()
 }
 return (ProcessInfo.processInfo.systemUptime-began)*1000
}
var report:[String:Any]=["scope":"50 radial lights at 2880x1800 Retina; controlled CPU draw comparison, not GPU presentation"]
for mode in 0..<3 {var a:[Double]=[];for i in 0..<35 {let value=draw(mode);if i>4{a.append(value)}};a.sort();report[["radialGradient","clippedGradient","cachedHalo"][mode]]=["medianMS":a[a.count/2],"p95MS":a[Int(Double(a.count-1)*0.95)]]}
try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/living-glow-optimization.json"))
print(report)
