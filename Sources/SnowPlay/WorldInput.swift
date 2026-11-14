import AppKit
import SnowCore
extension WinterCoordinator {
    func saveSnowman(_ id:String) {
        guard let d=displays.first(where:{$0.id==id}),let s=decorations.states[id] else{return}
        var placement=config.placements[id] ?? Placement()
        placement.snowman=s.snowballs.snowman.map{Vec(($0.x-d.rect.x)/d.rect.width,($0.y-d.rect.y)/d.rect.height)};placement.snowmanRadii=s.snowballs.snowman == nil ? nil:s.snowballs.assemblyBalls.map(\.radius)
        placement.snowmen=s.snowballs.snowmen.map{DesktopSnowman(id:$0.id,position:Vec(($0.position.x-d.rect.x)/d.rect.width,($0.position.y-d.rect.y)/d.rect.height),radii:$0.radii)}
        config.placements[id]=placement;persist()
    }

    func helpSnowman(_ id:String) {
        updateSculpting()
        guard let state=decorations.states[id],let area=state.sculptArea else{return}
        let source="sculpt-"+id
        for i in state.snowballs.balls.indices {
            let goal=[10.5,8.0,6.0][min(2,i)],r=state.snowballs.balls[i].radius
            let needed=max(0,Double.pi*(goal*goal-r*r))
            let mass=surfaces.surfaces[source]?.extract(volume:needed,at:Double(i+1)/4) ?? 0
            state.snowballs.balls[i].gather(volume:mass)
        }
        if state.snowballs.assemblePrepared(at:Vec(area.center.x,area.maxY-44)){state.snowmanFloating=true;saveSnowman(id)}
        else {diagnostic="Waiting for snow. Keep the play area clear."}
    }
    func handleWorldInput(_ event:String,p:Vec,display d:DisplayOverlay,state s:DecorationState)->Bool {
        let kind=event.components(separatedBy:":").first ?? ""
        if kind == "ornaments" {
            guard let centre=config.placements[d.id]?.tree else{return true}
            let origin=s.tree.map{Vec(d.rect.x+$0.position.x,d.rect.maxY-$0.position.y)} ?? Vec(d.rect.x+centre.x*d.rect.width,d.rect.y+centre.y*d.rect.height)
            var toys=config.placements[d.id]?.ornaments ?? TreeOrnament.defaults
            let local=Vec((p.x-origin.x)/s.treeHeight+0.5,(p.y-origin.y)/s.treeHeight+0.5)
            if event.hasSuffix(":down") {draggedToy=toys.indices.filter{!toys[$0].hidden}.min{(toys[$0].anchor-local).length<(toys[$1].anchor-local).length};if let i=draggedToy,(toys[i].anchor-local).length>0.2 {draggedToy=nil}}
            if let i=draggedToy,i<toys.count {
                toys[i].anchor=local
                if event.hasSuffix(":up") {
                    if local.x<0.12 || local.x>0.88 || local.y<0.17 || local.y>0.84 {toys[i].hidden=true}
                    else {
                        let candidates=TreeOrnament.branchAnchors.filter{point in !toys.enumerated().contains{$0.offset != i && !$0.element.hidden && ($0.element.anchor-point).length<0.06}}
                        toys[i].anchor=candidates.min{($0-local).length<($1-local).length} ?? Vec(clamp(local.x,0.25,0.75),clamp(local.y,0.3,0.8))
                    };draggedToy=nil;s.toyImpulse=ProcessInfo.processInfo.systemUptime
                }
                config.placements[d.id]?.ornaments=toys
                if event.hasSuffix(":up"){persist()}
            };return true
        }
        if kind == "garland-place" {
            if event.hasSuffix(":down") {
                var place=config.placements[d.id] ?? Placement()
                place.garlandWindow=nil;place.garlandTarget="desktop"
                if place.garland.count>=3 {place.garland=[]}
                place.garland.append(Vec((p.x-d.rect.x)/d.rect.width,(p.y-d.rect.y)/d.rect.height));config.placements[d.id]=place
                persist();statusChanged?()
            };return true
        }
        if kind.hasPrefix("garland-anchor@") {
            guard var place=config.placements[d.id],let index=Int(kind.dropFirst("garland-anchor@".count)),index<place.garland.count else{return true}
            let target=place.garlandTarget ?? (place.garlandWindow == nil ? "desktop":"window")
            var local=Vec((p.x-d.rect.x)/d.rect.width,(p.y-d.rect.y)/d.rect.height)
            if target == "window" {guard let w=interactionWindows.first(where:{$0.id==place.garlandWindow && $0.isVisible}) else{return true};local=Vec((p.x-w.frame.x)/w.frame.width,clamp((p.y-w.frame.y-5)/12,0,1))}
            if target == "tree",let t=place.tree {let origin=Vec(d.rect.x+t.x*d.rect.width,d.rect.y+t.y*d.rect.height);local=Vec((p.x-origin.x)/s.treeHeight+0.5,(p.y-origin.y)/s.treeHeight+0.5)}
            place.garland[index]=Vec(clamp(local.x,0.02,0.98),clamp(local.y,0,0.95));config.placements[d.id]=place
            if event.hasSuffix(":up"){persist()};return true
        }
        return false
    }
}
