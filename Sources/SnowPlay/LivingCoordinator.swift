import AppKit
import SnowCore
extension WinterCoordinator {
    func livingSnapshot()->[String:Any] {
        var game:[String:Any]=[:],activity:[String:Any]=[:]
        for (id,s) in decorations.states {
            if let duel=s.living.duel {game=["display":id,"phase":duel.phase.rawValue,"playerHP":duel.playerHP,"yetiHP":duel.yetiHP,"power":duel.power,"angle":duel.angle,"secondsLeft":duel.secondsLeft,"obscured":s.living.duelObscured,"area":["x":duel.area.x,"y":duel.area.y,"width":duel.area.width,"height":duel.area.height]]}
            if let kind=s.living.activity {activity=["kind":kind,"elapsed":s.living.activityElapsed,"result":s.living.activityResult]}
        }
        return ["busy":decorations.livingBusy,"duel":game,"activity":activity,"automaticSnowman":decorations.states.values.contains{$0.living.automaticTarget != nil},"treeDelivery":decorations.states.values.compactMap{$0.living.delivery?.elapsed},"characterSnowExported":decorations.consumedSnowMass,"automaticSanta":false]
    }
    func startLivingDuel(){
        guard !paused,!sleeping,config.mode != .focus,!director.reducedMotion,!decorations.livingBusy else{diagnostic="Finish the activity and enable motion to duel.";return}
        let blocked=interactionWindows.filter(\.isVisible).map(\.frame)+(dock?.isVisible == true ? [dock!.frame]:[])
        for d in displays {
            if let area=FreePlayArea.find(in:d.rect,blocked:blocked),decorations.startDuel(display:d,area:area) {
                finishSculpting();input.stop();onWorldInteraction?();syncDuelInput(activate:true);diagnostic="Aim, then click to throw. 5 seconds per turn. Esc to leave.";return
            }
        };diagnostic="Clear a desktop area of about 660 × 210 to play."
    }
    func syncDuelInput(activate:Bool=false) {
        guard !paused,!sleeping,let state=decorations.states.values.first(where:{$0.living.duel != nil}),let game=state.living.duel else {duelPanel?.close();duelPanel=nil;duelPanelArea=nil;return}
        if state.living.duelObscured {duelPanel?.orderOut(nil);return}
        guard displays.contains(where:{$0.rect.x<=game.area.x && $0.rect.y<=game.area.y && $0.rect.maxX>=game.area.maxX && $0.rect.maxY>=game.area.maxY})else{endLivingDuel();diagnostic="Screen size changed. Duel ended.";return}
        if duelPanel==nil || duelPanelArea != game.area || duelPanelPrimaryHeight != input.primaryHeight {
            duelPanel?.close()
            duelPanel=DuelInputPanel(area:game.area,primaryHeight:input.primaryHeight,aim:{[weak self] point in self?.decorations.aimDuel(at:point)},fire:{[weak self] in _=self?.decorations.fireDuel()},exit:{[weak self] in self?.endLivingDuel()})
            duelPanelArea=game.area
            duelPanelPrimaryHeight=input.primaryHeight
        }
        if activate {NSApp.activate(ignoringOtherApps:true);duelPanel?.makeKeyAndOrderFront(nil)}
        else if duelPanel?.isVisible == false {duelPanel?.orderFrontRegardless()}
    }
    func endLivingDuel(){decorations.exitDuel();duelPanel?.close();duelPanel=nil;duelPanelArea=nil;statusChanged?()}
    func startLivingYeti(_ kind:String) {
        guard !paused,config.mode != .focus,!director.reducedMotion,!decorations.livingBusy else{diagnostic="Finish the current activity first.";return}
        let mouse=NSEvent.mouseLocation,p=Vec(mouse.x,input.primaryHeight-mouse.y)
        guard let d=displays.first(where:{$0.rect.contains(p)}) ?? displays.first else{return}
        var target=Vec(clamp(p.x,d.rect.x+45,d.rect.maxX-45),clamp(p.y,d.rect.y+50,d.rect.maxY-30))
        if kind=="feed" {target=Vec(target.x,decorations.groundY(target.x,display:d,surfaces:surfaces)-25)}
        else if interactionWindows.contains(where:{$0.isVisible && $0.frame.expanded(24).contains(target)}) {
            guard let free=decorations.freePoint(display:d,windows:interactionWindows,dock:dock,size:50) else{diagnostic="Clear a small spot on the desktop.";return};target=free
        }
        let blocked=interactionWindows.filter(\.isVisible).map(\.frame)+(dock?.isVisible == true ? [dock!.frame]:[])
        guard let feetX=FreePlayArea.floorX(near:target.x-60,in:d.rect,blocked:blocked,left:kind=="feed" ? 65:25,groundY:{decorations.groundY($0,display:d,surfaces:surfaces)})else{diagnostic="Clear a spot in the bottom snow.";return}
        if decorations.startYetiActivity(kind,display:d,target:target,surfaces:surfaces,feetAt:feetX){finishSculpting();input.stop();config.interaction=false;diagnostic=kind=="feed" ? "Drag the snowball to Yeti.":kind=="dodge" ? "Move out of the circle.":"Yeti has a surprise.";onWorldInteraction?()}
        else{diagnostic="A little more snow is needed."}
    }
    func removeLivingTree(){
        guard !decorations.livingBusy else{return};finishSculpting();input.stop();config.interaction=false
        var started=false
        for d in displays {if let tree=decorations.states[d.id]?.tree {let target=Vec(d.rect.x+tree.position.x,d.rect.maxY-tree.position.y);started=decorations.requestCharacter(.chopTree,display:d,target:target,windows:interactionWindows,surfaces:surfaces,config:config)||started}}
        if started {config.tree=false;persist();applySettings();onWorldInteraction?()}
    }
    func removeLivingSnowman(){
        guard !decorations.livingBusy else{return};finishSculpting();input.stop()
        let mouse=NSEvent.mouseLocation,p=Vec(mouse.x,input.primaryHeight-mouse.y)
        for d in displays {if let s=decorations.states[d.id],let m=s.snowballs.snowmen.min(by:{($0.position-p).length<($1.position-p).length}) {s.snowballs.select(m.id);_=decorations.requestCharacter(.throwSnowball,display:d,target:m.position,windows:interactionWindows,surfaces:surfaces,config:config)}}
        onWorldInteraction?()
    }
}
