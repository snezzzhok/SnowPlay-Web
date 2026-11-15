import AppKit
import SpriteKit
import SnowCore
extension ChristmasStoryRuntime {
    func planSnowmanBuild(){
        spawn("elf0",color:"green",at:spot(175));spawn("elf1",color:"blue",at:opposite(175))
        walk("choose-the-building-spot",2.5,goals:["elf0":spot(65),"elf1":opposite(65)])
        for i in 0..<3 {
            let actor=i==1 ? "elf1":"elf0",radius=StorySnowmanRecipe.radii[i],duration=i==0 ? 3.8:i==1 ? 3.3:2.8
            let start=spot((i==1 ? -1:1)*(95-Double(i)*14)),end=spot(Double(i-1)*24)
            let pushingOffset=stage.side*(i==1 ? -1:1)*23
            walk("approach-ball-\(i+1)",1.2,goals:[actor:start+Vec(pushingOffset,0)],pose:.walk)
            beat("roll-ball-\(i+1)",duration,enter:{r in
                r.pose(actor,.makeSnowball);let ball=Snowball(position:start,radius:4);r.visualSnowballs.append(ball)
                _=r.add("ball\(i)","snowball_medium",height:8,at:start);r.props["ball\(i)"]?.alpha=0
                r.custom["ballMass\(i)"]=0;r.custom["ballTarget\(i)"]=Double.pi*radius*radius
            },update:{r,t in
                let f=clamp(t/duration,0,1),point=start+(end-start)*f,key="ground-"+r.display.id,target=Double.pi*radius*radius,previous=r.custom["ballMass\(i)"] ?? 0,requested=max(0,target*f-previous)
                let got=r.surfaces.surfaces[key]?.extract(volume:requested,at:(point.x-r.display.rect.x)/r.display.rect.width) ?? 0,mass=previous+got
                r.custom["ballMass\(i)"]=mass;r.takenMass+=got
                let actual=sqrt(max(0,mass)/Double.pi)
                if i<r.visualSnowballs.count {r.visualSnowballs[i].position=Vec(point.x,r.manager.groundY(point.x,display:r.display,surfaces:r.surfaces)-actual);r.visualSnowballs[i].radius=max(4,actual);r.visualSnowballs[i].rotation=(point.x-start.x)/max(4,actual)}
                if let node=r.props["ball\(i)"] {node.alpha=actual>=4 ? 1:0;node.setScale(actual/4/0.84);node.position=r.display.local(r.visualSnowballs[i].position);node.zRotation = -r.visualSnowballs[i].rotation}
                if let elf=r.actors[actor] {let offset=r.stage.side*(i==1 ? -1:1)*23;elf.position=Vec(point.x+offset,r.manager.groundY(point.x+offset,display:r.display,surfaces:r.surfaces));elf.target=elf.position;elf.facing=offset>0 ? -1:1;elf.actor.node.position=r.display.local(elf.position);elf.actor.storyRig?.lowering=5;elf.actor.pose(.walk,time:elf.poseTime,facing:elf.facing);r.pose(actor,.walk)
                    let contactPoint=r.visualSnowballs[i].position+Vec(offset>0 ? actual:-actual,0)
                    r.reach(actor,to:contactPoint,fraction:1)
                    r.custom["rollingHandErrorPt"]=max(r.custom["rollingHandErrorPt"] ?? 0,(r.actorHand(actor)-contactPoint).length)
                }
            },leave:{r in
                r.actors[actor]?.actor.storyRig?.lowering=0
                let required=Double.pi*radius*radius,current=r.custom["ballMass\(i)"] ?? 0,key="ground-"+r.display.id
                let got=r.surfaces.surfaces[key]?.extract(volume:max(0,required-current),at:(end.x-r.display.rect.x)/r.display.rect.width) ?? 0;r.takenMass+=got;r.custom["ballMass\(i)"]=current+got
                if current+got<required-0.05 {r.interrupt("Not enough snow to finish the ball")}else{r.visualSnowballs[i].radius=radius}
            })
        }
        walk("ready-to-lift",1.2,goals:["elf0":spot(38),"elf1":opposite(38)],pose:.carry)
        let finalHeight=DesktopSnowman(position:stage.focus,radii:StorySnowmanRecipe.radii).height
        let finalCentre=Vec(stage.focus.x,manager.groundY(stage.focus.x,display:display,surfaces:surfaces)-finalHeight*0.441)
        beat("lift-and-stack-three-balls",4.8,enter:{$0.pose("elf0",.lift);$0.pose("elf1",.lift)},update:{r,t in
            for i in 0..<3 {
                guard i<r.visualSnowballs.count,let node=r.props["ball\(i)"] else{continue}
                let start=r.visualSnowballs[i].position,target=finalCentre+Vec(0,([175.0,113,55][i]/256-0.5)*finalHeight),f=clamp((t-Double(i)*1.4)/1.7,0,1),smooth=f*f*(3-2*f),point=start+(target-start)*smooth+Vec(0,-sin(f*Double.pi)*(i==0 ? 3:12))
                node.position=r.display.local(point);let targetRadius=[66.0,49,37][i]/256*finalHeight,radius=StorySnowmanRecipe.radii[i]+(targetRadius-StorySnowmanRecipe.radii[i])*smooth;node.setScale(radius/4/0.84)
                if f>0 && f<1 {r.reach("elf0",to:point+Vec(9,0),fraction:1);r.reach("elf1",to:point+Vec(-9,0),fraction:1)}
            }
        },leave:{r in
            guard r.manager.snowmanCount<5,r.visualSnowballs.count==3 else{r.interrupt("Snowman limit reached");return}
            r.state.snowballs.balls=r.visualSnowballs
            guard r.state.snowballs.assemblePrepared(at:finalCentre) else{r.fail("Could not assemble three balls");return}
            r.createdSnowman=r.state.snowballs.primaryID;r.state.snowmanFloating=true;r.state.snowmanBuiltAt=r.currentNow
            for i in 0..<3 {r.props["ball\(i)"]?.removeFromParent()};r.contact("three-ball-stack",prop:"snowman",actor:"elf0+elf1")
        })
        walk("dress-the-snowman",0.7,goals:["elf0":spot(28),"elf1":opposite(28)])
        beat("a-carrot-nose",1.5,enter:{r in _=r.add("carrot","story_carrot",height:6);r.carry("carrot",by:"elf0")},update:{r,t in r.reach("elf0",to:(r.snowman?.position ?? r.stage.focus)+Vec(0,-14),fraction:t/1.5)},leave:{r in r.props["carrot"]?.removeFromParent();r.snowmanNode?.childNode(withName:"snowman_face")?.isHidden=false;r.snowmanNode?.childNode(withName:"snowman_buttons")?.isHidden=false;r.contact("nose-contact",prop:"carrot",actor:"elf0")})
        beat("a-hat-and-scarf",1.6,enter:{r in _=r.add("newHat","story_party_hat",height:17);r.carry("newHat",by:"elf1")},update:{r,t in r.reach("elf1",to:(r.snowman?.position ?? r.stage.focus)+Vec(0,-25),fraction:t/1.6)},leave:{r in r.props["newHat"]?.removeFromParent();r.snowmanNode?.childNode(withName:"snowman_hat")?.isHidden=false;r.snowmanNode?.childNode(withName:"snowman_scarf")?.isHidden=false;r.contact("hat-contact",prop:"hat",actor:"elf1")})
        if variant==1 {beat("straighten-a-crooked-hat",1.3,update:{r,t in r.snowmanNode?.childNode(withName:"snowman_hat")?.zRotation=0.2*(1-clamp(t/1.3,0,1))})}
        beat("a-new-friend-waves",1.8,enter:{$0.pose("elf0",.celebrate);$0.pose("elf1",.celebrate)},update:{r,t in r.snowmanNode?.zRotation=sin(t*3)*0.06;r.snowmanNode?.childNode(withName:"snowman_arms")?.zRotation=sin(t*5)*0.07},leave:{r in r.snowmanNode?.childNode(withName:"snowman_arms")?.zRotation=0;r.manager.onSnowmanBuilt?(r.display.id);r.outcome="Built from three snowballs using \(Int(r.takenMass)) units of real snow"})
        leaveTogether(["elf0","elf1"])
    }
}
