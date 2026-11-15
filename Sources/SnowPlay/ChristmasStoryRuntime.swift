import AppKit
import SpriteKit
import SnowCore

struct StoryFootprint {var point:Vec,born:Double}
struct ChristmasStoryAction {
    let beat:StoryBeat
    var enter:((ChristmasStoryRuntime)->Void)?
    var update:((ChristmasStoryRuntime,Double)->Void)?
    var leave:((ChristmasStoryRuntime)->Void)?
}
final class StoryPerformer {
    let actor:LivingActor
    var position:Vec,target:Vec,pose=LivingPose.idle,poseTime=0.0,facing=1.0
    var active=true,climbing=false
    var previousPosePosition:Vec?,walked=0.0
    var radius:Double {(actor.yeti ? 16:14)*(actor.storyRig?.scale ?? 1)}
    var waypoints:[Vec]=[]
    init(actor:LivingActor,position:Vec){self.actor=actor;self.position=position;target=position}
}
final class ChristmasStoryRuntime {
    let id:ChristmasStoryID,owner:UUID,stage:ChristmasStoryStage,variant:Int
    var settings:StorySettings
    unowned let manager:DecorationManager
    let surfaces:SurfaceManager,root=SKNode()
    var currentWindows:[TrackedWindow]=[]
    var garlandTarget:GarlandRemovalTarget?
    var shots:[StorySnowShot]=[],peakActors=0,peakShots=0,shotImpacts=0
    var temporaryNodes:[SKNode]=[],extraPartyVisibility:[(SKNode,Bool)]=[]
    var extraPartyRest:[(SKNode,CGPoint,CGFloat,[(SKNode,CGFloat)])]=[]
    var actors:[String:StoryPerformer]=[:],props:[String:SKNode]=[:],actions:[ChristmasStoryAction]=[]
    var timeline=StoryTimeline([]),machine=StoryLifecycleMachine()
    var currentNow=0.0
    var installedPartyNodes:[SKNode]=[],replacedPartyStyles:[SKNode]=[]
    var snowmanParts:[(SKNode,CGFloat,CGFloat,Bool,CGPoint)]=[]
    var giftSlots:[Vec]=[]
    var entered = -1,elapsed=0.0,finishElapsed=0.0,interruption="",succeeded=false,finished=false
    var contacts:[[String:Any]]=[],originalGifts:[TreePresent]=[],originalTreeRotation:CGFloat=0
    var initialSnowmen=Set<UUID>(),takenMass=0.0,createdSnowman:UUID?,persistentGifts:[(String,Vec)]=[]
    var snowmanOriginal:(node:SKNode,rotation:CGFloat,position:CGPoint)?,borrowed:[(node:SKNode,parent:SKNode,position:CGPoint,alpha:CGFloat)]=[]
    var branchHeldMass=0.0,branchHeldOrigin=Vec()
    var projectile:Projectile?,projectileTime=0.0,projectileNode:SKNode?,minimumActorGap=Double.infinity
    var footprints:[StoryFootprint]=[],lastFootprint:[String:Vec]=[:]
    var pairCarry:(prop:String,left:String,right:String)?
    var custom:[String:Double]=[:],selectedGift:TreePresent?,outcome=""
    var visualSnowballs:[Snowball]=[]
    var display:DisplayOverlay {stage.display};var state:DecorationState {stage.state}
    var snowmanNode:SKNode? {guard let id=stage.snowmanID ?? createdSnowman else{return nil};return state.snowmanVisualID==id ? state.snowmanNode:state.extraSnowmanNodes[id]}
    var snowman:DesktopSnowman? {state.snowballs.snowmen.first{$0.id==(stage.snowmanID ?? createdSnowman)}}
    init(id:ChristmasStoryID,owner:UUID,stage:ChristmasStoryStage,manager:DecorationManager,config:Configuration,surfaces:SurfaceManager,variant:Int){self.id=id;self.owner=owner;self.stage=stage;self.manager=manager;self.settings=config.stories;self.surfaces=surfaces;self.variant=variant;originalGifts=stage.state.treePresents;initialSnowmen=Set(stage.state.snowballs.snowmen.map(\.id));originalTreeRotation=stage.state.tree?.zRotation ?? 0}
    func prepare(){
        _=machine.transition(.validating);_=machine.transition(.reserving);root.name="christmas-story";root.zPosition=26;state.root.addChild(root)
        if let node=snowmanNode {snowmanOriginal=(node,node.zRotation,node.position);snowmanParts=node.children.map{($0,$0.zRotation,$0.alpha,$0.isHidden,$0.position)}}
        for offset in [0.0,34,68,102,136,-34,-68,-102,-136] {
            let point=spot(offset,-10)
            if !state.treePresents.contains(where:{abs($0.position.x-point.x)<31}),!giftSlots.contains(where:{abs($0.x-point.x)<31}){giftSlots.append(point)}
        }
        switch id {case .presentTheft:planPresentTheft();case .lightRepair:planLightRepair();case .snowballExchange:planSnowballExchange();case .snowmanBuild:planSnowmanBuild();case .treeShake:planTreeShake();case .santaDrop:planSantaDrop();case .snowmanParty:planSnowmanParty();case .starHat:planStarHat();case .giftConveyor:planGiftConveyor();case .tinyGift:planTinyGift();case .garlandRemoval:planGarlandRemoval()}
        timeline=StoryTimeline(actions.map(\.beat));_=machine.transition(.spawning)
    }
    func spot(_ distance:Double,_ depth:Double=0)->Vec {let x=clamp(stage.focus.x+stage.side*distance,stage.area.x+30,stage.area.maxX-30);return Vec(x,manager.groundY(x,display:display,surfaces:surfaces)+depth)}
    func giftSlot(_ index:Int)->Vec {index<giftSlots.count ? giftSlots[index]:spot(68+Double(index)*34,-10)}
    func opposite(_ distance:Double)->Vec {spot(-distance)}
    func spawn(_ name:String,yeti:Bool=false,color:String="red",at point:Vec?=nil,scale:Double=1,variant:Int=0,giant:Bool=false){
        let p=point ?? spot(Double(actors.count)*48+200),actor=LivingActor(yeti:yeti,color:["green","blue"].contains(color) ? color:"red");actor.node.alpha=0;root.addChild(actor.node)
        actor.storyRig=StoryActorRig(actor,color:color,scale:scale,variant:variant,giant:giant)
        let a=StoryPerformer(actor:actor,position:p);actor.compactHands=yeti;do {actor.held.texture=AssetManager.shared.texture("snowball_medium");actor.held.size=CGSize(width:18,height:18);actor.held.userData?["assetID"]="snowball_medium"};actors[name]=a;peakActors=max(peakActors,actors.count);actor.node.position=display.local(p)
    }
    func move(_ name:String,_ target:Vec,pose:LivingPose = .run){guard let a=actors[name] else{return};a.target=target;a.pose=pose;a.poseTime=0;a.waypoints=[]
    }
    func pose(_ name:String,_ pose:LivingPose){guard let a=actors[name] else{return};if a.pose != pose {a.poseTime=0};a.pose=pose}
    func add(_ name:String,_ asset:String,height:Double,at point:Vec?=nil)->SKNode {
        let node=Resources.layer(asset,size:height);node.name=name;root.addChild(node);if let point {node.position=display.local(point)};props[name]=node;return node
    }
    func place(_ name:String,at point:Vec){guard let node=props[name] else{return};node.removeFromParent();root.addChild(node);node.position=display.local(point);node.zRotation=0}
    func carry(_ prop:String,by actor:String){guard let node=props[prop],let a=actors[actor] else{return};node.removeFromParent();a.actor.palm.addChild(node);node.position = .zero;node.zRotation=0;node.xScale=1;node.yScale=1;contact("attach",prop:prop,actor:actor)}
    func reach(_ actor:String,to point:Vec,fraction:Double){
        guard let a=actors[actor] else{return};a.facing=point.x<a.position.x ? -1:1;a.actor.node.xScale=a.facing*(a.actor.storyRig?.scale ?? 1)
        let target=a.actor.node.convert(display.local(point),from:root),f=clamp(fraction,0,1),p=a.actor.palm.position
        a.actor.palm.position=CGPoint(x:p.x+(target.x-p.x)*f,y:p.y+(target.y-p.y)*f);a.actor.rigHand()
    }
    func sharedCarry(_ prop:String,left:String,right:String){
        guard let node=props[prop] else{return};node.removeFromParent();root.addChild(node);pairCarry=(prop,left,right);syncSharedCarry();contact("pair-pickup",prop:prop,actor:left+"+"+right)
    }
    func syncSharedCarry(){
        guard let pair=pairCarry,let left=actors[pair.left],let right=actors[pair.right],let node=props[pair.prop] else{return}
        left.facing=1;right.facing = -1;left.actor.pose(.carry,time:left.poseTime,facing:1);right.actor.pose(.carry,time:right.poseTime,facing:-1)
        let point=Vec((left.position.x+right.position.x)/2,(left.position.y+right.position.y)/2-24)
        node.position=display.local(point)
        reach(pair.left,to:point+Vec(-(custom["pairGrip"] ?? 10),0),fraction:1);reach(pair.right,to:point+Vec(custom["pairGrip"] ?? 10,0),fraction:1)
    }
    func release(_ prop:String,at point:Vec){if pairCarry?.prop==prop {pairCarry=nil};place(prop,at:point);contact("release",prop:prop,actor:"")}
    func contact(_ kind:String,prop:String,actor:String){
        var error=0.0
        if kind=="attach",let node=props[prop],let a=actors[actor] {let p=node.convert(.zero,to:root),hand=a.actor.hand(in:root);error=hypot(p.x-hand.x,p.y-hand.y)}
        contacts.append(["event":kind,"prop":prop,"actor":actor,"time":elapsed,"gripErrorPt":error]);if contacts.count>100 {contacts.removeFirst()}
    }
    func beat(_ name:String,_ duration:Double,arrivals:[String]=[],enter:((ChristmasStoryRuntime)->Void)?=nil,update:((ChristmasStoryRuntime,Double)->Void)?=nil,leave:((ChristmasStoryRuntime)->Void)?=nil){actions.append(ChristmasStoryAction(beat:StoryBeat(name,duration,arrivals:arrivals),enter:enter,update:update,leave:leave))}
    func walk(_ name:String,_ duration:Double=1.0,goals:[String:Vec],pose:LivingPose = .run){beat(name,duration,arrivals:Array(goals.keys),enter:{r in for (actor,goal) in goals {r.move(actor,goal,pose:pose)}})}
    func leaveTogether(_ names:[String],duration:Double=2.5){
        beat("walk-home",duration,arrivals:names,enter:{r in
            let live=names.filter{r.actors[$0] != nil}
            let left=live.filter{r.actors[$0]!.position.x<=r.stage.focus.x}.sorted{r.actors[$0]!.position.x<r.actors[$1]!.position.x}
            let right=live.filter{r.actors[$0]!.position.x>r.stage.focus.x}.sorted{r.actors[$0]!.position.x>r.actors[$1]!.position.x}
            for (i,name) in left.enumerated(){let x=r.stage.area.x+40+Double(i)*46;r.move(name,Vec(x,r.manager.groundY(x,display:r.display,surfaces:r.surfaces)),pose:.walk)}
            for (i,name) in right.enumerated(){let x=r.stage.area.maxX-40-Double(i)*46;r.move(name,Vec(x,r.manager.groundY(x,display:r.display,surfaces:r.surfaces)),pose:.walk)}
        })
        beat("goodbye",0.8,update:{r,t in for a in r.actors.values {a.actor.node.alpha=1-clamp(t/0.8,0,1)}})
    }
    func throwBall(from:Vec,to:Vec,duration:Double=1.35){
        projectile=Projectile(from:from,to:to,duration:duration,gravity:220);projectileTime=0
        let node=Resources.layer("snowball_medium",size:18);root.addChild(node);node.position=display.local(from);projectileNode=node
        contact("throw",prop:"snowball",actor:"")
    }
    func actorHand(_ name:String)->Vec {guard let actor=actors[name] else{return stage.focus};let p=actor.actor.hand(in:state.root);return Vec(display.rect.x+p.x,display.rect.maxY-p.y)}
    func puff(at point:Vec,count:Int=9){
        for i in 0..<min(count,12) {let node=Resources.layer(i%2==0 ? "snow_clump_0":"snow_clump_1",size:Double(4+i%3));node.position=display.local(point);root.addChild(node);let angle=Double(i)*2.4,move=SKAction.moveBy(x:cos(angle)*20,y:8+abs(sin(angle))*19,duration:0.7);move.timingMode = .easeOut;node.run(.sequence([.group([move,.fadeOut(withDuration:0.7)]),.removeFromParent()]))}
    }
    func renderFootprints(now:Double){
        footprints.removeAll{now-$0.born>8}
        guard let image=StoryDecorationsArt.footprint else{return}
        for footprint in footprints {
            let ground=manager.groundY(footprint.point.x,display:display,surfaces:surfaces)
            guard abs(footprint.point.y-ground)<5 else{continue}
            let p=display.local(footprint.point),alpha=0.23*(1-clamp((now-footprint.born)/8,0,1))*Double(root.alpha)
            display.canvas.composites.append(CanvasSprite(image:image,rect:CGRect(x:-5,y:-2,width:10,height:4),transform:CGAffineTransform(translationX:p.x,y:p.y),alpha:alpha))
        }
    }
    func tick(dt:Double,now:Double,config:Configuration,windows:[TrackedWindow],dock:DockGeometry?,surfaces:SurfaceManager){
        guard !finished else{return};currentWindows=windows;currentNow=now;elapsed+=dt;settings.sounds=config.stories.sounds;settings.keepDecorations=config.stories.keepDecorations
        if id == .snowmanBuild && !config.stories.allowSnowmanCreation {interrupt("Snowman creation disabled")}
        if interruption.isEmpty {
            let blocked=windows.filter(\.isVisible).contains{$0.frame.expanded(4).intersects(stage.area)} || (dock.map{$0.isVisible && $0.screenID==display.id && $0.frame.intersects(stage.area)} ?? false)
            if blocked || display.rect != stage.bounds || StoryStagePlanner.clipped(stage.area,to:display.rect) {interrupt("Scene is covered or display changed")}
            if id.needsTree && (!config.tree || state.tree == nil) {interrupt("Tree removed")}
            if id.needsTree,let tree=state.tree,abs(display.rect.x+tree.position.x-stage.focus.x)>3 {interrupt("Tree moved")}
            if id.needsSnowman,let snowman,abs(snowman.position.x-stage.focus.x)>3 {interrupt("Snowman moved")}
            if id.needsSnowman && snowman==nil {interrupt("Snowman removed")}
            if id == .garlandRemoval,let t=garlandTarget {
                let p=config.placements[t.display],exists=t.id=="active" ? (p?.garland.count ?? 0)>=2:(p?.extraGarlands?.contains{$0.id==t.id} ?? false)
                if !exists || !config.garland || t.target=="tree" && !config.tree || t.target=="window" && !windows.contains(where:{$0.id==t.owner && $0.isVisible}) {interrupt("Garland or parent removed")}
                if custom["released"]==nil {let live=t.id=="active" ? state.garlandPhysics.points:(state.extraGarlandPhysics[t.id]?.points ?? []);if let first=live.first,let saved=t.points.first,(first-saved).length>8 {interrupt("Garland moved during take-down")}}
            }
            if id == .lightRepair && (config.treeGarland=="none" || !config.garlandLights) {interrupt("Tree lights switched off")}
            if config.mode == .focus || config.reducedMotion {interrupt("Effects paused")}
            if elapsed>id.maximumDuration {fail("Scene movement timed out")}
        }
        if machine.phase == .interrupted || machine.phase == .failed || machine.phase == .finishing {
            finishElapsed+=dt;root.alpha=1-clamp(finishElapsed/0.6,0,1);renderFootprints(now:now)
            if finishElapsed>=0.6 {cleanup(success:interruption.isEmpty)};return
        }
        if machine.phase == .spawning {root.alpha=clamp(elapsed/0.5,0,1);if elapsed>=0.5 {_=machine.transition(.playing)}else{return}}
        guard timeline.current != nil else{_=machine.transition(.finishing);return}
        if entered != timeline.index {entered=timeline.index;for a in actors.values {a.poseTime=0};actions[entered].enter?(self)}
        var arrived=Set<String>()
        let names=actors.keys.sorted()
        for name in names {
            guard let a=actors[name] else{continue};a.poseTime+=dt
            if !a.climbing && a.pose != .climb {a.target.y=manager.groundY(a.target.x,display:display,surfaces:surfaces)}
            if let first=a.waypoints.first,(first-a.position).length<1 {a.waypoints.removeFirst()}
            let destination=a.waypoints.first ?? a.target,delta=destination-a.position,distance=delta.length
            if distance>0.7 {
                let speed=a.climbing ? 22.0:a.pose == .carry ? 63.0:82.0
                let amount=min(distance,min(speed,distance*4)*dt);a.position=a.position+delta*(amount/max(0.001,distance));if abs(delta.x)>1 {a.facing=delta.x<0 ? -1:1}
            } else {a.position=destination;if a.waypoints.isEmpty {arrived.insert(name)};if a.pose == .run {a.pose = .idle}}
        }
        let bodies=names.compactMap{name->StoryBody? in guard let a=actors[name],a.active else{return nil};return StoryBody(name,a.position,radius:a.radius)}
        let resolved=StoryCollisionAvoidance.resolve(bodies,bounds:stage.area)
        for (body,p) in zip(bodies,resolved){actors[body.id]?.position=p}
        for i in bodies.indices {for j in bodies.indices where j>i {minimumActorGap=min(minimumActorGap,(resolved[i]-resolved[j]).length-bodies[i].radius-bodies[j].radius)}}
        for a in actors.values {if !a.active {a.actor.node.isHidden=true;continue};a.actor.node.isHidden=false;if !a.climbing && a.pose != .climb {a.position.y=manager.groundY(a.position.x,display:display,surfaces:surfaces)}
            if let previous=a.previousPosePosition {a.walked+=(a.position-previous).length/(a.actor.storyRig?.scale ?? 1);a.actor.storyRig?.beginMotion(a.position.x-previous.x)}else{a.actor.storyRig?.beginMotion(0)};a.previousPosePosition=a.position
            a.actor.node.position=display.local(a.position);a.actor.pose(a.pose,time:a.poseTime,facing:a.facing,emotion:a.pose == .surprised ? "surprised":a.pose == .angry || a.pose == .brush ? "angry":a.pose == .fall || a.pose == .recover ? "tired":"happy");a.actor.node.alpha=min(1,a.actor.node.alpha+dt*2);if a.climbing {a.actor.model.childNode(withName:"gnome_foot_left")?.position.y=sin(a.poseTime*8)*2;a.actor.model.childNode(withName:"gnome_foot_right")?.position.y = -sin(a.poseTime*8)*2}}
        syncSharedCarry()
        if id == .lightRepair {state.tree?.childNode(withName:"tree-lights")?.alpha=custom["repairDim"] ?? 1}
        actions[entered].update?(self,timeline.elapsed)
        if id == .lightRepair,custom["steady"]==1 {let x=custom["ladderX"] ?? stage.focus.x;reach("elf1",to:Vec(x+stage.side*14,manager.groundY(x,display:display,surfaces:surfaces)-18),fraction:1)}
        if id == .santaDrop {santaFlight(max(0,elapsed-0.5));if elapsed>=7.5 {props["santa"]?.removeFromParent()}}
        updateTeamShots(dt:dt)
        if let shot=projectile,let node=projectileNode {projectileTime+=dt;node.position=display.local(shot.position(projectileTime));node.zRotation+=dt*3;if projectileTime>=shot.duration {puff(at:shot.target);contact("impact",prop:"snowball",actor:"");node.removeFromParent();projectile=nil;projectileNode=nil}}
        // Scripted climbing/rolling also passes through the same body separation.
        let finalNames=actors.keys.sorted().filter{actors[$0]?.active==true}
        let finalBodies=finalNames.map{StoryBody($0,actors[$0]!.position,radius:actors[$0]!.radius)},finalPoints=StoryCollisionAvoidance.resolve(finalBodies,bounds:stage.area)
        for (name,point) in zip(finalNames,finalPoints){var p=point;if let a=actors[name],!a.climbing,a.pose != .climb {p.y=manager.groundY(p.x,display:display,surfaces:surfaces)};actors[name]?.position=p;actors[name]?.actor.node.position=display.local(p);actors[name]?.actor.node.position.y += actors[name]?.actor.storyRig?.supportLift ?? 0}
        syncSharedCarry()
        for (name,a) in actors where a.active && a.actor.yeti && [.run,.walk,.sneak,.carry].contains(a.pose) && (a.target-a.position).length>1 {
            if let previous=lastFootprint[name],(previous-a.position).length<14 {continue}
            let p=Vec(a.position.x,manager.groundY(a.position.x,display:display,surfaces:surfaces)+1)
            footprints.append(StoryFootprint(point:p+Vec(0,footprints.count%2==0 ? 0:1.5),born:now));lastFootprint[name]=a.position
            if footprints.count>32 {footprints.removeFirst()}
        }
        renderFootprints(now:now)
        arrived=Set(actors.compactMap{name,a in a.waypoints.isEmpty && (a.position-a.target).length<3 ? name:nil})
        if timeline.step(dt,arrived:arrived) {actions[entered].leave?(self);if timeline.complete {_=machine.transition(.finishing)}}
    }
    func fail(_ reason:String){guard !finished else{return};interruption=reason;_=machine.transition(.failed)}
    func interrupt(_ reason:String,immediately:Bool=false){
        guard !finished else{return};if interruption.isEmpty {interruption=reason;_=machine.transition(.interrupted)}
        if immediately {cleanup(success:false)}
    }
    func cleanup(success:Bool){
        guard !finished else{return};succeeded=success;_=machine.transition(.cleanup)
        state.tree?.childNode(withName:"tree-topper")?.alpha=custom["oldTopAlpha"] ?? 1
        state.tree?.zRotation=originalTreeRotation;state.tree?.childNode(withName:"tree-lights")?.alpha=1
        if let saved=snowmanOriginal,saved.node.parent != nil {saved.node.zRotation=saved.rotation;saved.node.position=saved.position;if !success || !settings.keepDecorations {for child in installedPartyNodes {child.removeFromParent()};for child in replacedPartyStyles {if child.parent==nil {saved.node.addChild(child)}}}}
        for node in temporaryNodes {node.removeFromParent()};temporaryNodes=[];for (node,hidden) in extraPartyVisibility {node.isHidden=hidden};extraPartyVisibility=[]
        for (node,point,rotation,parts) in extraPartyRest {node.position=point;node.zRotation=rotation;for (part,angle) in parts {part.zRotation=angle}};extraPartyRest=[]
        for (node,rotation,alpha,hidden,position) in snowmanParts {node.zRotation=rotation;node.alpha=alpha;node.isHidden=hidden;node.position=position}
        if success,settings.keepDecorations,id == .snowmanParty {snowmanNode?.childNode(withName:"snowman_hat")?.alpha=0}
        state.snowmanLocation=nil
        for saved in borrowed {saved.node.removeFromParent();if success,settings.keepDecorations,custom["stolen"]==1 {continue};saved.parent.addChild(saved.node);saved.node.position=saved.position;saved.node.alpha=saved.alpha;saved.node.isHidden=false}
        if !success {state.treePresents=originalGifts}
        if !success,id.needsTree,state.tree==nil {for gift in state.treePresents{gift.node.removeFromParent()};state.treePresents=[]}

        if branchHeldMass>0 {manager.onSnowFall?(SnowFallEvent([SnowChunk(branchHeldOrigin,Vec(0,12),branchHeldMass,fallsToGround:true)]),display.id);branchHeldMass=0}
        if !success || id == .snowmanBuild && createdSnowman==nil {
            if let createdSnowman {_ = state.snowballs.remove(createdSnowman)}
            if takenMass>0 {manager.onSnowFall?(SnowFallEvent([SnowChunk(stage.focus,Vec(0,12),takenMass,fallsToGround:true)]),display.id);takenMass=0}
        }
        if success,settings.keepDecorations {commitGifts()}
        if !success {state.snowballs.balls.removeAll{ball in visualSnowballs.contains{$0.id==ball.id}}}
        for (key,node) in props where key.hasPrefix("repair-live-") {node.removeFromParent()}
        for shot in shots {shot.node.removeFromParent()};shots=[]
        projectileNode?.removeFromParent();root.removeAllActions();root.removeAllChildren();root.removeFromParent();actors=[:];props=[:];visualSnowballs=[];installedPartyNodes=[];replacedPartyStyles=[];footprints=[];lastFootprint=[:]
        _=machine.transition(.completed);finished=true
    }
    func commitGifts(){for (index,gift) in persistentGifts.enumerated() where state.treePresents.count<12 {
        let (variant,point)=gift,height=id == .giftConveyor && index==persistentGifts.count-1 ? 56.0:26.0
        let node=Resources.layer("story_present_"+variant,size:height);node.position=display.local(point);state.root.addChild(node)
        state.treePresents.append(TreePresent(node:node,position:point,placedAt:ProcessInfo.processInfo.systemUptime-1,variant:variant,artHeight:height))
    }}
    var snapshot:[String:Any] { ["id":id.rawValue,"title":id.title,"phase":machine.phase.rawValue,"step":timeline.current?.id ?? "done","variant":variant,"outcome":outcome,"display":display.id,"elapsed":elapsed,"succeeded":succeeded,"result":machine.transitions.contains(.failed) ? "failed":interruption.isEmpty ? "completed":"interrupted","interruption":interruption,"lifecycle":machine.transitions.map(\.rawValue),"contacts":contacts,"minimumActorGapPt":minimumActorGap.isFinite ? minimumActorGap:0,"peakActors":peakActors,"peakShots":peakShots,"shotImpacts":shotImpacts,"actorCount":actors.count,"propCount":props.count,"rollingHandErrorPt":custom["rollingHandErrorPt"] ?? 0] }
}
