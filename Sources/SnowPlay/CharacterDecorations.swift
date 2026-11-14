import AppKit
import SpriteKit
import SnowCore
struct SnowmanFragment {var p:Vec;var v:Vec;var radius:Double;var mass:Double;var rotation=0.0}
extension DecorationManager {
    @discardableResult func requestCharacter(_ action:CharacterAction,display d:DisplayOverlay,target:Vec,windows:[TrackedWindow],surfaces:SurfaceManager,config:Configuration)->Bool {
        guard let state=states[d.id],config.mode != .focus,!config.reducedMotion else{return false}
        if action == .chopTree && state.tree == nil {return false}
        if action == .throwSnowball && state.snowballs.snowman == nil {return false}
        if action == .helpBuild && state.sculptArea == nil {return false}
        if action == .carryObject && (state.gift == nil || !state.giftLanded || state.giftOpenedAt != nil) {return false}
        if states.values.contains(where:{$0.character != nil}) {
            if states.values.contains(where:{$0.character?.action==action && $0.character?.target==target}) || characterQueue.contains(where:{$0.action==action && $0.display==d.id && $0.target==target}) {return true}
            guard characterQueue.count<8 else{return false}
            characterQueue.append(CharacterRequest(action:action,display:d.id,target:target));if action == .chopTree {state.treeRemoving=true};return true
        }
        let floorAction=[CharacterAction.playWithSnow,.buildCastle,.chopTree,.throwSnowball].contains(action)
        let offset=action == .chopTree ? 25.0:action == .throwSnowball ? (target.x-d.rect.x<100 ? 82:-82):-24
        let feet=floorAction ? Vec(clamp(target.x+offset,d.rect.x+20,d.rect.maxX-20),groundY(target.x,display:d,surfaces:surfaces)):target+Vec(-65,25)
        let entry=Vec(feet.x>d.rect.center.x ? d.rect.maxX+28:d.rect.x-28,feet.y)
        var route:[Vec]=[]
        if floorAction {
            let n=max(2,Int(abs(entry.x-feet.x)/24))
            route=(0...n).map {i in let x=entry.x+(feet.x-entry.x)*Double(i)/Double(n);return Vec(x,groundY(clamp(x,d.rect.x,d.rect.maxX),display:d,surfaces:surfaces))}
        } else {route=[entry,feet]}
        if action == .throwSnowball || action == .playWithSnow || action == .buildCastle {
            let need=action == .buildCastle ? Double.pi*2*5.5*5.5:Double.pi*16
            guard let stock=surfaces.surfaces["ground-"+d.id],stock.volume>=need else{return false}
            state.heldSnow=surfaces.surfaces[stock.id]?.extract(volume:need,at:(target.x-d.rect.x)/d.rect.width) ?? 0
            state.throwDirection=Bool.random() ? 1:-1
        }
        let controller=CharacterController(action:action,target:target,path:route,speed:165)
        if let director=animationDirector {
            guard let id=director.start(.character,duration:controller.duration+0.5,priority:1) else {if state.heldSnow>0 {onSnowFall?(SnowFallEvent([SnowChunk(target,Vec(),state.heldSnow)]),d.id);state.heldSnow=0};return false};state.characterEffect=id
        }
        state.character=controller
        state.treeRemoving=action == .chopTree;state.treeFalling=false
        state.actor=makeYeti();state.root.addChild(state.actor!)
        state.actor?.isHidden=true;return true
    }
    func makeYeti()->SKNode {
        let root=SKNode();root.name="yeti";root.zPosition=30
        for id in ["yeti_foot_left","yeti_foot_right","yeti_body","yeti_head","yeti_arm_left","yeti_arm_right"] {
            let part=Resources.layer(id,size:40)
            if id.hasPrefix("yeti_arm") {AssetManager.shared.pivot(part,at:CGPoint(x:id.hasSuffix("right") ? 94.0/128:34.0/128,y:1-68.0/128))}
            root.addChild(part)
        }
        let axe=Resources.layer("yeti_axe",size:40);AssetManager.shared.pivot(axe,at:CGPoint(x:0.5,y:1-94.0/128));axe.position=CGPoint(x:3.5,y:-8);axe.name="held-axe";axe.xScale = -1;axe.isHidden=true
        root.childNode(withName:"yeti_arm_right")?.addChild(axe)
        let ball=Resources.layer("snowball_small",size:15);ball.name="held-snow";ball.position=CGPoint(x:3.5,y:-8);ball.isHidden=true;root.childNode(withName:"yeti_arm_right")?.addChild(ball)
        return root
    }
    func finishCharacter(_ s:DecorationState,surfaces:SurfaceManager?=nil,display:DisplayOverlay?=nil,completeRemoval:Bool=true) {
        let id=display?.id ?? states.first(where:{$0.value === s})?.key
        if s.treeRemoving {
            if completeRemoval,!s.treeFalling,s.tree != nil,let id {onTreeRemovalCancelled?(id)}
            else{s.root.childNode(withName:"tree-fall")?.removeFromParent();s.tree?.removeFromParent();s.tree=nil;s.builtTree=false;for gift in s.treePresents {gift.node.removeFromParent()};s.treePresents=[]}
        }
        if completeRemoval,s.castleBuildStarted != nil,let id,let base=s.castleBase {onSnowFall?(SnowFallEvent([SnowChunk(base,Vec(0,15),s.castleMass,fallsToGround:true)]),id);s.castleBase=nil;s.castleMass=0;s.castleBuildStarted=nil}
        if s.heldSnow>0,let id {onSnowFall?(SnowFallEvent([SnowChunk(s.character?.position ?? Vec(),Vec(0,5),s.heldSnow)]),id)}
        if let effect=s.characterEffect {animationDirector?.stop(effect)};s.characterEffect=nil;s.carryingGift=false
        s.heldSnow=0;s.treeRemoving=false;s.treeFalling=false;s.character=nil;s.actor?.removeFromParent();s.actor=nil;s.projectile?.removeFromParent();s.projectile=nil
    }
    func updateCharacter(state s:DecorationState,display d:DisplayOverlay,dt:Double,now:Double,config:Configuration,windows:[TrackedWindow],surfaces:SurfaceManager) {
        let blocked=windows.filter(\.isVisible).map(\.frame)
        if var c=s.character {
            if config.reducedMotion || config.mode == .focus || (c.action == .helpBuild && s.sculptArea == nil) || (c.action == .carryObject && s.gift == nil) || (c.action == .chopTree && s.tree == nil && !s.treeFalling) || (c.action == .throwSnowball && s.snowballs.snowman == nil && s.fragments.isEmpty && c.localTime<1.85) {finishCharacter(s,surfaces:surfaces,display:d);return}
            let events=c.step(dt);s.character=c
            let moving=c.phase == .walking || c.phase == .entering || c.phase == .leaving
            let feet=Vec(c.position.x,[CharacterAction.playWithSnow,.buildCastle,.chopTree,.throwSnowball].contains(c.action) ? groundY(clamp(c.position.x,d.rect.x,d.rect.maxX),display:d,surfaces:surfaces):c.position.y)
            let hop=c.phase == .reacting ? sin(clamp((c.elapsed-c.actionEnd)/0.35,0,1)*Double.pi)*5:0
            let gathering=c.action == .throwSnowball && c.localTime>=(-0.35) && c.localTime<0 ? sin((c.localTime+0.35)/0.35*Double.pi):0
            let p=feet+Vec(0,-18-(moving ? abs(sin(c.elapsed*9))*0.8:0)-hop+gathering*4)
            s.actor?.position=d.local(p)
            let look=moving ? (c.phase == .leaving ? c.path.first?.x:c.path.last?.x) ?? c.target.x:c.target.x
            s.actor?.xScale=look<c.position.x ? -1:1
            let foreground=true
            let hidden = !foreground && blocked.contains{$0.intersects(Rect(p.x-20,p.y-20,40,40))}
            if hidden {finishCharacter(s,surfaces:surfaces,display:d);return}
            s.actor?.isHidden=false
            let right=s.actor?.childNode(withName:"yeti_arm_right"),left=s.actor?.childNode(withName:"yeti_arm_left")
            let swing=c.localTime>=0 && c.action == .chopTree ? (sin(c.localTime*Double.pi*2.66)*0.75+0.45):c.localTime>=0 ? -0.8:sin(c.elapsed*9)*0.15
            right?.zRotation=swing
            if c.action == .throwSnowball {
                if gathering>0 {right?.zRotation=0}
                else if c.localTime>=0 && c.localTime<0.55 {right?.zRotation=1+sin(c.localTime/0.55*Double.pi)*0.5}
                right?.childNode(withName:"held-snow")?.setScale(0.2+0.8*clamp((c.localTime+0.25)/0.25,0,1))
            }
            if c.action == .chopTree,c.localTime>=0,let actor=s.actor,let arm=right {
                let point=actor.convert(d.local(c.target+Vec(0,s.treeHeight*0.38-6)),from:s.root)
                let pose=CharacterArmRig.pose(goal:Vec(point.x-arm.position.x,point.y-arm.position.y),hand:Vec(3.5,-8),tip:Vec(4.6875,8.125))
                let wave=(1-cos((c.localTime-0.55)*Double.pi*2.66))/2
                arm.zRotation=pose.arm+(1.1-pose.arm)*wave
                arm.childNode(withName:"held-axe")?.zRotation=pose.tool
            }
            left?.zRotation=moving ? -sin(c.elapsed*9)*0.15:0
            s.actor?.childNode(withName:"yeti_foot_left")?.position.y=moving ? max(0,sin(c.elapsed*9))*1.5:0
            s.actor?.childNode(withName:"yeti_foot_right")?.position.y=moving ? max(0,-sin(c.elapsed*9))*1.5:0
            right?.childNode(withName:"held-axe")?.isHidden=c.action != .chopTree || c.localTime < -0.2
            right?.childNode(withName:"held-snow")?.isHidden = ![CharacterAction.throwSnowball,.playWithSnow].contains(c.action) || c.localTime < -0.25 || c.localTime >= (c.action == .playWithSnow ? 0.4:0.55)
            if c.action == .buildCastle,c.localTime>=0 {right?.zRotation = -0.7+sin(c.localTime*12)*0.45;left?.zRotation=0.2-sin(c.localTime*12)*0.3}
            if c.action == .playWithSnow,c.localTime>=0 {right?.zRotation = -0.9+sin(min(1,c.localTime/0.45)*Double.pi)*1.8}
            func hand()->Vec {guard let arm=right else{return p};let q=arm.convert(CGPoint(x:3.5,y:-8),to:s.root);return Vec(d.rect.x+q.x,d.rect.maxY-q.y)}
            for event in events {
                switch event {
                case .strike(let i):
                    s.toyImpulse=now
                    if i==2,let tree=s.tree {
                        let pivot=SKNode();pivot.name="tree-fall";pivot.position=d.local(c.target+Vec(0,s.treeHeight*0.38));s.root.addChild(pivot)
                        tree.removeFromParent();tree.position=CGPoint(x:0,y:s.treeHeight*0.38);pivot.addChild(tree);s.treeFalling=true
                        if let snow=surfaces.surfaces.removeValue(forKey:"tree-"+d.id),snow.volume>0 {onSnowFall?(SnowFallEvent([SnowChunk(c.target,Vec(-20,-15),snow.volume)]),d.id)}
                    }
                case .release:
                    let n=Resources.layer("snowball_small",size:15);n.name="projectile";s.root.addChild(n);s.projectile=n;s.projectilePath=Projectile(from:hand(),to:c.target+Vec(0,-7),duration:1.3,gravity:160)
                case .impact:
                    if let model=s.snowballs.snowmen.min(by:{($0.position-c.target).length<($1.position-c.target).length}), (model.position-c.target).length<32 {_=destroySnowman(model.id,state:s,display:d)}
                    if s.heldSnow>0 {onSnowFall?(SnowFallEvent([SnowChunk(c.target,Vec(8,20),s.heldSnow)]),d.id);s.heldSnow=0}
                    s.projectile?.removeFromParent();s.projectile=nil
                case .help: onHelpBuild?(d.id)
                case .carry: s.carryingGift=true
                case .drop: s.carryingGift=false
                case .play:
                    onSnowFall?(SnowFallEvent([SnowChunk(hand(),Vec(s.throwDirection*135,-190),s.heldSnow)]),d.id);s.heldSnow=0
                case .build:
                    if s.castleMass>0,let old=s.castleBase {onSnowFall?(SnowFallEvent([SnowChunk(old,Vec(0,15),s.castleMass,fallsToGround:true)]),d.id)}
                    s.castleBase=Vec(clamp(c.target.x-1,d.rect.x+22,d.rect.maxX-22),groundY(c.target.x-1,display:d,surfaces:surfaces));s.castleMass=s.heldSnow;s.heldSnow=0;s.castleProgress=0;s.castleBuildStarted=now
                case .finished: finishCharacter(s,surfaces:surfaces,display:d,completeRemoval:false)
                }
            }
            if c.action == .throwSnowball,c.localTime>=0.55,c.localTime<1.85 {if let path=s.projectilePath{s.projectile?.isHidden=false;s.projectile?.position=d.local(path.position(c.localTime-0.55))}}
            if c.action == .chopTree,s.treeFalling,let pivot=s.root.childNode(withName:"tree-fall") {let f=clamp((c.localTime-2.05)/0.9,0,1);pivot.zRotation=pow(f,2)*1.65;pivot.alpha=1-clamp((f-0.7)/0.3,0,1);for gift in s.treePresents {gift.node.alpha=1-f};if f>=1 {onDust?(Vec(d.rect.x+pivot.position.x,d.rect.maxY-pivot.position.y),d.id);pivot.removeFromParent();s.tree=nil;s.builtTree=false;for gift in s.treePresents {gift.node.removeFromParent()};s.treePresents=[]}}
            if s.carryingGift,s.gift != nil {let q=hand();s.giftPosition=q;s.target=q;s.gift?.position=d.local(q)}
            if c.action == .throwSnowball,let model=s.snowmanNode {appendSprites(from:model,reference:s.root,to:d.actionCanvas)}
            if c.action == .chopTree {
                if let tree=s.root.childNode(withName:"tree-fall") ?? s.tree {tree.isHidden=false;s.tree?.isHidden=false;appendSprites(from:tree,reference:s.root,to:d.actionCanvas);tree.isHidden=true}
            }
            if foreground,let actor=s.actor {appendSprites(from:actor,reference:s.root,to:d.actionCanvas);actor.isHidden=true;if let projectile=s.projectile {appendSprites(from:projectile,reference:s.root,to:d.actionCanvas);projectile.isHidden=true}}
        }
        var kept:[SnowmanFragment]=[]
        for var f in s.fragments {
            let old=f.p;f.v.y+=240*dt;f.p=f.p+f.v*dt;f.rotation+=f.v.x*dt/18
            if let (key,fraction)=surfaces.collision(from:old+Vec(0,f.radius),to:f.p+Vec(0,f.radius),occluders:blocked,groundOnly:true) {
                let accepted=surfaces.surfaces[key]?.deposit(at:fraction,volume:f.mass) ?? 0
                onDust?(f.p+Vec(0,f.radius),d.id)
                f.mass-=accepted
                if f.mass>0.001 {onSnowFall?(SnowFallEvent([SnowChunk(f.p,Vec(5,15),f.mass,fallsToGround:true)]),d.id)}
            } else if f.p.y>d.rect.maxY {onSnowFall?(SnowFallEvent([SnowChunk(Vec(clamp(f.p.x,d.rect.x,d.rect.maxX),d.rect.maxY-20),Vec(),f.mass)]),d.id)}
            else {
                kept.append(f)
                if let image=AssetManager.shared.image("snowball_medium") {let p=d.local(f.p),size=f.radius*2/0.84,t=CGAffineTransform(translationX:p.x,y:p.y).rotated(by:f.rotation);d.actionCanvas.composites.append(CanvasSprite(image:image,rect:CGRect(x:-size/2,y:-size/2,width:size,height:size),transform:t,alpha:1))}
            }
        };s.fragments=kept
    }
}
