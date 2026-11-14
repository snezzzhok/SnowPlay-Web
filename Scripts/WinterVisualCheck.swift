import AppKit
import SnowCore
@main struct WinterVisualCheck {
    static func main() throws {
        _=NSApplication.shared
        let width=900,height=330
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap);defer {NSGraphicsContext.restoreGraphicsState()}
        let canvas=SnowCanvas(frame:NSRect(x:0,y:0,width:width,height:height)),context=NSGraphicsContext.current!.cgContext
        let tiles=[45.0,140,235,330].map { Rect($0,220,80,96) }
        let dock=DockGeometry(frame:Rect(35,220,390,96),axis:.horizontal,screenID:"fixture",slots:tiles)
        var snow=SnowSurface(id:"dock",screenID:"fixture",frame:dock.snowFrame,maxHeight:10)
        snow.setMounds(tiles.map { ($0.center.x-snow.frame.x)/snow.frame.width })
        for _ in 0..<20 {snow.add(volume:1000)}
        canvas.caps=SnowCapGeometry.paths(surface:snow,blocked:[],local: {CGPoint(x:$0.x,y:Double(height)-$0.y)})
        for (i,tile) in tiles.enumerated() {
            let icon=NSWorkspace.shared.icon(forFile:"/System/Applications/Calculator.app")
            let box=HatPlacement.iconRect(in:tile)
            canvas.artwork.append((icon.cgImage(forProposedRect:nil,context:nil,hints:nil)!,CGRect(x:box.x,y:Double(height)-box.maxY,width:box.width,height:box.height),1,false))
            if i==3 {continue}
            let id=["hat_red","hat_green","hat_blue"][i],anchor=AssetManager.shared.registry[id]!.anchor
            let hat=HatPlacement.frame(tile:tile,anchor:anchor)
            let attach=hat.y+hat.height*anchor.y
            precondition(attach>box.y+box.height*0.15 && attach<box.center.y,"Hat brim is detached from app icon")
            canvas.hats.append((AssetManager.shared.image(id)!,CGRect(x:hat.x,y:Double(height)-hat.maxY,width:hat.width,height:hat.height),1,false))
        }
        var window=SnowSurface(id:"window-fixture",screenID:"fixture",frame:Rect(490,150,330,160),maxHeight:8)
        for _ in 0..<20 {window.add(volume:1000)}
        canvas.caps+=SnowCapGeometry.paths(surface:window,blocked:[],local: {CGPoint(x:$0.x,y:Double(height)-$0.y)})
        canvas.draw(canvas.bounds)
        context.setBlendMode(.destinationOver);context.setFillColor(CGColor(red:0.34,green:0.42,blue:0.47,alpha:1));context.addPath(CGPath(roundedRect:CGRect(x:490,y:20,width:330,height:168),cornerWidth:12,cornerHeight:12,transform:nil));context.fillPath()
        context.setFillColor(CGColor(red:0.28,green:0.36,blue:0.40,alpha:1));context.addPath(CGPath(roundedRect:CGRect(x:35,y:10,width:390,height:100),cornerWidth:16,cornerHeight:16,transform:nil));context.fillPath()
        context.setFillColor(CGColor(red:0.16,green:0.23,blue:0.29,alpha:1));context.fill(CGRect(x:0,y:0,width:width,height:height));context.setBlendMode(.normal)
        for (text,point) in [("Dock: округлые сугробы и прилегающие шапочки",NSPoint(x:45,y:290)),("Окно: мягкий профиль снега",NSPoint(x:490,y:290))] {
            (text as NSString).draw(at:point,withAttributes:[.font:NSFont.systemFont(ofSize:14),.foregroundColor:NSColor.white])
        }
        let covered=SnowCapGeometry.paths(surface:window,blocked:[Rect(480,130,360,60)],local: {CGPoint(x:$0.x,y:$0.y)})
        precondition(covered.isEmpty,"Snow overlaps a foreground window")
        precondition(snow.heights.max()!-snow.heights.min()!>5 && snow.heights.first==0)
        try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Docs/snow-and-hats-preview.png"))
        print("PASS: actual canvas curved mound paths, foreground-window clipping, three hat anchor overlaps and supplied art raster render")
    }
}
