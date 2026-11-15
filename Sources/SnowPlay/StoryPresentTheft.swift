import AppKit
import SpriteKit
import SnowCore
extension ChristmasStoryRuntime {
 func planPresentTheft(){
  spawn("elf0",color:"green",at:spot(210));spawn("elf1",color:"blue",at:spot(258))
  _=add("parcel0","story_present_blue",height:24);_=add("parcel1","story_present_green",height:24);carry("parcel0",by:"elf0");carry("parcel1",by:"elf1")
  selectedGift=state.treePresents.first{$0.id==stage.giftID};if let gift=selectedGift,let parent=gift.node.parent {borrowed.append((gift.node,parent,gift.node.position,gift.node.alpha));props["victim"]=gift.node}
  walk("deliver-presents",2.8,goals:["elf0":spot(30),"elf1":spot(64)],pose:.carry)
  beat("set-presents-down",1.4,enter:{$0.pose("elf0",.putDown);$0.pose("elf1",.putDown)},update:{r,t in r.reach("elf0",to:r.giftSlot(0),fraction:t/1.4);r.reach("elf1",to:r.giftSlot(1),fraction:t/1.4)},leave:{r in r.release("parcel0",at:r.giftSlot(0));r.release("parcel1",at:r.giftSlot(1));r.persistentGifts=[("blue",r.giftSlot(0)),("green",r.giftSlot(1))]})
  beat("inspect-the-delivery",1.2,enter:{$0.pose("elf0",.point);$0.pose("elf1",.celebrate)})
  walk("elves-step-aside",1.8,goals:["elf0":spot(140),"elf1":spot(188)],pose:.walk)
  beat("yeti-peeks",1.4,enter:{r in r.spawn("yeti",yeti:true,at:r.opposite(148));r.pose("yeti",.sneak)})
  let giftPoint=selectedGift?.position ?? opposite(24),approachX=giftPoint.x-stage.side*23
  walk("tiptoe-to-the-present",2.0,goals:["yeti":Vec(approachX,manager.groundY(approachX,display:display,surfaces:surfaces))],pose:.sneak)
  beat("hands-touch-the-box",1.4,enter:{$0.pose("yeti",.pickUp)},update:{r,t in r.reach("yeti",to:giftPoint,fraction:t/1.4)},leave:{r in r.carry("victim",by:"yeti")})
  walk("yeti-runs-with-the-box",2,goals:["yeti":opposite(130)],pose:.carry)
  beat("elves-notice",1.0,enter:{$0.pose("elf0",.surprised);$0.pose("elf1",.point)})
  walk("chase",1.8,goals:["elf0":opposite(46),"elf1":spot(4)])
  beat("stumble-and-drop",1.6,enter:{r in let p=r.actorHand("yeti");r.custom["dropX"]=p.x;r.custom["dropY"]=p.y;r.release("victim",at:p);r.pose("yeti",.fall)},update:{r,t in
   let x=(r.custom["dropX"] ?? r.stage.focus.x)+20*(1-exp(-t*3)),ground=r.manager.groundY(x,display:r.display,surfaces:r.surfaces),height=max(0,ground-12-(r.custom["dropY"] ?? ground-24)),y=ground-12-height*(1-clamp(t/0.6,0,1))-abs(sin(t*Double.pi/0.65))*20*exp(-t*2)
   r.props["victim"]?.position=r.display.local(Vec(x,y));r.props["victim"]?.zRotation=sin(t*7)*0.35*exp(-t*1.7);r.custom["landX"]=x;r.custom["landY"]=ground-12
  })
  beat("a-moment-in-the-snow",1.0)
  beat("yeti-gets-back-up",1.9,enter:{$0.pose("yeti",.recover)})
  walk("elves-watch-from-a-safe-distance",2.0,goals:["elf0":spot(105),"elf1":spot(153)],pose:.walk)
  beat("pick-the-box-up-again",1.7,enter:{$0.pose("yeti",.pickUp)},update:{r,t in r.reach("yeti",to:Vec(r.custom["landX"] ?? r.opposite(155).x,r.custom["landY"] ?? r.spot(-155,-12).y),fraction:t/1.7)},leave:{r in r.carry("victim",by:"yeti");r.contact("yeti-recovers-box",prop:"victim",actor:"yeti")})
  if variant==0 {
   outcome="After his tumble, Yeti returns the present (70%)"
   walk("a-reluctant-return",2.5,goals:["yeti":Vec(approachX,manager.groundY(approachX,display:display,surfaces:surfaces))],pose:.carry)
   beat("put-the-present-back",1.4,enter:{$0.pose("yeti",.putDown);$0.pose("elf0",.angry)},update:{r,t in r.reach("yeti",to:giftPoint,fraction:t/1.4)},leave:{r in r.release("victim",at:giftPoint)})
   beat("an-embarrassed-bow",1.4,enter:{$0.pose("yeti",.bow);$0.pose("elf1",.point)})
   leaveTogether(["yeti","elf0","elf1"],duration:2.5)
  }else{
   outcome="Yeti recovers the box and escapes (30%)"
   walk("the-great-escape",2.2,goals:["yeti":opposite(225)],pose:.carry)
   beat("too-late",1.5,enter:{$0.pose("elf0",.surprised);$0.pose("elf1",.angry)},update:{r,t in r.actors["yeti"]?.actor.node.alpha=1-clamp(t/1.5,0,1)},leave:{r in r.actors["yeti"]?.active=false})
   if settings.keepDecorations {beat("count-the-missing-present",1.1,leave:{r in r.state.treePresents.removeAll{$0.id==r.stage.giftID};r.custom["stolen"]=1})}
   else{beat("a-replacement-from-the-sack",1.4,enter:{r in _=r.add("spare","story_present_red",height:24);r.carry("spare",by:"elf0")});walk("deliver-the-spare",2,goals:["elf0":spot(30),"elf1":spot(78)],pose:.carry);beat("replace-the-lost-present",1.4,enter:{$0.pose("elf0",.putDown)},leave:{r in r.release("spare",at:giftPoint);r.props["victim"]?.isHidden=true})}
   leaveTogether(["elf0","elf1"],duration:2.5)
  }
 }
}
