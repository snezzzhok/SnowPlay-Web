import AppKit
import SpriteKit
import SnowCore
extension ChristmasStoryRuntime {
 func planStarHat(){
  spawn("bigElf",color:"gold",at:spot(185),scale:1.55,variant:3,giant:true)
  _=add("star","story_star",height:22);carry("star",by:"bigElf")
  let topNode=state.tree!,local=topNode.convert(CGPoint(x:0,y:state.treeHeight*0.43),to:state.root),top=Vec(display.rect.x+local.x,display.rect.maxY-local.y),base=Vec(top.x+stage.side*36,manager.groundY(top.x+stage.side*36,display:display,surfaces:surfaces)),lift=max(0,base.y-top.y-43)
  walk("a-star-for-the-tree",2.5,goals:["bigElf":base],pose:.carry)
  beat("unfold-a-sturdy-ladder",1.4,enter:{r in _=r.add("star-ladder","story_ladder",height:max(45,lift+30),at:base+Vec(0,-max(45,lift+30)/2));r.pose("bigElf",.putDown)})
  beat("climb-carefully",3.0,enter:{$0.actors["bigElf"]?.climbing=true},update:{r,t in let f=clamp(t/3,0,1);r.actors["bigElf"]?.position=base+Vec(0,-lift*f);r.actors["bigElf"]?.target=base+Vec(0,-lift*f);r.pose("bigElf",.climb)})
  beat("hands-place-the-star",2.0,enter:{r in r.custom["oldTopAlpha"]=Double(r.state.tree?.childNode(withName:"tree-topper")?.alpha ?? 1);r.state.tree?.childNode(withName:"tree-topper")?.alpha=0;r.pose("bigElf",.lift)},update:{r,t in r.reach("bigElf",to:top,fraction:t/2)},leave:{r in r.release("star",at:top);r.contact("star-installed",prop:"star",actor:"bigElf")})
  beat("a-hat-on-the-branch",1.5,enter:{r in r.actors["bigElf"]?.actor.model.childNode(withName:"gnome_hat")?.isHidden=true;let p=r.stage.focus+Vec(r.stage.side*18,-r.state.treeHeight*0.58);_=r.add("lost-hat","sticker_hat",height:21,at:p);r.props["lost-hat"]?.zRotation = -0.25;r.pose("bigElf",.point)})
  beat("where-is-my-hat",1.2,enter:{$0.pose("bigElf",.surprised)})
  beat("carefully-take-it-back",1.8,enter:{$0.pose("bigElf",.pickUp)},update:{r,t in if let hat=r.props["lost-hat"]{r.reach("bigElf",to:Vec(r.display.rect.x+hat.position.x,r.display.rect.maxY-hat.position.y),fraction:t/1.8)}},leave:{r in r.carry("lost-hat",by:"bigElf")})
  beat("hat-back-on",1.2,enter:{$0.pose("bigElf",.lift)},leave:{r in r.props["lost-hat"]?.removeFromParent();r.actors["bigElf"]?.actor.model.childNode(withName:"gnome_hat")?.isHidden=false})
  beat("climb-down-again",3.0,update:{r,t in let p=base+Vec(0,-lift*(1-clamp(t/3,0,1)));r.actors["bigElf"]?.position=p;r.actors["bigElf"]?.target=p;r.pose("bigElf",.climb)},leave:{r in r.actors["bigElf"]?.climbing=false;r.props["star-ladder"]?.removeFromParent()})
  beat("a-proud-little-bow",2,enter:{$0.pose("bigElf",.bow)},leave:{$0.outcome="Star installed; hat safely recovered"})
  leaveTogether(["bigElf"],duration:2.8)
 }
 func planGiftConveyor(){
  let names=(0..<5).map{"elf\($0)"},colors=["red","green","blue","gold","purple"]
  for i in 0..<5 {spawn(names[i],color:colors[i],at:spot(70+Double(i)*42),variant:i)}
  beat("the-relay-forms",1.8,enter:{r in for name in names {r.pose(name,.point)}})
  for parcel in 0..<3 {
   let key="relay\(parcel)"
   beat("parcel-\(parcel)-arrives",1.2,enter:{r in _=r.add(key,"story_present_"+["red","blue","green"][parcel],height:24);r.carry(key,by:"elf4");r.pose("elf4",.carry)})
   for i in stride(from:4,through:1,by:-1) {
    beat("hand-off-\(parcel)-\(i)",1.15,enter:{r in r.pose(names[i],.carry);r.pose(names[i-1],.carry);r.actors[names[i]]?.facing = -r.stage.side;r.actors[names[i-1]]?.facing=r.stage.side},update:{r,t in
     let a=r.actors[names[i]]!.position,b=r.actors[names[i-1]]!.position,p=(a+b)*0.5+Vec(0,-25);r.reach(names[i],to:p,fraction:t/1.15);r.reach(names[i-1],to:p,fraction:t/1.15)
    },leave:{r in r.carry(key,by:names[i-1]);r.contact("relay-hand-off",prop:key,actor:names[i]+"→"+names[i-1])})
   }
   beat("place-parcel-\(parcel)",1.3,enter:{$0.pose("elf0",.putDown)},update:{r,t in r.reach("elf0",to:r.giftSlot(parcel),fraction:t/1.3)},leave:{r in r.release(key,at:r.giftSlot(parcel));r.persistentGifts.append((["red","blue","green"][parcel],r.giftSlot(parcel)))})
  }
  walk("make-room-for-the-big-one",2.5,goals:["elf0":spot(145)+Vec(-stage.side*38,0),"elf1":spot(145)+Vec(stage.side*38,0),"elf2":spot(250),"elf3":spot(295),"elf4":spot(340)])
  beat("the-oversized-box",1.8,enter:{r in _=r.add("bigBox","story_present_red",height:56,at:r.spot(145,-24));for name in names {r.pose(name,.surprised)}})
  beat("everyone-heave",1.7,enter:{$0.pose("elf0",.lift);$0.pose("elf1",.lift)},leave:{r in r.custom["pairGrip"]=23;let left=r.actors["elf0"]!.position.x<r.actors["elf1"]!.position.x ? "elf0":"elf1";r.sharedCarry("bigBox",left:left,right:left=="elf0" ? "elf1":"elf0")})
  walk("carry-the-big-present",2.6,goals:["elf0":spot(85)+Vec(-stage.side*38,0),"elf1":spot(85)+Vec(stage.side*38,0)],pose:.carry)
  beat("set-it-down-together",1.6,enter:{$0.pose("elf0",.putDown);$0.pose("elf1",.putDown)},leave:{r in r.release("bigBox",at:r.spot(85,-24));r.custom["pairGrip"]=10;r.persistentGifts.append(("red",r.spot(85,-24)))})
  beat("five-perfect-bows",2.0,enter:{r in for name in names {r.pose(name,.bow)}},leave:{$0.outcome="Five-elf relay; three parcels and one oversized present delivered"})
  leaveTogether(names,duration:3.0)
 }
 func planTinyGift(){
  spawn("giant",yeti:true,at:spot(155),scale:2.4,variant:5,giant:true)
  let boxPoint=spot(0,-12),box=Resources.object(["gift_box"],size:38);box.name="tiny-box";root.addChild(box);box.position=display.local(boxPoint);props["tiny-box"]=box
  for id in ["gift_lid","gift_bow"] {let p=Resources.layer(id,size:38);p.name=id;box.addChild(p);props[id]=p}
  walk("a-tiny-discovery",2.8,goals:["giant":spot(65)],pose:.walk)
  beat("can-those-fingers-fit",1.7,enter:{$0.pose("giant",.surprised)})
  beat("carefully-untying-the-bow",2.8,enter:{$0.pose("giant",.pickUp)},update:{r,t in r.reach("giant",to:boxPoint+Vec(0,-10),fraction:min(1,t));r.props["gift_bow"]?.zRotation=sin(t*3)*0.15;r.props["gift_bow"]?.setScale(1-0.35*clamp(t/2.8,0,1))},leave:{r in r.props["gift_bow"]?.removeFromParent();r.contact("tiny-bow-untied",prop:"tiny-box",actor:"giant")})
  beat("lift-the-little-lid",1.8,update:{r,t in r.props["gift_lid"]?.position.y=t*10;r.props["gift_lid"]?.zRotation=t*0.2},leave:{r in _=r.add("tiny-scarf","story_scarf",height:5,at:boxPoint+Vec(0,-8))})
  beat("a-very-small-scarf",1.6,enter:{$0.pose("giant",.surprised)})
  beat("one-finger-is-enough",2.0,enter:{$0.pose("giant",.pickUp)},update:{r,t in r.reach("giant",to:boxPoint+Vec(0,-8),fraction:t/2)},leave:{r in r.carry("tiny-scarf",by:"giant");r.props["tiny-scarf"]?.setScale(0.6);r.props["tiny-scarf"]?.position=CGPoint(x:2,y:2)})
  beat("a-proud-finger-wave",2.3,enter:{$0.pose("giant",.point)},leave:{$0.outcome="Tiny scarf wrapped around one giant finger"})
  leaveTogether(["giant"],duration:3)
 }
}
