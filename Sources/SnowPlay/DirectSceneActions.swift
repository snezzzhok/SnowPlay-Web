import AppKit
import SpriteKit
import SnowCore

// Direct actions replace the former actor visits. Each target owns one clock;
// repeated commands cannot restart a fall or create a second projectile.
extension DecorationManager {
    @discardableResult func cutTree(display d:DisplayOverlay,surfaces:SurfaceManager)->Bool {
        guard let s=states[d.id],let tree=s.tree,!s.treeRemoving else{return false}
        let pivot=SKNode();pivot.name="tree-fall";pivot.position=CGPoint(x:tree.position.x,y:tree.position.y-s.treeHeight*0.38)
        s.root.addChild(pivot);tree.removeFromParent();tree.position=CGPoint(x:0,y:s.treeHeight*0.38);tree.zRotation=0;pivot.addChild(tree)
        s.treeRemoving=true;s.treeFalling=true;s.directTreeElapsed=0
        if let snow=surfaces.surfaces.removeValue(forKey:"tree-"+d.id),snow.volume>0 {onSnowFall?(SnowFallEvent([SnowChunk(Vec(d.rect.x+pivot.position.x,d.rect.maxY-pivot.position.y),Vec(0,20),snow.volume,fallsToGround:true)]),d.id)}
        return true
    }
    @discardableResult func throwAtSnowman(display d:DisplayOverlay)->Bool {
        guard let s=states[d.id],let target=s.snowballs.snowman,s.directShotElapsed == nil else{return false}
        let from=Vec(max(d.rect.x+12,target.x-min(260,d.rect.width*0.5)),target.y+24)
        s.projectilePath=Projectile(from:from,to:target+Vec(0,-7),gravity:650);s.directShotElapsed=0
        let ball=Resources.layer("snowball_small",size:9);s.projectile=ball;s.root.addChild(ball)
        return true
    }
    func updateDirectActions(state s:DecorationState,display d:DisplayOverlay,dt:Double,surfaces:SurfaceManager,reduced:Bool) {
        if let elapsed=s.directTreeElapsed {
            let t=elapsed+dt;s.directTreeElapsed=t
            let f=clamp(t/(reduced ? 0.25:1.1),0,1),pivot=s.root.childNode(withName:"tree-fall")
            pivot?.zRotation=pow(f,2)*1.62;pivot?.alpha=1-clamp((f-0.85)/0.15,0,1)
            if f>=1 {pivot?.removeFromParent();s.tree=nil;s.builtTree=false;s.toyNodes=[:];s.directTreeElapsed=nil;s.treeRemoving=false;s.treeFalling=false}
        }
        if let elapsed=s.directShotElapsed {
            let t=elapsed+dt;s.directShotElapsed=t
            if let path=s.projectilePath {s.projectile?.position=d.local(path.position(min(t,0.65)))}
            if let ball=s.projectile {appendSprites(from:ball,reference:s.root,to:d.canvas);ball.isHidden=true}
            if t>=0.65 {
                _=destroySnowman(s.snowballs.primaryID,state:s,display:d)
                s.projectile?.removeFromParent();s.projectile=nil;s.projectilePath=nil;s.directShotElapsed=nil
            }
        }
    }
}
