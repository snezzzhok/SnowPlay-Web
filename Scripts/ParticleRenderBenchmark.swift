import AppKit
import SnowCore
@main struct ParticleRenderBenchmark {
    static func main() throws {
        _=NSApplication.shared
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:2880,pixelsHigh:1800,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap);let c=NSGraphicsContext.current!.cgContext;c.scaleBy(x:2,y:2)
        var rng=SeededRandom(seed:41)
        let dots=(0..<1000).map { _ in (CGRect(x:rng.range(0,1438),y:rng.range(0,898),width:rng.range(1,3),height:rng.range(1,3)),rng.range(0.3,0.85)) }
        func draw(_ batched: Bool) {
            c.clear(CGRect(x:0,y:0,width:1440,height:900))
            if batched {
                let paths=(0...8).map {_ in CGMutablePath()}
                for (rect,alpha) in dots {paths[min(8,max(1,Int((alpha*8).rounded())))].addEllipse(in:rect)}
                for i in 1...8 where !paths[i].isEmpty {c.setFillColor(CGColor(gray:1,alpha:Double(i)/8));c.addPath(paths[i]);c.fillPath()}
            } else {
                for (rect,alpha) in dots {c.setFillColor(CGColor(gray:1,alpha:alpha));c.fillEllipse(in:rect)}
            }
        }
        for _ in 0..<5 {draw(false);draw(true)}
        func measure(_ batched:Bool)->Double {let start=ProcessInfo.processInfo.systemUptime;for _ in 0..<50 {draw(batched)};return (ProcessInfo.processInfo.systemUptime-start)/50*1000}
        let old=measure(false),new=measure(true)
        let result:[String:Any]=["legacyFrameMS":old,"batchedFrameMS":new,"speedup":old/new,"particles":1000,"retina":true]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/particle-render-benchmark.json"))
        print(result)
    }
}
