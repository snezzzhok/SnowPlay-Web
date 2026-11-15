import AppKit
import SpriteKit
import SnowCore
final class StorySnowShot {
 let node:SKNode,flight:Projectile,target:String,size:Double
 var elapsed=0.0
 init(node:SKNode,flight:Projectile,target:String,size:Double){self.node=node;self.flight=flight;self.target=target;self.size=size}
}
extension ChristmasStoryRuntime {
 func teamPoint(_ fraction:Double)->Vec {let x=stage.area.x+stage.area.width*fraction;return Vec(x,manager.groundY(x,display:display,surfaces:surfaces))}
 func launchTeamShot(_ source:String,_ target:String,size:Double?=nil,duration:Double=1.65){
  guard shots.count<3,let actor=actors[source],let victim=actors[target] else{return}
  let actual=size ?? Double(actor.actor.held.size.width)*(actor.actor.storyRig?.scale ?? 1),from=actorHand(source),to=victim.position+Vec(0,-(victim.actor.yeti ? 23:27)*(victim.actor.storyRig?.scale ?? 1))
  actor.actor.held.isHidden=true;pose(source,.throwBall)
  let node=Resources.layer("snowball_medium",size:actual);node.zPosition=70;root.addChild(node);node.position=display.local(from)
  shots.append(StorySnowShot(node:node,flight:Projectile(from:from,to:to,duration:duration,gravity:size==nil ? 140:200),target:target,size:actual));peakShots=max(peakShots,shots.count);contact("team-release",prop:"snowball",actor:source)
 }
 func updateTeamShots(dt:Double){
  for shot in shots {shot.elapsed+=dt;shot.node.position=display.local(shot.flight.position(shot.elapsed));shot.node.zRotation+=dt*2
   if shot.elapsed>=shot.flight.duration {puff(at:shot.flight.target,count:shot.size>35 ? 12:7);pose(shot.target,.hit);actors[shot.target]?.poseTime=0;shotImpacts+=1;contact("team-impact",prop:"snowball",actor:shot.target);shot.node.removeFromParent()}
  };shots.removeAll{$0.elapsed>=$0.flight.duration}
 }
 func volley(_ name:String,senders:[String],targets:[String],interval:Double=0.85,size:Double?=nil){
  let duration=Double(senders.count-1)*interval+2.3
  beat(name,duration,enter:{r in for actor in senders {r.pose(actor,.aim)}},update:{r,t in
   for (i,actor) in senders.enumerated() where t>=Double(i)*interval && r.custom[name+actor]==nil {
    r.custom[name+actor]=1;r.launchTeamShot(actor,targets[i%targets.count],size:size)
   }
  },leave:{r in for actor in senders {r.pose(actor,.idle)}})
 }
}
