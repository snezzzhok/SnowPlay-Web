#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore

final class WindowEffectTests: XCTestCase {
    func testWindowEffectsRecoverInConfiguredRealTime() {
        for kind in [EffectKind.burst,.collapse] {
            for duration in [3.0,4.0,5.0] {
                let director=AnimationDirector()
                var completed=false
                _=director.start(kind,duration:duration,particles:12,region:Rect(100,100,400,300),completion:{ completed=$0 })
                XCTAssertEqual(director.snowTimeRegions[0].scale(at:Vec(200,200)),1)
                director.tick(0.3)
                XCTAssertEqual(director.snowTimeRegions[0].scale(at:Vec(200,200)),0.35,accuracy:0.0001)
                director.tick(duration*0.7-0.3)
                let recovering=director.snowTimeRegions[0].scale(at:Vec(200,200))
                XCTAssertGreaterThan(recovering,0.35); XCTAssertLessThan(recovering,1)
                director.tick(duration*0.25)
                XCTAssertEqual(director.snowTimeRegions[0].scale(at:Vec(200,200)),1,accuracy:0.0001)
                director.tick(duration*0.05+0.001)
                XCTAssertTrue(director.active.isEmpty); XCTAssertTrue(director.snowTimeRegions.isEmpty); XCTAssertTrue(completed)
            }
        }
    }
    func testOnlyFormerWindowAreaSlowsWithSoftBoundary() {
        let region=SnowTimeRegion(bounds:Rect(-1000,-100,400,300),multiplier:0.35,feather:48)
        XCTAssertEqual(region.scale(at:Vec(-900,0)),0.35,accuracy:0.0001)
        XCTAssertEqual(region.scale(at:Vec(-600,0)),0.35,accuracy:0.0001)
        XCTAssertEqual(region.scale(at:Vec(-552,0)),1)
        XCTAssertEqual(region.scale(at:Vec(500,300)),1) // Another display, same real-time frame.
        let edge=region.scale(at:Vec(-576,0)); XCTAssertGreaterThan(edge,0.35); XCTAssertLessThan(edge,1)
    }
    func testParticleMotionUsesLocalClockWithoutRespawningSnowfall() {
        let bounds=Rect(0,0,1000,2000)
        let regular=ParticleEngine(bounds:bounds,surfaces:SurfaceManager(),seed:45)
        let slowed=ParticleEngine(bounds:bounds,surfaces:SurfaceManager(),seed:45)
        let elsewhere=ParticleEngine(bounds:bounds,surfaces:SurfaceManager(),seed:45)
        for engine in [regular,slowed,elsewhere] { engine.setCount(40) }
        let before=regular.particles[0]
        regular.step(dt:0.02,config:Configuration())
        slowed.step(dt:0.02,config:Configuration(),timeRegions:[SnowTimeRegion(bounds:bounds,multiplier:0.35)])
        elsewhere.step(dt:0.02,config:Configuration(),timeRegions:[SnowTimeRegion(bounds:Rect(-2000,0,500,500),multiplier:0.35)])
        XCTAssertEqual(slowed.particles[0].position.y-before.position.y,(regular.particles[0].position.y-before.position.y)*0.35,accuracy:0.0001)
        XCTAssertEqual(elsewhere.particles[0].position,regular.particles[0].position)
        let phase=slowed.particles[0].phase, oldPosition=slowed.particles[0].position
        slowed.step(dt:0.02,config:Configuration()) // Empty fields: resume from the current position.
        XCTAssertEqual(slowed.particles[0].phase,phase)
        XCTAssertGreaterThan(slowed.particles[0].position.y,oldPosition.y)
        XCTAssertEqual(slowed.particles.count,40)
    }
    func testRapidNearbyEventsCoalesceButDistantWindowsRemainLocal() {
        let director=AnimationDirector(); var completions=0
        let first=director.start(.collapse,duration:4,particles:12,region:Rect(0,0,300,300),completion:{ _ in completions+=1 })!
        director.tick(0.1)
        let duplicate=director.start(.burst,duration:5,particles:30,region:Rect(30,30,300,300),completion:{ _ in completions+=1 })
        XCTAssertEqual(first,duplicate); XCTAssertEqual(director.active.count,1)
        let distant=director.start(.burst,duration:4,particles:30,region:Rect(2000,0,400,300))!
        XCTAssertFalse(first == distant); XCTAssertEqual(director.snowTimeRegions.count,2)
        XCTAssertEqual(director.snowTimeRegions.map { $0.scale(at:Vec(1000,100)) }.min(),1)
        director.cancel(first); XCTAssertEqual(completions,2)
    }
    func testBurstLifetimeMassAndCancellationFollowEffect() {
        let manager=SurfaceManager(), engine=ParticleEngine(bounds:Rect(0,-100,800,1500),surfaces:SurfaceManager())
        var source=SnowSurface(id:"window",screenID:"1",frame:Rect(100,100,400,300))
        for i in 0..<40 { source.deposit(at:Double(i)/39,volume:8) }
        let mass=source.volume, director=AnimationDirector()
        let id=director.start(.collapse,duration:4,particles:12,region:source.frame)!
        engine.burst(surface:source,count:12,collapse:true,duration:4,effectID:id)
        _=source.remove(fraction:0.25)
        XCTAssertEqual(source.volume,mass*0.75,accuracy:0.0001)
        XCTAssertEqual(source.volume+engine.particles.reduce(0) { $0+$1.snowVolume },mass,accuracy:0.0001)
        for _ in 0..<30 { engine.step(dt:0.05,config:Configuration(),timeRegions:director.snowTimeRegions); director.tick(0.05) }
        XCTAssertFalse(engine.particles.isEmpty)
        XCTAssertTrue(engine.particles.allSatisfy { $0.remaining>2 }) // No old 1.1-second timeout.
        engine.setCount(20)
        director.cancelAll(); engine.retainEffects(Set(director.active.map(\.id)))
        XCTAssertEqual(engine.particles.count,20); XCTAssertTrue(engine.particles.allSatisfy { $0.remaining<0 })
    }
    func testRestoringCapFinishesDespiteActivationAndGeometryEvents() {
        var window=WindowState(); window.send(.show,now:0); window.send(.minimized,now:1)
        window.send(.restore,now:2); window.send(.activate,now:2); window.send(.resize,now:2.1)
        window.tick(dt:0.2,now:2.2); XCTAssertEqual(window.restoreProgress,0.5,accuracy:0.0001)
        window.tick(dt:0.2,now:2.4); XCTAssertEqual(window.restoreProgress,1)
    }
    func testLegacySettingsKeepUserValuesAndNewDurationIsClamped() throws {
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:directory) }
        let url=directory.appendingPathComponent("settings.json")
        var configuration=Configuration(); configuration.intensity=0.72; configuration.windAngle = -25
        try configuration.save(to:url)
        var object=try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as! [String:Any]
        object.removeValue(forKey:"windowEffectDuration")
        try JSONSerialization.data(withJSONObject:object).write(to:url)
        let restored=Configuration.load(from:url)
        XCTAssertEqual(restored.intensity,0.72); XCTAssertEqual(restored.windAngle,-25); XCTAssertEqual(restored.windowEffectDuration,4)
        configuration.windowEffectDuration=99; configuration.validate(); XCTAssertEqual(configuration.windowEffectDuration,5)
        configuration.windowEffectDuration=0; configuration.validate(); XCTAssertEqual(configuration.windowEffectDuration,3)
    }
    func testFrontWindowCollectsSnowDespiteBackgroundWindowCoveringItsEdge() {
        let manager=SurfaceManager()
        let front=Rect(100,100,300,300), back=Rect(0,40,700,600)
        manager.surfaces["front"]=SnowSurface(id:"front",screenID:"1",frame:front)
        manager.setWindowOrder(["front","back"])
        XCTAssertEqual(manager.collision(from:Vec(200,90),to:Vec(200,110),occluders:[front,back])?.0,"front")
        manager.setWindowOrder(["back","front"])
        XCTAssertNil(manager.collision(from:Vec(200,90),to:Vec(200,110),occluders:[back,front]))
    }
}
