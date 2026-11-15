import AppKit
import SpriteKit
import SnowCore
/// Two fixed-length sleeve links replace the stretched full-canvas arms in stories.
final class StoryActorRig {
 unowned let a:LivingActor
 var arms:[String:(SKSpriteNode,SKSpriteNode,CGPoint)]=[:]
 var distance=0.0,frameBaseDistance=0.0,motionDelta=0.0
 var scale=1.0,variant=0,lastFacing=1.0,turn=0.0
 var maxReach=0.0,lowering=0.0,supportLift=0.0
 init(_ actor:LivingActor,color:String,scale:Double,variant:Int,giant:Bool){
  a=actor;self.scale=scale;self.variant=variant
  let prefix=a.yeti ? "yeti_":"gnome_",cloth=a.yeti ? "fur":color
  for side in ["left","right"] {
   guard let old=a.model.childNode(withName:prefix+"arm_"+side) else{continue};old.isHidden=true
   let upper=Resources.layer("story_rig_"+cloth,size:12.5),lower=Resources.layer("story_rig_"+cloth,size:12.5)
   for bone in [upper,lower]{bone.anchorPoint=CGPoint(x:0.5,y:1);bone.size=CGSize(width:a.yeti ? 6:5,height:12.5);bone.zPosition=6;a.model.addChild(bone)}
   arms[side]=(upper,lower,old.position)
  }
  if a.offhand==nil {let hand=Resources.layer(a.yeti ? "yeti_palm":"gnome_palm",size:a.yeti ? 7:6);hand.zPosition=7;a.node.addChild(hand);a.offhand=hand}
  if giant,let body=a.model.children.first(where:{$0.name?.hasPrefix(prefix+"body")==true}) as? SKSpriteNode {body.texture=AssetManager.shared.texture(a.yeti ? "story_rig_giant_yeti":"story_rig_big_gnome");body.userData?["assetID"]=a.yeti ? "story_rig_giant_yeti":"story_rig_big_gnome"}
  if a.yeti {let colors=["red","green","blue","gold","purple","fur"],id="story_friend_"+colors[variant%colors.count],scarf=Resources.layer(id,size:40);scarf.zPosition=6;a.model.addChild(scarf)
   if variant>=6 {let cap=Resources.layer("story_party_hat",size:8);cap.position=CGPoint(x:0,y:38);cap.zPosition=9;a.node.addChild(cap)}
   if variant%2==1 {let freckles=Resources.layer("story_rig_freckles",size:40);freckles.zPosition=7;a.model.addChild(freckles)}
  }else if variant>0,let hat=a.model.childNode(withName:"gnome_hat") as? SKSpriteNode {hat.color=[NSColor.systemRed,.systemGreen,.systemBlue,.systemOrange,.systemPurple][variant%5];hat.colorBlendFactor=0.48}
 }
 func solve(_ side:String,to requested:CGPoint)->CGPoint {
  guard let (upper,lower,shoulder)=arms[side] else{return requested}
  let local=a.model.convert(requested,from:a.node),delta=Vec(local.x-shoulder.x,local.y-shoulder.y),length=min(24.5,max(1,delta.length)),unit=delta*(1/max(0.001,delta.length)),end=Vec(shoulder.x,shoulder.y)+unit*length
  let midpoint=(Vec(shoulder.x,shoulder.y)+end)*0.5,bend=sqrt(max(0,12.5*12.5-length*length/4))*(side=="right" ? -1:1),elbow=midpoint+Vec(-unit.y,unit.x)*bend
  upper.position=shoulder;upper.zRotation=atan2(elbow.y-shoulder.y,elbow.x-shoulder.x)+Double.pi/2
  lower.position=CGPoint(x:elbow.x,y:elbow.y);lower.zRotation=atan2(end.y-elbow.y,end.x-elbow.x)+Double.pi/2
  maxReach=max(maxReach,length);return a.node.convert(CGPoint(x:end.x,y:end.y),from:a.model)
 }
 func right(){a.palm.position=solve("right",to:a.palm.position)}
 func left(_ p:CGPoint){a.offhand?.position=solve("left",to:p);a.offhand?.isHidden=false}
 func beginMotion(_ deltaX:Double){frameBaseDistance=distance;motionDelta=deltaX/scale}
 func pose(_ pose:LivingPose,time:Double,facing:Double,emotion:String){
  distance=frameBaseDistance+motionDelta*facing
  let moving=[LivingPose.run,.walk,.sneak,.carry,.drive].contains(pose)
  if facing != lastFacing {turn=1;lastFacing=facing};turn*=0.86
  a.node.xScale=facing*scale;a.node.yScale=scale
  let phase=distance/(a.yeti ? 20:18),bob=moving ? sin(phase*Double.pi*2)*0.6:sin(time*1.5)*0.15
  var lower = -lowering
  if [.pickSnow,.makeSnowball,.pickUp,.putDown].contains(pose){lower = -sin(clamp(time/1.5,0,1)*Double.pi)*5}
  if pose == .sneak {lower = -3}
  var jump=0.0
  if pose == .dance {jump=max(0,sin(time*Double.pi*2))*4}
  if pose == .celebrate {jump=max(0,sin(time*4))*5}
  a.model.position=CGPoint(x:0,y:(a.yeti ? 18:21.4)+bob+lower+jump)
  a.model.zRotation=pose == .bow ? sin(clamp(time/1.5,0,1)*Double.pi)*0.14:pose == .dance ? sin(time*3)*0.08:pose == .surprised ? -0.045:0
  for (i,side) in ["left","right"].enumerated(){if let foot=a.model.childNode(withName:(a.yeti ? "yeti_":"gnome_")+"foot_"+side){let p=StoryGait.foot(distance:distance,leg:i,stride:a.yeti ? 20:18);foot.position=CGPoint(x:moving ? p.x:0,y:(moving ? p.lift:0)-bob-lower);foot.zRotation=moving && !p.stance ? -sin(phase*6.28+Double(i)*Double.pi)*0.12:0}}
  var right=CGPoint(x:12,y:a.yeti ? 24:26),left=CGPoint(x:-12,y:24)
  if moving {right.y+=sin(phase*6.28)*2;left.y-=sin(phase*6.28)*2}
  if [.makeSnowball,.pickSnow,.pickUp,.putDown].contains(pose){right=CGPoint(x:13,y:10);left=CGPoint(x:-9,y:10)}
  if [.aim,.repair,.shake].contains(pose){right=CGPoint(x:18,y:30);left=CGPoint(x:-15,y:28)}
  if pose == .throwBall {let t=clamp(time/0.65,0,1);right=CGPoint(x:8+22*sin(t*Double.pi/2),y:32+5*sin(t*Double.pi))}
  if [.surprised,.point,.angry].contains(pose){right=CGPoint(x:18,y:35)}
  if pose == .brush {right=CGPoint(x:sin(time*6)*12,y:34+sin(time*3)*4)}
  if [.dance,.celebrate].contains(pose){right=CGPoint(x:18,y:30+sin(time*5)*6);left=CGPoint(x:-18,y:30-sin(time*5)*6)}
  if pose == .lift {right=CGPoint(x:12,y:34);left=CGPoint(x:-12,y:34)}
  a.palm.position=right;self.right();self.left(left)
  a.held.isHidden = ![LivingPose.aim,.makeSnowball,.pickSnow].contains(pose);a.held.setScale(pose == .makeSnowball ? 0.25+0.75*clamp(time/1.8,0,1):1)
  a.node.zRotation=pose == .fall ? -pow(clamp(time/0.9,0,1),2)*Double.pi/2:pose == .recover ? -(1-clamp(time/1.7,0,1))*Double.pi/2:pose == .hit ? sin(time*13)*exp(-time*4)*0.13:pose == .dodge ? sin(time*2)*0.16:turn*0.025
  supportLift=[LivingPose.fall,.recover].contains(pose) ? StoryGroundContact.lift(a):0
  if a.yeti,a.faceID != emotion {a.face?.removeFromParent();let overlay=Resources.layer("yeti_emotion_"+emotion,size:40);overlay.zPosition=5;a.model.addChild(overlay);a.face=overlay;a.faceID=emotion}
 }
}
