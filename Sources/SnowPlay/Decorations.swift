import AppKit
import SpriteKit
import SnowCore

final class DecorationState {
    let living=LivingSceneState()
    var passiveGift=false
    let root=SKNode()
    var tree: SKNode?; var treeSnow: SKNode?; var gift: SKNode?; var santa: SKNode?; var plow: SKNode?
    let garland=SKNode(), balls=SKNode(), celebration=SKNode()
    var snowballs=SnowballSystem()
    var snowmanVisualID:UUID?
    var extraSnowmanNodes:[UUID:SKNode]=[:]
    var snowballPlay=SnowballPlay()
    var deliveryElapsed: Double?; var giftPosition: Vec?; var giftDropped=false; var giftLanded=false; var countdown=false; var giftOpenedAt: Double?
    var target=Vec(); var time=0.0; var lastGarland=0.0; var lastBalls=0.0
    var ballNodes: [UUID:SKNode]=[:]; var snowmanNode: SKNode?; var snowmanLocation: Vec?
    var garlandKey=""; var dropTime=3.0; var dropPoint=Vec(); var countdownSecond = -1
    var garlandPaths: [CGPath]=[]
    var garlandBulbs: [GarlandBulb]=[]
    var recentGiftPositions: [Vec]=[]
    var giftLandedAt: Double?
    var sculptArea: Rect?
    var sculptSeeded=false
    var snowmanFloating=false
    var snowmanBuiltAt=0.0
    var snowmanFinalized=false
    var assemblyTargets: [String:CGPoint]=[:]
    var characterEffect:UUID?
    var character:CharacterController?
    var actor:SKNode?,projectile:SKNode?
    var projectilePath:Projectile?
    var heldSnow=0.0,carryingGift=false,treeRemoving=false,treeFalling=false
    var fragments:[SnowmanFragment]=[]
    var restoredSnowman=false
    var plowSurface:SnowSurface?,plowMass=0.0
    var garlandPhysics=GarlandPhysics()
    var extraGarlandPhysics:[String:GarlandPhysics]=[:]
    var toyImpulse=0.0,toyNodes:[String:SKNode]=[:]
    var treeHeight=132.0,treeStyleKey=""
    var treePresents:[TreePresent]=[]
    var castleBase:Vec?,castleBuildStarted:Double?,castleProgress=0.0,castleMass=0.0
    var lastYetiGame="",throwDirection=1.0
    var directTreeElapsed:Double?,directShotElapsed:Double?
    var builtTree=false
    var treeAppearedAt=0.0
    var plowProgress: Double?
    var plowBodyRestY: CGFloat=0
    var lastMouse=Vec(); var mouseSpeed=0.0; var sway=0.0
    init(scene: SKScene) { scene.addChild(root); root.addChild(garland); root.addChild(balls);balls.zPosition=25; root.addChild(celebration) }
}
final class DecorationManager {
    var consumedSnowMass=0.0
    var foregroundSnowmen=false
    var states: [String: DecorationState] = [:]
    struct CharacterRequest {var action:CharacterAction;var display:String;var target:Vec}
    var characterQueue:[CharacterRequest]=[]
    var animationDirector:AnimationDirector?
    var placementsForInput:[String:Placement]=[:]
    var pendingDelivery=false
    var fireworks:[SKNode]=[]
    var onSnowFall:((SnowFallEvent,String)->Void)?
    var onSnowmanRemoved:((String)->Void)?
    var onHelpBuild:((String)->Void)?
    var onSnowmanBuilt:((String)->Void)?
    var onDust:((Vec,String)->Void)?
    var onTreeDeliveryCancelled:((String)->Void)?
    var onTreeRemovalCancelled:((String)->Void)?
    var onDuelEnded:(()->Void)?
    var onDelivery: (()->Void)?
    func install(_ displays: [DisplayOverlay]) {
        let ids=Set(displays.map(\.id))
        for (id,s) in states where !ids.contains(id) {
            if s.living.duel != nil {onDuelEnded?()}
            if s.living.automaticMass>0,let p=s.living.automaticTarget {onSnowFall?(SnowFallEvent([SnowChunk(p,Vec(),s.living.automaticMass,fallsToGround:true)]),id)}
            if s.living.activityMass>0 {onSnowFall?(SnowFallEvent([SnowChunk(s.living.activityOrigin,Vec(),s.living.activityMass,fallsToGround:true)]),id)}
            if let delivery=s.living.delivery,!delivery.installed {onTreeDeliveryCancelled?(id)}
            s.living.clear()
        }
        states=states.filter { ids.contains($0.key) }
        for d in displays {
            if states[d.id] == nil {states[d.id]=DecorationState(scene:d.decorationScene)}
            else if let s=states[d.id],s.root.scene !== d.decorationScene {s.root.removeFromParent();d.decorationScene.addChild(s.root)}
        }
    }
    func freePoint(display d: DisplayOverlay, windows: [TrackedWindow], dock: DockGeometry?, size: Double = 96, reserveDecorations: Bool = false) -> Vec? {
        let r=d.rect
        var occupied=windows.filter(\.isVisible).map { $0.frame.expanded(12) } + (dock.map { [$0.frame.expanded(12)] } ?? [])
        if reserveDecorations, let state=states[d.id] {
            if let tree=state.tree, !tree.isHidden { occupied.append(Rect(r.x+tree.position.x-50,r.maxY-tree.position.y-50,100,100)) }
            occupied += state.snowballs.snowmen.map{$0.hitbox.expanded(12)}
        }
        return PlacementPlanner.candidates(in:r,occupied:occupied,size:size).first
    }
    private func deliveryPoint(display d: DisplayOverlay,windows: [TrackedWindow],dock: DockGeometry?,state: DecorationState)->Vec? {
        var occupied=windows.filter(\.isVisible).map { $0.frame.expanded(12) }+(dock.map { [$0.frame.expanded(12)] } ?? [])
        if let tree=state.tree,!tree.isHidden {occupied.append(Rect(d.rect.x+tree.position.x-48,d.rect.maxY-tree.position.y-48,96,96))}
        occupied += state.snowballs.snowmen.map{$0.hitbox.expanded(12)}
        if let area=state.sculptArea {occupied.append(area.expanded(10))}
        return PlacementPlanner.choose(from:PlacementPlanner.candidates(in:d.rect,occupied:occupied,size:110),bounds:d.rect,recent:state.recentGiftPositions)
    }

    func update(dt: Double, now: Double, displays: [DisplayOverlay], config: Configuration, windows: [TrackedWindow], dock: DockGeometry?, surfaces: SurfaceManager, director: AnimationDirector, mouse: Vec) {
        install(displays);placementsForInput=config.placements
        if !states.values.contains(where:{$0.character != nil}),!characterQueue.isEmpty {
            let request=characterQueue.removeFirst()
            if let d=displays.first(where:{$0.id==request.display}) {_ = requestCharacter(request.action,display:d,target:request.target,windows:windows,surfaces:surfaces,config:config)}
        }
        if pendingDelivery && config.mode != .focus && !config.reducedMotion && !states.values.contains(where: { ($0.giftPosition != nil && $0.giftOpenedAt == nil) || $0.deliveryElapsed != nil }) {
            for d in displays {
                guard let state=states[d.id],let p=deliveryPoint(display:d,windows:windows,dock:dock,state:state), director.start(.santa,duration:7,priority:0) != nil else { continue }
                state.gift?.removeFromParent(); state.gift=nil; state.giftPosition=nil; state.giftOpenedAt=nil; state.countdown=false; state.giftLanded=false;state.countdownSecond = -1; state.celebration.removeAllChildren()
                state.recentGiftPositions.append(p);state.recentGiftPositions=Array(state.recentGiftPositions.suffix(3));state.giftLandedAt=nil
                state.deliveryElapsed=0;state.giftDropped=false; state.target=p
                state.passiveGift=false
                state.santa=Resources.object(["sleigh","gift_sack","santa_character"],size:ArtScale.santa)
                let trail=Resources.layer("magic_trail",size:22); trail.position=CGPoint(x:-48,y:-12); trail.alpha=0.25; state.santa?.addChild(trail)
                state.dropTime=WinterMotion.flightTime(fraction:clamp((p.x-d.rect.x+80)/(d.rect.width+160),0.01,0.99))
                state.dropPoint=Vec(p.x,d.rect.y+145-sin(WinterMotion.flightProgress(state.dropTime/7) * .pi)*65)
                state.root.addChild(state.santa!)
                pendingDelivery=false; onDelivery?(); break
            }
        }
        for d in displays {
            guard let state=states[d.id] else { continue }
            if !state.restoredSnowman {
                state.restoredSnowman=true
                if let models=config.placements[d.id]?.snowmen {
                    let restored=models.prefix(5).map{DesktopSnowman(id:$0.id,position:Vec(d.rect.x+$0.position.x*d.rect.width,d.rect.y+$0.position.y*d.rect.height),radii:$0.radii)}
                    state.snowballs.additionalSnowmen=Array(restored.dropLast())
                    if let last=restored.last {state.snowballs.primaryID=last.id;state.snowballs.snowman=last.position;state.snowballs.assemblyBalls=last.radii.map{Snowball(position:last.position,radius:$0)}}
                }else if let saved=config.placements[d.id]?.snowman,let radii=config.placements[d.id]?.snowmanRadii,radii.count==3 {
                    let p=Vec(d.rect.x+saved.x*d.rect.width,d.rect.y+saved.y*d.rect.height)
                    state.snowballs.snowman=p;state.snowballs.assemblyBalls=radii.map{Snowball(position:p,radius:$0)}
                }
            }
            state.time+=dt
            d.actionCanvas.composites=[];d.canvas.reveals=[];d.canvas.garlandGlows=[];d.canvas.dynamicCaps=[];d.canvas.garlandPaths=[];d.canvas.garlandArt=[];d.canvas.snowballArt=[];d.canvas.composites=[];d.canvas.workbench=nil
            let occupied=windows.filter(\.isVisible).map(\.frame)+(state.living.duel.map{[$0.area]} ?? [])
            let focus=config.mode == .focus
            state.root.isHidden=focus; state.root.isPaused=focus
            if focus { continue }
            if d.desktopOccluded && !state.living.busy && state.character == nil && state.sculptArea == nil && state.snowballPlay.balls.isEmpty {
                state.root.isPaused=true
                updateWorldGarland(state:state,display:d,config:config,windows:windows,dt:0,now:now)
                continue
            }
            let mouseDelta=(mouse-state.lastMouse).length/max(dt,0.001); state.lastMouse=mouse
            let inEdge=mouse.y < d.rect.y+90 || mouse.x<d.rect.x+45 || mouse.x>d.rect.maxX-45
            if inEdge && mouseDelta>550 && mouseDelta<5000 && !config.reducedMotion { state.sway=1 }
            state.sway=max(0,state.sway-dt/0.8)
            updateFloorTree(state:state,display:d,config:config,now:now,surfaces:surfaces,windows:windows)
            updateTreeToys(state:state,display:d,config:config,now:now)
            updateWorldGarland(state:state,display:d,config:config,windows:windows,dt:dt,now:now)
            updateDelivery(state:state,display:d,dt:dt,now:now,occupied:occupied,reduced:config.reducedMotion)
            if let progress=state.plowProgress, let surface=state.plowSurface {
                let dock=DockGeometry(frame:surface.frame,axis:surface.axis,screenID:d.id)
                if state.plow == nil {
                    let node=Resources.object(["snowplow_body","snowplow_blade","snowplow_beacon"],size:ArtScale.plow)
                    for (id,x) in [("snowplow_wheel_left",105.0),("snowplow_wheel_right",218.0)] {
                        let wheel=Resources.layer(id,size:ArtScale.plow)
                        AssetManager.shared.pivot(wheel,at:CGPoint(x:x/320,y:1-176.0/230))
                        wheel.zPosition=1;node.addChild(wheel)
                    }
                    node.childNode(withName:"snowplow_blade")?.zPosition=5; node.childNode(withName:"snowplow_beacon")?.zPosition=6
                    state.plowBodyRestY=node.childNode(withName:"snowplow_body")?.position.y ?? 0
                    state.plow=node; state.root.addChild(node)
                }
                let p=PlowSweep.position(progress:progress,display:d.rect,dock:dock.snowFrame,axis:dock.axis)
                let distance=(p.x-(d.rect.x-45))
                for name in ["snowplow_wheel_left","snowplow_wheel_right"] {state.plow?.childNode(withName:name)?.zRotation=config.reducedMotion ? 0:-distance/(22.0/230*ArtScale.plow)}
                state.plow?.position=d.local(p)

                state.plow?.childNode(withName:"snowplow_body")?.position.y=state.plowBodyRestY+(config.reducedMotion ? 0:sin(distance/9)*min(1.4,0.45+state.plowMass/3000))
                state.plow?.zRotation=dock.axis == .horizontal ? 0 : dock.axis == .verticalLeft ? -.pi/2 : .pi/2
                state.plow?.childNode(withName:"snowplow_blade")?.zRotation=config.reducedMotion ? 0:-min(0.1,state.plowMass/16000)
                state.plow?.childNode(withName:"snowplow_beacon")?.alpha=config.reducedMotion ? 0.7 : 0.55+sin(now*4)*0.2
                let blocked=false
                state.plow?.isHidden=blocked
                if !blocked,let plow=state.plow {drawPlowPile(state:state,display:d,position:p,axis:dock.axis);appendSprites(from:plow,reference:state.root,to:d.canvas);plow.isHidden=true}
            } else { state.plow?.removeFromParent(); state.plow=nil }
            updateSnowballPlay(state:state,display:d,dt:dt,surfaces:surfaces)
            updateSnowman(state:state,display:d,occupied:occupied,reduced:config.reducedMotion,dock:dock,now:now,surfaces:surfaces)
            updateCharacter(state:state,display:d,dt:dt,now:now,config:config,windows:windows,surfaces:surfaces)
            updateDirectActions(state:state,display:d,dt:dt,surfaces:surfaces,reduced:config.reducedMotion)
            updateFloorObjects(state:state,display:d,now:now,dt:dt,config:config,surfaces:surfaces)
            updateLivingStories(state:state,display:d,dt:dt,now:now,config:config,surfaces:surfaces,mouse:mouse,windows:windows)

        }
    }
    private func updateDelivery(state: DecorationState, display d: DisplayOverlay, dt: Double, now: Double, occupied: [Rect], reduced: Bool) {
        if var t=state.deliveryElapsed {
            t+=dt; state.deliveryElapsed=t
            let progress=WinterMotion.flightProgress(t/7),x=d.rect.x-80+(d.rect.width+160)*progress
            let santaPoint=Vec(x,d.rect.y+145-sin(progress * .pi)*65+(reduced ? 0:sin(t*2.2)*2))
            state.santa?.position=d.local(santaPoint)
            let slope = -cos(progress * .pi)*65*Double.pi/(d.rect.width+160)
            state.santa?.zRotation=reduced ? 0 : -atan(slope)*0.7+sin(t*1.8)*0.018
            state.santa?.childNode(withName:"gift_sack")?.position.y=reduced ? 0:sin(t*2.4-0.6)*1.2
            state.santa?.childNode(withName:"magic_trail")?.alpha=reduced ? 0.25:0.25+sin(t*3)*0.07
            state.santa?.isHidden=occupied.contains { $0.intersects(Rect(santaPoint.x-38,santaPoint.y-26,76,52)) }
            if t>=state.dropTime && !state.giftDropped {
                state.giftDropped=true
                let gift=SKNode()
                let package=Resources.object(["gift_box","gift_lid","gift_bow"],size:ArtScale.gift)
                package.name="package"; package.setScale(0.53); package.position=CGPoint(x:-0.000625*ArtScale.gift,y:-0.17515625*ArtScale.gift)
                gift.addChild(package)
                let chute=Resources.object(["parachute_strings","parachute_canopy"],size:ArtScale.gift); chute.name="parachute"; chute.zPosition=3; gift.addChild(chute)
                state.gift=gift; state.root.addChild(gift)
            }
            if t>=state.dropTime && !state.giftLanded && state.gift != nil {
                let f=min(1,(t-state.dropTime)/4), eased=f*f*(3-2*f)
                let p=Vec(state.target.x+(reduced ? 0 : sin((t-state.dropTime)*2)*6*(1-f)),state.dropPoint.y+(state.target.y-state.dropPoint.y)*eased)
                state.giftPosition=p; state.gift?.position=d.local(p)
                state.gift?.childNode(withName:"parachute")?.alpha=min(1,(t-state.dropTime)*3)*(1-max(0,(f-0.85)/0.15))
                state.gift?.childNode(withName:"parachute")?.zRotation=reduced ? 0:sin((t-state.dropTime)*2)*0.065*(1-f)
                if f>=1 { state.giftLanded=true;state.giftLandedAt=now;if state.passiveGift {state.giftOpenedAt=now;state.countdown=true} }
            }
            if t>=7 { state.santa?.removeFromParent(); state.santa=nil }
            if t>=max(7,state.dropTime+4) { state.deliveryElapsed=nil;if state.gift != nil {state.giftPosition=state.target} }
        }
        if let p=state.giftPosition {
            if state.giftLanded,state.giftOpenedAt == nil,let landed=state.giftLandedAt {
                state.gift?.position=d.local(p+Vec(0,reduced ? 0:-WinterMotion.landingLift(elapsed:now-landed)))
            }
            state.gift?.isHidden=occupied.contains { $0.intersects(Rect(p.x-26,p.y-26,52,52)) }
        }
        if state.giftOpenedAt == nil,let landed=state.giftLandedAt {
            let age=now-landed
            state.gift?.alpha=1-clamp((age-(GiftLifecycle.unopenedLifetime-1))/1,0,1)
            if age>=GiftLifecycle.unopenedLifetime { removeGift(state);return }
        }
        if let opened=state.giftOpenedAt {
            let t=max(0,now-opened)
            if let gift=state.gift {
                if !state.passiveGift {for id in ["gift_lid","gift_bow"] { if let lid=gift.childNode(withName:"package/"+id) {lid.position.y=min(22,t*30);lid.alpha=max(0,1-t/2)} }}
                gift.alpha=state.passiveGift ? 1-clamp((t-4)/0.7,0,1):GiftLifecycle.boxOpacity(elapsed:t);gift.zRotation=reduced ? 0:sin(min(1,t) * .pi)*0.06
                if t>=(state.passiveGift ? 4.7:GiftLifecycle.boxLifetime) {gift.removeAllActions();gift.removeFromParent();state.gift=nil}
            }
            if t>=(state.passiveGift ? 4.8:GiftLifecycle.celebrationLifetime) {removeGift(state);return}
            state.celebration.alpha=state.passiveGift ? 1-clamp((t-3.5)/0.5,0,1):GiftLifecycle.celebrationOpacity(elapsed:t)
            if state.countdown {
                let label: SKLabelNode
                if let old=state.celebration.childNode(withName:"countdown") as? SKLabelNode {label=old}
                else {
                    let panel=Resources.layer("countdown_panel",size:90);panel.name="countdown-background";panel.alpha=0.85;panel.zPosition = -1;state.celebration.addChild(panel)
                    label=SKLabelNode(fontNamed:"HelveticaNeue");label.name="countdown";label.fontSize=10;label.fontColor=NSColor(calibratedRed:0.9,green:0.82,blue:0.63,alpha:1);state.celebration.addChild(label)
                }
                let calendar=Calendar.current,year=calendar.component(.year,from:Date())+1,next=calendar.date(from:DateComponents(year:Calendar.current.component(.year,from:Date())+1,month:1,day:1)) ?? Date()
                let seconds=max(0,Int(next.timeIntervalSinceNow))
                if seconds != state.countdownSecond {state.countdownSecond=seconds;label.text="\(year) · \(seconds/86400)d  \(seconds/3600%24)h  \(seconds/60%60)m  \(seconds%60)s"}
                if let p=state.giftPosition {
                    label.position=d.local(p+Vec(0,-44));label.isHidden=occupied.contains { $0.intersects(Rect(p.x-85,p.y-85,170,55)) }
                    if let panel=state.celebration.childNode(withName:"countdown-background") {panel.position=d.local(p+Vec(0,-48));panel.isHidden=label.isHidden}
                }
            }
        }
    }
    private func removeGift(_ state: DecorationState) {
        state.passiveGift=false
        state.gift?.removeAllActions();state.gift?.removeFromParent();state.gift=nil;state.giftPosition=nil;state.giftOpenedAt=nil;state.giftLanded=false;state.giftLandedAt=nil;state.countdown=false;state.countdownSecond = -1
        state.celebration.removeAllChildren();state.celebration.alpha=1
    }

    private func updateSnowman(state: DecorationState, display d: DisplayOverlay, occupied: [Rect], reduced: Bool, dock: DockGeometry?, now: Double,surfaces:SurfaceManager) {
        syncSnowmanVisuals(state:state,display:d,now:now,surfaces:surfaces,reduced:reduced,occupied:occupied)
        let ids=Set(state.snowballs.balls.map(\.id))
        for id in Array(state.ballNodes.keys) where !ids.contains(id) { state.ballNodes.removeValue(forKey:id)?.removeFromParent() }
        for i in state.snowballs.balls.indices {let ball=state.snowballs.balls[i];state.snowballs.balls[i].position.y=groundY(ball.position.x,display:d,surfaces:surfaces)-ball.radius}
        if let old=state.snowballs.snowman {let mass=state.snowballs.assemblyBalls.reduce(0){$0+Double.pi*$1.radius*$1.radius},h=clamp(56*sqrt(max(1,mass)/(Double.pi*261)),35,96);state.snowballs.snowman=Vec(old.x,groundY(old.x,display:d,surfaces:surfaces)-h*0.441);state.snowmanFloating=true}
        for b in state.snowballs.balls {
            let node: SKNode
            if let existing=state.ballNodes[b.id] { node=existing }
            else { node=Resources.layer("snowball_medium",size:36); state.balls.addChild(node); state.ballNodes[b.id]=node }
            node.setScale(b.radius*2/30); node.position=d.local(b.position)
            let nearDock: Bool
            if let dock,dock.isVisible,dock.screenID == d.id { nearDock=dock.frame.expanded(80).contains(b.position) } else { nearDock=false }
            node.isHidden=state.sculptArea != nil || nearDock || occupied.contains { $0.intersects(Rect(b.position.x-b.radius,b.position.y-b.radius,b.radius*2,b.radius*2)) }
            node.zRotation = -b.rotation
            if state.sculptArea != nil || nearDock {appendSprites(from:node,reference:state.root,to:d.canvas)}
        }
        guard let p=state.snowballs.snowman else { state.snowmanNode?.removeFromParent(); state.snowmanNode=nil; state.snowmanLocation=nil; return }
        if let node=state.snowmanNode,state.snowmanLocation != p { node.position=d.local(p);state.snowmanLocation=p }
        let mass=state.snowballs.assemblyBalls.reduce(0){$0+Double.pi*$1.radius*$1.radius}
        let snowmanSize=clamp(56*sqrt(max(1,mass)/(Double.pi*261)),35,96)
        if state.snowmanNode == nil {
            state.snowmanNode?.removeFromParent(); let node=SKNode(); node.position=d.local(p);state.snowmanBuiltAt=now;state.snowmanFinalized=false;state.assemblyTargets=[:]
            let parts=[("snowman_ball_base",175.0,66.0),("snowman_ball_middle",113.0,49.0),("snowman_ball_head",55.0,37.0)]
            for (i,part) in parts.enumerated() {
                let sphere=Resources.layer(part.0,size:snowmanSize)
                AssetManager.shared.pivot(sphere,at:CGPoint(x:0.5,y:1-part.1/256))
                let target=sphere.position;state.assemblyTargets[part.0]=target;node.addChild(sphere)
                if !reduced, i<state.snowballs.assemblyBalls.count {
                    let source=state.snowballs.assemblyBalls[i]
                    sphere.position=CGPoint(x:source.position.x-p.x,y:p.y-source.position.y)
                    sphere.setScale(source.radius/(part.2*snowmanSize/256))
                    let move=SKAction.move(to:target,duration:0.65); move.timingMode = .easeInEaseOut
                    sphere.run(.sequence([.wait(forDuration:Double(i)*0.35),.group([move,.scale(to:1,duration:0.65)])]))
                }
            }
            for (i,id) in ["snowman_arms","snowman_face","snowman_buttons","snowman_scarf","snowman_hat"].enumerated() {
                let part=Resources.layer(id,size:snowmanSize); part.zPosition=CGFloat(i+3);state.assemblyTargets[id]=part.position;node.addChild(part)
                if !reduced { part.alpha=0; part.run(.sequence([.wait(forDuration:1.3+Double(i)*0.1),.fadeIn(withDuration:0.35)])) }
            }
            let closed=Resources.layer("snowman_face_closed",size:snowmanSize);closed.name="snowman-face-closed";closed.zPosition=4.1;closed.isHidden=true;node.addChild(closed)

            state.snowmanLocation=p; state.snowmanNode=node; state.balls.addChild(node)
        }
        if let node=state.snowmanNode {
            let blink=state.snowmanFinalized && (now-state.snowmanBuiltAt).truncatingRemainder(dividingBy:4.7)>4.55
            node.childNode(withName:"snowman_face")?.isHidden=blink;node.childNode(withName:"snowman-face-closed")?.isHidden = !blink
            if !state.snowmanFinalized,now-state.snowmanBuiltAt>=2.5 || reduced {
                for child in node.children {child.removeAllActions();child.alpha=1;child.setScale(1);if let name=child.name,let target=state.assemblyTargets[name] {child.position=target}}
                state.snowmanFinalized=true
            }
            node.zRotation=reduced ? 0:sin(now*0.7)*0.015
            let hidden=occupied.contains { $0.intersects(Rect(p.x-28,p.y-28,56,56)) }
            node.isHidden=foregroundSnowmen || hidden;node.isPaused=reduced || hidden
            if foregroundSnowmen {appendSprites(from:node,reference:state.root,to:d.actionCanvas)}
        }
    }
    func appendSprites(from root: SKNode,reference: SKNode,to canvas: SnowCanvas) {
        func walk(_ node: SKNode,alpha: Double) {
            if node !== root && node.isHidden {return}
            let opacity=alpha*Double(node.alpha)
            if let sprite=node as? SKSpriteNode,let name=(sprite.userData?["assetID"] as? String) ?? sprite.name,let image=AssetManager.shared.image(name) {
                let o=sprite.convert(.zero,to:reference),x=sprite.convert(CGPoint(x:1,y:0),to:reference),y=sprite.convert(CGPoint(x:0,y:1),to:reference)
                let t=CGAffineTransform(a:x.x-o.x,b:x.y-o.y,c:y.x-o.x,d:y.y-o.y,tx:o.x,ty:o.y)
                canvas.composites.append(CanvasSprite(image:image,rect:CGRect(x:-sprite.anchorPoint.x*sprite.size.width,y:-sprite.anchorPoint.y*sprite.size.height,width:sprite.size.width,height:sprite.size.height),transform:t,alpha:opacity))
            }
            for child in node.children.sorted(by: { $0.zPosition<$1.zPosition }) {walk(child,alpha:opacity)}
        };walk(root,alpha:1)
    }

    func openGift(displayID: String, now: Double, fireworks: Bool, director: AnimationDirector) {
        guard let state=states[displayID], state.giftLanded, state.gift != nil, state.giftPosition != nil, state.giftOpenedAt == nil else { return }
        state.giftOpenedAt=now; state.countdown=true
        if fireworks, !director.active.contains(where: { $0.kind == .fireworks }), director.start(.fireworks,duration:2,particles:24) != nil, let gift=state.gift {
            tripleFireworks(parent:gift,reduced:false,now:now)

        }
    }
    func cancelTransient() {
        characterQueue=[]
        pendingDelivery=false
        for node in fireworks {node.removeAllActions();node.removeFromParent()};fireworks=[]
        for state in states.values {
            if state.living.duel != nil {onDuelEnded?()}
            if let id=states.first(where:{$0.value === state})?.key {
                if let delivery=state.living.delivery,!delivery.installed {onTreeDeliveryCancelled?(id)}
                if state.living.automaticMass>0,let target=state.living.automaticTarget {onSnowFall?(SnowFallEvent([SnowChunk(target,Vec(0,10),state.living.automaticMass,fallsToGround:true)]),id);state.snowballs.balls=[]}
                if state.living.activityMass>0 {onSnowFall?(SnowFallEvent([SnowChunk(state.living.activityOrigin,Vec(0,10),state.living.activityMass,fallsToGround:true)]),id)}
            }
            state.living.clear()
            state.directTreeElapsed=nil;state.directShotElapsed=nil;state.projectilePath=nil
            finishCharacter(state)
            if state.deliveryElapsed != nil && !state.giftLanded { state.gift?.removeFromParent(); state.gift=nil; state.giftPosition=nil }
            state.santa?.removeFromParent(); state.santa=nil; state.deliveryElapsed=nil
            state.plow?.removeFromParent(); state.plow=nil; state.plowProgress=nil
            state.celebration.removeAllActions()
        }
    }
    func reset(preserveSnowman: Bool) {
        if duelActive {onDuelEnded?()}
        characterQueue=[]
        pendingDelivery=false
        for node in fireworks {node.removeFromParent()};fireworks=[]
        for state in states.values {
            state.living.clear();state.passiveGift=false
            state.directTreeElapsed=nil;state.directShotElapsed=nil;state.projectilePath=nil
            state.extraSnowmanNodes=[:];state.snowmanVisualID=nil;state.snowballPlay=SnowballPlay();state.root.removeAllChildren(); state.root.addChild(state.garland); state.root.addChild(state.balls); state.root.addChild(state.celebration)
            state.garland.removeAllChildren(); state.balls.removeAllChildren(); state.celebration.removeAllChildren();state.treePresents=[];state.castleBase=nil;state.castleMass=0;state.castleBuildStarted=nil
            state.tree=nil; state.builtTree=false; state.treeSnow=nil; state.ballNodes.removeAll(); state.snowmanNode=nil; state.snowmanLocation=nil; state.garlandKey=""; state.garlandPaths=[];state.garlandBulbs=[];state.garlandPhysics.reset();finishCharacter(state);state.fragments=[];state.toyNodes=[:]; state.gift=nil; state.giftPosition=nil; state.deliveryElapsed=nil; state.giftOpenedAt=nil; state.santa=nil; state.plow=nil; state.plowProgress=nil; state.countdown=false; state.giftDropped=false;state.giftLanded=false;state.giftLandedAt=nil;state.sculptArea=nil;state.sculptSeeded=false;state.snowmanFloating=false
            state.snowballs.balls.removeAll(); if !preserveSnowman { state.snowballs.clearSnowmen();for n in state.extraSnowmanNodes.values{n.removeFromParent()};state.extraSnowmanNodes=[:] }
        }
        AssetManager.shared.purge()
    }
}
