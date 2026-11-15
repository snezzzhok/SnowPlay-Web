import Foundation
public enum WinterMode: String, Codable, CaseIterable { case focus, balanced, play }
public struct GarlandStrand:Codable,Equatable {
    public var id:String,anchors:[Vec],target:String,window:String?,palette:String,sag:Double
    public init(id:String=UUID().uuidString,anchors:[Vec],target:String="desktop",window:String?=nil,palette:String="pastel",sag:Double=12){self.id=id;self.anchors=anchors;self.target=target;self.window=window;self.palette=palette;self.sag=sag}
}
public struct TreeOrnament:Codable,Equatable {
    public var id:String;public var anchor:Vec;public var hidden:Bool
    public init(id:String,anchor:Vec,hidden:Bool=false){self.id=id;self.anchor=anchor;self.hidden=hidden}
    public static var branchAnchors:[Vec] {[Vec(0.41,0.43),Vec(0.61,0.59),Vec(0.38,0.73)]}
    public static var defaults:[TreeOrnament] {branchAnchors.enumerated().map{TreeOrnament(id:"tree_slot_\($0.offset)",anchor:$0.element)}}
}
public struct StoryPresentPlacement:Codable,Equatable {
    public var id:String,position:Vec,variant:String
    public var height:Double?
    public init(id:String,position:Vec,variant:String,height:Double?=nil){self.id=id;self.position=position;self.variant=variant;self.height=height}
}
public struct Placement: Codable, Equatable {
    public var treeIdentity:String?
    public var storyPresents:[StoryPresentPlacement]?
    public var storyPartySnowmen:[String]?
    public var extraGarlands:[GarlandStrand]?=[]
    public var snowman:Vec?
    public var snowmanRadii:[Double]?
    public var snowmen:[DesktopSnowman]?
    public var ornaments:[TreeOrnament]?
    public var garlandTarget:String?
    public var tree: Vec?; public var garland: [Vec]; public var garlandWindow: String?
    public init(tree: Vec? = nil, garland: [Vec] = [], garlandWindow: String? = nil,ornaments:[TreeOrnament]?=nil,garlandTarget:String?=nil,snowman:Vec?=nil,snowmanRadii:[Double]?=nil) {self.snowman=snowman;self.snowmanRadii=snowmanRadii;self.ornaments=ornaments;self.garlandTarget=garlandTarget; self.tree=tree; self.garland=garland; self.garlandWindow=garlandWindow }
}
public struct Configuration: Codable, Equatable {
    public var stickers=StickerStudioSettings()
    public var stories=StorySettings()
    public var treeSize="medium",treeStar="none",treeBalls="none",treeGarland="none"
    public var treeToy1="none",treeToy2="none",treeToy3="none"
    public var yetiEnabled=false
    public var floorWorldVersion=1
    public var livingWorldVersion=1
    public var snowSize=2.5
    public var automaticSnowman=true
    public var dockHats: [String:String] = [:]
    public var snow = true
    public var snowSpeed = 1.0
    public var intensity = 0.35
    public var windAngle = 0.0
    public var windStrength = 0.12
    public var accumulationRate = 1.0
    public var accumulationHeight = 5.0
    public var windowEffectDuration = 4.0
    public var groundSnow=true
    public var groundHeight=42.0
    public var windowSnow = false
    public var frost = false
    public var dockSnow = false
    public var interaction = false
    public var tree = false
    public var garland = false
    public var garlandLights=true
    public var garlandTwinkle = true
    public var mascot = "none"
    public var mode = WinterMode.balanced
    public var reducedMotion = false
    public var maxParticles = SnowfallDensity.maximumParticles
    public var fps = 60
    public var automaticCleaning = 0.0
    public var preserveSnowman = true
    public var bulbSpacing = 20.0
    public var bulbSize = 10.0
    public var bulbBrightness = 0.95
    public var bulbColor = "pastel"
    public var garlandSag = 12.0
    public var placements: [String: Placement] = [:]
    public var lastDelivery: Date?
    public init() {}
    public mutating func validate() {
        stories.validate();stickers.validate()
        let savedStrands=placements.mapValues{$0.extraGarlands ?? []}
        dockSnow=false;groundSnow=true;yetiEnabled=false
        snowSize=clamp(snowSize.isFinite ? snowSize:2.5,1,3)
        if !["small","medium","large"].contains(treeSize){treeSize="medium"}
        if !["none","gold","ice","ruby"].contains(treeStar){treeStar="none"}
        if !["none","red","gold","ice"].contains(treeBalls){treeBalls="none"}
        if !["none","multi","warm","ice"].contains(treeGarland){treeGarland="none"}
        if !["none","bauble","candy","flake"].contains(treeToy1){treeToy1="none"};if !["none","bauble","candy","flake"].contains(treeToy2){treeToy2="none"};if !["none","bauble","candy","flake"].contains(treeToy3){treeToy3="none"}
        snowSpeed=clamp(snowSpeed,0.25,2.5)
        intensity=clamp(intensity,0,1); windAngle=clamp(windAngle,-90,90); windStrength=clamp(windStrength,0,1)
        windowEffectDuration=clamp(windowEffectDuration,3,5)
        accumulationRate=accumulationRate.isFinite ? clamp(accumulationRate,0.1,5):1
        accumulationHeight=clamp(accumulationHeight,0,12); maxParticles=min(SnowfallDensity.maximumParticles,max(0,maxParticles)); fps=min(60,max(15,fps))
        automaticCleaning=automaticCleaning == 0 ? 0 : clamp(automaticCleaning,15,86400)
        bulbSpacing=clamp(bulbSpacing,15,25); bulbSize=clamp(bulbSize,7,20); bulbBrightness=clamp(bulbBrightness,0.6,1); garlandSag=clamp(garlandSag,0,30)
        dockHats=dockHats.filter { $0.key.count<1024 && ["red","green","blue"].contains($0.value) }; dockHats=Dictionary(uniqueKeysWithValues:dockHats.prefix(64).map { ($0.key,$0.value) })
        groundHeight=clamp(groundHeight,10,70);mascot="none";automaticCleaning=0
        if !["pastel","warm","ice"].contains(bulbColor) { bulbColor="pastel" }
        for key in placements.keys {
            if let old=placements[key]?.ornaments {
                placements[key]?.ornaments=TreeOrnament.defaults.map { slot in old.first(where:{$0.id==slot.id}) ?? slot }
            }
        }
        let storyGifts=placements.mapValues{$0.storyPresents},partyStyles=placements.mapValues{$0.storyPartySnowmen}
        let treeIdentities=placements.mapValues{$0.treeIdentity}
        let savedSnowmen=placements.mapValues{$0.snowmen}
        placements = Dictionary(uniqueKeysWithValues: placements.prefix(32).map { key, value in
            (key, Placement(tree: value.tree.map { Vec(clamp($0.x,0,1),clamp($0.y,0,1)) }, garland: value.garland.prefix(12).map { Vec(clamp($0.x,0,1),clamp($0.y,0,1)) },garlandWindow:value.garlandWindow.map { String($0.prefix(128)) },ornaments:value.ornaments.map { Array($0.prefix(12)).filter {$0.id.range(of:"^(tree_toy_[0-6]|tree_slot_[0-2])$",options:.regularExpression) != nil}.map { TreeOrnament(id:$0.id,anchor:Vec(clamp($0.anchor.x,0.15,0.85),clamp($0.anchor.y,0.2,0.82)),hidden:$0.hidden) } },garlandTarget:["desktop","tree","window"].contains(value.garlandTarget ?? "") ? value.garlandTarget:nil,snowman:value.snowman.map {Vec(clamp($0.x,0,1),clamp($0.y,0,1))},snowmanRadii:value.snowmanRadii.map {Array($0.prefix(3)).map{clamp($0.isFinite ? $0:4,4,26)}}))
        })
        var remainingSnowmen=5
        for id in placements.keys.sorted() {
            placements[id]?.treeIdentity=(treeIdentities[id] ?? nil).flatMap{UUID(uuidString:$0) == nil ? nil:$0}
            if let saved=storyGifts[id] ?? nil {
                var giftIDs=Set<String>()
                placements[id]?.storyPresents=Array(saved.filter{!$0.id.isEmpty && $0.id.count<80 && ["red","blue","green"].contains($0.variant) && giftIDs.insert($0.id).inserted}.prefix(12)).map{StoryPresentPlacement(id:$0.id,position:Vec(clamp($0.position.x,0,1),clamp($0.position.y,0,1)),variant:$0.variant,height:$0.height.map{clamp($0,20,60)})}
            }
            placements[id]?.storyPartySnowmen=(partyStyles[id] ?? nil).map{Array($0.prefix(5)).filter{UUID(uuidString:$0) != nil}}
            if let models=savedSnowmen[id] ?? nil {
                var seen=Set<UUID>()
                placements[id]?.snowmen=Array(models.filter{seen.insert($0.id).inserted && $0.radii.count==3 && $0.position.x.isFinite && $0.position.y.isFinite}.prefix(remainingSnowmen)).map{DesktopSnowman(id:$0.id,position:Vec(clamp($0.position.x,0,1),clamp($0.position.y,0,1)),radii:$0.radii)}
                let normalized=placements[id]?.snowmen
                placements[id]?.snowman=normalized?.last?.position
                placements[id]?.snowmanRadii=normalized?.last?.radii
                remainingSnowmen-=placements[id]?.snowmen?.count ?? 0
            }else if placements[id]?.snowman != nil {if remainingSnowmen==0{placements[id]?.snowman=nil;placements[id]?.snowmanRadii=nil}else{remainingSnowmen-=1}}
            placements[id]?.extraGarlands=Array((savedStrands[id] ?? []).prefix(8)).filter{$0.id.count<80 && $0.anchors.count>=2}.map { strand in
                GarlandStrand(id:strand.id,anchors:Array(strand.anchors.prefix(12)).map{Vec(clamp($0.x,0,1),clamp($0.y,0,1))},target:["desktop","window","tree"].contains(strand.target) ? strand.target:"desktop",window:strand.window.map{String($0.prefix(128))},palette:["pastel","warm","ice"].contains(strand.palette) ? strand.palette:"pastel",sag:clamp(strand.sag,0,30))
            }
        }
    }
    public static func preset(_ mode: WinterMode) -> Configuration {
        var c=Configuration(); c.mode=mode
        if mode == .focus { c.intensity=0.18; c.frost=false; c.maxParticles=45 }
        if mode == .play { c.intensity=0.65 }
        return c
    }
    public static func decodeCompatible(_ data: Data) throws -> Configuration {
        var object=try JSONSerialization.jsonObject(with:data) as? [String:Any] ?? [:]
        if object["livingWorldVersion"]==nil {
            if object["groundHeight"]==nil || (object["groundHeight"] as? Double)==18 {object["groundHeight"]=42.0}
            object["automaticCleaning"]=0.0
        }
        if object["stickers"]==nil {object["stickers"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(StickerStudioSettings()))}
        if object["stories"]==nil {object["stories"]=try JSONSerialization.jsonObject(with:JSONEncoder().encode(StorySettings()))}
        object["livingWorldVersion"]=1
        if object["snowSize"]==nil {object["snowSize"]=2.5}
        if object["automaticSnowman"]==nil {object["automaticSnowman"]=true}
        for (key,value) in ["treeSize":"medium","treeStar":"none","treeBalls":"none","treeGarland":"none","treeToy1":"none","treeToy2":"none","treeToy3":"none"] where object[key]==nil {object[key]=value}
        if object["yetiEnabled"]==nil {object["yetiEnabled"]=false}
        if object["floorWorldVersion"]==nil {object["dockSnow"]=false;object["bulbSize"]=10.0;object["bulbBrightness"]=0.95}
        // Upgrade former stock caps; retain Focus and explicit non-stock limits.
        if [100,1200].contains(object["maxParticles"] as? Int ?? -1), (object["mode"] as? String) != "focus" { object["maxParticles"]=SnowfallDensity.maximumParticles }
        object["floorWorldVersion"]=1
        if object["groundSnow"] == nil {object["groundSnow"]=true}
        if object["groundHeight"] == nil {object["groundHeight"]=18.0}
        if object["dockHats"] == nil { object["dockHats"]=[String:String]() }
        if object["garlandLights"] == nil {object["garlandLights"]=true}
        if object["garlandTwinkle"] == nil { object["garlandTwinkle"]=true }
        if object["accumulationRate"] == nil {object["accumulationRate"]=1.0}
        if object["snowSpeed"] == nil { object["snowSpeed"]=1.0 }
        if object["windowEffectDuration"] == nil { object["windowEffectDuration"]=4.0 }
        var c=try JSONDecoder().decode(Configuration.self,from:JSONSerialization.data(withJSONObject:object)); c.validate(); return c
    }
    public static func load(from url: URL) -> Configuration {
        guard let data=try? Data(contentsOf:url), let c=try? decodeCompatible(data) else { return Configuration() }
        return c
    }
    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(),withIntermediateDirectories:true)
        let e=JSONEncoder(); e.outputFormatting=[.prettyPrinted,.sortedKeys]; try e.encode(self).write(to:url,options:.atomic)
    }
}
