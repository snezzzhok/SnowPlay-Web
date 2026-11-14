// Draws only our own transparent SnowCanvas into a bitmap. No screen capture.
import AppKit
@main struct RendererCheck {
    static func main() throws {
        _=NSApplication.shared
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:64,pixelsHigh:64,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        let context=NSGraphicsContext(bitmapImageRep:bitmap)!
        NSGraphicsContext.saveGraphicsState(); defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current=context
        let canvas=SnowCanvas(frame:NSRect(x:0,y:0,width:64,height:64))
        canvas.dots=[SnowDot(center:CGPoint(x:12,y:12),size:3,alpha:1)]
        canvas.draw(canvas.bounds)
        func opaquePixels() -> Set<Int> {
            var set=Set<Int>()
            for y in 0..<64 { for x in 0..<64 { if (bitmap.colorAt(x:x,y:y)?.alphaComponent ?? 0)>0.2 { set.insert(y*64+x) } } }
            return set
        }
        let first=opaquePixels(); precondition(!first.isEmpty && first.count<25,"small dot was not rendered correctly")
        canvas.dots=[SnowDot(center:CGPoint(x:44,y:44),size:3,alpha:1)]
        canvas.draw(NSRect(x:8,y:8,width:8,height:8)); canvas.draw(NSRect(x:40,y:40,width:8,height:8))
        let second=opaquePixels(); precondition(first.isDisjoint(with:second),"old particles left a trail")
        precondition(second.count<25,"unexpected background fill")
        let path=CGMutablePath(); path.addRect(CGRect(x:5,y:20,width:30,height:4)); canvas.caps=[path]
        canvas.draw(NSRect(x:3,y:18,width:34,height:8)); precondition(opaquePixels().count>80,"cap was not drawn")
        canvas.caps=[]; canvas.draw(NSRect(x:3,y:18,width:34,height:8)); precondition(opaquePixels().count<25,"removed cap left a trail")
        let output=URL(fileURLWithPath:".build/renderer-check.png")
        try bitmap.representation(using:.png,properties:[:])!.write(to:output)
        print("PASS: native transparent canvas, small dot, partial repaint without trails, cap drawing/removal")
    }
}
