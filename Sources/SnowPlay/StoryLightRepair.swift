import AppKit
import SpriteKit
import SnowCore
extension ChristmasStoryRuntime {
    func repairLights(_ alpha:Double){custom["repairDim"]=alpha;state.tree?.childNode(withName:"tree-lights")?.alpha=alpha}
    func planLightRepair(){
        spawn("elf0",color:"green",at:spot(180));spawn("elf1",color:"blue",at:spot(228))
        let belt=Resources.layer("story_toolbelt",size:7);belt.position=CGPoint(x:0,y:18);actors["elf0"]?.actor.node.addChild(belt)
        let wire=state.tree!.convert(CGPoint(x:state.treeHeight*(145.0/256-0.5),y:state.treeHeight*(0.5-104.0/256)),to:state.root),repairPoint=Vec(display.rect.x+wire.x,display.rect.maxY-wire.y),base=Vec(repairPoint.x+stage.side*21,manager.groundY(repairPoint.x+stage.side*21,display:display,surfaces:surfaces)),groundRepair=state.treeHeight<100
        let lift=groundRepair ? 0:max(0,base.y-repairPoint.y-24),ladderHeight=max(38,lift/0.72)
        actors["elf0"]?.actor.node.zPosition=10;actors["elf1"]?.actor.node.zPosition=10
        actors["elf0"]?.active=false;actors["elf1"]?.active=false
        _=add("toolbox","story_toolbox",height:19);_=add("ladder","story_ladder",height:ladderHeight)
        let spare=Resources.layer("story_bulb",size:7);spare.position=CGPoint(x:7,y:4);props["toolbox"]?.addChild(spare)
        carry("toolbox",by:"elf0");carry("ladder",by:"elf1")
        beat("the-lights-go-dim",3.0,enter:{r in
            let style=r.state.treeStyleKey.components(separatedBy:"|").last ?? "multi"
            let colors=style=="warm" ? ["gold","gold","gold"]:style=="ice" ? ["blue","purple","blue"]:["red","green","gold"]
            // Three working bulbs keep their own brightness while the other section fails.
            for (i,point) in [Vec(105,104),Vec(111.6667,110.6667),Vec(118.3333,114.6667)].enumerated() {
                let h=r.state.treeHeight/16,node=Resources.layer("fairy_bulb_"+colors[i],size:h)
                node.name="story-repair-live-\(i)";node.zPosition=8;node.position=CGPoint(x:(point.x/256-0.5)*r.state.treeHeight,y:(0.5-point.y/256)*r.state.treeHeight+h*3/52)
                r.state.tree?.addChild(node);r.props["repair-live-\(i)"]=node
            }
        },update:{r,t in r.repairLights(t<1 ? 0.75+sin(t*8)*0.12:0.75-0.6*clamp((t-1)/2,0,1))},leave:{r in r.actors["elf0"]?.active=true;r.actors["elf1"]?.active=true})
        walk("the-repair-crew",2.4,goals:["elf0":base,"elf1":base+Vec(stage.side*40,0)],pose:.carry)
        beat("inspect-the-failed-section",1.4,enter:{$0.pose("elf0",.point);$0.pose("elf1",.surprised)})
        beat("unfold-and-steady",1.5,enter:{$0.pose("elf0",.putDown);$0.pose("elf1",.putDown)},leave:{r in r.release("toolbox",at:r.spot(110,-8));r.release("ladder",at:base+Vec(0,-ladderHeight/2));r.props["ladder"]?.isHidden=groundRepair;r.custom["steady"]=groundRepair ? 0:1;r.custom["ladderX"]=base.x})
        beat("climb-the-rungs",2.8,enter:{r in r.pose("elf1",.carry);r.actors["elf0"]?.climbing=true},update:{r,t in
            guard let elf=r.actors["elf0"] else{return};let progress=clamp(t/2.8,0,1),steps=groundRepair ? 0:4.0,step=progress*steps
            // Every footfall settles on one of the four actual SVG rungs.
            let rung=floor(step),f=step-rung,smooth=f*f*(3-2*f),lift=(rung+smooth)*ladderHeight*0.18
            elf.position=base+Vec(0,-lift);elf.target=elf.position;r.pose("elf0",.climb)
        },leave:{r in r.actors["elf0"]?.climbing=false;_=r.add("tool","story_screwdriver",height:15);r.carry("tool",by:"elf0");r.contact("rung-contact",prop:"ladder",actor:"elf0")})
        beat("repair-the-wire",3.0,enter:{$0.pose("elf0",.repair)},update:{r,t in r.repairLights(0.18+sin(t*2)*0.03);r.reach("elf0",to:repairPoint,fraction:1)})
        beat("a-little-surprise",1.1,enter:{$0.pose("elf0",.surprised)},update:{r,t in r.repairLights(0.6+sin(t*2)*0.07)})
        if variant==1 {beat("one-more-adjustment",1.5,enter:{$0.pose("elf0",.repair)},update:{r,t in r.repairLights(0.7+sin(t*4)*0.12)})}
        beat("lights-restored",1.2,enter:{$0.pose("elf1",.celebrate)},update:{r,t in r.repairLights(0.6+min(1,t/1.2)*0.4)})
        beat("climb-down",2.6,update:{r,t in guard let elf=r.actors["elf0"] else{return};let steps=groundRepair ? 0:4.0,step=(1-clamp(t/2.6,0,1))*steps,rung=floor(step),f=step-rung,lift=(rung+f*f*(3-2*f))*ladderHeight*0.18;elf.position=base+Vec(0,-lift);elf.target=elf.position;r.pose("elf0",.climb)},leave:{r in r.props["tool"]?.removeFromParent()})
        beat("fold-and-pack",1.4,enter:{$0.custom["steady"]=0;$0.pose("elf0",.pickUp);$0.pose("elf1",.pickUp)},update:{r,t in r.props["ladder"]?.xScale=1-0.65*clamp(t/1.4,0,1)},leave:{r in r.carry("toolbox",by:"elf0");r.carry("ladder",by:"elf1");r.props["ladder"]?.xScale=0.35})
        beat("a-job-well-done",1.1,enter:{$0.pose("elf0",.celebrate);$0.pose("elf1",.celebrate)})
        leaveTogether(["elf0","elf1"])
    }
}
