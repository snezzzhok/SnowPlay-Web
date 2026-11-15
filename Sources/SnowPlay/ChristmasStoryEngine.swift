import AppKit
import SpriteKit
import SnowCore

struct ChristmasStoryStage {
    let display:DisplayOverlay,state:DecorationState,area:Rect,focus:Vec,bounds:Rect
    let snowmanID:UUID?,giftID:String?
    var side:Double {focus.x<area.center.x ? 1:-1}
}
struct ChristmasStoryAvailability {
    let id:ChristmasStoryID,reason:String,stage:ChristmasStoryStage?
    var available:Bool {reason.isEmpty && stage != nil}
}
final class ChristmasStoryEngine {
    var removalTarget:GarlandRemovalTarget?
    var scheduler=ChristmasStoryScheduler(),reservations=StoryReservations()
    private(set) var active:ChristmasStoryRuntime?
    private(set) var lastResult:[String:Any]=[:]
    var onFinished:((ChristmasStoryRuntime)->Void)?
    var developerMode=CommandLine.arguments.contains("--story-developer")
    private var sound:NSSound?
    func availability(_ id:ChristmasStoryID,manager:DecorationManager,displays:[DisplayOverlay],config:Configuration,windows:[TrackedWindow],dock:DockGeometry?,surfaces:SurfaceManager,ignoringBusy:Bool=false)->ChristmasStoryAvailability {
        func no(_ why:String)->ChristmasStoryAvailability {ChristmasStoryAvailability(id:id,reason:why,stage:nil)}
        if !ignoringBusy,(manager.livingBusy || manager.pendingDelivery || !manager.characterQueue.isEmpty || manager.states.values.contains{$0.plowProgress != nil || $0.deliveryElapsed != nil}) {return no("Another activity is playing")}
        if config.mode == .focus {return no("Switch to Balanced or Play")}
        if config.reducedMotion {return no("Reduce Motion is on")}
        if id == .lightRepair && (config.treeGarland == "none" || !config.garlandLights) {return no("Requires tree lights")}
        if id == .snowmanBuild && !config.stories.allowSnowmanCreation {return no("Allow snowman creation in Advanced")}
        if config.stories.keepDecorations,[ChristmasStoryID.presentTheft,.santaDrop].contains(id),manager.states.values.contains(where:{$0.treePresents.count>9}) {return no("Open some presents to make room")}
        if id == .snowmanBuild,manager.states.values.contains(where:{!$0.snowballs.balls.isEmpty}) {return no("Finish your current snowballs first")}
        if id == .garlandRemoval && removalTarget==nil {return no("Choose a garland with Delete first")}
        if id == .giftConveyor && manager.states.values.contains(where:{$0.treePresents.count>8}) {return no("Open some presents to make room for four parcels")}
        if id == .snowmanBuild && manager.snowmanCount>=5 {return no("Five snowmen already")}
        var objectFound=false
        for d in displays {
            guard let s=manager.states[d.id] else{continue}
            if id == .garlandRemoval && removalTarget?.display != d.id {continue}
            let model=s.snowballs.snowmen.first
            if id.needsTree && (s.tree == nil || !config.tree || s.treeRemoving) {continue}
            if id.needsSnowman && model == nil {continue}
                if id == .presentTheft && !s.treePresents.contains(where:{$0.openedAt==nil}) {continue}
            if id == .treeShake && branchKeys(d.id,surfaces:surfaces).reduce(0.0,{ $0+(surfaces.surfaces[$1]?.volume ?? 0) })<8 {continue}
            if id == .snowmanBuild && (surfaces.surfaces["ground-"+d.id]?.volume ?? 0)<StorySnowmanRecipe.mass {continue}
            objectFound=true
            let tree=s.tree.map{Vec(d.rect.x+$0.position.x,d.rect.maxY-$0.position.y+s.treeHeight*0.38)}
            let focus=id.needsTree ? tree! : id.needsSnowman ? Vec(model!.position.x,manager.groundY(model!.position.x,display:d,surfaces:surfaces)):Vec(d.rect.center.x,manager.groundY(d.rect.center.x,display:d,surfaces:surfaces))
            var blocked=windows.filter(\.isVisible).map{$0.frame.expanded(8)}
            if let dock,dock.isVisible,dock.screenID==d.id {blocked.append(dock.frame.expanded(4))}
            blocked+=config.stories.reservedZones.filter{$0.screen==d.id || $0.screen=="all"}.map{Rect(d.rect.x+$0.rect.x*d.rect.width,d.rect.y+$0.rect.y*d.rect.height,$0.rect.width*d.rect.width,$0.rect.height*d.rect.height)}
            if !id.needsTree,let tree {blocked.append(Rect(tree.x-s.treeHeight*0.4,tree.y-s.treeHeight*0.9,s.treeHeight*0.8,s.treeHeight))}
            for snowman in s.snowballs.snowmen where id != .snowmanParty && snowman.id != (id.needsSnowman ? model?.id:nil) {blocked.append(snowman.hitbox.expanded(15))}
            let height=id == .santaDrop || id == .snowballExchange ? 340:max(250,id.needsTree ? s.treeHeight+110:250)
            let width=id == .snowballExchange ? 960.0:id == .giftConveyor ? 860.0:680.0
            if let area=StoryStagePlanner.stage(bounds:d.rect,focus:focus,width:width,height:height,blocked:blocked) {
                if id == .snowballExchange && abs(focus.x-area.center.x)>120 {continue}
                if id == .presentTheft && min(focus.x-area.x,area.maxX-focus.x)<130 {continue}
                let side=focus.x<area.center.x ? 1.0:-1.0
                let victim=s.treePresents.filter{$0.openedAt==nil}.max{($0.position.x-focus.x)*(-side)<($1.position.x-focus.x)*(-side)}?.id
                return ChristmasStoryAvailability(id:id,reason:"",stage:ChristmasStoryStage(display:d,state:s,area:area,focus:focus,bounds:d.rect,snowmanID:id.needsSnowman ? model?.id:nil,giftID:id == .presentTheft ? victim:nil))
            }
        }
        if objectFound {return no(id == .snowballExchange ? "Clear 960 × 340 pt around a centered snowman":"Needs a clear area beside the scene")}
        if id == .presentTheft {return no("Requires a tree with unopened gifts")}
        if id == .lightRepair {return no("Requires a Christmas tree with lights")}
        if id == .treeShake {return no("Requires snow on tree branches")}
        if id.needsTree {return no("Requires a Christmas tree")}
        if id.needsSnowman {return no("Requires a snowman")}
        return no("Requires enough snow and free space")
    }
    func branchKeys(_ id:String,surfaces:SurfaceManager)->[String] {surfaces.surfaces.keys.filter{$0.hasPrefix("tree-"+id+"-branch-")}.sorted()}
    @discardableResult func start(_ id:ChristmasStoryID,manager:DecorationManager,displays:[DisplayOverlay],config:Configuration,windows:[TrackedWindow],dock:DockGeometry?,surfaces:SurfaceManager,variant:Int?=nil)->String? {
        guard active==nil else{return "Another story is playing"}
        let choice=availability(id,manager:manager,displays:displays,config:config,windows:windows,dock:dock,surfaces:surfaces)
        guard let stage=choice.stage,choice.available else{return choice.reason}
        let owner=UUID(),keys=["stage:"+stage.display.id,"yeti","elves"]+(id.needsTree ? ["tree:"+stage.display.id]:[])+(stage.snowmanID.map{["snowman:"+$0.uuidString]} ?? [])+(stage.giftID.map{["gift:"+$0]} ?? [])
        guard reservations.acquire(keys,owner:owner) else{return "Scene is reserved"}
        let picked=variant ?? (id == .presentTheft ? (Double.random(in:0...1)<0.7 ? 0:1):Int.random(in:0...1))
        let runtime=ChristmasStoryRuntime(id:id,owner:owner,stage:stage,manager:manager,config:config,surfaces:surfaces,variant:picked)
        active=runtime;runtime.garlandTarget=removalTarget;runtime.prepare();scheduler.didStart(id,frequency:config.stories.frequency);return nil
    }
    func stop(immediately:Bool=false,reason:String="Stopped") {active?.interrupt(reason,immediately:immediately);if immediately {finishIfReady()}}
    func update(dt:Double,now:Double,config:Configuration,windows:[TrackedWindow],dock:DockGeometry?,surfaces:SurfaceManager) {
        guard let active else{return}
        active.tick(dt:dt,now:now,config:config,windows:windows,dock:dock,surfaces:surfaces)
        finishIfReady()
    }
    private func finishIfReady(){
        guard let run=active,run.finished else{return}
        lastResult=run.snapshot;reservations.release(run.owner);active=nil
        if run.succeeded,run.settings.sounds {
            if sound==nil {sound=NSSound(contentsOf:Resources.root.appendingPathComponent("SnowPlayAssets/World/story_chime.wav"),byReference:true);sound?.volume=0.35};sound?.play()
        }
        onFinished?(run)
    }
    var snapshot:[String:Any] { ["active":active?.snapshot ?? [:],"last":lastResult,"reservedObjects":reservations.owners.count,"eligibleSeconds":scheduler.eligibleSeconds,"nextIn":max(0,scheduler.nextAt-scheduler.eligibleSeconds),"developerMode":developerMode,"focusStatus":"notAuthorized"] }
}

enum StorySnowmanRecipe {static let radii=[10.5,8.0,6.0];static var mass:Double {radii.reduce(0){$0+Double.pi*$1*$1}}}
