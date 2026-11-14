#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class EngineTests: XCTestCase {
    func testParticleMotionAndPoolBounds() {
        let engine=ParticleEngine(bounds:Rect(0,0,1000,800),surfaces:SurfaceManager())
        engine.setCount(10000); XCTAssertEqual(engine.particles.count,3600)
        let old=engine.particles[0]; engine.step(dt:0.02,config:Configuration())
        XCTAssertGreaterThan(engine.particles[0].position.y,old.position.y)
        for _ in 0..<3000 { engine.step(dt:0.02,config:Configuration()) }
        XCTAssertEqual(engine.particles.count,3600); XCTAssertTrue(engine.particles.allSatisfy { $0.size <= 3 && $0.position.x.isFinite })
        engine.setCount(0); XCTAssertTrue(engine.particles.isEmpty)
    }
    func testWindInterpolationAndFrameRateIndependence() {
        var a=Wind(), b=Wind(); a.update(angle:90,strength:1,dt:0.5)
        for _ in 0..<50 { b.update(angle:90,strength:1,dt:0.01) }
        XCTAssertEqual(a.velocity.x,b.velocity.x,accuracy:0.00001)
        XCTAssertGreaterThan(a.velocity.x,0); XCTAssertLessThan(a.velocity.x,65)
    }
    func testAccumulationResizeAndBoundedLoss() {
        var s=SnowSurface(id:"test",screenID:"1",frame:Rect(0,100,400,100))
        for i in 0..<100 { s.deposit(at:Double(i)/99,volume:4) }
        let beforeExtract=s.volume; let extracted=s.extract(volume:20,at:0.5); XCTAssertEqual(beforeExtract-s.volume,extracted,accuracy:0.0001)
        let mass=s.volume; XCTAssertGreaterThan(mass,0); XCTAssertTrue(s.heights.allSatisfy { $0<=5 })
        let lost=s.resize(to:Rect(0,100,200,100),dt:0.1)
        XCTAssertEqual(s.volume+lost,mass,accuracy:0.001)
        let before=s.volume, removed=s.remove(fraction:0.25)
        XCTAssertEqual(s.volume,before*0.75,accuracy:0.001); XCTAssertEqual(removed,before*0.25,accuracy:0.001)
        let v=s.volume; s.resize(to:Rect(0,100,800,100),dt:0.1); XCTAssertEqual(s.volume,v,accuracy:0.001)
    }
    func testNearestCollisionAndOcclusion() {
        let m=SurfaceManager()
        m.surfaces["a"]=SnowSurface(id:"a",screenID:"1",frame:Rect(0,100,200,50))
        m.surfaces["b"]=SnowSurface(id:"b",screenID:"1",frame:Rect(0,200,200,50))
        XCTAssertEqual(m.collision(from:Vec(20,0),to:Vec(20,300),occluders:[])?.0,"a")
        XCTAssertEqual(m.collision(from:Vec(20,0),to:Vec(20,300),occluders:[Rect(0,50,200,100)])?.0,"b")
    }
    func testWindowLifecycleFrostRestore() {
        var w=WindowState(now:0); w.send(.show,now:0); w.tick(dt:1,now:60)
        XCTAssertEqual(w.frost,1); w.send(.activate,now:60); w.tick(dt:0.25,now:60.25); XCTAssertEqual(w.frost,0.5)
        w.tick(dt:0.25,now:60.5); XCTAssertEqual(w.frost,0)
        w.send(.minimize,now:61); w.send(.minimized,now:61.1); XCTAssertFalse(w.canAccumulate)
        w.send(.restore,now:62); XCTAssertEqual(w.restoreProgress,0); w.tick(dt:0.4,now:62.4); XCTAssertEqual(w.restoreProgress,1)
        w.send(.close,now:63); w.send(.closed,now:63.1); w.send(.show,now:64); XCTAssertEqual(w.phase,.closed)
    }
    func testDirectorCoalescingCancellationAndSlowMotion() {
        let d=AnimationDirector(); var completed: Bool?
        let id=d.start(.burst,duration:4,particles:30,region:Rect(0,0,500,400),completion:{ completed=$0 })!
        XCTAssertEqual(d.start(.burst,duration:4,particles:30,region:Rect(0,0,500,400)),id); XCTAssertEqual(d.active.count,1)
        d.tick(0.4); XCTAssertEqual(d.snowTimeRegions[0].multiplier,0.35,accuracy:0.001)
        d.tick(2.4); XCTAssertGreaterThan(d.snowTimeRegions[0].multiplier,0.35)
        d.cancel(id); XCTAssertEqual(completed,false); XCTAssertTrue(d.snowTimeRegions.isEmpty)
        d.focus=true; XCTAssertNil(d.start(.santa,duration:7))
        d.focus=false; d.reducedMotion=true; XCTAssertNil(d.start(.fireworks,duration:1))
    }
    func testPerEffectClock() {
        let d=AnimationDirector(); let id=d.start(.melt,duration:0.5)!
        d.setTimeMultiplier(id,to:0); d.tick(5); XCTAssertEqual(d.active.count,1)
        d.setTimeMultiplier(id,to:2); d.tick(0.3); XCTAssertTrue(d.active.isEmpty)
    }
    func testDirectorPriorityAndCompletion() {
        let d=AnimationDirector(); d.maxConcurrent=1
        var done: Bool?
        _=d.start(.santa,duration:7,priority:0,completion:{ done=$0 })
        XCTAssertNil(d.start(.plow,duration:3,priority:0))
        let high=d.start(.melt,duration:0.5,priority:2)
        XCTAssertNotNil(high); XCTAssertEqual(done,false); d.tick(1); XCTAssertTrue(d.active.isEmpty)
    }
    func testConfigurationRoundTripCorruptionAndValidation() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:dir) }
        let url=dir.appendingPathComponent("config.json"); var c=Configuration(); c.accumulationHeight=500; c.maxParticles=9999; c.mascot="invalid"; c.validate()
        XCTAssertEqual(c.accumulationHeight,12); XCTAssertEqual(c.maxParticles,3600); XCTAssertEqual(c.mascot,"none")
        try c.save(to:url); XCTAssertEqual(Configuration.load(from:url),c)
        try Data("broken".utf8).write(to:url); XCTAssertEqual(Configuration.load(from:url),Configuration())
    }
}
extension EngineTests {
    func testBurstDoesNotCreateAccumulatedMass() {
        let surfaces=SurfaceManager(), engine=ParticleEngine(bounds:Rect(0,0,500,500),surfaces:SurfaceManager())
        var s=SnowSurface(id:"source",screenID:"1",frame:Rect(0,100,300,50))
        for i in 0..<30 { s.deposit(at:Double(i)/30,volume:2) }
        engine.burst(surface:s,count:30,collapse:true)
        XCTAssertEqual(engine.particles.reduce(0) { $0+$1.snowVolume },s.volume*0.25,accuracy:0.0001)
        surfaces.surfaces["source"]=s
        _=surfaces.surfaces["source"]?.remove(fraction:0.25)
        XCTAssertEqual((surfaces.surfaces["source"]?.volume ?? 0)+engine.particles.reduce(0) { $0+$1.snowVolume },s.volume,accuracy:0.0001)
    }
    func testSnowballVolumeAndAssembly() {
        var system=SnowballSystem()
        var ball=Snowball(position:Vec(50,50)); let before=ball.radius*ball.radius*Double.pi
        ball.gather(volume:100)
        XCTAssertEqual(ball.radius*ball.radius*Double.pi,before+100,accuracy:0.0001)
        ball.gather(volume:1e9); XCTAssertEqual(ball.radius,26)
        system.balls=[ball,Snowball(position:Vec(60,50),radius:10),Snowball(position:Vec(45,55),radius:5)]
        XCTAssertTrue(system.assemble(near:Vec(50,50))); XCTAssertTrue(system.balls.isEmpty); XCTAssertNotNil(system.snowman)
        XCTAssertFalse(system.assemble(near:Vec(50,50)))
    }
    func testDisplayRecyclingAndVerticalDock() {
        let surfaces=SurfaceManager()
        surfaces.surfaces["dock"]=SnowSurface(id:"dock",screenID:"left",frame:Rect(-1000,0,60,800),axis:.verticalLeft)
        XCTAssertEqual(surfaces.collision(from:Vec(-900,40),to:Vec(-980,40),occluders:[])?.0,"dock")
        let engine=ParticleEngine(bounds:Rect(-1440,-200,1440,900),surfaces:surfaces)
        engine.setCount(40); var config=Configuration(); config.windAngle=90; config.windStrength=1
        for _ in 0..<3000 { engine.step(dt:0.04,config:config) }
        XCTAssertTrue(engine.particles.allSatisfy { $0.position.x >= -1445 && $0.position.x <= 5 })
    }
}
