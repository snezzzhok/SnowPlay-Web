import AppKit
import SpriteKit
import SnowCore

final class LivingActor {
    let node=SKNode(),model:SKNode
    let palm:SKSpriteNode,held:SKSpriteNode
    let yeti:Bool
    var storyRig:StoryActorRig?
    var compactHands=false
    var offhand:SKSpriteNode?
    var face:SKSpriteNode?
    var faceID=""
    init(yeti:Bool,color:String="red") {
        self.yeti=yeti
        if yeti {model=DecorationManager().makeYeti();model.position.y=18}
        else {model=Resources.object(["gnome_foot_left","gnome_foot_right","gnome_body_"+color,"gnome_head","gnome_hat","gnome_arm_left","gnome_arm_right"],size:48);model.position.y=21.4}
        node.addChild(model)
        if !yeti {for (side,x) in [("left",34.0),("right",94.0)] {if let arm=model.childNode(withName:"gnome_arm_"+side) as? SKSpriteNode {AssetManager.shared.pivot(arm,at:CGPoint(x:x/128,y:1-71.0/128))}}}
        palm=Resources.layer(yeti ? "yeti_palm":"gnome_palm",size:yeti ? 7:6)
        palm.position=CGPoint(x:yeti ? 13:12,y:yeti ? 29:27);palm.zPosition=5;node.addChild(palm)
        held=Resources.layer("snowball_small",size:7);held.zPosition=6;palm.addChild(held);held.isHidden=true
    }
    func pose(_ pose:LivingPose,time:Double,facing:Double=1,emotion:String="happy") {
        if let storyRig {storyRig.pose(pose,time:time,facing:facing,emotion:emotion);return}
        node.xScale=facing
        let moving=pose == .run || pose == .drive || pose == .carry || pose == .walk || pose == .sneak || pose == .climb
        model.position.y=(yeti ? 18:21.4)+(moving ? abs(sin(time*(yeti ? 9:15)))*1.2:sin(time*1.5)*0.25)
        let prefix=yeti ? "yeti_":"gnome_"
        if offhand != nil {offhand?.isHidden=true;model.childNode(withName:prefix+"arm_left")?.setScale(1)}
        model.childNode(withName:prefix+"foot_left")?.position.y=moving ? max(0,sin(time*(yeti ? 9:15)))*2:0
        model.childNode(withName:prefix+"foot_right")?.position.y=moving ? max(0,-sin(time*(yeti ? 9:15)))*2:0
        let arm=pose == .throwBall ? -0.8+sin(min(1,time)*Double.pi)*0.8:pose == .carry || pose == .lift ? -0.9:pose == .aim || pose == .makeSnowball ? -0.45:moving ? sin(time*(yeti ? 9:15))*0.13:0
        model.childNode(withName:prefix+"arm_right")?.zRotation=arm
        model.childNode(withName:prefix+"arm_left")?.zRotation=pose == .lift || pose == .carry ? 0.9:-arm*0.5
        held.isHidden = ![LivingPose.aim,.makeSnowball,.pickSnow].contains(pose)
        palm.position.y = pose == .carry || pose == .lift ? 24:yeti ? 29:27
        if yeti,compactHands {palm.position.y-=(pose == .carry || pose == .lift ? 6:10)}
        palm.position.x=(yeti ? 13:12)+(pose == .throwBall ? sin(min(1,time/0.5)*Double.pi)*3:0)
        held.setScale(1)
        if moving {palm.position.x+=sin(time*(yeti ? 9:15))*2;palm.position.y+=sin(time*(yeti ? 9:15))*1.5}
        if pose == .makeSnowball || pose == .pickSnow {
            let f=clamp(time/0.8,0,1),reach=sin(f*Double.pi)
            model.position.y-=reach*4
            palm.position.y-=reach*22;palm.position.x+=reach*4+sin(time*22)*reach
            held.isHidden=time<0.27;held.setScale(0.2+0.8*clamp((time-0.27)/0.4,0,1))
        }
        if pose == .sneak {model.position.y-=3;palm.position.y-=3}
        if pose == .pickUp || pose == .putDown {let f=sin(clamp(time/1.1,0,1)*Double.pi);model.position.y-=f*6;palm.position.y-=f*17}
        if pose == .repair || pose == .shake {palm.position.y+=4+sin(time*5)*2;palm.position.x+=sin(time*6)*2}
        if pose == .point || pose == .surprised || pose == .angry {palm.position.y+=8;palm.position.x+=3;model.zRotation=sin(time*2)*0.035}else{model.zRotation=0}
        if pose == .brush {palm.position.y+=13+sin(time*7)*3}
        if pose == .dance {model.position.y+=abs(sin(time*5))*2;model.zRotation=sin(time*4)*0.06;palm.position.y+=7+sin(time*5)*3}
        if pose == .bow {model.zRotation=sin(clamp(time/1.2,0,1)*Double.pi)*0.16}
        if pose == .celebrate {let hop=abs(sin(time*8))*5;model.position.y+=hop;palm.position.y+=9+hop*0.3}
        if pose == .throwBall {palm.position.y+=sin(clamp(time/0.5,0,1)*Double.pi)*2}
        if yeti,faceID != emotion {
            face?.removeFromParent();let overlay=Resources.layer("yeti_emotion_"+emotion,size:40);overlay.zPosition=5;model.addChild(overlay);face=overlay;faceID=emotion
        }
        let blink=time.truncatingRemainder(dividingBy:4.7)>4.55
        face?.alpha=blink ? 0.6:1
        node.zRotation=pose == .dodge ? sin(min(1,time)*Double.pi)*0.24:pose == .hit ? sin(time*18)*exp(-time*5)*0.18:pose == .fall ? -pow(clamp(time/0.65,0,1),2)*Double.pi/2:pose == .recover ? -(1-clamp(time/1.2,0,1))*Double.pi/2:pose == .stop ? -0.035:0
        rigHand()
    }
    func rigHand(){
        if let storyRig {storyRig.right();return}
        guard let arm=model.childNode(withName:(yeti ? "yeti_":"gnome_")+"arm_right") else{return}
        let grip=model.convert(palm.position,from:node),end=yeti ? Vec(3.5,-8):Vec(0,-17.0/128*48)
        let delta=Vec(grip.x-arm.position.x,grip.y-arm.position.y)
        // Extend the arm along its length without inflating the sleeve width.
        let width=min(1,max(0.05,delta.length/max(0.001,abs(end.x))*0.99))
        let length=sqrt(max(0.0001,delta.length*delta.length-pow(end.x*width,2)))/max(0.001,abs(end.y))
        arm.xScale=width;arm.yScale=length;arm.zRotation=atan2(delta.y,delta.x)-atan2(end.y*length,end.x*width)
    }
    func reachOffhand(_ point:CGPoint,in reference:SKNode){
        if let storyRig {storyRig.left(node.convert(point,from:reference));return}
        guard let arm=model.childNode(withName:(yeti ? "yeti_":"gnome_")+"arm_left") else{return}
        if offhand==nil {let hand=Resources.layer(yeti ? "yeti_palm":"gnome_palm",size:yeti ? 7:6);hand.zPosition=5;node.addChild(hand);offhand=hand}
        let local=node.convert(point,from:reference);offhand?.position=local;offhand?.isHidden=false
        let grip=model.convert(local,from:node),end=yeti ? Vec(-3.5,-8):Vec(0,-17.0/128*48),delta=Vec(grip.x-arm.position.x,grip.y-arm.position.y)
        let length=sqrt(max(0.0001,delta.length*delta.length-end.x*end.x))/max(0.001,abs(end.y))
        arm.xScale=1;arm.yScale=length;arm.zRotation=atan2(delta.y,delta.x)-atan2(end.y*length,end.x)
    }
    func hand(in reference:SKNode)->CGPoint {palm.convert(.zero,to:reference)}
}
final class LivingVehicle {
    let node=SKNode(),model:SKNode
    let width:Double
    init(width:Double=142) {
        self.width=width;let height=width*180/320
        model=Resources.object(["truck_platform","truck_body","truck_ribbon","truck_lights"],size:height)
        model.position.y=height*(147.0/180-0.5);node.addChild(model)
        for (name,x) in [("truck_wheel_front",83.0),("truck_wheel_rear",237.0)] {
            let wheel=Resources.layer(name,size:height);AssetManager.shared.pivot(wheel,at:CGPoint(x:x/320,y:1-125.0/180));model.addChild(wheel)
        }
    }
    func apply(_ pose:VehiclePose,local:(Vec)->CGPoint) {
        node.position=local(pose.position);node.zRotation=pose.tilt
        for name in ["truck_wheel_front","truck_wheel_rear"]{model.childNode(withName:name)?.zRotation = -pose.wheelAngle*node.xScale}
    }
    var cargo:CGPoint {CGPoint(x:width*0.15,y:width*0.17)}
}

final class LivingSceneState {
    var delivery:TreeSceneController?,vehicle:LivingVehicle?,gnome:LivingActor?,treePayload:SKNode?
    var automaticTarget:Vec?,automaticElapsed=0.0,automaticMass=0.0
    var activity:String?,activityElapsed=0.0,activityOrigin=Vec(),activityTarget=Vec(),activityActor:LivingActor?,activityBall:SKNode?,activityShot:Projectile?,activityReleased=false,activityResult="",feedDragging=false
    var activityMarker:SKShapeNode?,activityMass=0.0,feedCaughtAt:Double?,feedCaughtFrom=Vec()
    var duel:DuelController?,arena:SnowSurface?
    var player:LivingActor?,enemy:LivingActor?,helpers:[LivingActor]=[],gameRoot:SKNode?,hpLabels:[SKLabelNode]=[],title:SKLabelNode?,arrow:SKShapeNode?,duelBall:SKNode?,lastDuelPhase:DuelPhase?
    var duelVehicle:LivingVehicle?,carried:SKNode?,rescueRoot:SKNode?
    var arenaNode:SKShapeNode?,arenaRevision:UInt64=UInt64.max,duelObscured=false
    var busy:Bool {delivery != nil || automaticTarget != nil || activity != nil || duel != nil}
    func removeStoryNodes(){vehicle?.node.removeFromParent();gnome?.node.removeFromParent();treePayload?.removeFromParent();vehicle=nil;gnome=nil;treePayload=nil;delivery=nil}
    func clear() {
        removeStoryNodes();automaticTarget=nil;automaticElapsed=0;automaticMass=0
        activityActor?.node.removeFromParent();activityBall?.removeFromParent();activityMarker?.removeFromParent();activity=nil;activityActor=nil;activityBall=nil;activityShot=nil;activityMarker=nil;feedDragging=false;activityMass=0;feedCaughtAt=nil;activityReleased=false
        gameRoot?.removeFromParent();duel=nil;arena=nil;player=nil;enemy=nil;helpers=[];gameRoot=nil;hpLabels=[];title=nil;arrow=nil;duelBall=nil;duelVehicle=nil;carried=nil;rescueRoot=nil;arenaNode=nil;arenaRevision=UInt64.max;duelObscured=false
    }
}
