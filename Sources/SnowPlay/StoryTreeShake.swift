import AppKit
import SpriteKit
import SnowCore
extension ChristmasStoryRuntime {
    func shedBranch(_ index:Int){
        let keys=manager.stories.branchKeys(display.id,surfaces:surfaces)
        guard index<keys.count,let surface=surfaces.surfaces[keys[index]],surface.volume>0 else{return}
        let mass=surfaces.surfaces[keys[index]]?.extract(volume:surface.volume,at:0.5) ?? 0
        guard mass>0 else{return}
        let held=index==0 ? min(10,mass*0.18):0;branchHeldMass+=held;branchHeldOrigin=Vec(clamp(actors["yeti"]?.position.x ?? surface.frame.center.x,surface.frame.x,surface.frame.maxX),surface.frame.y)
        let chunks=(0..<5).map{i->SnowChunk in let p=Vec(surface.frame.x+surface.frame.width*Double(i+1)/6,surface.frame.y);return SnowChunk(p,Vec(Double(i-2)*5,18),(mass-held)/5,fallsToGround:true)}
        manager.onSnowFall?(SnowFallEvent(chunks),display.id);contact("branch-snow-release",prop:keys[index],actor:"yeti")
    }
    func planTreeShake(){
        spawn("yeti",yeti:true,at:opposite(155));spawn("elf0",color:"green",at:spot(85));spawn("elf1",color:"blue",at:spot(133))
        walk("approach-the-snowy-tree",2.1,goals:["yeti":opposite(27)],pose:.walk)
        beat("inspect-the-branches",1.4,enter:{$0.pose("yeti",.point)})
        beat("grip-the-trunk",1.2,enter:{$0.pose("yeti",.carry)},update:{r,t in r.reach("yeti",to:r.stage.focus+Vec(0,-18),fraction:t/1.2);r.actors["yeti"]?.actor.reachOffhand(r.display.local(r.stage.focus+Vec(-r.stage.side*7,-19)),in:r.root)},leave:{$0.contact("trunk-grip",prop:"tree",actor:"yeti")})
        beat("shake-the-branches",3.6,enter:{$0.pose("yeti",.shake)},update:{r,t in
            let envelope=min(1,t/0.5)*min(1,(3.6-t)/0.8);r.state.tree?.zRotation=sin(t*8)*0.075*envelope;r.state.toyImpulse=ProcessInfo.processInfo.systemUptime
            r.reach("yeti",to:r.stage.focus+Vec(sin(t*8)*2,-18),fraction:1);r.actors["yeti"]?.actor.reachOffhand(r.display.local(r.stage.focus+Vec(-r.stage.side*7+sin(t*8)*2,-19)),in:r.root)
            for i in 0..<3 where t>0.8+Double(i)*0.9 && r.custom["shed\(i)"]==nil {r.shedBranch(i);r.custom["shed\(i)"]=1;r.puff(at:r.spot(85+Double(i%2)*48)+Vec(0,-25))}
            if t>1 {r.pose("elf0",.surprised);r.pose("elf1",.brush)}
        },leave:{r in r.state.tree?.zRotation=0
            for name in ["elf0","elf1"] {let cap=Resources.layer("snow_pile_small",size:8);cap.name="snowy-hat";cap.position=CGPoint(x:0,y:42);r.actors[name]?.actor.node.addChild(cap)}
        })
        beat("elves-emerge",1.5,enter:{$0.pose("elf0",.brush);$0.pose("elf1",.brush)},update:{r,t in for name in ["elf0","elf1"] {r.actors[name]?.actor.node.childNode(withName:"snowy-hat")?.alpha=1-clamp(t/2,0,1)}})
        beat("yeti-laughs",1.2,enter:{$0.pose("yeti",.celebrate)},leave:{r in _=r.add("last-clump","snow_clump_0",height:23,at:r.branchHeldOrigin)})
        beat("one-last-clump",1.05,update:{r,t in let from=r.branchHeldOrigin,to=(r.actors["yeti"]?.position ?? r.opposite(27))+Vec(0,-36),f=clamp(t/1.05,0,1);r.props["last-clump"]?.position=r.display.local(Vec(from.x+(to.x-from.x)*f,from.y+(to.y-from.y)*f*f))},leave:{r in
            r.props["last-clump"]?.removeFromParent();r.pose("yeti",.surprised);let cap=Resources.layer("snow_pile_small",size:12);cap.name="head-snow";cap.position=CGPoint(x:0,y:36);r.actors["yeti"]?.actor.node.addChild(cap)
            let point=(r.actors["yeti"]?.position ?? r.stage.focus)+Vec(0,-36);r.puff(at:point);if r.branchHeldMass>0{r.manager.onSnowFall?(SnowFallEvent([SnowChunk(point,Vec(0,15),r.branchHeldMass,fallsToGround:true)]),r.display.id);r.branchHeldMass=0}
        })
        beat("the-surprised-pause",1.2,enter:{$0.pose("yeti",.surprised)})
        beat("not-so-funny-now",1.8,enter:{$0.pose("yeti",.brush);$0.pose("elf0",.celebrate);$0.pose("elf1",.celebrate)},update:{r,t in r.actors["yeti"]?.actor.node.childNode(withName:"head-snow")?.alpha=1-clamp(t/1.8,0,1)})
        beat("fix-the-decorations",1.2,enter:{$0.pose("elf0",.repair);$0.pose("elf1",.point)},leave:{r in r.state.toyImpulse=0;r.outcome="Tree kept in place; branch snow returned to ground physics"})
        leaveTogether(["yeti","elf0","elf1"],duration:2.0)
    }
}
