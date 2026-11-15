import AppKit
import SpriteKit
import IOKit.ps
import SnowCore

final class WinterCoordinator {
    let surfaces=SurfaceManager(), observer=WindowObserver(), dockObserver=DockObserver(), director=AnimationDirector()
    let decorations=DecorationManager(), input=InteractionController(), server=LocalServer(), performance=PerformanceMonitor()
    var manualStoryPlayback:ManualStoryPlayback?
    lazy var garlandRemoval=GarlandRemovalController(self)
    lazy var stickerStudio=StickerStudio(self)
    var displays: [DisplayOverlay] = []
    var config: Configuration
    var manualChecks=ManualCheckProgress()
    // New checklist has different scenarios; retain the user's previous checks file untouched.
    var checksURL: URL { configURL.deletingPathExtension().appendingPathExtension("living-checks.json") }
    var configURL: URL
    var paused=false
    var sleeping=false
    var sessionInactive=false
    var dock: DockGeometry?
    var statusChanged: (()->Void)?
    var diagnostic=""
    var duelPanel:DuelInputPanel?,duelPanelArea:Rect?
    var duelPanelPrimaryHeight=0.0
    var onWorldInteraction:(()->Void)?
    // Optional geometry source for isolated controller/interaction fixtures.
    var interactionWindowSource: (() -> [TrackedWindow])?
    var interactionWindows: [TrackedWindow] { interactionWindowSource?() ?? observer.sorted }
    private var timer: Timer?
    private var tokens: [NSObjectProtocol]=[]
    private var lastTick=0.0, lastPoll=0.0, lastInput=0.0, lastCleaning=0.0, lastPower=0.0, lastSession=0.0, lastDock=0.0
    var storyLastPolicyPoll=0.0,storyFocusBlocked=false,storyUserBusy=false
    var isOnBattery:Bool {battery}
    private var battery=false
    private var fps=60
    var plowLoad=SnowPile()
    private var pendingSnow:[String:[SnowChunk]]=[:]
    private var quietCleaning=false
    private var cleaningSurfaceID:String?
    private var cleaningElapsed: Double?
    private var draggedBall: (String,UUID)?
    private var lastDrag=Vec()
    private var objectDrag: (kind:String,display:String,offset:Vec,start:Vec,moved:Bool)?
    var draggedToy:Int?
    var draggedAnchor:Int?
    private var nextYetiGame=ProcessInfo.processInfo.systemUptime+100
    private var previousPointer: Vec?
    private var lastBrush=0.0
    private var brushedVolume=0.0
    private var interactionShape=""

    private var lastVisibleSnow: [String:(surface: SnowSurface, time: Double)] = [:]
    private var noAutoDelivery=false
    init() {
        let args=CommandLine.arguments
        if let i=args.firstIndex(of:"--config"), i+1<args.count { configURL=URL(fileURLWithPath:args[i+1]) }
        else { configURL=FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask).first!.appendingPathComponent("SnowPlay/settings.json") }
        config=Configuration.load(from:configURL)
        manualChecks=ManualCheckProgress.load(from:checksURL)
        noAutoDelivery=args.contains("--no-auto-delivery")
        observer.onClose={ [weak self] w in self?.windowClose(w) }
        observer.onMinimize={ [weak self] w in self?.windowMinimize(w) }
        observer.onGeometry={ [weak self] w,old,dt in self?.windowGeometry(w,old:old,dt:dt) }
        input.onEvent={ [weak self] e,p,id in self?.handleInput(e,p:p,id:id) }
        decorations.animationDirector=director
        decorations.onSnowFall={ [weak self] event,id in self?.queueSnow(event,displayID:id) }
        decorations.onSnowmanRemoved={ [weak self] id in self?.saveSnowman(id) }
        decorations.onHelpBuild={ [weak self] id in self?.helpSnowman(id) }
        decorations.stories.onFinished={ [weak self] run in self?.christmasStoryFinished(run) }
        decorations.onSnowmanBuilt={ [weak self] id in self?.saveSnowman(id) }
        decorations.onDust={ [weak self] p,id in self?.displays.first(where:{$0.id==id})?.engine.dust(at:p) }
        decorations.onDuelEnded={ [weak self] in self?.duelPanel?.close();self?.duelPanel=nil;self?.duelPanelArea=nil }
        decorations.onTreeDeliveryCancelled={ [weak self] id in self?.config.tree=false;self?.config.placements[id]?.tree=nil;self?.persist() }
        decorations.onTreeRemovalCancelled={ [weak self] _ in self?.config.tree=true;self?.persist() }
        decorations.onDelivery={ [weak self] in self?.config.lastDelivery=Date(); self?.persist() }
        server.handler={ [weak self] request in self?.handle(request) ?? .json(["error":"stopped"],status:503) }
    }
    func start() {
        rebuildDisplays()
        do { try server.start() } catch { diagnostic="Local panel unavailable: \(error.localizedDescription)" }
        let center=NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification,NSWorkspace.screensDidSleepNotification,NSWorkspace.sessionDidResignActiveNotification] {
            tokens.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in self?.sessionPause() })
        }
        for name in [NSWorkspace.didWakeNotification,NSWorkspace.screensDidWakeNotification,NSWorkspace.sessionDidBecomeActiveNotification] {
            tokens.append(center.addObserver(forName:name,object:nil,queue:.main) { [weak self] _ in self?.sessionResume() })
        }
        tokens.append(NotificationCenter.default.addObserver(forName:NSApplication.didChangeScreenParametersNotification,object:nil,queue:.main) { [weak self] _ in self?.rebuildDisplays() })
        tokens.append(center.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main) { [weak self] _ in self?.applySettings() })
        lastCleaning=ProcessInfo.processInfo.systemUptime; lastTick=lastCleaning
        applySettings(); scheduleTimer()
        if let i=CommandLine.arguments.firstIndex(of:"--control-url-file"), i+1<CommandLine.arguments.count {
            try? Data(server.url.absoluteString.utf8).write(to:URL(fileURLWithPath:CommandLine.arguments[i+1]),options:.atomic)
        }
    }
    private func sessionPause() {manualStoryPlayback?.stop();garlandRemoval.cancel(); stickerStudio.finish(cancelDrag:true); finishSculpting();cancelCleaning();decorations.cancelTransient();cancelWindowEffects(); sleeping=true; input.stop(); for d in displays { d.hide(true); (d.foreground.contentView as? SKView)?.isPaused=true; (d.background.contentView as? SKView)?.isPaused=true } }
    private func sessionResume() { sleeping=false; lastTick=ProcessInfo.processInfo.systemUptime; applySettings() }
    func rebuildDisplays() {
        manualStoryPlayback?.stop()
        garlandRemoval.cancel()
        stickerStudio.finish(cancelDrag:true)
        if !displays.isEmpty {finishSculpting();cancelCleaning();decorations.cancelTransient();input.stop()}
        let existing=Dictionary(uniqueKeysWithValues:displays.map { ($0.id,$0) })
        var next: [DisplayOverlay]=[]
        let height=NSScreen.screens.first?.frame.height ?? 900
        input.primaryHeight=height
        for screen in NSScreen.screens {
            let id=String((screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0)
            if let old=existing[id], old.screen.frame == screen.frame {old.refreshScreenInsets();next.append(old)}
            else { existing[id]?.close(); next.append(DisplayOverlay(screen:screen,surfaces:surfaces,primaryHeight:height)) }
        }
        for d in displays where !next.contains(where: { $0 === d }) { d.close() }
        displays=next
        let ids=Set(displays.map(\.id));pendingSnow=pendingSnow.filter{ids.contains($0.key)}; surfaces.surfaces=surfaces.surfaces.filter { ids.contains($0.value.screenID) }
        decorations.install(displays); applySettings()
    }
    private func scheduleTimer() {
        timer?.invalidate()
        let t=Timer(timeInterval:1/Double(fps),repeats:true) { [weak self] _ in self?.tick() }; t.tolerance=0.002
        RunLoop.main.add(t,forMode:.common); timer=t
    }
    func applyPreset(_ mode: WinterMode) {
        let previous=config,date=config.lastDelivery, placements=config.placements, hats=config.dockHats
        config=Configuration.preset(mode); config.lastDelivery=date; config.placements=placements; config.dockHats=hats
        config.stickers=previous.stickers;config.stories=previous.stories;config.tree=previous.tree;config.garland=previous.garland;config.treeSize=previous.treeSize;config.treeStar=previous.treeStar;config.treeBalls=previous.treeBalls;config.treeGarland=previous.treeGarland;config.treeToy1=previous.treeToy1;config.treeToy2=previous.treeToy2;config.treeToy3=previous.treeToy3;config.yetiEnabled=previous.yetiEnabled
        persist(); applySettings()
    }
    func persist() {
        if !config.tree {for id in config.placements.keys {config.placements[id]?.treeIdentity=nil};for id in config.placements.keys where decorations.states[id]?.tree == nil && decorations.states[id]?.treeRemoving != true {if config.placements[id]?.storyPresents != nil {config.placements[id]?.storyPresents=[]}}}
        do { try config.save(to:configURL) } catch { diagnostic="Cannot save settings: \(error.localizedDescription)" } }
    func applySettings() {
        config.validate()
        director.focus=config.mode == .focus; director.reducedMotion=config.reducedMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if director.focus || director.reducedMotion { finishSculpting();cancelCleaning();director.cancelAll(); decorations.cancelTransient(); surfaces.surfaces["dock"]?.sweepFraction=nil; input.stop(); config.interaction=false }
        for key in Array(surfaces.surfaces.keys) { surfaces.surfaces[key]?.setMaximum(key.hasPrefix("ground-") ? config.groundHeight:key.hasPrefix("tree-") ? 2:key.hasPrefix("sculpt-") ? 10:config.accumulationHeight) }
        let hide=paused || sleeping || sessionInactive
        for d in displays {
            d.hide(hide)
            for window in [d.foreground,d.background] { let view=window.contentView as? SKView; view?.isPaused=hide; view?.preferredFramesPerSecond=fps }
        }
        if !config.interaction && input.mode == .snow { input.stop() }
        statusChanged?()
    }
    func togglePause() { paused.toggle();if paused {manualStoryPlayback?.stop()};if paused {garlandRemoval.cancel();stickerStudio.finish(cancelDrag:true)}; if paused { finishSculpting();cancelCleaning();input.stop(); director.cancelAll(); decorations.cancelTransient(); surfaces.surfaces["dock"]?.sweepFraction=nil }; applySettings() }
    private func tick() {
        let now=ProcessInfo.processInfo.systemUptime, dt=min(0.05,max(0,now-lastTick)); let actualDT=now-lastTick; lastTick=now
        var simulated=false
        defer { performance.tick(dt:actualDT,now:now,particles:displays.reduce(0) { $0+$1.engine.particles.count },battery:battery,targetFPS:fps,simulating:simulated) }
        if now-lastPower>3 {
            lastPower=now
            if let info=IOPSCopyPowerSourcesInfo()?.takeRetainedValue() { battery=(IOPSGetProvidingPowerSourceType(info)?.takeUnretainedValue() as String?) == kIOPSBatteryPowerValue }
        }
        guard !paused && !sleeping else { return }
        let nsMouse=NSEvent.mouseLocation,mouse=Vec(nsMouse.x,input.primaryHeight-nsMouse.y)
        if now-lastSession>0.25 {
            lastSession=now
            let front=NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            sessionInactive=front == "com.apple.loginwindow"
        } // Public frontmost-app fallback; see feasibility report.
        if sessionInactive {manualStoryPlayback?.stop();garlandRemoval.cancel();stickerStudio.finish(cancelDrag:true); for d in displays { d.hide(true); d.setRenderActivity(snow:false,decoration:false) }; return }
        let trackWindowGeometry=stickerStudio.editing || config.stickers.items.contains{$0.anchor.kind == .window} || config.windowSnow || config.frost || (config.garland && config.placements.values.contains{$0.garlandTarget=="window" || ($0.extraGarlands ?? []).contains{$0.target=="window"}})
        let trackingMotion=trackWindowGeometry && (NSEvent.pressedMouseButtons != 0 || observer.sorted.contains{$0.state.phase == .moving || $0.state.phase == .resizing})
        let storyActive=decorations.visibleStoryActive || input.mode != .none || decorations.states.values.contains{!$0.snowballPlay.balls.isEmpty || !$0.fragments.isEmpty} || cleaningElapsed != nil || decorations.states.values.contains{$0.deliveryElapsed != nil}
        let covered = !displays.isEmpty && displays.allSatisfy(\.desktopOccluded)
        let brushing = !covered && surfaces.surfaces.values.contains{$0.id.hasPrefix("ground-") && $0.volume>0 && abs(mouse.y-$0.frame.y)<80} && previousPointer.map{($0-mouse).length>0.5} == true
        let airborne=displays.contains{$0.engine.particles.contains{$0.remaining>=0}}
        let responseFPS=min(config.fps,config.mode == .focus ? 20:trackingMotion || storyActive || brushing || airborne ? 60:covered && !config.windowSnow ? 5:!config.snow || config.intensity<=0 ? 15:(battery || ProcessInfo.processInfo.isLowPowerModeEnabled ? 30:60))
        if responseFPS != fps {fps=responseFPS;performance.resetTiming();scheduleTimer()}
        if trackWindowGeometry,observer.refreshGeometry(now:now) {syncSurfaces(now:now)}
        let pollInterval=trackingMotion ? 0.1:trackWindowGeometry || decorations.duelActive || input.mode != .none ? 0.2:0.6
        if now-lastPoll > pollInterval {
            lastPoll=now; observer.poll(now:now,screens:displays.map(\.rect),trackAccessibility:trackWindowGeometry)
            syncSurfaces(now:now)
        }
        let trackIcons=input.mode == .hat || (!config.dockHats.isEmpty && dock?.frame.expanded(64).contains(mouse) == true)
        if now-lastDock>(trackIcons ? 0.08:0.6) {
            lastDock=now;dock=dockObserver.detect(displays:displays,rows:observer.snapshotRows,wantedIDs:input.mode == .hat ? nil:Set(config.dockHats.keys),now:now)
            if config.mode != .focus && (!config.dockHats.isEmpty || input.mode == .hat) {dockObserver.updateIcons(dock:dock)} else {dockObserver.clearIcons()}
            // Dock geometry is retained for hats, never for a snow surface.
            if let old=surfaces.surfaces.removeValue(forKey:"dock"),old.volume>0 {queueSnow(SnowFallEvent([SnowChunk(Vec(old.frame.center.x,old.frame.y),Vec(),old.volume,fallsToGround:true)]),displayID:old.screenID)}
        }
        for d in displays {
            let key="ground-"+d.id
            if config.groundSnow {
                let frame=Rect(d.rect.x,d.rect.maxY-2,d.rect.width,1)
                if surfaces.surfaces[key] == nil {surfaces.surfaces[key]=SnowSurface(id:key,screenID:d.id,frame:frame,maxHeight:config.groundHeight)}
                if surfaces.surfaces[key]?.frame != frame {_=surfaces.surfaces[key]?.resize(to:frame,dt:0.1)}
            } else {surfaces.surfaces.removeValue(forKey:key)}
        }
        flushSnowEvents()
        let hidden=observer.fullscreen
        if hidden {suppressForFullscreen();return}
        for d in displays { d.hide(false) }
        simulated=true
        director.tick(actualDT)
        brushPointer(mouse,now:now)
        let activeEffectIDs=Set(director.active.map(\.id))
        let timeRegions=director.snowTimeRegions
        let windows=observer.sorted
        let visibleWindows=windows.filter(\.isVisible)
        surfaces.setWindowOrder(visibleWindows.map(\.id))
        let occluders=visibleWindows.map(\.frame)
        for d in displays {
            let desktop=Rect(d.rect.x,d.rect.y+24,d.rect.width,max(1,d.rect.height-24))
            d.setDesktopOccluded(DesktopVisibility.exposedFraction(in:desktop,blocked:occluders)<0.015)
        }
        for w in windows { w.state.tick(dt:dt,now:now) }
        stepCleaning(dt:dt,now:now)
        for id in Array(surfaces.surfaces.keys){surfaces.surfaces[id]?.relax(dt:dt)}
        let active=observer.activeFrame
        var motionConfig=config; motionConfig.reducedMotion=director.reducedMotion
        if decorations.duelActive {motionConfig.snowSpeed=min(motionConfig.snowSpeed,0.45)}
        for d in displays {
            let count=config.snow ? SnowfallDensity.count(intensity:decorations.duelActive ? min(config.intensity,0.18):config.intensity,area:d.rect.width*d.rect.height,mode:config.mode,limit:config.maxParticles):0
            d.engine.retainEffects(activeEffectIDs)
            d.engine.setCount(count)
            if (!d.desktopOccluded || config.windowSnow) && (config.snow || d.engine.particles.contains(where: { $0.remaining >= 0 })) { d.engine.step(dt:dt,config:motionConfig,occluders:occluders,timeRegions:timeRegions) }
            d.canvas.hats=[]
            if config.mode != .focus, let dock, dock.isVisible, dock.screenID == d.id {
                for icon in dockObserver.icons {
                    guard let color=config.dockHats[icon.id], let image=AssetManager.shared.image("hat_knit_"+color) else { continue }
                    let anchor=AssetManager.shared.registry["hat_"+color]?.anchor ?? Vec(0.5,0.78)
                    let rect=HatPlacement.frame(tile:icon.frame,anchor:anchor),p=d.local(Vec(rect.x,rect.maxY))
                    d.canvas.hats.append((image,CGRect(x:p.x,y:p.y,width:rect.width,height:rect.height),0.95,false))
                }
            }
            d.render(config:config,windows:windows,surfaces:surfaces,active:active)
        }
        updateSculpting()
        garlandRemoval.update()
        updateChristmasScheduler(dt:actualDT,now:now,battery:battery)
        var renderConfig=config; renderConfig.reducedMotion=director.reducedMotion
        decorations.foregroundSnowmen=[EditorMode.snow,.snowballPlay,.snowmen].contains(input.mode)
        for panel in input.panels {if let v=panel.contentView as? InputView,v.glove || v.playSnow {v.needsDisplay=true}}
        stickerStudio.prepareAccessories()
        decorations.update(dt:dt,now:now,displays:displays,config:renderConfig,windows:windows,dock:dock,surfaces:surfaces,director:director,mouse:mouse)
        stickerStudio.update(now:now)
        syncDuelInput()
        // Living Winter World starts story animations only after an explicit command.
        var shape="\(input.mode)-\(dock?.isVisible ?? false)-\(config.treeSize)-\(decorations.states.values.reduce(0){$0+$1.treePresents.filter{$0.openedAt==nil}.count})"
        if input.mode == .hat {shape+="-\(dockObserver.icons.map(\.frame))"}
        for d in displays {
            if let s=decorations.states[d.id] { shape+="-\(d.id)-\(s.tree?.isHidden ?? true)-\(s.giftLanded)-\(s.gift?.isHidden ?? true)-\(s.snowballs.balls.count)-\(s.snowballs.snowman != nil)" }
        }
        if shape != interactionShape { interactionShape=shape;lastInput=0 }
        if now-lastInput>0.5 { lastInput=now; input.rebuild(displays:displays,windows:windows,dock:dock,decorations:decorations,focus:config.mode == .focus,icons:dockObserver.icons) }
        for d in displays {
            let state=decorations.states[d.id]
            d.presentDesktopObjects()
            let ornament=config.mode != .focus && ((state?.snowballs.snowmen.count ?? 0)>0 || (state?.snowmanFloating == true && now-(state?.snowmanBuiltAt ?? 0)<2.5) || state?.tree?.isHidden == false || !(state?.garland.children.isEmpty ?? true) || state?.gift?.isHidden == false || state?.santa?.isHidden == false || state?.plow?.isHidden == false || (state?.balls.children.contains { !$0.isHidden } ?? false) || (state?.celebration.children.contains { !$0.isHidden } ?? false))
            let surfaceVisible=surfaces.surfaces.values.contains { $0.screenID == d.id && $0.visible && $0.renderVisible && $0.volume>0 }
            let frosted=config.frost && config.mode != .focus && windows.contains { $0.isVisible && $0.state.frost>0 }
            d.setRenderActivity(snow:!d.canvas.storyEffects.isEmpty || !d.canvas.stickers.isEmpty || !d.desktopCanvas.stickers.isEmpty || !d.engine.particles.isEmpty || surfaceVisible || frosted || !d.canvas.hats.isEmpty || !d.canvas.garlandArt.isEmpty || !d.desktopCanvas.snowballArt.isEmpty || d.canvas.workbench != nil || !d.desktopCanvas.composites.isEmpty || !d.desktopCanvas.reveals.isEmpty,decoration:decorations.stories.active != nil || d.snowCloud.activeCount>0 || ornament || state?.actor != nil || state?.living.busy == true)
            let moving=decorations.stories.active != nil || d.snowCloud.activeCount>0 || state?.living.busy == true || state?.character != nil || !((state?.fragments.isEmpty) ?? true) || input.mode == .garland || objectDrag != nil || state?.deliveryElapsed != nil || state?.plowProgress != nil || (state?.snowmanNode != nil && state?.snowmanFinalized == false) || (state?.giftOpenedAt.map { now-$0<3 } ?? false)
            let appearing=decorations.states[d.id].map { $0.tree != nil && now-$0.treeAppearedAt<0.7 } ?? false
            (d.background.contentView as? SKView)?.preferredFramesPerSecond=(moving || appearing) ? fps:min(8,fps)
        }
    }
    func suppressForFullscreen() {
        garlandRemoval.cancel()
        stickerStudio.finish(cancelDrag:true)
        finishSculpting();cancelCleaning();decorations.cancelTransient(preserveStories:!config.stories.pauseInFullscreen);cancelWindowEffects();input.stop()
        for d in displays {d.hide(true);(d.background.contentView as? SKView)?.isPaused=true}
    }
    func syncSurfaces(now: Double) {
        let windows=interactionWindows,valid=Set(windows.map(\.id))
        for key in Array(surfaces.surfaces.keys) where key.hasPrefix("window-") && (!valid.contains(key) || !config.windowSnow) {surfaces.surfaces.removeValue(forKey:key);lastVisibleSnow.removeValue(forKey:key)}
        guard config.windowSnow else {return}
        for w in windows {
            guard let display=displays.first(where: { $0.rect.contains(w.frame.center) }) ?? displays.first(where: { $0.rect.intersects(w.frame) }) else {continue}
            let frame=Rect(w.frame.x+2,w.frame.y+0.5,max(1,w.frame.width-4),w.frame.height)
            if surfaces.surfaces[w.id] == nil {surfaces.surfaces[w.id]=SnowSurface(id:w.id,screenID:display.id,frame:frame,maxHeight:config.accumulationHeight)}
            if let old=surfaces.surfaces[w.id],old.visible {lastVisibleSnow[w.id]=(old,now)}
            if surfaces.surfaces[w.id]?.frame != frame {let event=surfaces.surfaces[w.id]?.updateWindow(to:frame,dt:0.12,now:now) ?? SnowFallEvent();queueSnow(event,displayID:display.id)}
            surfaces.surfaces[w.id]?.screenID=display.id
            let visible=w.isVisible && w.state.canAccumulate
            surfaces.surfaces[w.id]?.visible=visible;surfaces.surfaces[w.id]?.renderVisible=visible
        }
    }
    private func cancelWindowEffects() {
        for effect in director.active where effect.region != nil { director.cancel(effect.id) }
        let activeIDs=Set(director.active.map(\.id))
        for display in displays { display.engine.retainEffects(activeIDs) }
    }
    private func detachWindowSnow(_ w: TrackedWindow,fraction: Double) {
        let source: SnowSurface?
        if let current=surfaces.surfaces[w.id],current.visible {source=current}
        else if let snapshot=lastVisibleSnow[w.id],ProcessInfo.processInfo.systemUptime-snapshot.time<1 {source=snapshot.surface}
        else {source=nil}
        defer {lastVisibleSnow.removeValue(forKey:w.id)}
        guard let source,source.volume>1 else {return}
        _=director.start(.collapse,duration:config.windowEffectDuration,priority:1,particles:0,region:w.frame,sourceID:w.id)
        _=surfaces.surfaces[w.id]?.remove(fraction:fraction)
        let cell=source.length/Double(source.heights.count)
        let chunks=source.heights.enumerated().filter {$0.element>0}.map {SnowChunk(Vec(source.frame.x+(Double($0.offset)+0.5)*cell,source.frame.y-$0.element-2),Vec(0,20),$0.element*cell*fraction,fallsToGround:true)}
        queueSnow(SnowFallEvent(chunks),displayID:source.screenID)
    }
    private func windowClose(_ w: TrackedWindow) {detachWindowSnow(w,fraction:1);surfaces.surfaces.removeValue(forKey:w.id)}
    private func windowMinimize(_ w: TrackedWindow) {detachWindowSnow(w,fraction:1);surfaces.surfaces[w.id]?.visible=false;surfaces.surfaces[w.id]?.renderVisible=false}
    func windowGeometry(_ w: TrackedWindow,old:Rect,dt:Double) {
        guard config.windowSnow,let source=surfaces.surfaces[w.id],source.visible else{return}
        let frame=Rect(w.frame.x+2,w.frame.y+0.5,max(1,w.frame.width-4),w.frame.height)
        let event=surfaces.surfaces[w.id]?.updateWindow(to:frame,dt:dt,now:ProcessInfo.processInfo.systemUptime) ?? SnowFallEvent()
        queueSnow(event,displayID:source.screenID)
    }
    func queueSnow(_ event:SnowFallEvent,displayID:String) {
        guard event.mass>0 else{return};pendingSnow[displayID,default:[]]+=event.chunks
        if let chunks=pendingSnow[displayID],chunks.count>128 {
            var merged:[SnowChunk]=[]
            for falls in [false,true] {
                let sorted=chunks.filter{$0.fallsToGround==falls}.sorted{$0.position.x<$1.position.x},size=max(1,(chunks.count+31)/32)
                for start in stride(from:0,to:sorted.count,by:size) {
                    let group=Array(sorted[start..<min(sorted.count,start+size)]),mass=group.reduce(0){$0+$1.mass}
                    guard mass>0 else{continue};merged.append(SnowChunk(group.reduce(Vec()){$0+$1.position*$1.mass}/mass,group.reduce(Vec()){$0+$1.velocity*$1.mass}/mass,mass,fallsToGround:falls))
                }
            };pendingSnow[displayID]=merged
        }
    }
    func flushSnowEvents() {
        var available=max(0,80-displays.reduce(0){$0+$1.engine.particles.filter{$0.remaining>=0}.count})
        for d in displays {
            guard let chunks=pendingSnow[d.id],!chunks.isEmpty else{continue}
            var retained:[SnowChunk]=[]
            for fallsToGround in [false,true] {
                let group=chunks.filter{$0.fallsToGround==fallsToGround}
                guard !group.isEmpty else{continue}
                let count=min(12,available,group.count)
                if d.engine.emit(SnowFallEvent(group),limit:count)>0 {available-=count}
                else {retained+=group}
            };pendingSnow[d.id]=retained
        }
    }
    func stepCleaning(dt:Double,now:Double) {
        if let elapsed=cleaningElapsed {
            let t=elapsed+dt;cleaningElapsed=t
            if let key=cleaningSurfaceID,let surface=surfaces.surfaces[key],let display=displays.first(where:{$0.id==surface.screenID}) {
                if quietCleaning {
                    let removed=surfaces.surfaces[key]?.remove(fraction:min(1,dt/max(0.001,0.6-elapsed))) ?? 0;plowLoad.melted+=removed
                    if t>=0.6 {cleaningElapsed=nil;cleaningSurfaceID=nil;lastCleaning=now};return
                }


                let fraction=PlowSweep.fraction(progress:t/6,display:display.rect,dock:surface.frame,axis:surface.axis)
                surfaces.surfaces[key]?.sweepReversed=surface.axis == .verticalRight
                let collected=surfaces.surfaces[key]?.clearThrough(fraction) ?? 0
                plowLoad.collect(collected);surfaces.surfaces[key]?.sweepFraction=fraction
                plowLoad.position=PlowSweep.position(progress:t/6,display:display.rect,dock:surface.frame,axis:surface.axis)
                for (id,state) in decorations.states {state.plowProgress=id==display.id ? min(1,t/6):nil;state.plowSurface=id==display.id ? surface:nil;state.plowMass=plowLoad.mass}
                if t>=6 {plowLoad.export();surfaces.surfaces[key]?.sweepFraction=nil;cleaningElapsed=nil;cleaningSurfaceID=nil;for state in decorations.states.values {state.plowProgress=nil;state.plowMass=0};lastCleaning=now}
            } else {cancelCleaning()}
        } else if input.mode != .snow && config.automaticCleaning>0 && now-lastCleaning>=config.automaticCleaning {clean()}
    }
    func cancelCleaning() {
        if let key=cleaningSurfaceID,var surface=surfaces.surfaces[key] {surface.sweepFraction=nil;let mass=plowLoad.take(),accepted=surface.add(volume:mass);surfaces.surfaces[key]=surface;if mass>accepted {queueSnow(SnowFallEvent([SnowChunk(plowLoad.position,Vec(0,10),mass-accepted)]),displayID:surface.screenID)}}
        if cleaningSurfaceID != nil,plowLoad.mass>0 {plowLoad.export()}
        cleaningElapsed=nil;cleaningSurfaceID=nil;for state in decorations.states.values{state.plowProgress=nil;state.plowMass=0}
    }
    func startSculpting() {
        for d in displays {guard let state=decorations.states[d.id] else{continue}
            state.sculptArea=Rect(d.rect.x,d.rect.maxY-180,d.rect.width,180)
            state.sculptSeeded=false;state.snowmanFloating=true
        }
        diagnostic=config.automaticSnowman ? "Choose a spot. Click to build; Esc to cancel.":"Drag the shovel through the bottom snow. Roll three balls. Esc to finish."
    }
    func updateSculpting() {
        for (id,state) in decorations.states where state.sculptArea != nil {
            state.sculptSeeded=(surfaces.surfaces["ground-"+id]?.volume ?? 0)>50
        }
    }
    func finishSculpting() {
        finishSnowballPlay()
        for (id,state) in decorations.states where state.sculptArea != nil {
            let source="ground-"+id
            for ball in state.snowballs.balls {
                if let surface=surfaces.surfaces[source] {
                    let f=(ball.position.x-surface.frame.x)/max(1,surface.length),mass=Double.pi*ball.radius*ball.radius
                    let accepted=surfaces.surfaces[source]?.depositImpact(at:f,volume:mass) ?? 0
                    if mass>accepted {queueSnow(SnowFallEvent([SnowChunk(ball.position,Vec(0,15),mass-accepted,fallsToGround:true)]),displayID:id)}
                }
            }
            state.snowballs.balls=[];state.sculptArea=nil;state.sculptSeeded=false
        };draggedBall=nil;objectDrag=nil;NSCursor.arrow.set()
    }
    func clean(surfaceID:String?=nil) {
        guard cleaningElapsed == nil,!decorations.livingBusy else{return}
        if let id=surfaceID,surfaces.surfaces[id] != nil {cleaningSurfaceID=id}
        else {cleaningSurfaceID=surfaces.surfaces.values.filter{$0.id.hasPrefix("ground-") && $0.volume>0}.max(by:{$0.volume<$1.volume})?.id}
        guard cleaningSurfaceID != nil else{return}
        quietCleaning=config.mode == .focus || director.reducedMotion
        if quietCleaning {plowLoad=SnowPile();cleaningElapsed=0;return}
        guard director.start(.plow,duration:6,priority:2) != nil else { return }
        cleaningElapsed=0;plowLoad=SnowPile()
        for state in decorations.states.values { if state.sculptArea == nil { state.snowballs.balls.removeAll() }; if !config.preserveSnowman {state.snowballs.clearSnowmen();saveSnowman(displays.first(where:{decorations.states[$0.id] === state})?.id ?? "")} }
    }
    func reset() {
        finishSculpting();cancelCleaning();pendingSnow=[:];director.cancelAll(); lastVisibleSnow.removeAll(); surfaces.clear(); displays.forEach { $0.engine.reset() }; decorations.reset(preserveSnowman:false); input.stop(); config.interaction=false; config.tree=false; config.garland=false; config.mascot="none"; config.placements=[:]; cleaningElapsed=nil; lastCleaning=ProcessInfo.processInfo.systemUptime; persist(); applySettings()
    }
    func beginEditor(_ mode: EditorMode,addingAnchor:Bool=false) {
        guard config.mode != .focus && !paused && !sleeping else { return }
        guard !decorations.livingBusy else{diagnostic="Finish the current activity first.";return}
        if mode == .snow,decorations.snowmanCount>=5 {diagnostic="Five snowmen already. Hit one to make room.";return}
        decorations.stories.stop(immediately:true,reason:"User started editing")
        onWorldInteraction?()
        if mode != .garlandDelete {garlandRemoval.endPicker()}
        if mode != .decorations {stickerStudio.finish(cancelDrag:true)}
        finishSculpting();input.stop(); objectDrag=nil; draggedBall=nil; input.mode=mode;input.addingGarlandAnchor=addingAnchor
        if (mode == .hat || mode == .garlandWindow) && !observer.hasAccessibility { observer.permissionPrompt() }
        if mode == .snow { config.automaticSnowman=false;config.interaction=true;startSculpting() }
        if mode == .garland || mode == .garlandWindow {config.garland=true}
        if mode == .ornaments {for id in decorations.states.keys {if config.placements[id]?.tree != nil,config.placements[id]?.ornaments == nil {config.placements[id]?.ornaments=TreeOrnament.defaults}}}
        input.sculptSurface={ [weak self] id in self?.surfaces.surfaces["ground-"+id] };input.automaticSnowman=config.automaticSnowman;input.placementModelHeight=decorations.treeHeight(config)
        input.groundForPlacement={ [weak self] x,d in guard let self else{return d.rect.maxY-12};return self.decorations.groundY(x,display:d,surfaces:self.surfaces) }
        input.onCancel={ [weak self] in guard let self else{return};self.finishSculpting();self.input.stop();self.config.interaction=false;self.diagnostic="Cancelled.";self.lastInput=0;self.persist();self.statusChanged?() }
        if mode == .tree {diagnostic="Click to place your tree. Esc to cancel."}
        input.rebuild(displays:displays,windows:interactionWindows,dock:dock,decorations:decorations,focus:false,icons:dockObserver.icons)
        lastInput=0; persist(); statusChanged?()
    }
    func brushPointer(_ p:Vec,now:Double) {
        defer {previousPointer=p}
        guard let previous=previousPointer,input.mode == .none,objectDrag == nil,draggedBall == nil else{return}
        let distance=(p-previous).length
        guard distance>1,distance<200 else{return}
        for source in surfaces.surfaces.values where source.visible && source.renderVisible && source.volume>0 {
            if source.id.hasPrefix("ground-"),interactionWindows.contains(where:{$0.isVisible && $0.frame.contains(p)}){continue}
            let f=source.axis == .horizontal ? (p.x-source.frame.x)/max(1,source.length):(p.y-source.frame.y)/max(1,source.length)
            let normal=source.axis == .horizontal ? abs(p.y-source.frame.y):abs(p.x-source.point(at:f).x)
            guard f>=0,f<=1,normal<max(12,source.maxHeight+5) else{continue}
            if let owner=interactionWindows.first(where:{$0.id==source.id}),interactionWindows.contains(where:{$0.isVisible && $0.z<owner.z && $0.frame.contains(p)}) {continue}
            let event=surfaces.surfaces[source.id]?.displace(at:f,radius:25,distance:p.x-previous.x,speed:distance*Double(fps)) ?? SnowFallEvent()
            brushedVolume+=event.mass
            queueSnow(event,displayID:source.screenID)
        }
    }
    func handleInput(_ rawEvent: String,p: Vec,id: String) {
        var event=rawEvent
        if rawEvent.hasPrefix("move-snowman@"),let d=decorations.states[id],let name=rawEvent.split(separator:":").first,let uuid=UUID(uuidString:String(name.dropFirst(13))) {
            d.snowballs.select(uuid);event="move-snowman:"+(rawEvent.split(separator:":").last.map(String.init) ?? "")
        }
        guard let d=displays.first(where: { $0.id == id }),let state=decorations.states[id] else { return }
        let now=ProcessInfo.processInfo.systemUptime
        let kind=String(event.split(separator:":").first ?? "")
        if kind=="snowball-play" {snowballPlayInput(event,p:p,display:d);return}
        if kind=="feed-snow" {decorations.feedInput(event,p:p,display:d);return}
        if handleWorldInput(event,p:p,display:d,state:state) {return}
        if ["move-tree","move-snowman","gift"].contains(kind),event.hasSuffix(":down") {
            let origin: Vec?
            if kind == "move-tree",let tree=state.tree { origin=Vec(d.rect.x+tree.position.x,d.rect.maxY-tree.position.y) }
            else if kind == "move-snowman" { origin=state.snowballs.snowman }
            else { origin=state.giftPosition }
            if let origin { objectDrag=(kind,id,origin-p,p,false) };return
        }
        if var drag=objectDrag,drag.display == id {
            if drag.kind == "gift",state.gift == nil {objectDrag=nil;return}
            if event.hasSuffix(":drag") {
                if (p-drag.start).length>4 { drag.moved=true };objectDrag=drag
                let radius=drag.kind == "move-tree" ? 44.0:30.0
                let target=p+drag.offset
                let snowmanMass=state.snowballs.assemblyBalls.reduce(0){$0+Double.pi*$1.radius*$1.radius},snowmanHeight=clamp(56*sqrt(max(1,snowmanMass)/(Double.pi*261)),35,96)
                let q:Vec
                if drag.kind == "move-tree" {q=Vec(clamp(target.x,d.rect.x+state.treeHeight*0.42,d.rect.maxX-state.treeHeight*0.42),decorations.groundY(target.x,display:d,surfaces:surfaces)-state.treeHeight*0.38)}
                else if drag.kind == "move-snowman" {let x=clamp(target.x,d.rect.x+30,d.rect.maxX-30);q=Vec(x,decorations.groundY(x,display:d,surfaces:surfaces)-snowmanHeight*0.441)}
                else {q=Vec(clamp(target.x,d.rect.x+radius,d.rect.maxX-radius),clamp(target.y,d.rect.y+44,d.rect.maxY-radius))}
                if drag.kind == "move-snowman",state.snowballs.snowmen.contains(where:{$0.id != state.snowballs.primaryID && abs($0.position.x-q.x)<($0.height+snowmanHeight)*0.4+8}) {return}
                guard (drag.kind == "move-snowman" && (state.snowmanFloating || input.mode == .snowmen)) || !interactionWindows.contains(where: { $0.isVisible && $0.frame.intersects(Rect(q.x-radius,q.y-radius,radius*2,radius*2)) }) else { return }
                if drag.kind == "move-tree" {
                    var placement=config.placements[id] ?? Placement();placement.treeIdentity=UUID().uuidString;placement.tree=Vec((q.x-d.rect.x)/d.rect.width,(q.y-d.rect.y)/d.rect.height);config.placements[id]=placement;state.tree?.position=d.local(q)
                } else if drag.kind == "move-snowman" { state.snowballs.snowman=q;state.snowmanNode?.position=d.local(q);state.snowmanLocation=q }
                else { state.giftPosition=q;state.target=q;state.gift?.position=d.local(q) }
            } else if event.hasSuffix(":up") {
                objectDrag=nil
                if drag.kind == "gift" && !drag.moved { decorations.openGift(displayID:id,now:now,fireworks:config.mode != .focus && !director.reducedMotion,director:director) }
                if drag.kind == "move-tree" {persist()}
                if drag.kind == "move-snowman" {saveSnowman(id)}
                if drag.kind == "move-snowman",state.sculptArea == nil,let q=state.snowballs.snowman {state.snowmanFloating=interactionWindows.contains { $0.isVisible && $0.frame.intersects(Rect(q.x-30,q.y-30,60,60)) }}
                lastInput=0
            };return
        }
        if event == "hat:down" {
            if let icon=dockObserver.icons.first(where: { $0.frame.contains(p) }) { config.dockHats[icon.id]=input.hatColor;input.stop();persist();statusChanged?() };return
        }
        if kind.hasPrefix("tree-gift@"),event.hasSuffix(":down"),let index=state.treePresents.firstIndex(where:{$0.id==String(kind.dropFirst(10))}),state.treePresents[index].openedAt==nil {
            state.treePresents[index].openedAt=now
            if config.placements[id]?.storyPresents != nil {saveStoryDecorations(id)}
            if director.start(.fireworks,duration:2.6,particles:36) != nil {decorations.tripleFireworks(parent:state.treePresents[index].node,reduced:director.reducedMotion,now:now)}
            lastInput=0;return
        }
        if event == "tree:down" {
            let h=decorations.treeHeight(config),preferred=clamp(p.x,d.rect.x+h*0.42,d.rect.maxX-h*0.42)
            let candidates=[preferred]+Array(stride(from:d.rect.x+h*0.42,through:d.rect.maxX-h*0.42,by:12)).sorted{abs($0-preferred)<abs($1-preferred)}
            guard let x=candidates.first(where:{x in !state.snowballs.snowmen.contains{abs($0.position.x-x)<h*0.38+$0.height*0.35+10}}) else{diagnostic="Move a snowman to make room for the tree.";return}
            let q=Vec(x,decorations.groundY(x,display:d,surfaces:surfaces)-h*0.38)
            guard decorations.deliverTree(display:d,feet:Vec(q.x,decorations.groundY(q.x,display:d,surfaces:surfaces)),config:config) else{return};config.tree=true
            var placement=config.placements[id] ?? Placement();placement.tree=Vec((q.x-d.rect.x)/d.rect.width,(q.y-d.rect.y)/d.rect.height);placement.ornaments=TreeOrnament.defaults;config.placements[id]=placement;input.stop();diagnostic="Tree on its way. It will appear behind your windows.";persist();statusChanged?();return
        }
        if kind.hasPrefix("garland@"),event.hasSuffix(":down") {
            let selected=String(kind.dropFirst(8))
            guard let window=interactionWindows.first(where: { $0.id == selected && $0.isVisible }) else { return }
            var placement=config.placements[id] ?? Placement();placement.garlandWindow=window.id;placement.garlandTarget="window";placement.garland=[Vec(0.15,0),Vec(0.55,0),Vec(0.95,0)];config.placements[id]=placement
            input.mode = .garland;persist();statusChanged?();lastInput=0;return
        }
        if ["snow:down","ball:down"].contains(event) {
            guard decorations.snowmanCount<5 else{diagnostic="Five snowmen already. Hit one to make room.";return}
            if config.automaticSnowman,event=="snow:down" {
                let target=Vec(clamp(p.x,d.rect.x+40,d.rect.maxX-40),decorations.groundY(p.x,display:d,surfaces:surfaces))
                guard decorations.automaticSnowman(display:d,at:target) else{diagnostic="Finish the current activity first.";return}
                finishSculpting();input.stop();config.interaction=false;diagnostic="Spot chosen. Waiting for enough snow.";persist();statusChanged?();return
            }
            let ground="ground-"+id
            if let ball=state.snowballs.balls.min(by:{abs($0.position.x-p.x)<abs($1.position.x-p.x)}),abs(ball.position.x-p.x)<ball.radius+14 {draggedBall=(id,ball.id)}
            else if input.mode == .snow,state.snowballs.balls.count<3,let surface=surfaces.surfaces[ground] {
                let f=clamp((p.x-d.rect.x)/d.rect.width,0,1),mass=surfaces.surfaces[ground]?.extract(volume:Double.pi*16,at:f) ?? 0
                if mass>=Double.pi*16-0.01 {
                    let ball=Snowball(position:Vec(p.x,surface.frame.y-surface.height(at:f)-4));state.snowballs.balls.append(ball);draggedBall=(id,ball.id)
                } else {if mass>0 {_=surfaces.surfaces[ground]?.depositImpact(at:f,volume:mass)};diagnostic="Not enough snow yet. Increase snowfall or shake a window."}
            };lastDrag=p;return
        }
        if event.hasSuffix(":drag"),let (screenID,ballID)=draggedBall,screenID==id,let i=state.snowballs.balls.firstIndex(where:{$0.id==ballID}),let surface=surfaces.surfaces["ground-"+id] {
            let x=clamp(p.x,d.rect.x+20,d.rect.maxX-20),distance=abs(x-lastDrag.x),f=(x-d.rect.x)/d.rect.width
            state.snowballs.balls[i].rotation+=(x-lastDrag.x)/max(4,state.snowballs.balls[i].radius)
            let capacity=max(0,Double.pi*(26*26-pow(state.snowballs.balls[i].radius,2)))
            let gathered=surfaces.surfaces[surface.id]?.extract(volume:min(capacity,distance*6),at:f) ?? 0
            state.snowballs.balls[i].gather(volume:gathered)
            state.snowballs.balls[i].position=Vec(x,surface.frame.y-surface.height(at:f)-state.snowballs.balls[i].radius)
            lastDrag=Vec(x,p.y)
        } else if event.hasSuffix(":up"),draggedBall != nil {
            draggedBall=nil
            if let surface=surfaces.surfaces["ground-"+id] {
                let f=clamp((p.x-d.rect.x)/d.rect.width,0.08,0.92),q=Vec(d.rect.x+f*d.rect.width,surface.frame.y-surface.height(at:f)-27)
                let used=state.snowballs.snowmen
                let newHeight=clamp(56*sqrt(state.snowballs.balls.reduce(0){$0+Double.pi*$1.radius*$1.radius}/(Double.pi*261)),35,96)
                let preferred=q.x,candidates=[preferred]+Array(stride(from:d.rect.x+55,through:d.rect.maxX-55,by:12)).sorted{abs($0-preferred)<abs($1-preferred)}
                let clearX=candidates.first{x in !used.contains{abs($0.position.x-x)<($0.height+newHeight)*0.45+12}}
                if let x=clearX,state.snowballs.balls.allSatisfy({$0.radius>=6}),state.snowballs.assemblePrepared(at:Vec(x,q.y)) {state.snowmanFloating=true;saveSnowman(id);finishSculpting();input.stop();config.interaction=false;diagnostic="Your snowman is ready!";persist();statusChanged?()}
            };lastInput=0
        }
    }
    func stateJSON() -> [String:Any] {
        let data=(try? JSONEncoder().encode(config)) ?? Data("{}".utf8)
        return ["stickerStudio":stickerStudio.snapshot(),"christmasStories":storySnapshot(),"tracking":["dockInventoryScans":dockObserver.inventoryScans,"dockFrameQueries":dockObserver.frameQueries],"rendering":displays.map { ["display":$0.id,"desktop":$0.desktopCanvas.probe.snapshot,"windowCaps":$0.canvas.probe.snapshot,"interactive":$0.actionCanvas.probe.snapshot,"spriteKit":($0.decorationScene as? WinterScene)?.probe.snapshot ?? [:]] as [String:Any] },"living":livingSnapshot(),"config":(try? JSONSerialization.jsonObject(with:data)) ?? [:],"paused":paused,"systemPaused":sleeping || sessionInactive,"fullscreenSuppressed":observer.fullscreen,"reducedMotionActive":director.reducedMotion,"deliveryState":["giftActive":decorations.states.values.contains{$0.deliveryElapsed != nil || $0.gift != nil || $0.giftOpenedAt != nil},"pending":decorations.pendingDelivery,"flying":decorations.states.values.contains { $0.deliveryElapsed != nil },"giftWaiting":decorations.states.values.contains { $0.giftPosition != nil && $0.giftOpenedAt == nil && $0.giftLanded }],"accessibility":observer.hasAccessibility,"windows":observer.windows.count,"windowSnowStates":observer.sorted.map { window -> [String:Any] in
            ["id":window.id,"phase":window.state.phase.rawValue,"visible":window.isVisible,"accessibilityLinked":window.ax != nil,
             "frame":["x":window.frame.x,"y":window.frame.y,"width":window.frame.width,"height":window.frame.height],
             "snowOrigin":surfaces.surfaces[window.id].map{[$0.frame.x,$0.frame.y]} ?? [],"snowVolume":surfaces.surfaces[window.id]?.volume ?? 0,"restoreProgress":window.state.restoreProgress]
        },"windowEvents":observer.events,"windowEffects":director.active.compactMap { effect -> [String:Any]? in
            guard let region=effect.region else { return nil }
            return ["id":effect.id.uuidString,"sourceID":effect.sourceID ?? "","kind":effect.kind.rawValue,"elapsed":effect.elapsed,"duration":effect.duration,"timeScale":effect.snowMultiplier,
                    "region":["x":region.x,"y":region.y,"width":region.width,"height":region.height]]
        },"surfaceIDs":surfaces.surfaces.keys.sorted(),"displays":displays.count,"dockDetected":dock != nil,"dockVisible":dock?.isVisible ?? false,"dockSnowVolume":surfaces.surfaces["dock"]?.volume ?? 0,"yetiGames":decorations.states.mapValues{["lastGame":$0.lastYetiGame,"castleMass":$0.castleMass,"castleProgress":$0.castleProgress] as [String:Any]},"snowWorld":["carriedMass":plowLoad.mass,"exportedMass":plowLoad.exported,"meltedMass":plowLoad.melted,"pendingMass":pendingSnow.values.flatMap{$0}.reduce(0){$0+$1.mass},"groundMass":surfaces.surfaces.values.filter{$0.id.hasPrefix("ground-")}.reduce(0){$0+$1.volume}],"brushedSnowVolume":brushedVolume,"dockIcons":dockObserver.icons.count,"editor":input.mode.rawValue,"characters":decorations.states.compactMap {id,s -> [String:Any]? in guard let c=s.character else{return nil};return ["display":id,"action":c.action.rawValue,"phase":c.phase.rawValue,"elapsed":c.elapsed]},"snowmen":decorations.states.flatMap{id,s in s.snowballs.snowmen.map{["id":$0.id.uuidString,"display":id,"x":$0.position.x,"y":$0.position.y,"height":$0.height]}},"looseSnowballs":decorations.states.values.reduce(0){$0+$1.snowballPlay.balls.count},"sculpting":["balls":decorations.states.values.reduce(0){$0+$1.snowballs.balls.count},"snowmen":decorations.snowmanCount,"limit":5,"active":decorations.states.values.contains { $0.sculptArea != nil },"seeded":decorations.states.values.contains { $0.sculptSeeded },"ready":decorations.states.values.contains { $0.sculptArea != nil && $0.snowballs.snowman != nil }],"performance":performance.snapshot,"diagnostic":diagnostic,"sessionToken":server.policy.token]
    }
    private func handle(_ request: HTTPRequest) -> HTTPResponse {
        if request.method == "GET" {
            if request.path == "/api/checks" { return HTTPResponse(body:(try? JSONEncoder().encode(manualChecks)) ?? Data("{}".utf8)) }
            if request.path == "/api/stickers/preset" {return HTTPResponse(body:(try? JSONEncoder().encode(StickerPreset(settings:config.stickers))) ?? Data())}
            if request.path == "/api/state" { return .json(stateJSON()) }
            if request.path.hasPrefix("/assets/") {
                let id=String(request.path.dropFirst(8))
                if let data=AssetManager.shared.preview(id) { return HTTPResponse(type:"image/png",body:data) }
                return .json(["error":"unknown asset"],status:404)
            }
            if request.path == "/api/assets" { return .json(["ids":AssetManager.shared.registry.keys.sorted(),"textureLoads":AssetManager.shared.loadCount]) }
            let files=["/":"index.html","/app.js":"app.js","/stickers.js":"stickers.js","/testing.js":"testing.js","/style.css":"style.css","/models":"models.html"]
            if let file=files[request.path], let data=try? Data(contentsOf:Resources.root.appendingPathComponent("Web/\(file)")) {
                let type=file.hasSuffix("js") ? "text/javascript; charset=utf-8" : file.hasSuffix("css") ? "text/css; charset=utf-8" : "text/html; charset=utf-8"
                return HTTPResponse(type:type,body:data)
            }
            return .json(["error":"not found"],status:404)
        }
        if request.path == "/api/stickers" {return stickerRequest(request)}
        if request.path == "/api/checks" {
            guard var next=try? JSONDecoder().decode(ManualCheckProgress.self,from:request.body) else { return .json(["error":"invalid checklist"],status:400) }
            next.validate()
            do { try next.save(to:checksURL); manualChecks=next; return HTTPResponse(body:try JSONEncoder().encode(next)) }
            catch { return .json(["error":"cannot save checklist"],status:500) }
        }
        if request.path == "/api/config" {
            do {
                var next=try Configuration.decodeCompatible(request.body);next.validate()
                if decorations.livingBusy {next.treeSize=config.treeSize}
                let before=[config.treeToy1,config.treeToy2,config.treeToy3],after=[next.treeToy1,next.treeToy2,next.treeToy3]
                for id in next.placements.keys {
                    var toys=next.placements[id]?.ornaments ?? TreeOrnament.defaults
                    for i in 0..<3 where before[i] != after[i] {if let index=toys.firstIndex(where:{$0.id=="tree_slot_\(i)"}) {toys[index].hidden=false}}
                    next.placements[id]?.ornaments=toys
                }
                if next.stories.frequency != config.stories.frequency {decorations.stories.scheduler.schedule(next.stories.frequency)}
                config=next;applySettings();persist();return .json(stateJSON())
            }
            catch { return .json(["error":"invalid configuration"],status:400) }
        }
        guard request.path == "/api/action", let body=try? JSONSerialization.jsonObject(with:request.body) as? [String:Any], let action=body["action"] as? String else { return .json(["error":"invalid command"],status:400) }
        diagnostic=""
        switch action {
        case "story-play":
            guard let raw=body["id"] as? String,let id=ChristmasStoryID(rawValue:raw) else{return .json(["error":"unknown story"],status:400)}
            let variant=decorations.stories.developerMode ? body["variant"] as? Int:nil
            if let variant,!(0...1).contains(variant){return .json(["error":"invalid variant"],status:400)}
            _=playChristmasStory(id,variant:variant)
        case "story-random":_=playChristmasStory()
        case "story-stop":manualStoryPlayback?.stop();decorations.stories.stop();diagnostic="Finishing the story…"
        case "stories-toggle":config.stories.enabled.toggle();persist()
        case "pause": if !paused { togglePause() }
        case "resume": if paused { togglePause() }
        case "reset": reset()
        case "reset-settings": reset();config=Configuration();paused=false;persist();applySettings()
        case "clean": if !decorations.livingBusy {clean()}
        case "clean-ground":clean(surfaceID:displays.first.map{"ground-"+$0.id})
        case "shake-windows":for w in interactionWindows where w.isVisible {detachWindowSnow(w,fraction:1)}
        case "garland-add-anchor":beginEditor(.garland,addingAnchor:true)
        case "delivery": if !paused,!sleeping,config.mode != .focus,!director.reducedMotion,!decorations.livingBusy {decorations.pendingDelivery=true}
        case "tree": if !config.tree {beginEditor(.tree)}else{diagnostic="Tree already placed. Drag it to move."}
        case "hat-red","hat-green","hat-blue": input.hatColor=String(action.dropFirst(4)); beginEditor(.hat)
        case "remove-hats": config.dockHats=[:]; persist()
        case "remove-tree":removeLivingTree()
        case "remove-snowman","throw-snowball":removeLivingSnowman()
        case "yeti-help":beginEditor(.snow)
        case "yeti-play","yeti-surprise":startLivingYeti("surprise")
        case "yeti-dodge":startLivingYeti("dodge")
        case "yeti-carry","feed-yeti":startLivingYeti("feed")
        case "start-duel":startLivingDuel()
        case "exit-duel":endLivingDuel()
        case "duel-aim":guard let power=body["power"] as? Double,power.isFinite else{return .json(["error":"invalid power"],status:400)};decorations.aimDuel(power)
        case "duel-fire":_ = decorations.fireDuel()
        case "drop-gift":if !paused,!sleeping,config.mode != .focus,!director.reducedMotion,!decorations.livingBusy {for d in displays {if decorations.startParachuteGift(display:d,surfaces:surfaces){break}}}
        case "cancel-story":manualStoryPlayback?.stop();decorations.cancelTransient();endLivingDuel();input.stop()
        case "tree-gifts":if !decorations.livingBusy {for d in displays {decorations.addTreePresents(display:d,surfaces:surfaces);if config.placements[d.id]?.storyPresents != nil {saveStoryDecorations(d.id)}};lastInput=0}
        case "ornaments":beginEditor(.ornaments)
        case "reset-ornaments":for id in config.placements.keys {config.placements[id]?.ornaments=TreeOrnament.defaults};persist()
        case "garland-tree":
            for id in config.placements.keys where config.placements[id]?.tree != nil {config.placements[id]?.garlandTarget="tree";config.placements[id]?.garlandWindow=nil;config.placements[id]?.garland=[Vec(0.25,0.5),Vec(0.7,0.6),Vec(0.25,0.76)]};config.garland=true;beginEditor(.garland)
        case "garland-window":beginEditor(.garlandWindow)
        case "remove-garland":garlandRemoval.deleteAll()
        case "garland-delete-select":garlandRemoval.pickMode()
        case "new-garland":
            for id in config.placements.keys {
                if let p=config.placements[id],p.garland.count>=2 {
                    var strands=p.extraGarlands ?? [];if strands.count>=8 {diagnostic="Up to eight strands per screen.";break}
                    strands.append(GarlandStrand(anchors:p.garland,target:p.garlandTarget ?? "desktop",window:p.garlandWindow,palette:config.bulbColor,sag:config.garlandSag));config.placements[id]?.extraGarlands=strands;config.placements[id]?.garland=[]
                }
            };persist();beginEditor(.garland)
        case "remove-garland-strand":garlandRemoval.pickMode()
        case "garland":
            for id in config.placements.keys where config.placements[id]?.garlandTarget == "tree" || config.placements[id]?.garlandWindow != nil {
                config.placements[id]?.garland=[];config.placements[id]?.garlandWindow=nil;config.placements[id]?.garlandTarget="desktop"
            };beginEditor(.garland)
        case "move-snowmen":beginEditor(.snowmen)
        case "snowball-play":beginSnowballPlay()
        case "snowballs": beginEditor(.snow)
        case "done": stickerStudio.finish();finishSculpting();input.stop(); config.interaction=false; persist(); statusChanged?()
        case "permission": observer.permissionPrompt()
        case "focus","balanced","play": applyPreset(WinterMode(rawValue:action)!)
        default: return .json(["error":"unknown action"],status:400)
        }
        return .json(stateJSON())
    }
    func startYetiGame() {
        guard config.mode != .focus,!director.reducedMotion,!paused else{return}
        guard let d=displays.first,let state=decorations.states[d.id] else{return}
        let castle=YetiGame.choose(unit:Double.random(in:0..<1)) == .castle,action:CharacterAction=castle ? .buildCastle:.playWithSnow
        let x=Double.random(in:(d.rect.x+145)...max(d.rect.x+146,d.rect.maxX-145)),p=Vec(x,decorations.groundY(x,display:d,surfaces:surfaces))
        if decorations.requestCharacter(action,display:d,target:p,windows:interactionWindows,surfaces:surfaces,config:config) {state.lastYetiGame=castle ? "castle":"snowball";diagnostic=castle ? "Yeti is building a snow wall.":"Yeti is throwing a snowball."}
        else {diagnostic="Yeti needs some snow and a clear moment."}
    }
    func stop() {
        garlandRemoval.cancel()
        stickerStudio.finish(cancelDrag:true)
        manualStoryPlayback?.stop();decorations.stories.stop(immediately:true,reason:"App closed");persist()
        duelPanel?.close();duelPanel=nil
        timer?.invalidate(); timer=nil; server.stop(); input.stop(); displays.forEach { $0.close() }; displays=[]
        for token in tokens { NSWorkspace.shared.notificationCenter.removeObserver(token); NotificationCenter.default.removeObserver(token) }; tokens=[]
    }
}
