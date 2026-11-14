import AppKit
import SpriteKit
import SnowCore
extension DecorationManager {
    @discardableResult func startDuel(display d:DisplayOverlay,area:Rect)->Bool {
        guard !livingBusy,let s=states[d.id] else{return false}
        let l=s.living,root=SKNode();root.name="snow-duel";root.zPosition=60;s.root.addChild(root);l.gameRoot=root;l.duel=DuelController(area:area)
        var snow=SnowSurface(id:"duel-"+d.id,screenID:d.id,frame:Rect(area.x,area.maxY-10,area.width,1),maxHeight:8);snow.seedArena(height:6);l.arena=snow
        let mesh=SKShapeNode();mesh.fillColor=NSColor(calibratedRed:0.9,green:0.96,blue:1,alpha:0.9);mesh.strokeColor = .clear;mesh.zPosition = -5;root.addChild(mesh);l.arenaNode=mesh
        l.player=LivingActor(yeti:false);l.enemy=LivingActor(yeti:true)
        root.addChild(l.player!.node);root.addChild(l.enemy!.node)
        for _ in 0..<2 {let label=SKLabelNode(fontNamed:"HelveticaNeue-Medium");label.fontSize=10;label.fontColor=NSColor(calibratedRed:0.85,green:0.33,blue:0.43,alpha:1);root.addChild(label);l.hpLabels.append(label)}
        let title=SKLabelNode(fontNamed:"HelveticaNeue-Bold");title.fontSize=30;title.fontColor=NSColor(calibratedRed:1,green:0.91,blue:0.7,alpha:1);title.position=d.local(Vec(area.center.x,area.y+58));root.addChild(title);l.title=title
        let arrow=SKShapeNode();arrow.strokeColor=NSColor(calibratedRed:1,green:0.85,blue:0.45,alpha:1);arrow.lineWidth=2;root.addChild(arrow);l.arrow=arrow
        return true
    }
    func aimDuel(at point:Vec){for s in states.values {s.living.duel?.aim(at:point)}}
    func aimDuel(_ power:Double){for s in states.values {s.living.duel?.aim(power)}}
    @discardableResult func fireDuel()->Bool {for s in states.values where s.living.duel != nil {return s.living.duel!.fire()};return false}
    func exitDuel(){for s in states.values where s.living.duel != nil {s.living.clear()};onDuelEnded?()}
    private func setActor(_ actor:LivingActor?,at point:Vec,pose:LivingPose,time:Double,facing:Double,display d:DisplayOverlay,emotion:String="happy") {
        actor?.node.position=d.local(point);actor?.pose(pose,time:time,facing:facing,emotion:emotion)
    }
    func updateDuel(state s:DecorationState,display d:DisplayOverlay,dt:Double,now:Double,surfaces:SurfaceManager) {
        let l=s.living
        guard var game=l.duel,let root=l.gameRoot else{return}
        let area=game.area
        let events=game.step(dt,snowHeight:{x in (l.arena?.height(at:(x-area.x)/area.width) ?? 6)-6});l.duel=game
        for event in events {
            switch event {
            case .hit(let owner):onDust?(owner == 0 ? game.playerFeet+Vec(0,-28):game.yetiFeet+Vec(0,-28),d.id)
            case .ground(let point):_ = l.arena?.displace(at:(point.x-game.area.x)/game.area.width,radius:12,distance:18,speed:150);onDust?(point,d.id)
            default:break
            }
        }
        if !game.active {l.clear();onDuelEnded?();return}
        if let arena=l.arena,arena.revision != l.arenaRevision {
            let path=CGMutablePath();for part in SnowCapGeometry.paths(surface:arena,blocked:[],local:d.local){path.addPath(part)};l.arenaNode?.path=path;l.arenaRevision=arena.revision
        }
        let intro=clamp(game.elapsed/1.1,0,1),ease=intro*intro*(3-2*intro)
        let player=Vec(game.area.x-38+(game.playerFeet.x-game.area.x+38)*ease,game.playerFeet.y)
        let enemy=Vec(game.area.maxX+38+(game.yetiFeet.x-game.area.maxX-38)*ease,game.yetiFeet.y)
        let ended=game.ended
        if !ended {
            let playerPose:LivingPose=game.phase == .introduction ? .run:game.phase == .playerAim ? .aim:game.phase == .playerFlight ? .throwBall:game.hitOwner==0 && game.elapsed-game.hitAt<0.5 ? .hit:.idle
            let yetiPose:LivingPose=game.phase == .introduction ? .run:game.phase == .yetiPrepare ? .makeSnowball:game.phase == .yetiFlight ? .throwBall:game.hitOwner==1 && game.elapsed-game.hitAt<0.5 ? .hit:.idle
            setActor(l.player,at:player,pose:playerPose,time:game.phaseTime,facing:1,display:d)
            let mood=game.hitOwner==1 && game.elapsed-game.hitAt<0.8 ? "angry":game.yetiHP<=2 ? "tired":game.phase == .reaction ? "surprised":"happy"
            setActor(l.enemy,at:enemy,pose:yetiPose,time:game.phaseTime,facing:-1,display:d,emotion:mood)
        }
        for (i,hp) in [game.playerHP,game.yetiHP].enumerated() {
            let text=String(repeating:"● ",count:hp)+String(repeating:"○ ",count:5-hp)
            if l.hpLabels[i].text != text {l.hpLabels[i].text=text}
            l.hpLabels[i].position=d.local((i==0 ? player:enemy)+Vec(0,-57));l.hpLabels[i].isHidden=ended
        }
        if let shot=game.ball {
            if l.duelBall==nil {l.duelBall=Resources.layer("snowball_small",size:11);root.addChild(l.duelBall!)}
            l.duelBall?.position=d.local(shot.position);l.duelBall?.zRotation=shot.time*3
        }else{l.duelBall?.removeFromParent();l.duelBall=nil}
        l.arrow?.isHidden=game.phase != .playerAim
        if game.phase == .playerAim {
            let a=game.hand(0),direction=game.aimedVelocity/max(1,game.speed(for:game.power)),length=28+game.power*80,b=a+direction*length,path=CGMutablePath()
            let side=Vec(-direction.y,direction.x)
            path.move(to:d.local(a));path.addLine(to:d.local(b));path.move(to:d.local(b-direction*9+side*5));path.addLine(to:d.local(b));path.addLine(to:d.local(b-direction*9-side*5))
            let preview=BallisticSnowball(origin:a,velocity:game.aimedVelocity,gravity:game.gravity)
            for i in 1...16 {let p=preview.position(at:Double(i)*0.085);if p.y>area.maxY-16 || p.x>area.maxX {break};let local=d.local(p);path.addEllipse(in:CGRect(x:local.x-1.2,y:local.y-1.2,width:2.4,height:2.4))}
            l.arrow?.path=path
        }
        if game.phase == .introduction {l.title?.text="DUEL!";l.title?.alpha=1-clamp((game.phaseTime-0.8)/0.4,0,1)}
        else if !ended {l.title?.text=game.phase == .playerAim ? String(format:"Your turn · %.1fs",game.secondsLeft):"Yeti’s turn";l.title?.fontSize=12;l.title?.alpha=0.9}
        else {l.title?.fontSize=25;l.title?.alpha=1;l.title?.text=game.phase == .victory ? "YOU WIN!":"YOU LOSE!";updateRescue(state:s,display:d,game:game)}
        l.lastDuelPhase=game.phase
    }
    private func updateRescue(state s:DecorationState,display d:DisplayOverlay,game:DuelController) {
        let l=s.living,t=game.phaseTime,win=game.phase == .victory
        let fallSide=win ? 1.0:-1.0
        guard let root=l.gameRoot,let fallen=win ? l.enemy:l.player else{return}
        let feet=win ? game.yetiFeet:game.playerFeet
        fallen.held.isHidden=true
        if l.helpers.isEmpty {
            l.helpers=[LivingActor(yeti:false,color:"green"),LivingActor(yeti:false,color:"blue")]
            for helper in l.helpers {root.addChild(helper.node)}
        }
        if !win,l.duelVehicle==nil {let vehicle=LivingVehicle();vehicle.node.xScale = -1;l.duelVehicle=vehicle;root.addChild(vehicle.node);vehicle.node.zPosition = -1}
        let approachEnd=win ? 1.7:2.8,liftEnd=approachEnd+0.6,carryStart=liftEnd+0.3
        if t<approachEnd {
            fallen.node.position=d.local(feet);fallen.node.zRotation = -fallSide*min(1,t/0.55)*Double.pi/2
            for (i,helper) in l.helpers.enumerated() {
                let target=feet+Vec(fallSide*18+Double(i==0 ? -31:31),0)
                let begin=win ? Vec(d.rect.maxX+50+Double(i)*52,feet.y):Vec(game.area.x-30+Double(i)*52,feet.y)
                let f=clamp((t-(win ? 0.5:1.5))/(win ? 1.2:1.3),0,1),ease=f*f*(3-2*f)
                helper.node.isHidden = !win && t<1.5
                setActor(helper,at:begin+(target-begin)*ease,pose:.run,time:t,facing:target.x>=begin.x ? 1:-1,display:d)
            }
        } else {
            if l.rescueRoot==nil {
                let group=SKNode();root.addChild(group);l.rescueRoot=group
                fallen.node.removeFromParent();group.addChild(fallen.node);fallen.node.position=CGPoint(x:-fallSide*18,y:0);fallen.node.zRotation = -fallSide*Double.pi/2
                for helper in l.helpers {helper.node.removeFromParent();group.addChild(helper.node)}
            }
            let lift=clamp((t-approachEnd)/0.6,0,1)
            var centre=feet+Vec(fallSide*18,-lift*24)
            if win {
                centre=RescueRig.victory(elapsed:t,feet:feet,exitX:d.rect.maxX+120).body
            }else if t>carryStart {
                let cargo=l.duelVehicle!.node.convert(l.duelVehicle!.cargo,to:root)
                let target=Vec(d.rect.x+cargo.x,d.rect.maxY-cargo.y),f=clamp((t-carryStart)/1.1,0,1),ease=f*f*(3-2*f)
                centre=centre+(target-centre)*ease
            }
            l.rescueRoot?.position=d.local(centre)
            for (i,helper) in l.helpers.enumerated() {
                helper.node.isHidden=false;helper.node.position=CGPoint(x:i==0 ? -31:31,y:-24*lift)
                helper.pose(t<liftEnd ? .lift:.carry,time:t,facing:i==0 ? 1:-1);helper.palm.position.y=24*lift;helper.rigHand()
            }
            if !win,t>=4.8,let vehicle=l.duelVehicle,l.carried==nil {
                let position=fallen.node.convert(.zero,to:vehicle.node);fallen.node.removeFromParent();vehicle.node.addChild(fallen.node);fallen.node.position=position;l.carried=fallen.node
            }
            if !win,t>4.8 {
                for (i,helper) in l.helpers.enumerated() {
                    let f=clamp((t-4.8-Double(1-i)*0.38)/0.35,0,1)
                    helper.node.position=CGPoint(x:Double(i==0 ? -31:31)*(1-f)+Double(i==0 ? 42:68)*f,y:-24*lift+15*f)
                    helper.node.isHidden=f>=0.85;helper.pose(.run,time:t,facing:1)
                }
            }
        }
        if !win,let vehicle=l.duelVehicle {
            let start=Vec(d.rect.x-170,feet.y),stop=Vec(game.playerFeet.x-64,feet.y),f=clamp(t/1.4,0,1),ease=f*f*(3-2*f)
            var p=start+(stop-start)*ease,phase=VehiclePhase.brake
            if t>=5.5 {let q=clamp((t-5.5)/1.4,0,1);p=stop+(start-stop)*q*q*(3-2*q);phase = .exit}
            vehicle.apply(VehiclePose(position:p,distance:p.x-start.x,phase:phase),local:d.local)
        }
    }
}
