#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class InteractiveWorldTests:XCTestCase {
    func filled()->SnowSurface {var s=SnowSurface(id:"window-1",screenID:"1",frame:Rect(100,200,480,200),maxHeight:10);s.add(volume:1400);return s}
    func testResizeDropsOnlyMassWhichLostSupport() {
        var s=filled();let before=s.volume
        let fall=s.updateWindow(to:Rect(220,200,240,200),dt:0.1,now:1)
        XCTAssertGreaterThan(fall.mass,0);XCTAssertGreaterThan(s.volume,0)
        XCTAssertEqual(s.volume+fall.mass,before,accuracy:0.00001)
        XCTAssertTrue(fall.chunks.allSatisfy{$0.position.y<=200 && $0.mass>0})
    }
    func testSlowMovementCarriesButJoltShedsAndConservesMass() {
        var slow=filled();let mass=slow.volume
        XCTAssertEqual(slow.updateWindow(to:Rect(102,200,480,200),dt:0.1,now:1).mass,0)
        XCTAssertEqual(slow.volume,mass,accuracy:0.00001)
        let event=slow.updateWindow(to:Rect(160,200,480,200),dt:0.05,now:2)
        XCTAssertGreaterThan(event.mass,0);XCTAssertEqual(slow.volume+event.mass,mass,accuracy:0.00001)
    }
    func testSweepingAccumulatesWithoutDoubleCollection() {
        var surface=filled(),pile=SnowPile();let before=surface.volume
        pile.collect(surface.clearThrough(0.4));let first=pile.mass
        pile.collect(surface.clearThrough(0.4));XCTAssertEqual(pile.mass,first)
        pile.collect(surface.clearThrough(1));XCTAssertEqual(pile.mass,before,accuracy:0.00001)
        pile.export();XCTAssertEqual(pile.mass,0);XCTAssertEqual(pile.exported,before,accuracy:0.00001)
    }
    func testActualTopSurfaceCatchesFlakesBeforeWindowBaseline() {
        let manager=SurfaceManager();let surface=filled();manager.surfaces[surface.id]=surface
        let f=surface.heights.enumerated().max(by:{$0.element<$1.element})!.offset
        let x=surface.frame.x+Double(f)/Double(surface.heights.count-1)*surface.length,h=surface.height(at:Double(f)/Double(surface.heights.count-1))
        XCTAssertNotNil(manager.collision(from:Vec(x,200-h-1),to:Vec(x,200-h+1),occluders:[]))
    }
    func testEmissionIsBoundedAndAccountsForAllSourceMass() {
        let engine=ParticleEngine(bounds:Rect(0,0,800,600),surfaces:SurfaceManager());engine.setCount(3600)
        let source=(0..<200).map{SnowChunk(Vec(Double($0),100),Vec(0,-5),5)}
        XCTAssertEqual(engine.emit(SnowFallEvent(source),limit:8),1000)
        XCTAssertEqual(engine.particles.filter{$0.remaining>=0}.count,8)
        XCTAssertEqual(engine.particles.filter{$0.remaining>=0}.reduce(0){$0+$1.snowVolume},1000,accuracy:0.00001)
        XCTAssertEqual(engine.emit(SnowFallEvent(source),limit:0),0)
    }
    func testOverflowingChunksKeepTheirUndepositedMass() {
        let surfaces=SurfaceManager();var source=SnowSurface(id:"dock",screenID:"1",frame:Rect(0,200,500,30),maxHeight:0.2);source.add(volume:100);surfaces.surfaces[source.id]=source
        let engine=ParticleEngine(bounds:Rect(0,0,600,600),surfaces:surfaces);let initial=source.volume
        engine.emit(SnowFallEvent([SnowChunk(Vec(250,190),Vec(0,80),500)]))
        for _ in 0..<20 {engine.step(dt:0.03,config:Configuration())}
        XCTAssertEqual((surfaces.surfaces["dock"]!.volume-initial)+engine.particles.reduce(0){$0+$1.snowVolume}+engine.escapedMass+engine.dissipatedMass,500,accuracy:0.0001)
    }
    func testSaturatedWindowRemainsSolidAndChunksMoveTowardItsEdge() {
        let surfaces=SurfaceManager();var window=SnowSurface(id:"window-1-9",screenID:"1",frame:Rect(0,200,500,1),maxHeight:8)
        for _ in 0..<20 {window.add(volume:10000)}
        surfaces.surfaces[window.id]=window
        XCTAssertNotNil(surfaces.collision(from:Vec(250,185),to:Vec(250,205),occluders:[]))
        let engine=ParticleEngine(bounds:Rect(0,0,600,600),surfaces:surfaces)
        engine.emit(SnowFallEvent([SnowChunk(Vec(250,185),Vec(0,80),500)]))
        for _ in 0..<20 {engine.step(dt:0.03,config:Configuration())}
        XCTAssertEqual(engine.particles.count,1)
        XCTAssertLessThan(engine.particles[0].position.y,200)
        XCTAssertGreaterThan(abs(engine.particles[0].velocity.x),0)
        XCTAssertEqual((surfaces.surfaces[window.id]!.volume-window.volume)+engine.particles[0].snowVolume,500,accuracy:0.0001)
    }
    func testVerletWirePinsEndpointsAndSettlesUnderGravity() {
        var wire=GarlandPhysics();let anchors=[Vec(10,20),Vec(200,20)]
        for _ in 0..<240 {wire.step(anchors:anchors,sag:20,dt:1/60)}
        XCTAssertEqual(wire.points.first,anchors.first);XCTAssertEqual(wire.points.last,anchors.last)
        XCTAssertGreaterThan(wire.points[5].y,30);XCTAssertTrue(wire.points.allSatisfy{$0.x.isFinite && $0.y.isFinite && abs($0.y)<1000})
        let moved=[Vec(30,25),Vec(230,30)];wire.step(anchors:moved,sag:20,dt:1/60)
        XCTAssertEqual(wire.points.first,moved.first);XCTAssertEqual(wire.points.last,moved.last)
        wire.step(anchors:[],sag:20,dt:0.03);XCTAssertTrue(wire.points.isEmpty)
    }
    func testAttachmentsFollowWindowAndTreeAndDisappearWithoutOwner() {
        let bounds=Rect(-1000,0,1000,700)
        let p=Placement(garland:[Vec(0.1,0),Vec(0.9,0)],garlandWindow:"window",garlandTarget:"window")
        let a=GarlandAttachment.resolve(p,bounds:bounds,window:Rect(100,200,400,300),tree:nil,treeSize:84)
        let b=GarlandAttachment.resolve(p,bounds:bounds,window:Rect(150,230,400,300),tree:nil,treeSize:84)
        XCTAssertEqual(b[0]-a[0],Vec(50,30));XCTAssertTrue(GarlandAttachment.resolve(p,bounds:bounds,window:nil,tree:nil,treeSize:84).isEmpty)
    }
    func testCharactersDispatchContactsExactlyOnceEvenOnSlowFrames() {
        var actor=CharacterController(action:.chopTree,target:Vec(100,100),path:[Vec(0,120),Vec(120,120)])
        let events=actor.step(100);XCTAssertEqual(events.filter{if case .strike = $0{return true};return false}.count,3)
        XCTAssertTrue(events.contains(.finished));XCTAssertTrue(actor.step(1).isEmpty);XCTAssertEqual(actor.phase,.finished)
        var thrower=CharacterController(action:.throwSnowball,target:Vec(100,100),path:[Vec(0,100),Vec(40,100)])
        let all=thrower.step(100);XCTAssertEqual(all.filter{$0 == .release}.count,1);XCTAssertEqual(all.filter{$0 == .impact}.count,1)
    }
    func testProjectileHasContinuousPhysicalArcAndExactImpactPoint() {
        let arc=Projectile(from:Vec(0,0),to:Vec(90,20))
        XCTAssertEqual(arc.position(0),Vec());XCTAssertEqual(arc.position(arc.duration),Vec(90,20))
        XCTAssertLessThan(arc.position(arc.duration/2).y,10)
    }
    func testNavigationRoutesAroundObstaclesAndRejectsBlockedTargets() {
        let bounds=Rect(0,0,600,400),block=Rect(200,70,120,150)
        let path=CharacterNavigation.path(from:Vec(20,130),to:Vec(550,130),bounds:bounds,obstacles:[block])
        XCTAssertNotNil(path);XCTAssertGreaterThan(path!.count,2)
        XCTAssertNil(CharacterNavigation.path(from:Vec(20,130),to:block.center,bounds:bounds,obstacles:[block]))
    }
    func testAxeRigReachesTrunkWithoutSeparatingGrip() {
        let goal=Vec(11.625,-11.83),hand=Vec(3.5,-8),tip=Vec(4.6875,8.125)
        let pose=CharacterArmRig.pose(goal:goal,hand:hand,tip:tip)
        func rotate(_ p:Vec,_ a:Double)->Vec {Vec(p.x*cos(a)-p.y*sin(a),p.x*sin(a)+p.y*cos(a))}
        let reached=rotate(hand,pose.arm)+rotate(tip,pose.arm+pose.tool)
        XCTAssertEqual(reached.x,goal.x,accuracy:0.0001);XCTAssertEqual(reached.y,goal.y,accuracy:0.0001)
    }
    func testSavedSnowmanKeepsNormalizedPositionAndPhysicalRadii() throws {
        var c=Configuration();c.placements["1"]=Placement(snowman:Vec(0.3,0.7),snowmanRadii:[12,9,6])
        let loaded=try Configuration.decodeCompatible(JSONEncoder().encode(c))
        XCTAssertEqual(loaded.placements["1"]?.snowman,Vec(0.3,0.7));XCTAssertEqual(loaded.placements["1"]?.snowmanRadii,[12,9,6])
    }
    func testDecorationsSurviveConfigurationRoundTrip() throws {
        var c=Configuration();c.garland=true;c.placements["1"]=Placement(tree:Vec(0.5,0.7),garland:[Vec(0.2,0.2),Vec(0.8,0.2)],ornaments:TreeOrnament.defaults,garlandTarget:"desktop")
        let loaded=try Configuration.decodeCompatible(JSONEncoder().encode(c))
        XCTAssertEqual(c,loaded);XCTAssertTrue(loaded.garland);XCTAssertEqual(loaded.placements["1"]?.ornaments?.count,3)
    }
}
