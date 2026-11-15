import AppKit
import SnowCore

/// An explicit Play gets a temporary, click-through stage, independent of desktop prerequisites.
/// It uses the same production story engine and actors as automatic desktop stories.
final class ManualStoryPlayback {
    let manager=DecorationManager(),surfaces=SurfaceManager(),director=AnimationDirector()
    let display:DisplayOverlay
    var config=Configuration.preset(.play)
    private var timer:Timer?,lastTime=ProcessInfo.processInfo.systemUptime
    var onFinished:(()->Void)?
    private(set) var closed=false
    init?(id:ChristmasStoryID,variant:Int?,screen:NSScreen) {
        display=DisplayOverlay(screen:screen,surfaces:surfaces,primaryHeight:Double(NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY))
        config.snow=false;config.maxParticles=0;config.stories.enabled=false;config.stories.keepDecorations=false
        config.stories.allowSnowmanCreation=true;config.stories.pauseOnBattery=false
        config.tree=id.needsTree;config.treeGarland=id == .lightRepair ? "multi":"none"
        let d=display,key="ground-"+d.id
        surfaces.surfaces[key]=SnowSurface(id:key,screenID:d.id,frame:Rect(d.rect.x,d.rect.maxY-3,d.rect.width,1),maxHeight:42)
        surfaces.surfaces[key]?.add(volume:d.rect.width*14)
        manager.install([d]);guard let s=manager.states[d.id] else{display.close();return nil}
        if id.needsTree {config.placements[d.id]=Placement(tree:Vec(0.5,0.9))}
        if id.needsSnowman {
            let radii=StorySnowmanRecipe.radii,h=DesktopSnowman(position:Vec(),radii:radii).height,x=d.rect.center.x
            s.snowballs.additionalSnowmen=[DesktopSnowman(position:Vec(x,manager.groundY(x,display:d,surfaces:surfaces)-h*0.441),radii:radii)]
            s.restoredSnowman=true
        }
        if id == .garlandRemoval {config.garland=true;config.placements[d.id]=Placement(garland:[Vec(0.25,0.55),Vec(0.75,0.55)],garlandTarget:"desktop")}
        for _ in 0..<120 {manager.update(dt:1.0/60,now:lastTime-2,displays:[d],config:config,windows:[],dock:nil,surfaces:surfaces,director:director,mouse:Vec())}
        if id == .presentTheft {manager.addTreePresents(display:d,surfaces:surfaces,now:lastTime-2)}
        if id == .treeShake {for key in manager.stories.branchKeys(d.id,surfaces:surfaces){surfaces.surfaces[key]?.add(volume:100)}}
        if id == .garlandRemoval {manager.stories.removalTarget=GarlandRemovalTarget(display:d.id,id:"active",points:s.garlandPhysics.points,palette:config.bulbColor,bulbSize:config.bulbSize,owner:nil)}
        manager.onSnowFall={ [weak self] event,_ in _=self?.display.engine.emit(event,limit:48) }
        guard manager.stories.start(id,manager:manager,displays:[d],config:config,windows:[],dock:nil,surfaces:surfaces,variant:variant)==nil else{display.close();return nil}
        for window in [d.background,d.desktopSnow,d.foreground] {window.level = .floating;window.ignoresMouseEvents=true}
        d.setDesktopOccluded(false);d.setRenderActivity(snow:true,decoration:true)
        timer=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.tick()}
        RunLoop.main.add(timer!,forMode:.common)
    }
    func tick(dt forced:Double?=nil){
        guard !closed else{return};let now=ProcessInfo.processInfo.systemUptime,dt=forced ?? min(0.05,max(0,now-lastTime));lastTime=now
        display.engine.step(dt:dt,config:config)
        display.render(config:config,windows:[],surfaces:surfaces,active:nil)
        manager.update(dt:dt,now:now,displays:[display],config:config,windows:[],dock:nil,surfaces:surfaces,director:director,mouse:Vec())
        display.presentDesktopObjects();display.canvas.needsDisplay=true;display.desktopCanvas.needsDisplay=true
        if manager.stories.active==nil {stop()}
    }
    func stop(){guard !closed else{return};closed=true;timer?.invalidate();timer=nil;manager.stories.stop(immediately:true);display.close();onFinished?()}
    deinit {timer?.invalidate()}
}
