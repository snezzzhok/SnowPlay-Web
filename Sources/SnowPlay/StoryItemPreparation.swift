import AppKit
import SnowCore

extension WinterCoordinator {
    func canPrepareStory(_ id:ChristmasStoryID,reason:String)->Bool {
        ["Requires a tree with unopened gifts","Requires a Christmas tree with lights","Requires tree lights","Requires a Christmas tree","Requires a snowman","Requires snow on tree branches","Requires enough snow and free space","Allow snowman creation in Advanced","Choose a garland with Delete first"].contains(reason)
    }

    /// Explicit Play prepares prerequisites once. Automatic stories never change the scene.
    func prepareStoryItems(_ id:ChristmasStoryID) {
        let engine=decorations.stories
        let check=engine.availability(id,manager:decorations,displays:displays,config:config,windows:interactionWindows,dock:dock,surfaces:surfaces)
        guard canPrepareStory(id,reason:check.reason),let d=displays.first(where:{!$0.desktopOccluded}),let s=decorations.states[d.id] else{return}
        let now=ProcessInfo.processInfo.systemUptime
        if id.needsTree {
            config.tree=true
            var p=config.placements[d.id] ?? Placement()
            if p.tree==nil {p.tree=Vec(0.5,0.9);p.treeIdentity=UUID().uuidString}
            config.placements[d.id]=p
            if id == .lightRepair {if config.treeGarland=="none" {config.treeGarland="multi"};config.garlandLights=true}
            decorations.updateFloorTree(state:s,display:d,config:config,now:now-2,surfaces:surfaces,windows:interactionWindows)
            s.treeAppearedAt=now-2
            decorations.updateFloorTree(state:s,display:d,config:config,now:now,surfaces:surfaces,windows:interactionWindows)
            decorations.updateBranchSurfaces(display:d,state:s,config:config,surfaces:surfaces)
            if id == .presentTheft,!s.treePresents.contains(where:{$0.openedAt==nil}) {decorations.addTreePresents(display:d,surfaces:surfaces,now:now-2);saveStoryDecorations(d.id)}
            if id == .treeShake {for key in engine.branchKeys(d.id,surfaces:surfaces) {let mass=surfaces.surfaces[key]?.volume ?? 0;surfaces.surfaces[key]?.add(volume:max(0,30-mass))}}
        }
        if id.needsSnowman,s.snowballs.snowmen.isEmpty,decorations.snowmanCount<5 {
            let x=d.rect.center.x,radii=StorySnowmanRecipe.radii
            let model=DesktopSnowman(position:Vec(),radii:radii)
            s.snowballs.additionalSnowmen.append(DesktopSnowman(position:Vec(x,decorations.groundY(x,display:d,surfaces:surfaces)-model.height*0.441),radii:radii))
            saveSnowman(d.id)
        }
        if id == .snowmanBuild {
            config.stories.allowSnowmanCreation=true
            let key="ground-"+d.id
            if surfaces.surfaces[key]==nil {surfaces.surfaces[key]=SnowSurface(id:key,screenID:d.id,frame:Rect(d.rect.x,d.rect.maxY-2,d.rect.width,1),maxHeight:42)}
            let mass=surfaces.surfaces[key]?.volume ?? 0
            surfaces.surfaces[key]?.add(volume:max(0,StorySnowmanRecipe.mass*2-mass))
        }
        if id == .garlandRemoval,engine.removalTarget==nil {
            if garlandRemoval.targets().isEmpty {
                config.garland=true
                var p=config.placements[d.id] ?? Placement();p.garland=[Vec(0.2,0.3),Vec(0.8,0.3)];p.garlandTarget="desktop";p.garlandWindow=nil;config.placements[d.id]=p
                decorations.updateWorldGarland(state:s,display:d,config:config,windows:interactionWindows,dt:1.0/60,now:now)
            }
            engine.removalTarget=garlandRemoval.targets().first
        }
        persist()
    }
}
