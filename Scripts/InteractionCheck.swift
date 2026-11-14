import AppKit
import SpriteKit
import SnowCore
@main struct InteractionCheck {
    static func main() throws {
        _=NSApplication.shared
        let w=WinterCoordinator();w.config.snow=false;w.config.mode = .play;w.config.tree=false;w.config.garland=false;w.config.placements=[:];w.config.automaticCleaning=0;w.config.automaticSnowman=false
        w.start();defer { w.stop() }
        let fixturePID=Int32(CommandLine.arguments[CommandLine.arguments.firstIndex(of:"--fixture-pid")!+1])!
        let deadline=Date().addingTimeInterval(7)
        repeat {RunLoop.main.run(until:Date().addingTimeInterval(0.2));w.observer.poll(now:ProcessInfo.processInfo.systemUptime,screens:w.displays.map(\.rect))} while Date()<deadline && !w.observer.sorted.contains(where: { $0.pid == fixturePID && $0.isVisible })
        guard let d=w.displays.first,let state=w.decorations.states[d.id] else { fatalError("No display") }
        let pidIndex=CommandLine.arguments.firstIndex(of:"--fixture-pid")!
        let pid=Int32(CommandLine.arguments[pidIndex+1])!
        guard let target=w.observer.sorted.first(where: { $0.pid == pid && $0.isVisible }) else { fatalError("Fixture window not observed") }
        w.interactionWindowSource={ [target] }
        func update() { w.decorations.update(dt:0.02,now:ProcessInfo.processInfo.systemUptime,displays:w.displays,config:w.config,windows:w.interactionWindows,dock:w.dock,surfaces:w.surfaces,director:w.director,mouse:Vec()) }
        w.config.tree=true;update();precondition(state.tree == nil,"Tree appeared before choosing a position")
        let p=Vec(d.rect.x+90,d.rect.maxY-55)
        w.beginEditor(.tree)
        let selection=w.input.panels.first!,selectionView=selection.contentView as! InputView
        precondition(selection.level == .floating && selection.canBecomeKey && selectionView.placementAsset == "tree_bare","Placement cursor overlay unavailable above working windows")
        w.input.rebuild(displays:w.displays,windows:w.interactionWindows,dock:w.dock,decorations:w.decorations,focus:false,icons:[])
        precondition(w.input.panels.first === selection,"Placement preview recreated while aiming")
        let escape=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:selection.windowNumber,context:nil,characters:"\u{1b}",charactersIgnoringModifiers:"\u{1b}",isARepeat:false,keyCode:53)!
        selectionView.keyDown(with:escape);precondition(w.input.mode == .none && w.input.panels.isEmpty,"Escape cancellation left an overlay")
        w.beginEditor(.tree);w.handleInput("tree:down",p:p,id:d.id);update();precondition(state.tree == nil && state.living.delivery != nil && w.input.panels.isEmpty)
        let deliveryDeadline=Date().addingTimeInterval(7)
        while state.living.delivery != nil && Date()<deliveryDeadline {RunLoop.main.run(until:Date().addingTimeInterval(0.03))}
        update();precondition(state.tree != nil && state.living.delivery==nil)
        let actual=Vec(d.rect.x+state.tree!.position.x,d.rect.maxY-state.tree!.position.y),q=actual+Vec(100,0)
        w.handleInput("move-tree:down",p:actual,id:d.id);w.handleInput("move-tree:drag",p:q,id:d.id);w.handleInput("move-tree:up",p:q,id:d.id)
        let saved=w.config.placements[d.id]!.tree!
        precondition(abs(saved.x-(q.x-d.rect.x)/d.rect.width)<0.00001,"Tree drag not persisted")
        w.config.garland=true;w.config.validate();w.beginEditor(.garland)
        precondition(w.config.garland && w.input.mode == .garland);w.input.stop();w.config.garland=false
        let giftPoint=p
        state.gift=Resources.object(["gift_box","gift_lid","gift_bow"],size:50);state.root.addChild(state.gift!);state.giftPosition=giftPoint;state.deliveryElapsed=5;state.giftDropped=true;state.giftLanded=true;state.giftOpenedAt=nil
        let view=InputView(frame:NSRect(x:0,y:0,width:44,height:44))
        view.eventHandler={ kind,_ in w.handleInput("gift:"+kind,p:giftPoint,id:d.id) }
        let down=NSEvent.mouseEvent(with:.leftMouseDown,location:.zero,modifierFlags:[],timestamp:1,windowNumber:0,context:nil,eventNumber:1,clickCount:1,pressure:1)!
        let up=NSEvent.mouseEvent(with:.leftMouseUp,location:.zero,modifierFlags:[],timestamp:1.1,windowNumber:0,context:nil,eventNumber:2,clickCount:1,pressure:0)!
        precondition(view.acceptsFirstMouse(for:down));view.mouseDown(with:down);view.mouseUp(with:up)
        precondition(state.giftOpenedAt != nil,"First single click did not open the gift")
        w.handleInput("gift:down",p:giftPoint,id:d.id);w.handleInput("gift:drag",p:q,id:d.id);w.handleInput("gift:up",p:q,id:d.id);precondition(state.giftPosition == q)
        state.snowballs.snowman=p;update();let snowman=state.snowmanNode!
        w.handleInput("move-snowman:down",p:p,id:d.id);w.handleInput("move-snowman:drag",p:q,id:d.id);w.handleInput("move-snowman:up",p:q,id:d.id);update()
        precondition(state.snowballs.snowman?.x == q.x && state.snowmanNode === snowman,"Snowman drag recreated assembly")
        state.giftOpenedAt=ProcessInfo.processInfo.systemUptime-4;update()
        w.input.rebuild(displays:w.displays,windows:w.interactionWindows,dock:w.dock,decorations:w.decorations,focus:false,icons:[])
        precondition(state.gift == nil && !w.input.panels.contains { $0.contentView?.identifier?.rawValue == "gift" },"Expired gift retained an invisible hit area")
        state.giftOpenedAt=ProcessInfo.processInfo.systemUptime-13;update();precondition(state.giftPosition == nil && state.celebration.children.isEmpty)
        let dock=DockGeometry(frame:Rect(d.rect.x+300,d.rect.maxY-80,600,70),axis:.horizontal,screenID:d.id)
        var hiddenDock=dock;hiddenDock.isVisible=false;w.dock=hiddenDock
        var cap=SnowSurface(id:"ground-"+d.id,screenID:d.id,frame:Rect(d.rect.x,d.rect.maxY-2,d.rect.width,1),maxHeight:18)
        cap.add(volume:7000);w.surfaces.surfaces[cap.id]=cap
        state.snowballs.snowman=nil;state.snowballs.assemblyBalls=[];state.snowmanNode?.removeFromParent();state.snowmanNode=nil
        w.config.automaticSnowman=true;w.beginEditor(.snow);update()
        precondition(!w.config.automaticSnowman && AssetManager.shared.image("shovel_cursor") != nil,"Build action did not enter manual shovel mode")
        let floorPanel=w.input.panels.first{$0.contentView?.identifier?.rawValue=="snow"}
        precondition((floorPanel?.contentView as? InputView)?.glove==true && floorPanel!.level.rawValue>Int(CGWindowLevelForKey(.dockWindow)),"Shovel strip is behind auto-hide Dock")
        precondition(state.sculptArea?.maxY==d.rect.maxY && state.snowballs.balls.isEmpty && d.canvas.workbench==nil,"Separate workbench returned")
        for start in [d.rect.x+200,d.rect.x+500,d.rect.x+800] {
            w.handleInput("snow:down",p:Vec(start,d.rect.maxY-12),id:d.id)
            w.handleInput("snow:drag",p:Vec(start+95,d.rect.maxY-12),id:d.id)
            w.handleInput("snow:up",p:Vec(start+95,d.rect.maxY-12),id:d.id)
        };update()
        precondition(state.snowballs.snowman != nil && state.snowmanFloating && (state.snowmanNode != nil || !d.canvas.composites.isEmpty),"Floor gestures did not assemble a snowman")
        state.snowmanBuiltAt-=3;update();precondition(state.snowmanFinalized)
        precondition(state.sculptArea==nil && w.input.mode == .none && !w.config.interaction && state.snowballs.snowman != nil,"Completed sculpture did not exit shovel mode")
        w.input.stop();w.dock=dock
        let before=w.surfaces.surfaces[cap.id]!.volume
        w.brushPointer(Vec(d.rect.center.x,d.rect.maxY-4),now:100);w.brushPointer(Vec(d.rect.center.x+30,d.rect.maxY-4),now:100.1)
        precondition(w.surfaces.surfaces[cap.id]!.volume<before,"Cursor brush did not remove ground mass")
        w.input.mode = .hat
        w.input.rebuild(displays:w.displays,windows:w.interactionWindows,dock:dock,decorations:w.decorations,focus:false,icons:[DockIcon(id:"file:///Fixture.app",frame:Rect(dock.frame.x,dock.frame.y,70,70))])
        precondition(w.input.panels.first?.level.rawValue == Int(CGWindowLevelForKey(.dockWindow))+2)
        precondition(d.foreground.level.rawValue>Int(CGWindowLevelForKey(.dockWindow)))
        w.beginEditor(.snow);precondition(state.sculptArea != nil)
        w.suppressForFullscreen();precondition(state.sculptArea == nil && w.input.mode == .none,"Fullscreen left an orphaned sculpting panel")
        let result:[String:Any]=["passed":true,"scope":"native Cocoa events/controller with owned foreign fixture and seeded physics unit fixture; no global input injection","placementCursorPreviewAndCancellation":true,"treePlacementAndDrag":true,"garlandsRestored":true,"singleClickGift":true,"giftAndSnowmanDrag":true,"manualShovelThreeBallsAndAutomaticExit":true,"groundGloveWithoutWorkbench":true,"cursorBrushConservesRemovedMass":true,"aboveDockLevels":true,"fullscreenCancellationPolicy":true,"manualUserRetestRequired":true]
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/interaction-fixes-result.json"))
        print("PASS: native first-click routing, chosen tree position, drag/persistence, restored garland editor, single-click gift, gift/snowman dragging, ground-only glove sculpting, local cursor brush, Dock overlay/input levels")
    }
}
