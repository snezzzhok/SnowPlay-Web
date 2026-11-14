import AppKit
import SnowCore
@testable import SnowPlay
@main struct GlowRendererCheck {
 static func main() throws {
  _=NSApplication.shared;var errors:[Double]=[],maximum=0
  for scale in [1,2] {for color in [NSColor.systemPink,.systemGreen,.systemYellow,.systemPurple,.systemCyan] {
   func render(_ optimized:Bool)->CGImage {
    let n=128*scale,c=CGContext(data:nil,width:n,height:n,bitsPerComponent:8,bytesPerRow:n*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.scaleBy(x:CGFloat(scale),y:CGFloat(scale));c.setFillColor(CGColor(red:0.08,green:0.17,blue:0.21,alpha:1));c.fill(CGRect(x:0,y:0,width:128,height:128))
    if optimized {
     NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false)
     let canvas=SnowCanvas(frame:NSRect(x:0,y:0,width:128,height:128));canvas.clearsBeforeDraw=false;canvas.garlandGlows=[GarlandGlow(point:CGPoint(x:64,y:64),radius:30,color:color,alpha:0.24)];canvas.draw(canvas.bounds);NSGraphicsContext.restoreGraphicsState()
    }else {
     c.setBlendMode(.plusLighter)
     let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[color.withAlphaComponent(0.24).cgColor,color.withAlphaComponent(0).cgColor] as CFArray,locations:[0,1])!
     c.drawRadialGradient(gradient,startCenter:CGPoint(x:64,y:64),startRadius:0,endCenter:CGPoint(x:64,y:64),endRadius:30,options:[])
    };return c.makeImage()!
   }
   func pixels(_ image:CGImage)->[UInt8]{let data=image.dataProvider!.data!;return Array(UnsafeBufferPointer(start:CFDataGetBytePtr(data),count:CFDataGetLength(data)))}
   let reference=render(false),optimized=render(true),a=pixels(reference),b=pixels(optimized)
   let differences=zip(a,b).map{abs(Int($0)-Int($1))};maximum=max(maximum,differences.max() ?? 0);errors.append(Double(differences.reduce(0,+))/Double(differences.count))
   if scale==2 && errors.count==6 {
    for (name,image) in [("reference",reference),("cached",optimized)] {let rep=NSBitmapImageRep(cgImage:image);try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Docs/optimization-glow-\(name).png"))}
   }
  }}
  let mean=errors.reduce(0,+)/Double(errors.count);precondition(mean<0.5 && maximum<=8,"Glow changed visibly: mean \(mean), max \(maximum)")
  try JSONSerialization.data(withJSONObject:["passed":true,"retina1xAnd2x":true,"colors":5,"meanChannelErrorOf255":mean,"maximumChannelErrorOf255":maximum],options:.prettyPrinted).write(to:URL(fileURLWithPath:"Docs/optimization-glow-result.json"));print("PASS: cached glow matches 1x/2x radial reference; mean \(mean)/255, max \(maximum)/255")
 }
}
