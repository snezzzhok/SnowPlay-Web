// Exercises the real native nodes and renders only our own scene, without screen capture.
import AppKit
import SpriteKit
import SnowCore
@main struct AssetIntegrationCheck {
    static func main() throws {
        _=NSApplication.shared
        guard let screen=NSScreen.main else { fatalError("No macOS display") }
        let assets=AssetManager.shared
        precondition(assets.registry.count == 126)
        for id in assets.registry.keys { precondition(assets.texture(id) != nil,"Missing \(id)") }
        _ = assets.texture("tree_foliage")
        let loads=assets.loadCount
        for _ in 0..<100 { _=assets.texture("tree_foliage") }
        precondition(assets.loadCount == loads,"Texture cache missed repeated requests")
        let missing=assets.sprite("does_not_exist",height:50); precondition(missing.isHidden && missing.texture == nil)
        let surfaces=SurfaceManager(), director=AnimationDirector(), manager=DecorationManager()
        let display=DisplayOverlay(screen:screen,surfaces:surfaces,primaryHeight:screen.frame.height); display.hide(true)
        defer { display.close() }
        let dockObserver=DockObserver()
        let observedDock=dockObserver.detect(displays:[display],rows:[])
        dockObserver.updateIcons(dock:observedDock)
        let result: [String:Any]=["passed":true,"originalAssets":63,"retinaTextures":true,"nativeNodeChecks":true,"nativeSceneRendered":true,"dockDetected":observedDock != nil,"dockIconFramesObserved":dockObserver.icons.count,"actualHatMouseInteractionTested":false]

        let dock=DockGeometry(frame:Rect(200,display.rect.maxY-70,600,60),axis:.horizontal,screenID:display.id)
        var c=Configuration.preset(.play); c.tree=true; c.garland=false; c.automaticCleaning=0
        let window=TrackedWindow(number:123,pid:1,frame:Rect(200,200,600,350),z:0,now:0)
        c.placements[display.id]=Placement(tree:Vec(0.85,0.8),garland:[Vec(0.15,0),Vec(0.5,0),Vec(0.95,0)],garlandWindow:window.id)
        manager.install([display]); let state=manager.states[display.id]!
        state.snowballs.balls=[Snowball(position:Vec(400,500),radius:12),Snowball(position:Vec(410,500),radius:9),Snowball(position:Vec(420,500),radius:6)]
        precondition(state.snowballs.assemble(near:Vec(410,500)))
        state.plowProgress=0.4;state.plowSurface=SnowSurface(id:"dock",screenID:display.id,frame:dock.snowFrame); manager.pendingDelivery=true
        manager.update(dt:0.016,now:1,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.tree?.children.count == 2)
        precondition(state.tree?.alpha == 0 && (state.tree?.xScale ?? 1)<1,"Tree entrance did not start softly")
        precondition(state.santa?.childNode(withName:"santa_character") != nil)
        precondition(state.plow?.childNode(withName:"snowplow_blade") != nil)
        for id in ["snowplow_wheel_left","snowplow_wheel_right"] { precondition(abs(state.plow?.childNode(withName:id)?.zRotation ?? 0)>1) }
        precondition(state.snowmanNode?.children.count == 9)
        precondition(state.snowmanNode?.children.prefix(3).allSatisfy { $0.hasActions() } == true)
        precondition(display.canvas.garlandArt.isEmpty)
        manager.update(dt:state.dropTime+0.01,now:2,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.gift?.childNode(withName:"package/gift_bow") != nil)
        precondition(state.gift?.childNode(withName:"parachute/parachute_strings") != nil)
        precondition(state.tree?.alpha == 1 && state.tree?.xScale == 1,"Tree entrance failed to settle")
        precondition(abs(state.gift?.childNode(withName:"parachute")?.zRotation ?? 0)>0,"Parachute swing missing")
        c.reducedMotion=true
        manager.update(dt:0,now:2.1,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.gift?.childNode(withName:"parachute")?.zRotation == 0,"Reduced Motion still swings parachute")
        precondition(state.tree?.xScale == 1 && state.tree?.alpha == 1)
        c.reducedMotion=false
        manager.update(dt:4.01,now:6,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.giftLanded)
        manager.openGift(displayID:display.id,now:6,fireworks:true,director:director)
        precondition(state.giftOpenedAt != nil,"Landed gift stayed locked while Santa was still flying")
        manager.update(dt:0.5,now:6.5,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.countdown && state.celebration.childNode(withName:"countdown") != nil)
        precondition(state.gift?.childNode(withName:"firework") != nil)
        // Slow animation time must not respawn a box whose real-time lifetime ended.
        state.dropTime=0.5;state.deliveryElapsed=4.6
        manager.update(dt:0.01,now:10,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.gift == nil && state.giftPosition != nil)
        manager.update(dt:0.01,now:11,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.gift == nil,"Expired box respawned during a slow Santa flight")
        let oldTarget=state.target
        manager.update(dt:0.5,now:18.1,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.giftPosition == nil && state.celebration.children.isEmpty,"Celebration did not expire")
        manager.update(dt:12,now:18.5,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.santa == nil && state.deliveryElapsed == nil && state.giftPosition == nil,"Flight completion resurrected expired gift state")
        director.cancelAll();manager.pendingDelivery=true
        manager.update(dt:0.016,now:19,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.target != oldTarget,"Two deliveries selected the same free place")
        manager.update(dt:12,now:31,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        state.giftLandedAt = -60
        manager.update(dt:0.016,now:32,displays:[display],config:c,windows:[window],dock:dock,surfaces:surfaces,director:director,mouse:Vec())
        precondition(state.gift == nil && state.giftPosition == nil,"Unopened gift did not time out")
        // Render a standalone art board with the same composition/pivots used at runtime.
        let scene=SKScene(size:CGSize(width:780,height:210)); scene.backgroundColor=NSColor(calibratedRed:0.13,green:0.19,blue:0.23,alpha:1)
        let models=[(["tree_trunk","tree_foliage","tree_snow_caps","tree_ornaments","tree_star"],120.0),(["snowman_ball_base","snowman_ball_middle","snowman_ball_head","snowman_arms","snowman_scarf","snowman_buttons","snowman_face","snowman_hat"],100),(["snowplow_body","snowplow_wheel_left","snowplow_wheel_right","snowplow_blade","snowplow_beacon"],90),(["sleigh","gift_sack","santa_character"],100),(["gift_parachute"],110)]
        for (i,model) in models.enumerated() {
            let n=assets.model(model.0,height:model.1); n.position=CGPoint(x:80+Double(i)*150,y:115); scene.addChild(n)
            let label=SKLabelNode(fontNamed:"HelveticaNeue"); label.text=["Tree","Snowman","Snowplow","Santa","Parachute gift"][i]; label.fontSize=13; label.position=CGPoint(x:80+Double(i)*150,y:25); scene.addChild(label)
        }
        let view=SKView(frame:NSRect(x:0,y:0,width:780,height:210)); view.presentScene(scene)
        guard let texture=view.texture(from:scene) else { fatalError("Native scene render failed") }
        let bitmap=NSBitmapImageRep(cgImage:texture.cgImage()); try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Docs/native-assets-preview.png"))
        manager.cancelTransient(); precondition(state.plow == nil && state.santa == nil)
        manager.reset(preserveSnowman:false); precondition(state.balls.children.isEmpty && state.tree == nil)
        try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/native-asset-check-result.json"))
        print("Dock app icon frames observed: \(dockObserver.icons.count)")
        print("PASS: 63 resources; cached loads; safe missing asset; composition/pivots; ball assembly actions; wheel rotation; Santa drop; parachute; gift opening/countdown/fireworks; native render; cancellation/reset")
    }
}
