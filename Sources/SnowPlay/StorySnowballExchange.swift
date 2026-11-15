import AppKit
import SpriteKit
import SnowCore
extension ChristmasStoryRuntime {
 func planSnowballExchange(){
  let elfNames=(0..<5).map{"elf\($0)"},yetiNames=(0..<10).map{"yeti\($0)"},colors=["red","green","blue","gold","purple"]
  func elfSpot(_ i:Int)->Vec {teamPoint(0.16+Double(i==0 ? 4:i-1)*0.054)}
  func yetiSpot(_ i:Int)->Vec {teamPoint(0.56+Double(i)*0.0355)}
  spawn("elf0",color:"red",at:Vec(stage.focus.x-45,manager.groundY(stage.focus.x-45,display:display,surfaces:surfaces)))
  spawn("yeti0",yeti:true,at:teamPoint(0.91),scale:0.86)
  walk("a-friendly-mischief",2.5,goals:["yeti0":teamPoint(0.68)],pose:.walk)
  beat("a-visible-windup",2.0,enter:{$0.pose("yeti0",.makeSnowball)},leave:{r in r.launchTeamShot("yeti0","elf0",duration:1.8)})
  beat("the-first-snowy-surprise",2.0,leave:{$0.pose("elf0",.angry)})
  walk("make-room-for-friends",2.2,goals:["elf0":elfSpot(0)],pose:.walk)
  beat("calling-four-friends",1.5,enter:{$0.pose("elf0",.point)},leave:{r in for i in 1..<5 {r.spawn(elfNames[i],color:colors[i],at:r.teamPoint(0.035+Double(i-1)*0.04),variant:i)}})
  walk("five-elves-line-up",3,goals:Dictionary(uniqueKeysWithValues:elfNames.enumerated().map{($0.element,elfSpot($0.offset))}))
  beat("five-snowballs-ready",1.8,enter:{r in for name in elfNames {r.pose(name,.makeSnowball)}})
  volley("the-elves-take-turns",senders:elfNames,targets:["yeti0"],interval:0.9)
  beat("yeti-topples-into-snow",1.8,enter:{$0.pose("yeti0",.fall)})
  beat("up-again",1.9,enter:{$0.pose("yeti0",.recover)})
  walk("a-tactical-retreat",2.0,goals:["yeti0":yetiSpot(0)],pose:.walk)
  beat("calling-nine-friends",1.5,enter:{$0.pose("yeti0",.point)},leave:{r in for i in 1..<10 {r.spawn(yetiNames[i],yeti:true,at:r.teamPoint(0.56+Double(i)*0.0355)+Vec(28,0),scale:0.86,variant:i)}})
  walk("ten-distinct-yetis",2.0,goals:Dictionary(uniqueKeysWithValues:yetiNames.enumerated().map{($0.element,yetiSpot($0.offset))}),pose:.walk)
  beat("the-yeti-team-prepares",1.8,enter:{r in for name in yetiNames {r.pose(name,.makeSnowball)}})
  volley("the-yetis-reply",senders:yetiNames,targets:elfNames,interval:0.85)
  beat("a-comical-elf-tumble",1.5,enter:{r in for name in elfNames {r.pose(name,.fall)}})
  beat("five-elves-stand-up",1.9,enter:{r in for name in elfNames {r.pose(name,.recover)}})
  beat("calling-big-brother",1.5,enter:{$0.pose("elf0",.point)},leave:{r in r.spawn("bigElf",color:"gold",at:r.teamPoint(0.045),scale:1.9,variant:3,giant:true)})
  walk("big-brother-arrives",2.0,goals:["bigElf":teamPoint(0.05)],pose:.walk)
  beat("one-very-big-snowball",2.8,enter:{r in r.actors["bigElf"]?.actor.held.size=CGSize(width:26,height:26);r.pose("bigElf",.makeSnowball)})
  beat("big-brother-takes-aim",1.2,enter:{$0.pose("bigElf",.aim)},leave:{$0.launchTeamShot("bigElf","yeti4",duration:2.1)})
  beat("a-team-sized-snow-cloud",2.5,leave:{r in for name in yetiNames {r.pose(name,.fall);r.puff(at:r.actors[name]!.position+Vec(0,-15),count:4)}})
  beat("the-yetis-get-up",2.0,enter:{r in for name in yetiNames {r.pose(name,.recover)}})
  beat("calling-the-giant",1.4,enter:{$0.pose("yeti0",.point)},leave:{r in r.spawn("giantYeti",yeti:true,at:r.teamPoint(0.945),scale:2.35,variant:4,giant:true)})
  walk("the-giant-arrives",2,goals:["giantYeti":teamPoint(0.95)],pose:.walk)
  beat("an-even-bigger-snowball",3,enter:{r in r.actors["giantYeti"]?.actor.held.size=CGSize(width:29,height:29);r.pose("giantYeti",.makeSnowball)})
  beat("one-last-friendly-throw",1.3,enter:{$0.pose("giantYeti",.aim)},leave:{$0.launchTeamShot("giantYeti","bigElf",duration:2.4)})
  beat("the-final-powder-cloud",2.8,leave:{r in for name in elfNames+["bigElf"] {r.pose(name,.fall);r.puff(at:r.actors[name]!.position+Vec(0,-18),count:5)}})
  beat("everyone-gets-up",2.0,enter:{r in for name in elfNames+["bigElf"] {r.pose(name,.recover)}})
  beat("brush-off-and-laugh",2.2,enter:{r in for name in elfNames+yetiNames+["bigElf","giantYeti"] {r.pose(name,.brush)}})
  beat("friends-wave-goodbye",2.0,enter:{r in for name in elfNames+yetiNames+["bigElf","giantYeti"] {r.pose(name,.celebrate)}},leave:{r in r.outcome="Five elves, ten Yetis and two giants; everyone leaves as friends"})
  // Each team exits toward its own nearest boundary, preserving its ordering.
  beat("teams-go-home",3.8,enter:{r in for name in elfNames+["bigElf"] {r.move(name,r.actors[name]!.position+Vec(-30,0),pose:.walk)};for name in yetiNames+["giantYeti"] {r.move(name,r.actors[name]!.position+Vec(30,0),pose:.walk)}},update:{r,t in if t>2 {for a in r.actors.values {a.actor.node.alpha=1-clamp((t-2)/1.8,0,1)}}})
 }
}
