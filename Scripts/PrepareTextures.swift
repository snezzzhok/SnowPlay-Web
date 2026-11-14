import AppKit
struct Index: Decodable { var assets: [Entry] }
struct Entry: Decodable { var id: String; var source: String; var width: Double; var height: Double }
let root=URL(fileURLWithPath:CommandLine.arguments[1])
let index=try JSONDecoder().decode(Index.self,from:Data(contentsOf:root.appendingPathComponent("Prepared/index.json")))
for e in index.assets {
    guard let image=NSImage(contentsOf:root.appendingPathComponent(e.source)) else { fatalError("Invalid SVG: \(e.source)") }
    for scale in [1,2] {
        let w=Int(ceil(e.width*Double(scale))), h=Int(ceil(e.height*Double(scale)))
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        bitmap.size=NSSize(width:e.width,height:e.height)
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
        image.draw(in:NSRect(x:0,y:0,width:e.width,height:e.height),from:.zero,operation:.copy,fraction:1)
        NSGraphicsContext.restoreGraphicsState()
        guard let data=bitmap.representation(using:.png,properties:[:]) else { fatalError("PNG export failed") }
        try data.write(to:root.appendingPathComponent("Prepared/\(e.id)\(scale == 2 ? "@2x" : "").png"),options:.atomic)
    }
}
