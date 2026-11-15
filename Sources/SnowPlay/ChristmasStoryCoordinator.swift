import AppKit
import Intents
import SnowCore
extension WinterCoordinator {
    func storySnapshot()->[String:Any] {
        var snapshot=manualStoryPlayback?.manager.stories.snapshot ?? decorations.stories.snapshot
        snapshot["catalogue"]=ChristmasStoryID.allCases.map{id->[String:Any] in
            let blocked=sleeping || sessionInactive || manualStoryPlayback != nil || decorations.stories.active != nil
            return ["automaticAllowed":id.automaticAllowed,"id":id.rawValue,"title":id.title,"description":id.summary,"icon":id.icon,"available":!blocked,"reason":blocked ? "Another story is playing or Mac is sleeping":""]
        }
        let focus=INFocusStatusCenter.default
        snapshot["focusStatus"]=focus.authorizationStatus == .authorized ? (focus.focusStatus.isFocused == true ? "focused":"available"):"notAuthorized"
        return snapshot
    }
    @discardableResult func playChristmasStory(_ id:ChristmasStoryID?=nil,variant:Int?=nil,automatic:Bool=false)->Bool {
        if !automatic {
            guard !sleeping,!sessionInactive,manualStoryPlayback==nil,decorations.stories.active==nil,let screen=NSScreen.main ?? NSScreen.screens.first else{return false}
            let chosen=id ?? ChristmasStoryID.allCases.randomElement()!
            guard let player=ManualStoryPlayback(id:chosen,variant:variant,screen:screen) else{diagnostic="Could not prepare the story stage.";return false}
            manualStoryPlayback=player
            player.onFinished={ [weak self] in self?.manualStoryPlayback=nil;self?.statusChanged?() }
            onWorldInteraction?();diagnostic="Playing · "+chosen.title;statusChanged?();return true
        }
        guard !paused,!sleeping,!sessionInactive,config.mode != .focus,!director.reducedMotion,input.mode == .none else {diagnostic="Finish editing and resume effects first.";return false}
        guard !(isOnBattery && config.stories.pauseOnBattery) else{diagnostic="Stories paused on battery. See Advanced Settings.";return false}
        let engine=decorations.stories
        let chosen:ChristmasStoryID
        if let id {chosen=id}else {
            let possible=ChristmasStoryID.allCases.filter{(!automatic || $0.automaticAllowed) && engine.availability($0,manager:decorations,displays:displays,config:config,windows:interactionWindows,dock:dock,surfaces:surfaces).available}
            guard let next=engine.scheduler.choose(possible,enabled:automatic ? config.stories.enabledStories:ChristmasStoryID.allCases.map(\.rawValue)) else{diagnostic="No story available. Check the Stories cards.";return false};chosen=next
        }
        if !automatic,engine.active==nil,!decorations.livingBusy {
            prepareStoryItems(chosen)
        }
        let error=engine.start(chosen,manager:decorations,displays:displays,config:config,windows:interactionWindows,dock:dock,surfaces:surfaces,variant:variant)
        if let error {diagnostic=error;return false}
        input.stop();onWorldInteraction?();diagnostic="Playing · "+chosen.title;statusChanged?();return true
    }
    func updateChristmasScheduler(dt:Double,now:Double,battery:Bool){
        let engine=decorations.stories
        guard manualStoryPlayback==nil else{return}
        guard config.stories.enabled || engine.active != nil else{return}
        // Focus and aggregate activity metadata need only a one-second policy poll.
        if now-storyLastPolicyPoll>=1 {
            storyLastPolicyPoll=now
            let focus=INFocusStatusCenter.default
            storyFocusBlocked=focus.authorizationStatus == .authorized && focus.focusStatus.isFocused == true
            storyUserBusy=CGEventSource.secondsSinceLastEventType(.combinedSessionState,eventType:.keyDown)<15 || CGEventSource.secondsSinceLastEventType(.combinedSessionState,eventType:.leftMouseDown)<3 || NSEvent.pressedMouseButtons != 0
        }
        if engine.active != nil,battery && config.stories.pauseOnBattery {engine.stop(reason:"Paused on battery")}
        if engine.active != nil,storyFocusBlocked {engine.stop(reason:"Focus mode became active")}
        let eligible=config.stories.enabled && !paused && !sleeping && !sessionInactive && !observer.fullscreen && !storyFocusBlocked && !(battery && config.stories.pauseOnBattery) && config.mode != .focus && !director.reducedMotion && input.mode == .none && !decorations.livingBusy && !CommandLine.arguments.contains("--no-auto-stories")
        // Typing counts as active Mac time; a due event waits for a quiet moment.
        engine.scheduler.advance(dt,eligible:eligible)
        guard eligible,!storyUserBusy,engine.scheduler.due else{return}
        if !playChristmasStory(automatic:true){engine.scheduler.retryLater()}
    }
    func christmasStoryFinished(_ run:ChristmasStoryRuntime){
        if !config.tree {config.placements[run.display.id]?.storyPresents=[];persist()}
        garlandStoryFinished(run)
        if run.succeeded,run.id == .starHat,run.settings.keepDecorations {config.treeStar="gold";persist()}
        if run.createdSnowman != nil {saveSnowman(run.display.id)}
        if run.succeeded,run.settings.keepDecorations {saveStoryDecorations(run.display.id)}
        diagnostic=run.succeeded ? "Story finished.":"Story stopped. "+run.interruption
        statusChanged?()
    }
    func saveStoryDecorations(_ id:String){
        guard let d=displays.first(where:{$0.id==id}),let s=decorations.states[id] else{return}
        var placement=config.placements[id] ?? Placement()
        placement.storyPresents=s.treePresents.filter{$0.openedAt==nil}.map{StoryPresentPlacement(id:$0.id,position:Vec(($0.position.x-d.rect.x)/d.rect.width,($0.position.y-d.rect.y)/d.rect.height),variant:$0.variant,height:$0.artHeight)}
        if let snowman=decorations.stories.lastResult["id"] as? String,snowman==ChristmasStoryID.snowmanParty.rawValue {
            let styled=s.snowballs.snowmen.filter{m in let node=s.snowmanVisualID==m.id ? s.snowmanNode:s.extraSnowmanNodes[m.id];return node?.childNode(withName:"story-party-hat") != nil}.map{$0.id.uuidString}
            placement.storyPartySnowmen=styled
        }
        config.placements[id]=placement;persist()
    }
}
extension DecorationManager {
    func updateBranchSurfaces(display d:DisplayOverlay,state s:DecorationState,config:Configuration,surfaces:SurfaceManager){
        let prefix="tree-"+d.id+"-branch-",keys=surfaces.surfaces.keys.filter{$0.hasPrefix(prefix)}
        guard config.tree,let tree=s.tree,!s.treeRemoving,config.mode != .focus else{
            for key in keys {if let old=surfaces.surfaces.removeValue(forKey:key),old.volume>0 {onSnowFall?(SnowFallEvent([SnowChunk(old.frame.center,Vec(0,12),old.volume,fallsToGround:true)]),d.id)}};return
        }
        for (i,row) in [(0,0.35),(1,0.55),(2,0.75)] {
            let width=s.treeHeight*[0.22,0.39,0.56][i],local=tree.convert(CGPoint(x:0,y:(0.5-row)*s.treeHeight),to:s.root)
            let point=Vec(d.rect.x+local.x,d.rect.maxY-local.y),key=prefix+String(i),frame=Rect(point.x-width/2,point.y,width,1)
            if surfaces.surfaces[key]==nil {surfaces.surfaces[key]=SnowSurface(id:key,screenID:d.id,frame:frame,maxHeight:2)}
            // Translation carries a bank without creating or deleting snow.
            surfaces.surfaces[key]?.frame=frame;surfaces.surfaces[key]?.visible = !tree.isHidden;surfaces.surfaces[key]?.renderVisible = !tree.isHidden
        }
    }
}
