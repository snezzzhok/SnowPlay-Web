import AppKit
import SpriteKit
import SnowCore
extension ChristmasStoryRuntime {
    func santaFlight(_ seconds:Double){
        guard let santa=props["santa"] else{return}
        let f=clamp(seconds/7,0,1),area=stage.area,x=area.x+70+(area.width-200)*f,y=area.y+60+sin(f*Double.pi)*24
        santa.position=display.local(Vec(x,y));santa.zRotation = -atan(cos(f*Double.pi)*24*Double.pi/max(1,area.width-140))*0.6+sin(seconds*2)*0.018
        santa.alpha=min(1,f*8)*min(1,(1-f)*9)
        santa.childNode(withName:"gift_sack")?.zRotation=sin(seconds*2)*0.04
        for i in 0..<2 {if let deer=santa.childNode(withName:"deer\(i)") {deer.position.y=4+sin(seconds*5+Double(i))*2;for j in 0..<4 {deer.childNode(withName:"leg\(j)")?.zRotation=sin(seconds*6+Double(j)*2)*0.35}}}
    }
    func planSantaDrop(){
        let santa=Resources.object(["sleigh","gift_sack","santa_character"],size:60);santa.name="santa";root.addChild(santa);props["santa"]=santa
        for i in 0..<2 {let deer=Resources.layer("story_reindeer",size:27);deer.name="deer\(i)";deer.position=CGPoint(x:42+Double(i)*37,y:4);santa.addChild(deer)
            for j in 0..<4 {let leg=Resources.layer("story_reindeer_leg",size:12);leg.name="leg\(j)";AssetManager.shared.pivot(leg,at:CGPoint(x:0.5,y:0.9));leg.position=CGPoint(x:Double(j%2)*13-7,y:-8);leg.zPosition=j<2 ? -1:1;deer.addChild(leg)}
        }
        santaFlight(0) // Position and hide the sleigh before the first visible frame.
        let landing=spot(120,-10),destination=giftSlot(0)
        _=add("fallen-present","story_present_red",height:27);props["fallen-present"]?.isHidden=true
        beat("santa-over-the-scene",2.8,update:{$0.santaFlight($1)},leave:{r in
            let p=r.props["santa"]!.convert(CGPoint(x:-7,y:7),to:r.root),from=Vec(r.display.rect.x+p.x,r.display.rect.maxY-p.y)
            r.projectile=Projectile(from:from,to:landing,duration:1.5,gravity:260);r.projectileTime=0;r.props["fallen-present"]?.position=r.display.local(from);r.props["fallen-present"]?.isHidden=false;r.custom["giftFromX"]=from.x;r.custom["giftFromY"]=from.y;r.contact("sack-release",prop:"fallen-present",actor:"santa")
        })
        beat("a-present-tumbles",1.6,update:{r,t in
            r.santaFlight(2.8+t)
            if let path=r.projectile {r.props["fallen-present"]?.position=r.display.local(path.position(t));r.props["fallen-present"]?.zRotation=sin(min(1,t/1.5)*Double.pi)*0.7}
        },leave:{r in r.projectile=nil;r.release("fallen-present",at:landing);r.puff(at:landing);r.spawn("elf0",color:"green",at:r.spot(205));r.spawn("elf1",color:"blue",at:r.spot(253))})
        beat("what-was-that",1.6,enter:{$0.pose("elf0",.surprised);$0.pose("elf1",.point)},update:{$0.santaFlight(4.4+$1)})
        let left=Vec(landing.x-25,manager.groundY(landing.x-25,display:display,surfaces:surfaces)),right=Vec(landing.x+25,manager.groundY(landing.x+25,display:display,surfaces:surfaces))
        let leftName=stage.side>0 ? "elf0":"elf1",rightName=stage.side>0 ? "elf1":"elf0"
        walk("inspect-the-fallen-box",2.2,goals:[leftName:left,rightName:right])
        beat("lift-together",1.4,enter:{r in r.props["santa"]?.removeFromParent();r.pose(leftName,.lift);r.pose(rightName,.lift)},update:{r,t in r.reach(leftName,to:landing+Vec(-10,0),fraction:t/1.4);r.reach(rightName,to:landing+Vec(10,0),fraction:t/1.4)},leave:{r in r.sharedCarry("fallen-present",left:leftName,right:rightName)})
        walk("carry-it-home",2.8,goals:[leftName:Vec(destination.x-25,destination.y+10),rightName:Vec(destination.x+25,destination.y+10)],pose:.carry)
        beat("a-safe-delivery",1.4,enter:{$0.pose(leftName,.putDown);$0.pose(rightName,.putDown)},update:{r,t in
            let f=clamp(t/1.4,0,1);r.pairCarry=nil;r.props["fallen-present"]?.position=r.display.local(destination+Vec(0,-(1-f)*14));r.reach(leftName,to:destination+Vec(-10,0),fraction:1);r.reach(rightName,to:destination+Vec(10,0),fraction:1)
        },leave:{r in r.release("fallen-present",at:destination);r.persistentGifts=[("red",destination)];r.outcome="Santa’s present recovered by two elves"})
        beat("a-proud-little-bow",1.4,enter:{$0.pose(leftName,.bow);$0.pose(rightName,.bow)})
        leaveTogether(["elf0","elf1"])
    }
}
