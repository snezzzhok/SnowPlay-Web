import AppKit
import SpriteKit
import SnowCore
extension DecorationManager {
    var livingBusy:Bool {stories.active != nil || states.values.contains{$0.living.busy || $0.character != nil || $0.directTreeElapsed != nil || $0.directShotElapsed != nil}}
    var visibleStoryActive:Bool {stories.active != nil || states.values.contains{s in
        s.character != nil || s.directTreeElapsed != nil || s.directShotElapsed != nil || s.living.delivery != nil || s.living.activity != nil || s.living.automaticTarget != nil || (s.living.duel != nil && !s.living.duelObscured)
    }}
    var duelActive:Bool {states.values.contains{$0.living.duel != nil}}
    @discardableResult func deliverTree(display d:DisplayOverlay,feet:Vec,config:Configuration)->Bool {
        guard !livingBusy,let s=states[d.id] else{return false}
        let l=s.living,entry=Vec(feet.x<d.rect.center.x ? d.rect.x-170:d.rect.maxX+170,feet.y)
        l.delivery=TreeSceneController(entry:entry,target:feet,exit:Vec(entry.x<feet.x ? d.rect.maxX+170:d.rect.x-170,feet.y),treeHeight:treeHeight(config));l.vehicle=LivingVehicle();l.gnome=LivingActor(yeti:false,color:"green")
        let payload=Resources.object(["tree_stem","tree_bare"],size:treeHeight(config));let pivot=SKNode();payload.position.y=treeHeight(config)*0.38;pivot.addChild(payload);l.treePayload=pivot
        s.root.addChild(l.vehicle!.node);s.root.addChild(l.gnome!.node);s.root.addChild(pivot)
        s.tree?.removeFromParent();s.tree=nil;s.builtTree=false;return true
    }
    @discardableResult func automaticSnowman(display d:DisplayOverlay,at p:Vec)->Bool {
        guard !livingBusy,snowmanCount<5,let s=states[d.id],s.snowballs.snowman == nil else{return false}
        s.living.automaticTarget=p;s.living.automaticElapsed=0;return true
    }
    func updateLivingStories(state s:DecorationState,display d:DisplayOverlay,dt:Double,now:Double,config:Configuration,surfaces:SurfaceManager,mouse:Vec,windows:[TrackedWindow]) {
        let l=s.living
        if var delivery=l.delivery {
            let install=delivery.step(dt);l.delivery=delivery
            var vehicle=delivery.vehicle
            let shift=groundY(clamp(vehicle.position.x,d.rect.x,d.rect.maxX),display:d,surfaces:surfaces)-vehicle.position.y
            vehicle.position.y+=shift;l.vehicle?.node.xScale = -delivery.heading;vehicle.tilt*=delivery.heading;l.vehicle?.apply(vehicle,local:d.local)
            let fraction=clamp((delivery.elapsed-1.8)/1.1,0,1),blend=fraction*fraction*(3-2*fraction)
            let targetY=groundY(delivery.target.x,display:d,surfaces:surfaces)
            let base=delivery.treeBase+Vec(0,shift*(1-blend)+(targetY-delivery.target.y)*blend)
            let grip=base+delivery.gripDisplacement
            var gnome=delivery.gnome
            if delivery.elapsed>=1.8 && delivery.elapsed<3.1 {gnome.x=grip.x-delivery.heading*16}
            gnome.y=groundY(clamp(gnome.x,d.rect.x,d.rect.maxX),display:d,surfaces:surfaces)
            l.gnome?.node.position=d.local(gnome);l.gnome?.node.isHidden=delivery.elapsed<1.25;let clearance=abs(gnome.x-vehicle.position.x);l.gnome?.node.alpha=delivery.elapsed<1.8 ? clamp((clearance-62)/20,0,1):1
            let working=delivery.elapsed>1.8 && delivery.elapsed<3.1
            l.gnome?.pose(working ? .unload:.run,time:delivery.elapsed,facing:working ? delivery.heading:-delivery.heading)
            if working {l.gnome?.palm.position.x=16;l.gnome?.palm.position.y=gnome.y-grip.y;l.gnome?.rigHand()}
            l.treePayload?.position=d.local(base);l.treePayload?.zRotation=delivery.treeAngle
            if install,let pivot=l.treePayload,let tree=pivot.children.first {
                tree.removeFromParent();s.root.addChild(tree);tree.position=d.local(Vec(delivery.target.x,targetY-treeHeight(config)*0.38));tree.zRotation=0
                s.tree=tree;s.builtTree=true;s.treeAppearedAt=now-0.8;s.treeStyleKey=[config.treeSize,config.treeStar,config.treeBalls,config.treeGarland].joined(separator:"|");l.treePayload?.removeFromParent();l.treePayload=nil
                if config.treeBalls != "none" {tree.addChild(Resources.layer("tree_balls_"+config.treeBalls,size:treeHeight(config)))}
                if config.treeGarland != "none" {let n=Resources.layer("tree_string_"+config.treeGarland,size:treeHeight(config));n.name="tree-lights";tree.addChild(n)}
                if config.treeStar != "none" {let n=Resources.layer("tree_topper_"+config.treeStar,size:treeHeight(config));n.name="tree-topper";tree.addChild(n)}
            }
            if delivery.complete {l.removeStoryNodes()}
        }
        if let target=l.automaticTarget {
            let radii=[10.5,8.0,6.0],needed=radii.reduce(0){$0+Double.pi*$1*$1}
            if l.automaticMass==0 {
                let key="ground-"+d.id
                if (surfaces.surfaces[key]?.volume ?? 0)>=needed {
                    l.automaticMass=surfaces.surfaces[key]?.extract(volume:needed,at:(target.x-d.rect.x)/d.rect.width) ?? 0
                    s.snowballs.balls=[]
                }
            } else {
                l.automaticElapsed+=dt
                for i in 0..<3 where l.automaticElapsed>=Double(i)*0.45 && s.snowballs.balls.count<=i {s.snowballs.balls.append(Snowball(position:target+Vec(Double(i-1)*34,-4),radius:4))}
                // Existing ball nodes provide independent roll/lift/stack animations.
                for i in s.snowballs.balls.indices {let f=clamp((l.automaticElapsed-Double(i)*0.45)/0.8,0,1);s.snowballs.balls[i].position.x=target.x+Double(i-1)*34*(1-f);s.snowballs.balls[i].radius=4+(radii[i]-4)*f;s.snowballs.balls[i].rotation+=dt*2}
                if l.automaticElapsed>=2.25 {
                    let centre=Vec(target.x,groundY(target.x,display:d,surfaces:surfaces)-25)
                    if s.snowballs.assemblePrepared(at:centre){s.snowmanFloating=true;s.snowmanBuiltAt=now;onSnowmanBuilt?(d.id)}
                    l.automaticTarget=nil;l.automaticMass=0
                }
            }
        }
        updateYetiActivity(state:s,display:d,dt:dt,now:now,config:config,surfaces:surfaces,mouse:mouse)
        if let game=l.duel {
            l.duelObscured=windows.contains{$0.isVisible && $0.frame.intersects(game.area)}
            if l.duelObscured {l.title?.text="Paused · clear the play area"}else{updateDuel(state:s,display:d,dt:dt,now:now,surfaces:surfaces)}
        }
    }
    func startParachuteGift(display d:DisplayOverlay,surfaces:SurfaceManager)->Bool {
        guard let s=states[d.id],s.deliveryElapsed == nil,s.gift == nil,s.giftOpenedAt == nil else{return false}
        // Use the actual snow surface, leaving clearance around placed models.
        let occupied=s.snowballs.snowmen.map{ $0.hitbox.expanded(24) }+s.treePresents.map{Rect($0.position.x-32,$0.position.y-35,64,70)}
        let treeX=s.tree.map{d.rect.x+$0.position.x}
        let margin=min(100,d.rect.width/4) // Room for all three bursts at either edge.
        var candidates:[Double]=[]
        for i in 0..<24 {
            let x=d.rect.x+margin+(d.rect.width-2*margin)*Double(i)/23
            let point=Vec(x,groundY(x,display:d,surfaces:surfaces)-15)
            if occupied.contains(where:{$0.contains(point)}) {continue}
            if let treeX,abs(x-treeX)<s.treeHeight*0.45+25 {continue}
            candidates.append(x)
        }
        let separated=candidates.filter{x in !s.recentGiftPositions.suffix(2).contains{abs(x-$0.x)<80}}
        guard let x=(separated.isEmpty ? candidates:separated).randomElement() else{return false}
        s.recentGiftPositions.append(Vec(x,d.rect.maxY));s.recentGiftPositions=Array(s.recentGiftPositions.suffix(3))
        let anchor=AssetManager.shared.registry["gift_box"]?.anchor.y ?? 0.84
        let landing=Double(ArtScale.gift)*(0.17515625+0.53*(anchor-0.5))
        s.deliveryElapsed=0;s.dropTime=0;s.dropPoint=Vec(x,d.rect.y+60);s.target=Vec(x,groundY(x,display:d,surfaces:surfaces)-landing)
        s.giftDropped=false;s.giftLanded=false;s.giftOpenedAt=nil;s.passiveGift=true;return true
    }
}
