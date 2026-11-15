import AppKit
import SpriteKit
import SnowCore
extension ChristmasStoryRuntime {
    func installPartyStyle(_ node:SKNode,name:String,to point:CGPoint){
        guard let snowman=snowmanNode else{return}
        for old in snowman.children where old.name==name {old.removeFromParent();replacedPartyStyles.append(old)}
        node.removeFromParent();node.name=name;snowman.addChild(node);node.position=point;installedPartyNodes.append(node)
    }
    func attachParty(_ key:String,to point:CGPoint){
        guard let node=props[key],snowmanNode != nil else{return};installPartyStyle(node,name:"story-party-"+key,to:point);contact("decorate-contact",prop:key,actor:"snowman")
    }
    func dancingSnowmen(_ t:Double,jumps:Bool=false){
        for m in state.snowballs.snowmen where stage.area.contains(m.position) {
            guard let node=state.snowmanVisualID==m.id ? state.snowmanNode:state.extraSnowmanNodes[m.id] else{continue}
            if !extraPartyRest.contains(where:{$0.0 === node}) {extraPartyRest.append((node,node.position,node.zRotation,node.children.map{($0,$0.zRotation)}))}
            if node.childNode(withName:"party-left-arm")==nil {
                if let old=node.childNode(withName:"snowman_arms"){extraPartyVisibility.append((old,old.isHidden));old.isHidden=true}
                for (side,x,y) in [("left",80.0,131.0),("right",177.0,130.0)] {
                    let arm=Resources.layer("story_rig_snowman_"+side,size:m.height);AssetManager.shared.pivot(arm,at:CGPoint(x:x/256,y:1-y/256));arm.name="party-"+side+"-arm";arm.zPosition=7;node.addChild(arm);temporaryNodes.append(arm)
                }
            }
            let phase=t+(m.id==stage.snowmanID ? 0:0.2),hop=jumps ? pow(max(0,sin(phase*Double.pi*1.8)),1.5)*8:0,p=display.local(m.position)
            node.position=CGPoint(x:p.x+sin(phase*3)*3,y:p.y+hop);node.zRotation=sin(phase*3)*(jumps ? 0.06:0.13)
            node.childNode(withName:"snowman_ball_head")?.zRotation=sin(phase*2.2)*0.1
            node.childNode(withName:"party-left-arm")?.zRotation=sin(phase*4)*0.35
            node.childNode(withName:"party-right-arm")?.zRotation = -sin(phase*4+0.7)*0.35
        }
    }
    func planSnowmanParty(){
        spawn("elf0",color:"red",at:spot(190));spawn("elf1",color:"blue",at:opposite(190))
        _=add("hat","story_party_hat",height:18);_=add("scarf","story_scarf",height:9);carry("hat",by:"elf0");carry("scarf",by:"elf1")
        let h=snowman?.height ?? 56,ladderHeight=max(30,h*0.65),lift=max(0,min(ladderHeight*0.72,h*0.84-30)),ladderBase=spot(32)
        walk("the-party-arrives",2.8,goals:["elf0":spot(32),"elf1":opposite(35)],pose:.carry)
        if variant==1 {
            beat("a-dropped-star",1.1,enter:{r in _=r.add("star","story_star",height:8,at:r.opposite(40)+Vec(0,-6));r.pose("elf1",.surprised)})
            beat("pick-it-up-again",1.1,enter:{$0.pose("elf1",.pickUp)},leave:{r in r.carry("star",by:"elf1")})
        }
        if lift>5 {
            beat("a-little-step-up",1.6,enter:{r in _=r.add("party-ladder","story_ladder",height:ladderHeight,at:ladderBase+Vec(0,-ladderHeight/2))},update:{r,t in if let elf=r.actors["elf0"] {let step=clamp(t/1.6,0,1)*3,rung=floor(step),f=step-rung;elf.position=ladderBase+Vec(0,-lift*(rung+f*f*(3-2*f))/3);elf.target=elf.position;r.pose("elf0",.climb)}})
        }
        beat("a-festive-hat",1.7,enter:{$0.pose("elf0",.lift)},update:{r,t in let p=(r.snowman?.position ?? r.stage.focus)+Vec(0,-(r.snowman?.height ?? 56)*0.4);r.reach("elf0",to:p,fraction:t/1.7)},leave:{r in
            let h=r.snowman?.height ?? 56;r.attachParty("hat",to:CGPoint(x:0,y:h*0.38));r.snowmanNode?.childNode(withName:"snowman_hat")?.alpha=0
        })
        if lift>5 {
            beat("back-to-the-snow",1.5,update:{r,t in if let elf=r.actors["elf0"] {elf.position=ladderBase+Vec(0,-lift*(1-clamp(t/1.5,0,1)));elf.target=elf.position;r.pose("elf0",.climb)}},leave:{r in r.props["party-ladder"]?.removeFromParent()})
        }
        beat("a-warm-scarf",1.7,enter:{$0.pose("elf1",.repair)},update:{r,t in r.reach("elf1",to:(r.snowman?.position ?? r.stage.focus),fraction:t/1.7)},leave:{r in let h=r.snowman?.height ?? 56;r.attachParty("scarf",to:CGPoint(x:0,y:h*0.03))})
        beat("tiny-party-lights",2.0,enter:{r in
            guard r.snowmanNode != nil else{return}
            let lights=StoryDecorationsArt.partyLights(height:r.snowman?.height ?? 56)
            r.installPartyStyle(lights,name:"story-party-lights",to:.zero)
            r.contact("decorate-contact",prop:"party-lights",actor:"elf1")
        },update:{r,t in r.snowmanNode?.childNode(withName:"story-party-lights")?.alpha=min(1,t/2)})
        beat("side-step-and-turn",3.6,enter:{$0.pose("elf0",.dance);$0.pose("elf1",.dance)},update:{r,t in r.dancingSnowmen(t)})
        beat("two-snowy-hops",3.6,enter:{$0.pose("elf0",.celebrate);$0.pose("elf1",.dance)},update:{r,t in r.dancingSnowmen(t,jumps:true)})
        beat("everyone-waves",2.0,enter:{$0.pose("elf0",.point);$0.pose("elf1",.celebrate)},update:{r,t in r.dancingSnowmen(t)})
        beat("the-grand-finale",2.2,enter:{$0.pose("elf0",.bow);$0.pose("elf1",.bow)},update:{r,t in r.snowmanNode?.childNode(withName:"story-party-lights")?.alpha=0.88+sin(t*1.4)*0.12},leave:{r in r.snowmanNode?.childNode(withName:"snowman_arms")?.zRotation=0;r.snowmanNode?.childNode(withName:"snowman_ball_head")?.zRotation=0;r.outcome=r.settings.keepDecorations ? "Party decorations kept":"Temporary party decorations cleaned up"})
        leaveTogether(["elf0","elf1"])
    }
}
