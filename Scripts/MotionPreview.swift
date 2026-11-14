// An owned scene rendered by the application code; never captures the user's screen.
import AppKit
import SpriteKit
import ImageIO
import SnowCore
@main struct MotionPreview {
    static func main() throws {
        _=NSApplication.shared
        guard let screen=NSScreen.main else {fatalError("No display")}
        let width=960,height=540,dt=1.0/12
        let surfaces=SurfaceManager(),manager=DecorationManager(),director=AnimationDirector()
        let d=DisplayOverlay(screen:screen,surfaces:surfaces,primaryHeight:screen.frame.height)
        d.hide(true);defer {d.close()}
        d.rect=Rect(0,0,Double(width),Double(height));d.engine.bounds=d.rect
        d.canvas.frame=NSRect(x:0,y:0,width:width,height:height);d.decorationScene.size=d.canvas.frame.size
        let view=SKView(frame:d.canvas.frame);view.allowsTransparency=true;view.presentScene(d.decorationScene)
        var c=Configuration.preset(.play);c.intensity=1;c.windAngle = -15;c.windStrength=0.4;c.frost=false;c.tree=true
        c.placements[d.id]=Placement(tree:Vec(0.84,0.76))
        let window=TrackedWindow(number:991,pid:1,frame:Rect(50,190,350,230),z:0,now:0)
        let dock=DockGeometry(frame:Rect(210,475,540,50),axis:.horizontal,screenID:d.id)
        surfaces.surfaces["dock"]=SnowSurface(id:"dock",screenID:d.id,frame:dock.snowFrame,maxHeight:8)
        surfaces.surfaces[window.id]=SnowSurface(id:window.id,screenID:d.id,frame:window.frame,maxHeight:8)
        d.engine.setCount(SnowfallDensity.count(intensity:1,area:d.rect.width*d.rect.height,mode:.play,limit:c.maxParticles))
        manager.install([d]);manager.pendingDelivery=true
        let url=URL(fileURLWithPath:"Docs/snow-motion-preview.gif")
        let frames=132
        guard let gif=CGImageDestinationCreateWithURL(url as CFURL,"com.compuserve.gif" as CFString,frames,nil) else {fatalError("GIF")}
        CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        for frame in 0..<frames {
            try autoreleasepool {
                let now=Double(frame)*dt
                for _ in 0..<2 {d.engine.step(dt:dt/2,config:c,occluders:[window.frame])}
                d.render(config:c,windows:[window],surfaces:surfaces,active:nil)
                manager.update(dt:dt,now:now,displays:[d],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
                if now>8.6 {manager.openGift(displayID:d.id,now:now,fireworks:true,director:director)}
                let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
                NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)
                d.canvas.draw(d.canvas.bounds)
                let context=NSGraphicsContext.current!.cgContext
                context.setBlendMode(.destinationOver)
                context.setFillColor(CGColor(red:0.20,green:0.29,blue:0.35,alpha:1))
                context.addPath(CGPath(roundedRect:CGRect(x:50,y:120,width:350,height:230),cornerWidth:12,cornerHeight:12,transform:nil));context.fillPath()
                if let texture=view.texture(from:d.decorationScene) {context.draw(texture.cgImage(),in:d.canvas.bounds)}
                let colors=[CGColor(red:0.08,green:0.15,blue:0.23,alpha:1),CGColor(red:0.19,green:0.32,blue:0.39,alpha:1)]
                if let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,1]) {context.drawLinearGradient(gradient,start:CGPoint(x:0,y:height),end:.zero,options:[])}
                context.setBlendMode(.normal)
                ("SnowPlay · 100%" as NSString).draw(at:NSPoint(x:50,y:475),withAttributes:[.font:NSFont.systemFont(ofSize:24,weight:.medium),.foregroundColor:NSColor.white])
                ("Native animation preview · 960 × 540" as NSString).draw(at:NSPoint(x:50,y:450),withAttributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.white.withAlphaComponent(0.65)])
                NSGraphicsContext.restoreGraphicsState()
                if frame==72 {try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Docs/snow-motion-preview.png"))}
                CGImageDestinationAddImage(gif,bitmap.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:dt]] as CFDictionary)
            }
        }
        precondition(CGImageDestinationFinalize(gif))
        print("Rendered \(frames) owned frames using ParticleEngine, SnowCanvas and DecorationManager")
    }
}
