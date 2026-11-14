import AppKit
import SpriteKit
import SnowCore
struct TreePresent {
    var id=UUID().uuidString
    var node:SKNode
    var position:Vec
    var openedAt:Double?
    var placedAt:Double
}
extension DecorationManager {
    func treeHeight(_ config:Configuration)->Double {config.treeSize == "small" ? 88:config.treeSize == "large" ? 188:132}
    func groundY(_ x:Double,display d:DisplayOverlay,surfaces:SurfaceManager)->Double {
        guard let ground=surfaces.surfaces["ground-"+d.id] else{return d.rect.maxY-3}
        return ground.frame.y-ground.height(at:(x-d.rect.x)/d.rect.width)
    }
    func updateFloorTree(state s:DecorationState,display d:DisplayOverlay,config:Configuration,now:Double,surfaces:SurfaceManager,windows:[TrackedWindow]) {
        if let delivery=s.living.delivery,!delivery.installed {return}
        let key=[config.treeSize,config.treeStar,config.treeBalls,config.treeGarland].joined(separator:"|")
        if config.tree,!s.treeRemoving,s.treeStyleKey != key {
            s.tree?.removeFromParent();s.tree=nil;s.builtTree=false;s.toyNodes=[:];s.treeStyleKey=key
        }
        s.treeHeight=treeHeight(config)
        if config.tree,config.placements[d.id]?.tree != nil,!s.builtTree {
            let tree=Resources.object(["tree_stem","tree_bare"],size:s.treeHeight)
            if config.treeBalls != "none" {tree.addChild(Resources.layer("tree_balls_"+config.treeBalls,size:s.treeHeight))}
            if config.treeGarland != "none" {let lights=Resources.layer("tree_string_"+config.treeGarland,size:s.treeHeight);lights.name="tree-lights";lights.zPosition=5;tree.addChild(lights)}
            if config.treeStar != "none" {let star=Resources.layer("tree_topper_"+config.treeStar,size:s.treeHeight);star.name="tree-topper";star.zPosition=6;tree.addChild(star)}
            s.tree=tree;s.root.addChild(tree);s.builtTree=true;s.treeAppearedAt=now
        }
        if !config.tree && !s.treeRemoving {s.tree?.removeFromParent();s.tree=nil;s.builtTree=false;s.toyNodes=[:];surfaces.surfaces.removeValue(forKey:"tree-"+d.id)}
        guard let node=s.tree,!s.treeFalling,let saved=config.placements[d.id]?.tree else{return}
        let x=clamp(d.rect.x+saved.x*d.rect.width,d.rect.x+s.treeHeight*0.42,d.rect.maxX-s.treeHeight*0.42)
        let p=Vec(x,groundY(x,display:d,surfaces:surfaces)-s.treeHeight*0.38)
        node.position=d.local(p)
        let appearance=WinterMotion.appearance(elapsed:now-s.treeAppearedAt)
        node.alpha=config.reducedMotion ? 1:appearance.opacity;node.setScale(config.reducedMotion ? 1:appearance.scale)
        node.isHidden=windows.contains{$0.isVisible && $0.frame.intersects(Rect(p.x-s.treeHeight*0.33,p.y-s.treeHeight*0.4,s.treeHeight*0.66,s.treeHeight*0.8))}
        node.zRotation=config.reducedMotion ? 0:sin(now*0.65)*config.windStrength*0.012
        node.childNode(withName:"tree-topper")?.alpha=config.reducedMotion ? 1:0.91+sin(now*0.8)*0.09
        node.childNode(withName:"tree-lights")?.alpha=config.reducedMotion ? 1:0.92+sin(now*0.9)*0.08
    }
    func addTreePresents(display d:DisplayOverlay,surfaces:SurfaceManager,now:Double=ProcessInfo.processInfo.systemUptime) {
        guard let s=states[d.id],let tree=s.tree else{return}
        for gift in s.treePresents {gift.node.removeFromParent()};s.treePresents=[]
        let x=d.rect.x+tree.position.x
        for (i,offset) in [-34.0,0,34].enumerated() {
            let p=Vec(x+offset,groundY(x+offset,display:d,surfaces:surfaces)-50*(216.5/256-0.5))
            let node=SKNode(),box=Resources.object(["gift_box","gift_lid","gift_bow"],size:50);box.name="package";node.addChild(box);node.position=d.local(p);s.root.addChild(node)
            node.alpha=0;node.setScale(0.8)
            s.treePresents.append(TreePresent(node:node,position:p,placedAt:now+Double(i)*0.1))
        }
    }
    func tripleFireworks(parent:SKNode,reduced:Bool,now:Double) {
        fireworks.removeAll{$0.parent==nil || $0.scene==nil}
        guard fireworks.isEmpty else{return}
        for (i,id) in ["firework_gold","firework_pink","firework_blue"].enumerated() {
            let burst=Resources.layer(id,size:82);burst.name="firework";burst.position=CGPoint(x:Double(i-1)*30,y:28+Double(i%2)*15);burst.alpha=0;burst.setScale(0.12)
            burst.userData?["born"]=now+Double(i)*0.14;burst.userData?["x"]=burst.position.x;burst.userData?["y"]=burst.position.y;burst.userData?["reduced"]=reduced
            parent.addChild(burst);fireworks.append(burst)
        }
    }
    func updateFloorObjects(state s:DecorationState,display d:DisplayOverlay,now:Double,dt:Double,config:Configuration,surfaces:SurfaceManager) {
        // SpriteKit's // search starts at the scene, including thousands of weather sprites.
        // Keep direct references to the three active bursts instead of scanning that tree.
        fireworks.removeAll{$0.parent==nil || $0.scene==nil}
        for node in fireworks where node.scene === s.root.scene {
            guard let born=node.userData?["born"] as? Double else{continue}
            let t=now-born,reduced=(node.userData?["reduced"] as? Bool) ?? false
            if t<0 {node.alpha=0;continue};if t>1.6 {node.removeFromParent();continue}
            let f=clamp(t/0.6,0,1),ease=1-pow(1-f,3)
            node.setScale(reduced ? 0.45:0.12+ease*0.88);node.alpha=min(1,t/0.12)*(1-clamp((t-0.55)/1.05,0,1))*(reduced ? 0.45:0.9)
            node.position.y=(node.userData?["y"] as? Double ?? 28)+(reduced ? 0:ease*24)
        }
        for i in s.treePresents.indices {
            let gift=s.treePresents[i]
            if gift.openedAt==nil && !s.treeFalling {
                let f=clamp((now-gift.placedAt)/0.45,0,1),ease=1-pow(1-f,3)
                gift.node.alpha=f;gift.node.setScale(0.8+0.2*ease)
                gift.node.position=d.local(gift.position+Vec(0,-(1-ease)*10-sin(f*Double.pi)*2))
            }
            if let opened=gift.openedAt {
                let t=now-opened
                gift.node.childNode(withName:"package/gift_lid")?.position.y=min(22,t*40)
                gift.node.childNode(withName:"package")?.alpha=1-clamp((t-1.8)/0.7,0,1)
                if t>3 {gift.node.removeFromParent()}
            }
        }
        s.treePresents.removeAll{$0.openedAt.map{now-$0>3} ?? false}
        // Legacy castle fields now hold a tiny wall of two ordinary snow clumps.
        if let began=s.castleBuildStarted {s.castleProgress=clamp((now-began)/1.4,0,1);if s.castleProgress>=1 {s.castleBuildStarted=nil}}
        if let base=s.castleBase,let image=AssetManager.shared.image("snowball_medium") {
            let radius=5.5,size=radius*128/47
            for i in 0..<2 {
                let elapsed=s.castleProgress*1.4-Double(i)*0.65
                guard elapsed>=0 else{continue}
                let f=clamp(elapsed/0.55,0,1),ease=1-pow(1-f,3)
                let x=base.x+Double(i)*9-4.5-(1-ease)*8
                let p=d.local(Vec(x,groundY(x,display:d,surfaces:surfaces)-radius-sin(f*Double.pi)*1.2))
                d.canvas.reveals.append(CanvasReveal(image:image,rect:CGRect(x:p.x-size/2,y:p.y-size/2,width:size,height:size),progress:1))
            }
        }
        for gift in s.treePresents {gift.node.isHidden=false;appendSprites(from:gift.node,reference:s.root,to:d.canvas);gift.node.isHidden=true}
    }
}
