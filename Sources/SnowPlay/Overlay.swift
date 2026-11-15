import AppKit
import SpriteKit
import SnowCore

final class OverlayWindow: NSWindow {
    init(screen: NSScreen, desktop: Bool) {
        super.init(contentRect:screen.frame,styleMask:.borderless,backing:.buffered,defer:false)
        isOpaque=false; backgroundColor = .clear; hasShadow=false; ignoresMouseEvents=true
        level = desktop ? NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.desktopIconWindow))+1) : NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.dockWindow))+1)
        collectionBehavior=[.canJoinAllSpaces,.stationary,.ignoresCycle]
        isReleasedWhenClosed=false; animationBehavior = .none
        contentView=NSView(frame:NSRect(origin:.zero,size:screen.frame.size))
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
struct GarlandBulb { var id: String; var rect: CGRect; var index: Int }
struct SnowDot {
    var center: CGPoint
    var size: Double
    var alpha: Double
    var rotation:Double=0
    var clump:Bool=false
}
struct CanvasReveal {var image:CGImage;var rect:CGRect;var progress:Double}
struct GarlandGlow {var point:CGPoint;var radius:Double;var color:NSColor;var alpha:Double}
/// Small reusable bitmap for the same radial light; alpha/size remain per bulb.
/// Drawing a bounded image avoids asking CoreGraphics to rasterize a shading on
/// the full desktop surface for every lamp, every frame.
private enum BulbGlowCache {
    static var images:[UInt32:CGImage]=[:]
    static func image(_ color:NSColor)->CGImage? {
        guard let c=color.usingColorSpace(.deviceRGB) else{return nil}
        let r=UInt32(clamp(Double(c.redComponent),0,1)*255),g=UInt32(clamp(Double(c.greenComponent),0,1)*255),b=UInt32(clamp(Double(c.blueComponent),0,1)*255),key=r<<16|g<<8|b
        if let old=images[key]{return old}
        let side=128
        guard let bitmap=CGContext(data:nil,width:side,height:side,bitsPerComponent:8,bytesPerRow:side*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue),let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[c.withAlphaComponent(1).cgColor,c.withAlphaComponent(0).cgColor] as CFArray,locations:[0,1]) else{return nil}
        bitmap.drawRadialGradient(gradient,startCenter:CGPoint(x:64,y:64),startRadius:0,endCenter:CGPoint(x:64,y:64),endRadius:64,options:[])
        guard let image=bitmap.makeImage() else{return nil}
        if images.count>=16 {images.removeAll()};images[key]=image;return image
    }
}
final class SnowCanvas: NSView {
    let probe=RenderProbe()
    var groundLayer=false
    var clearsBeforeDraw=true
    private static let snowGradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[CGColor(red:0.72,green:0.83,blue:0.91,alpha:0.97),CGColor(red:0.99,green:1,blue:1,alpha:0.98)] as CFArray,locations:[0,1])
    var storyEffects:[StickerDrawing]=[]
    var stickers:[StickerDrawing]=[]
    var composites: [CanvasSprite]=[]
    var workbenchLabel="Roll three snowballs along the bottom"
    var workbench: Rect?
    var dots: [SnowDot] = []
    var reveals:[CanvasReveal]=[]
    var garlandGlows:[GarlandGlow]=[]
    var caps: [CGPath] = []
    var dynamicCaps:[CGPath]=[]
    var frost: [(CGPath, Double)] = [] // Retained for renderer compatibility; new frost uses supplied art.
    var artwork: [(CGImage, CGRect, Double, Bool)] = []
    var garlandPaths: [CGPath]=[]
    var snowballArt: [(CGImage,CGRect,Double,Bool)]=[]
    var garlandArt: [(CGImage,CGRect,Double,Bool)]=[]
    var hats: [(CGImage, CGRect, Double, Bool)] = []
    private var hadContent=false
    private var staticSignature:Int?
    // Retain the previous immutable drawing objects until comparison. Otherwise a
    // newly allocated path/image could reuse the old address and hide a real change.
    private var staticPaths:[CGPath]=[],staticImages:[CGImage]=[]
    func invalidateFrame() {
        let dynamic = !storyEffects.isEmpty || workbench != nil || !composites.isEmpty || !dots.isEmpty || !reveals.isEmpty || !garlandGlows.isEmpty || !snowballArt.isEmpty
        if dynamic {staticSignature=nil;staticPaths=[];staticImages=[];hadContent=true;needsDisplay=true;return}
        var hash=Hasher();hash.combine(groundLayer);hash.combine(caps.count);hash.combine(dynamicCaps.count);hash.combine(garlandPaths.count)
        for item in stickers {hash.combine(item.id);hash.combine(item.alpha);hash.combine(item.transform.a);hash.combine(item.transform.b);hash.combine(item.transform.c);hash.combine(item.transform.d);hash.combine(item.transform.tx);hash.combine(item.transform.ty);hash.combine(ObjectIdentifier(item.image));for r in item.clips {hash.combine(r.minX);hash.combine(r.minY);hash.combine(r.width);hash.combine(r.height)}}
        for path in caps+dynamicCaps+garlandPaths {hash.combine(ObjectIdentifier(path))}
        for (path,alpha) in frost {hash.combine(ObjectIdentifier(path));hash.combine(alpha)}
        for (image,rect,alpha,mirror) in artwork+hats+garlandArt {
            hash.combine(ObjectIdentifier(image));hash.combine(rect.origin.x);hash.combine(rect.origin.y);hash.combine(rect.width);hash.combine(rect.height);hash.combine(alpha);hash.combine(mirror)
        }
        let key=hash.finalize(),content = !stickers.isEmpty || !caps.isEmpty || !dynamicCaps.isEmpty || !frost.isEmpty || !artwork.isEmpty || !hats.isEmpty || !garlandPaths.isEmpty || !garlandArt.isEmpty
        if staticSignature != key || content != hadContent {if content || hadContent {needsDisplay=true}}
        staticSignature=key;hadContent=content;staticPaths=caps+dynamicCaps+garlandPaths+frost.map{$0.0};staticImages=(artwork+hats+garlandArt).map{$0.0}
    }
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        let began=ProcessInfo.processInfo.systemUptime
        defer {probe.record(now:began,workMS:(ProcessInfo.processInfo.systemUptime-began)*1000)}
        guard let context=NSGraphicsContext.current?.cgContext else { return }
        if clearsBeforeDraw {context.clear(dirtyRect)}
        if let bench=workbench {
            let box=CGRect(x:bench.x,y:bench.y,width:bench.width,height:bench.height)
            context.setFillColor(CGColor(red:0.90,green:0.95,blue:0.97,alpha:0.96));context.addPath(CGPath(roundedRect:box,cornerWidth:16,cornerHeight:16,transform:nil));context.fillPath()
            let text=workbenchLabel
            (text as NSString).draw(at:NSPoint(x:box.minX+15,y:box.maxY-26),withAttributes:[.font:NSFont.systemFont(ofSize:11,weight:.medium),.foregroundColor:NSColor(calibratedRed:0.28,green:0.43,blue:0.48,alpha:1)])
        }
        for dot in dots {
            if dot.clump,let image=AssetManager.shared.image(dot.rotation>0 ? "snow_clump_0":"snow_clump_1") {
                context.saveGState();context.translateBy(x:dot.center.x,y:dot.center.y);context.rotate(by:dot.rotation);context.setAlpha(dot.alpha)
                context.draw(image,in:CGRect(x:-dot.size*0.65,y:-dot.size*0.5,width:dot.size*1.3,height:dot.size));context.restoreGState();continue
            }
            context.setFillColor(CGColor(gray:1,alpha:dot.alpha))
            let stretch=dot.size>4 ? 0.8:1.0
            context.fillEllipse(in:CGRect(x:dot.center.x-dot.size*stretch/2,y:dot.center.y-dot.size/2,width:dot.size*stretch,height:dot.size))
        }
        context.setFillColor(CGColor(red:0.94,green:0.98,blue:1,alpha:0.88))
        for path in caps+dynamicCaps {
            if groundLayer,let gradient=Self.snowGradient {
                let box=path.boundingBoxOfPath;context.saveGState();context.addPath(path);context.clip();context.drawLinearGradient(gradient,start:CGPoint(x:box.midX,y:box.minY),end:CGPoint(x:box.midX,y:box.maxY),options:[]);context.restoreGState()
            }else{context.addPath(path);context.fillPath()}
        }
        context.setStrokeColor(CGColor(red:0.28,green:0.4,blue:0.34,alpha:0.65)); context.setLineWidth(1.8)
        for path in garlandPaths { context.addPath(path);context.strokePath() }
        for glow in garlandGlows {
            guard glow.radius>0,glow.alpha>0,let image=BulbGlowCache.image(glow.color) else{continue}
            context.saveGState();context.setBlendMode(.plusLighter);context.setAlpha(glow.alpha)
            context.draw(image,in:CGRect(x:glow.point.x-glow.radius,y:glow.point.y-glow.radius,width:glow.radius*2,height:glow.radius*2));context.restoreGState()
        }
        for item in reveals {context.saveGState();context.clip(to:CGRect(x:item.rect.minX,y:item.rect.minY,width:item.rect.width,height:item.rect.height*item.progress));context.draw(item.image,in:item.rect);context.restoreGState()}
        for (image,rect,alpha,mirror) in artwork+hats+garlandArt+snowballArt {
            context.saveGState(); context.setAlpha(alpha)
            if mirror { context.translateBy(x:rect.midX,y:0); context.scaleBy(x:-1,y:1); context.translateBy(x:-rect.midX,y:0) }
            context.draw(image,in:rect); context.restoreGState()
        }
        for item in stickers+storyEffects {item.draw(context)}
        for sprite in composites {
            context.saveGState();context.concatenate(sprite.transform);context.setAlpha(sprite.alpha);context.draw(sprite.image,in:sprite.rect);context.restoreGState()
        }
        context.setLineWidth(0.7)
        for (path,alpha) in frost {
            context.setStrokeColor(CGColor(red:0.76,green:0.9,blue:1,alpha:alpha)); context.addPath(path); context.strokePath()
        }
    }
}
final class DisplayOverlay {
    let id: String
    let screen: NSScreen
    let foreground: OverlayWindow
    let background: OverlayWindow
    let actionWindow:OverlayWindow
    let actionCanvas=SnowCanvas()
    let desktopSnow:OverlayWindow
    let decorationScene: SKScene
    let canvas=SnowCanvas()
    let desktopCanvas=SnowCanvas()
    let snowCloud=SnowSpriteCloud()
    private var hidden=false
    private(set) var desktopOccluded=false
    private var menuBarInset=24.0
    private var lastSurfaceRender=0.0
    private var backgroundRendering=false
    private var foregroundRendering=true
    private var groundPaths:[String:(instance:UUID,revision:UInt64,frame:Rect,paths:[CGPath])]=[:]
    let engine: ParticleEngine
    var rect: Rect
    init(screen: NSScreen, surfaces: SurfaceManager, primaryHeight: Double) {
        self.screen=screen
        id=String((screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0)
        rect=Rect(screen.frame.minX,primaryHeight-screen.frame.maxY,screen.frame.width,screen.frame.height)
        menuBarInset=max(24,screen.frame.maxY-screen.visibleFrame.maxY)
        engine=ParticleEngine(bounds:rect,surfaces:surfaces,seed:UInt64(id) ?? 42)
        decorationScene=WinterScene(size:screen.frame.size); decorationScene.backgroundColor = .clear; decorationScene.scaleMode = .resizeFill
        decorationScene.addChild(snowCloud.node)
        foreground=OverlayWindow(screen:screen,desktop:false)
        background=OverlayWindow(screen:screen,desktop:true)
        desktopSnow=OverlayWindow(screen:screen,desktop:true)
        actionWindow=OverlayWindow(screen:screen,desktop:false);actionWindow.level = .floating;actionCanvas.frame=NSRect(origin:.zero,size:screen.frame.size);actionWindow.contentView=actionCanvas;actionWindow.orderOut(nil)
        background.level=NSWindow.Level(rawValue:Int(CGWindowLevelForKey(.desktopIconWindow))+2)
        desktopCanvas.frame=NSRect(origin:.zero,size:screen.frame.size);desktopCanvas.groundLayer=true;desktopSnow.contentView=desktopCanvas
        canvas.frame=NSRect(origin:.zero,size:screen.frame.size); foreground.contentView=canvas
        foreground.orderFrontRegardless()
        desktopSnow.orderFrontRegardless()
    }
    func local(_ p: Vec) -> CGPoint { CGPoint(x:p.x-rect.x,y:rect.maxY-p.y) }
    func refreshScreenInsets(){menuBarInset=max(24,screen.frame.maxY-screen.visibleFrame.maxY)}
    func setDesktopOccluded(_ value:Bool){
        guard desktopOccluded != value else{return};desktopOccluded=value
        if value {desktopSnow.orderOut(nil);background.orderOut(nil)}
        else if !hidden {if foregroundRendering{desktopSnow.orderFrontRegardless()};if backgroundRendering{background.orderFrontRegardless()}}
        (background.contentView as? SKView)?.isPaused=value || !backgroundRendering || hidden
    }
    func hide(_ hidden: Bool) { guard hidden != self.hidden else { return }; self.hidden=hidden; if hidden { foreground.orderOut(nil); background.orderOut(nil);desktopSnow.orderOut(nil);actionWindow.orderOut(nil) } else { if foregroundRendering { foreground.orderFrontRegardless();desktopSnow.orderFrontRegardless() }; if backgroundRendering { background.orderFrontRegardless() } } }
    func setRenderActivity(snow: Bool, decoration: Bool) {
        if decoration && !(background.contentView is SKView) {
            let view=SKView(frame:NSRect(origin:.zero,size:screen.frame.size)); view.allowsTransparency=true; view.ignoresSiblingOrder=true
            view.preferredFramesPerSecond=foregroundRendering ? 30 : 60
            view.presentScene(decorationScene); background.contentView=view
        }
        if foregroundRendering != snow { foregroundRendering=snow; if !hidden {if snow {foreground.orderFrontRegardless();desktopSnow.orderFrontRegardless()}else{foreground.orderOut(nil);desktopSnow.orderOut(nil)}} }
        if backgroundRendering != decoration { backgroundRendering=decoration; if !hidden { decoration ? background.orderFrontRegardless() : background.orderOut(nil) } }
        (foreground.contentView as? SKView)?.isPaused = !snow || hidden
        (background.contentView as? SKView)?.isPaused = !decoration || hidden
        if !hidden {
            if desktopOccluded {if desktopSnow.isVisible {desktopSnow.orderOut(nil)};if background.isVisible {background.orderOut(nil)};(background.contentView as? SKView)?.isPaused=true}
            let front = !canvas.storyEffects.isEmpty || !canvas.stickers.isEmpty || !canvas.caps.isEmpty || !canvas.artwork.isEmpty || !canvas.hats.isEmpty || !canvas.garlandArt.isEmpty || !canvas.garlandPaths.isEmpty
            if front && !foreground.isVisible {foreground.orderFrontRegardless()}
            else if !front && foreground.isVisible {foreground.orderOut(nil)}
        }
    }
    func close() { foreground.close(); background.close();desktopSnow.close();actionWindow.close() }
    func render(config: Configuration, windows: [TrackedWindow], surfaces: SurfaceManager, active: Rect?) {
        snowCloud.present(particles:engine.particles,bounds:rect,menuInset:menuBarInset,config:config,activeWindow:active,ground:surfaces.surfaces["ground-"+id],occluded:desktopOccluded)
        canvas.dots.removeAll(keepingCapacity:true);desktopCanvas.dots.removeAll(keepingCapacity:true)
        for p in engine.particles where !desktopOccluded && p.remaining>=0 {
            let inActive=active?.contains(p.position) ?? false
            let menuBar=p.position.y < rect.y+menuBarInset
            guard !menuBar, !(config.mode == .focus && inActive) else { continue }
            desktopCanvas.dots.append(SnowDot(center:local(p.position),size:p.size*(p.remaining<0 ? config.snowSize:1),alpha:p.alpha*(p.remaining >= 0 ? min(1,p.remaining*3) : 1),rotation:p.rotation,clump:p.clump))
        }
        desktopCanvas.caps=[]
        for s in surfaces.surfaces.values where !desktopOccluded && s.id.hasPrefix("ground-") && s.visible && s.renderVisible && s.screenID==id && s.volume>0 {
            if groundPaths[s.id]?.instance != s.instanceID || groundPaths[s.id]?.revision != s.revision || groundPaths[s.id]?.frame != s.frame {groundPaths[s.id]=(s.instanceID,s.revision,s.frame,SnowCapGeometry.paths(surface:s,blocked:[],local:local))}
            desktopCanvas.caps+=groundPaths[s.id]?.paths ?? []
        }
        let now=ProcessInfo.processInfo.systemUptime
        guard now-lastSurfaceRender >= 0.05 || NSEvent.pressedMouseButtons != 0 || windows.contains(where:{$0.state.phase == .moving || $0.state.phase == .resizing}) else { return }; lastSurfaceRender=now
        canvas.caps.removeAll(keepingCapacity:true); canvas.frost.removeAll(keepingCapacity:true); canvas.artwork.removeAll(keepingCapacity:true)
        for s in surfaces.surfaces.values where !s.id.hasPrefix("ground-") && s.visible && s.renderVisible && s.screenID == id && s.volume > 0 {
            let owner=windows.first { $0.id == s.id }
            let higher: [Rect]
            if let w=owner { higher=windows.filter { $0.z < w.z && $0.isVisible }.map(\.frame) }
            else { higher=(s.id == "dock" || s.id.hasPrefix("sculpt-") || s.id.hasPrefix("ground-")) ? []:windows.filter(\.isVisible).map(\.frame) }
            let paths=SnowCapGeometry.paths(surface:s,blocked:higher,progress:owner?.state.restoreProgress ?? 1,local:local)
            if s.id.hasPrefix("ground-"){desktopCanvas.caps+=paths}else{canvas.caps+=paths}
        }
        guard config.frost && config.mode != .focus else { return }
        for w in windows where w.isVisible && w.state.frost > 0 && w.frame.intersects(rect) {
            let higher=windows.filter { $0.z < w.z && $0.isVisible }.map(\.frame)
            for side in [0,1] {
                // Exterior right/left edge below titlebar; never crosses traffic-light controls.
                let x=side == 0 ? w.frame.x-2 : w.frame.maxX+2
                let region=Rect(x-6,w.frame.y+32,12,30)
                guard !higher.contains(where: { $0.intersects(region) }) else { continue }
                if let image=AssetManager.shared.image("frost_corner") {
                    let point=local(Vec(side == 0 ? w.frame.x-16 : w.frame.maxX,w.frame.y+50))
                    canvas.artwork.append((image,CGRect(x:point.x,y:point.y,width:16,height:16),0.16*w.state.frost,side == 1))
                }

            }
        }
    }
    func presentDesktopObjects() {
        actionCanvas.invalidateFrame()
        if !hidden && !actionCanvas.composites.isEmpty {if !actionWindow.isVisible {actionWindow.orderFrontRegardless()}}else if actionWindow.isVisible {actionWindow.orderOut(nil)}
        desktopCanvas.composites=canvas.composites;canvas.composites=[]
        desktopCanvas.dynamicCaps=canvas.dynamicCaps;canvas.dynamicCaps=[]
        desktopCanvas.snowballArt=canvas.snowballArt;canvas.snowballArt=[]
        desktopCanvas.reveals=canvas.reveals;canvas.reveals=[]
        canvas.invalidateFrame();desktopCanvas.invalidateFrame()
    }
}
