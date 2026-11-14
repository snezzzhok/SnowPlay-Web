import AppKit
import SpriteKit
import SnowCore
extension DecorationManager {
    func updateTreeToys(state s:DecorationState,display d:DisplayOverlay,config:Configuration,now:Double) {
        guard let tree=s.tree else{s.toyNodes=[:];return}
        let choices=[config.treeToy1,config.treeToy2,config.treeToy3]
        let toys=config.placements[d.id]?.ornaments ?? TreeOrnament.defaults
        for i in 0..<3 {
            let id="tree_slot_\(i)",asset="tree_charm_"+choices[i]
            guard choices[i] != "none",let toy=toys.first(where:{$0.id==id}),!toy.hidden else{s.toyNodes.removeValue(forKey:id)?.removeFromParent();continue}
            let node:SKNode
            if let old=s.toyNodes[id],old.parent === tree,(old.userData?["assetID"] as? String)==asset {node=old}
            else {s.toyNodes[id]?.removeFromParent();node=Resources.layer(asset,size:max(10,s.treeHeight*0.13));node.name=id;node.zPosition=7;tree.addChild(node);s.toyNodes[id]=node}
            node.position=CGPoint(x:(toy.anchor.x-0.5)*s.treeHeight,y:(0.5-toy.anchor.y)*s.treeHeight)
            let t=max(0,now-s.toyImpulse)
            node.zRotation=config.reducedMotion || t>2 ? 0:sin(t*10+Double(i)*0.3)*exp(-t*2.7)*0.19
        }
    }

    func updateWorldGarland(state s:DecorationState,display d:DisplayOverlay,config:Configuration,windows:[TrackedWindow],dt:Double,now:Double) {
        d.canvas.garlandPaths=[];d.canvas.garlandArt=[]
        guard config.garland,let placement=config.placements[d.id] else {s.garlandPhysics.reset();return}
        var strands:[(String,Placement,String,Double)]=[("active",placement,config.bulbColor,config.garlandSag)]
        for strand in placement.extraGarlands ?? [] {
            var p=placement;p.garland=strand.anchors;p.garlandWindow=strand.window;p.garlandTarget=strand.target
            strands.append((strand.id,p,strand.palette,strand.sag))
        }
        let valid=Set(strands.map{$0.0});s.extraGarlandPhysics=s.extraGarlandPhysics.filter{valid.contains($0.key)}
        for (key,placement,paletteName,sag) in strands {
            let owner=windows.first{$0.id==placement.garlandWindow && $0.isVisible}
        let tree=placement.tree.map{Vec(d.rect.x+$0.x*d.rect.width,d.rect.y+$0.y*d.rect.height)}
        var anchors=GarlandAttachment.resolve(placement,bounds:d.rect,window:owner?.frame,tree:config.tree ? tree:nil,treeSize:s.treeHeight)
        if placement.garlandTarget == "tree",let node=s.tree {
            anchors=placement.garland.map { anchor in let q=node.convert(CGPoint(x:(anchor.x-0.5)*s.treeHeight,y:(0.5-anchor.y)*s.treeHeight),to:s.root);return Vec(d.rect.x+q.x,d.rect.maxY-q.y) }
        }
        guard anchors.count>=2 else {continue}
        var physics=key=="active" ? s.garlandPhysics:(s.extraGarlandPhysics[key] ?? GarlandPhysics())
        physics.step(anchors:anchors,sag:sag,dt:dt,reduced:config.reducedMotion)
        if key=="active" {s.garlandPhysics=physics}else{s.extraGarlandPhysics[key]=physics}
        let blocked=owner.map { w in windows.filter{$0.isVisible && $0.z<w.z}.map(\.frame) } ?? windows.filter(\.isVisible).map(\.frame)
        let path=CGMutablePath();var previous:Vec?,distance=0.0,index=0
        let palette=paletteName=="ice" ? ["fairy_bulb_blue","fairy_bulb_purple"]:paletteName=="warm" ? ["fairy_bulb_gold"]:["fairy_bulb_red","fairy_bulb_green","fairy_bulb_gold","fairy_bulb_blue"]
        for point in physics.points {
            let safe=point.y>d.rect.y+26 && !blocked.contains{$0.expanded(1).contains(point)}
            if safe {
                if let old=previous,!blocked.contains(where:{$0.contains(old)}) {path.addLine(to:d.local(point));distance+=(point-old).length}else {path.move(to:d.local(point))}
                if distance>=config.bulbSpacing {distance=0
                    if config.garlandLights,d.canvas.garlandArt.count<120,let image=AssetManager.shared.image(palette[index%palette.count]) {
                        let p=d.local(point),h=config.bulbSize*2.2,w=h*48/52,alpha=config.bulbBrightness*(config.reducedMotion || !config.garlandTwinkle ? 1:0.88+sin(now*0.7+Double(index))*0.12)
                        let name=palette[index%palette.count]
                        let color:NSColor=name.hasSuffix("red") ? .systemPink:name.hasSuffix("green") ? .systemGreen:name.hasSuffix("gold") ? .systemYellow:name.hasSuffix("purple") ? .systemPurple:.systemCyan
                        d.canvas.garlandGlows.append(GarlandGlow(point:CGPoint(x:p.x,y:p.y-h*0.48),radius:config.bulbSize*2,color:color,alpha:alpha*0.25))
                        d.canvas.garlandArt.append((image,CGRect(x:p.x-w/2,y:p.y-h*0.9,width:w,height:h),alpha,false))
                    };index+=1
                }
            } else {path.move(to:d.local(point))};previous=point
        }
        d.canvas.garlandPaths.append(path)
        }
    }
    func drawPlowPile(state s:DecorationState,display d:DisplayOverlay,position p:Vec,axis:SurfaceAxis) {
        guard s.plowMass>0 else{return}
        let width=clamp(sqrt(s.plowMass)*1.6,12,58),height=min(27,max(2,s.plowMass/max(1,width)*1.8))
        let path=CGMutablePath(),base=p+Vec(axis == .horizontal ? 29:0,axis == .horizontal ? 23:axis == .verticalLeft ? 29:-29)
        func point(_ tangent:Double,_ normal:Double)->CGPoint {
            switch axis {case .horizontal:return d.local(base+Vec(tangent,-normal));case .verticalLeft:return d.local(base+Vec(normal,tangent));case .verticalRight:return d.local(base+Vec(-normal,-tangent))}
        }
        path.move(to:point(-4,0));path.addCurve(to:point(width,0),control1:point(0,height*1.5),control2:point(width*0.6,height));path.closeSubpath();d.canvas.dynamicCaps.append(path)
    }
}
