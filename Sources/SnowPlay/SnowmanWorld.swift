import AppKit
import SpriteKit
import SnowCore
extension DecorationManager {
    var snowmanCount:Int {states.values.reduce(0){$0+$1.snowballs.snowmen.count}}
    func syncSnowmanVisuals(state s:DecorationState,display d:DisplayOverlay,now:Double,surfaces:SurfaceManager,reduced:Bool,occupied:[Rect]){
        let live=Set(s.snowballs.snowmen.map(\.id))
        if s.snowmanVisualID != s.snowballs.primaryID {
            if let old=s.snowmanVisualID,let node=s.snowmanNode {if live.contains(old){
                if !s.snowmanFinalized {for child in node.children {if let name=child.name,let target=s.assemblyTargets[name] {child.removeAllActions();child.alpha=1;child.setScale(1);child.position=target}}}
                s.extraSnowmanNodes[old]=node
            }else{node.removeFromParent()}}
            s.snowmanVisualID=s.snowballs.primaryID;s.snowmanNode=s.extraSnowmanNodes.removeValue(forKey:s.snowballs.primaryID);s.snowmanLocation=nil
            if s.snowmanNode != nil {s.snowmanFinalized=true}
        }
        for id in Array(s.extraSnowmanNodes.keys) where !live.contains(id){s.extraSnowmanNodes.removeValue(forKey:id)?.removeFromParent()}
        for i in s.snowballs.additionalSnowmen.indices {
            var m=s.snowballs.additionalSnowmen[i];m.position.y=groundY(m.position.x,display:d,surfaces:surfaces)-m.height*0.441;s.snowballs.additionalSnowmen[i]=m
            let node:SKNode
            if let old=s.extraSnowmanNodes[m.id]{node=old}else{node=Resources.object(["snowman_ball_base","snowman_ball_middle","snowman_ball_head","snowman_arms","snowman_face","snowman_buttons","snowman_scarf","snowman_hat"],size:m.height);let closed=Resources.layer("snowman_face_closed",size:m.height);closed.name="snowman-face-closed";closed.zPosition=4.1;closed.isHidden=true;node.addChild(closed);node.zPosition=25;s.root.addChild(node);s.extraSnowmanNodes[m.id]=node}
            let blink = !reduced && (now+Double(i)*0.35).truncatingRemainder(dividingBy:4.7)>4.55
            node.childNode(withName:"snowman_face")?.isHidden=blink;node.childNode(withName:"snowman-face-closed")?.isHidden = !blink
            node.position=d.local(m.position);node.zRotation=reduced ? 0:sin(now*0.7)*0.015
            if foregroundSnowmen {appendSprites(from:node,reference:s.root,to:d.actionCanvas)};node.isHidden=foregroundSnowmen || occupied.contains{ $0.intersects(m.hitbox) }
        }
    }
    @discardableResult func destroySnowman(_ id:UUID,state s:DecorationState,display d:DisplayOverlay)->Bool {
        guard let m=s.snowballs.remove(id) else{return false}
        let radii=m.radii.count==3 ? m.radii:[12,9,6]
        s.fragments += radii.enumerated().map{i,r in SnowmanFragment(p:m.position+Vec(0,([175.0,113,55][i]/256-0.5)*m.height),v:Vec(Double(i-1)*55,-65-Double(i)*17),radius:[66.0,49,37][i]/256*m.height,mass:Double.pi*r*r)}
        if s.snowmanVisualID==id {s.snowmanNode?.removeFromParent();s.snowmanNode=nil;s.snowmanLocation=nil}
        s.extraSnowmanNodes.removeValue(forKey:id)?.removeFromParent();onDust?(m.position,d.id);onSnowmanRemoved?(d.id);return true
    }
    func updateSnowballPlay(state s:DecorationState,display d:DisplayOverlay,dt:Double,surfaces:SurfaceManager){
        let events=s.snowballPlay.step(dt,bounds:d.rect,targets:s.snowballs.snowmen,ground:{self.groundY($0,display:d,surfaces:surfaces)})
        for e in events {
            switch e {
            case .hit(let id,let point,let mass):_ = destroySnowman(id,state:s,display:d);onSnowFall?(SnowFallEvent([SnowChunk(point,Vec(0,20),mass,fallsToGround:true)]),d.id)
            case .land(let point,let mass):onSnowFall?(SnowFallEvent([SnowChunk(point,Vec(0,12),mass,fallsToGround:true)]),d.id)
            }
        }
        for b in s.snowballPlay.balls {guard let image=AssetManager.shared.image("snowball_medium") else{continue};let p=d.local(b.position),size=b.radius*2/0.84
            d.actionCanvas.composites.append(CanvasSprite(image:image,rect:CGRect(x:-size/2,y:-size/2,width:size,height:size),transform:CGAffineTransform(translationX:p.x,y:p.y),alpha:1))
        }
    }
}
extension WinterCoordinator {
    func beginSnowballPlay(){
        guard !paused,!sleeping,config.mode != .focus,!decorations.livingBusy else{return}
        beginEditor(.snowballPlay);diagnostic="Move through snow to roll a ball. Grab, flick and release to throw. Esc to finish.";statusChanged?()
    }
    func finishSnowballPlay(){for (id,s) in decorations.states {for (p,mass) in s.snowballPlay.cancel(){queueSnow(SnowFallEvent([SnowChunk(p,Vec(0,8),mass,fallsToGround:true)]),displayID:id)}}}
    func snowballPlayInput(_ event:String,p:Vec,display d:DisplayOverlay){
        guard input.mode == .snowballPlay,let s=decorations.states[d.id] else{return};let now=ProcessInfo.processInfo.systemUptime
        if event.hasSuffix(":down"){_ = s.snowballPlay.grab(at:p,now:now)}
        else if event.hasSuffix(":drag"){s.snowballPlay.drag(to:p,now:now)}
        else if event.hasSuffix(":up"){s.snowballPlay.release(at:p,now:now)}
        else if event.hasSuffix(":hover") {
            guard let stock=surfaces.surfaces["ground-"+d.id],abs(p.y-stock.frame.y)<stock.maxHeight+18 else{return}
            let point=Vec(p.x,stock.frame.y-stock.height(at:(p.x-stock.frame.x)/stock.length))
            var play=s.snowballPlay
            play.gather(at:point){amount in self.surfaces.surfaces[stock.id]?.extract(volume:amount,at:(p.x-stock.frame.x)/stock.length) ?? 0}
            s.snowballPlay=play
        }
    }
}
