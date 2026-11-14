import AppKit
import SpriteKit
import SnowCore
import os
import ImageIO

enum Resources {
    static var root: URL {
        if let path=ProcessInfo.processInfo.environment["SNOWPLAY_RESOURCE_ROOT"] { return URL(fileURLWithPath:path) }
        if let resource=Bundle.main.resourceURL {
            for candidate in [resource.appendingPathComponent("Resources"),resource.appendingPathComponent("SnowPlay_SnowPlay.bundle/Resources")] {
                if FileManager.default.fileExists(atPath:candidate.appendingPathComponent("Web/index.html").path) { return candidate }
            }
        }
        #if SWIFT_PACKAGE
        return Bundle.module.bundleURL.appendingPathComponent("Resources")
        #else
        return Bundle.main.resourceURL!.appendingPathComponent("Resources")
        #endif
    }
    static func layer(_ id: String, size: CGFloat = 96) -> SKSpriteNode { AssetManager.shared.sprite(id,height:size) }
    static func object(_ ids: [String], size: CGFloat) -> SKNode { AssetManager.shared.model(ids,height:size) }
}
/// All sizes refer to the shared SVG canvas. Layer registration is independent of pivots.
enum ArtScale {
    static let snowman: CGFloat=56, plow: CGFloat=70, santa: CGFloat=94, tree: CGFloat=84, gift: CGFloat=80
}
final class AssetManager {
    struct Prepared: Decodable {
        var id: String; var source: String; var width: Double; var height: Double; var anchor: Vec
        var derived_from: String?
    }
    struct Index: Decodable { var assets: [Prepared] }
    static let shared=AssetManager()
    let root=Resources.root.appendingPathComponent("SnowPlayAssets")
    private(set) var registry: [String:AssetManifest.Asset]=[:]
    private var prepared: [String:Prepared]=[:]
    private var images: [String:CGImage]=[:]
    struct AtlasRow:Decodable {var id:String;var page:Int;var x:Int;var y:Int;var width:Int;var height:Int}
    struct AtlasIndex:Decodable {var size:Int;var assets:[AtlasRow]}
    private var atlasRows:[String:AtlasRow]=[:],sheetImages:[Int:CGImage]=[:],sheetTextures:[Int:SKTexture]=[:]
    private var atlasSize=1024
    private func sheet(_ page:Int)->CGImage? {
        if let image=sheetImages[page]{return image}
        let url=root.appendingPathComponent("Prepared/Atlas/characters-\(page).png")
        guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCacheImmediately:true] as CFDictionary) else{return nil}
        sheetImages[page]=image;return image
    }
    func image(_ id: String) -> CGImage? {
        if let image=images[id] { return image }
        if let row=atlasRows[id],let atlas=sheet(row.page),let image=atlas.cropping(to:CGRect(x:row.x,y:row.y,width:row.width,height:row.height)) {images[id]=image;return image}
        guard prepared[id] != nil, let image=NSImage(contentsOf:root.appendingPathComponent("Prepared/\(id)@2x.png")), let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil) else { report(id); return nil }
        images[id]=cg; return cg
    }
    private let cache=NSCache<NSString,SKTexture>()
    private var missing=Set<String>()
    private let log=Logger(subsystem:"local.SnowPlay",category:"assets")
    private(set) var loadCount=0
    init() {
        cache.totalCostLimit=12*1024*1024; cache.countLimit=80
        do {
            let manifest=try JSONDecoder().decode(AssetManifest.self,from:Data(contentsOf:root.appendingPathComponent("manifest.json")))
            let extras=(try? JSONDecoder().decode(AssetManifest.self,from:Data(contentsOf:root.appendingPathComponent("World/manifest.json"))))?.assets ?? []
            for asset in manifest.assets+extras {
                let paths=[asset.svg,asset.preview]
                guard registry[asset.id] == nil, asset.id.range(of:"^[a-z0-9_]+$",options:.regularExpression) != nil,
                      paths.allSatisfy({ AssetManifest.safeRelativePath($0) && FileManager.default.fileExists(atPath:root.appendingPathComponent($0).path) }) else { report(asset.id); continue }
                registry[asset.id]=asset
            }
            let index=try JSONDecoder().decode(Index.self,from:Data(contentsOf:root.appendingPathComponent("Prepared/index.json")))
            for e in index.assets where e.width>0 && e.height>0 && e.width.isFinite && e.height.isFinite && AssetManifest.safeRelativePath(e.source) {
                if registry[e.derived_from ?? e.id] != nil { prepared[e.id]=e }
            }
            if let atlas=try? JSONDecoder().decode(AtlasIndex.self,from:Data(contentsOf:root.appendingPathComponent("Prepared/Atlas/index.json"))) {
                atlasSize=atlas.size
                for row in atlas.assets where prepared[row.id] != nil {atlasRows[row.id]=row}
            }
        } catch { log.error("Asset registry unavailable: \(String(describing:error),privacy:.public)") }
    }
    func texture(_ id: String) -> SKTexture? {
        if let texture=cache.object(forKey:id as NSString) { return texture }
        if let row=atlasRows[id],let cg=sheet(row.page) {
            let base:SKTexture
            if let old=sheetTextures[row.page]{base=old}else{base=SKTexture(cgImage:cg);base.filteringMode = .linear;sheetTextures[row.page]=base}
            let scale=Double(atlasSize),rect=CGRect(x:Double(row.x)/scale,y:Double(atlasSize-row.y-row.height)/scale,width:Double(row.width)/scale,height:Double(row.height)/scale)
            let texture=SKTexture(rect:rect,in:base);texture.filteringMode = .linear
            cache.setObject(texture,forKey:id as NSString,cost:row.width*row.height*4);loadCount+=1;return texture
        }
        guard let entry=prepared[id], let image=NSImage(contentsOf:root.appendingPathComponent("Prepared/\(id)@2x.png")) else { report(id); return nil }
        image.size=NSSize(width:entry.width,height:entry.height)
        let texture=SKTexture(image:image); texture.filteringMode = .linear
        cache.setObject(texture,forKey:id as NSString,cost:Int(ceil(entry.width*2)*ceil(entry.height*2))*4); loadCount+=1
        return texture
    }
    private func report(_ id: String) { if missing.insert(id).inserted { log.error("Visual disabled; missing SnowPlay asset: \(id,privacy:.public)") } }
    func sprite(_ id: String, height: CGFloat) -> SKSpriteNode {
        guard let e=prepared[id], let texture=texture(id) else { report(id); let n=SKSpriteNode(); n.isHidden=true; return n }
        let node=SKSpriteNode(texture:texture); node.name=id;node.userData=["assetID":id]
        node.size=CGSize(width:height*e.width/e.height,height:height)
        node.anchorPoint=CGPoint(x:e.anchor.x,y:1-e.anchor.y)
        node.position=CGPoint(x:(e.anchor.x-0.5)*node.size.width,y:(0.5-e.anchor.y)*height)
        return node
    }
    func model(_ ids: [String], height: CGFloat) -> SKNode {
        let node=SKNode()
        for (i,id) in ids.enumerated() { let part=sprite(id,height:height); part.zPosition=CGFloat(i); node.addChild(part) }
        return node
    }
    /// Move a registered full-canvas layer's pivot without changing its visual position.
    func pivot(_ node: SKSpriteNode, at point: CGPoint) {
        let old=node.anchorPoint
        node.position.x+=(point.x-old.x)*node.size.width; node.position.y+=(point.y-old.y)*node.size.height
        node.anchorPoint=point
    }
    func purge() { cache.removeAllObjects(); images.removeAll();sheetTextures=[:];sheetImages=[:] }
    func preview(_ requestedID: String) -> Data? {
        let id=requestedID == "snowplow" ? "snowplow_complete":requestedID
        guard registry[id] != nil else { return nil }
        return try? Data(contentsOf:root.appendingPathComponent("Prepared/\(id)@2x.png"))
    }
}
