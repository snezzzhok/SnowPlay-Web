#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class DesktopInteractionTests: XCTestCase {
    func testDensitySliderHasAVisibleFullRangeWithoutBatteryReduction() {
        let area=1440.0*900
        XCTAssertEqual(SnowfallDensity.count(intensity:0,area:area,mode:.play,limit:1200),0)
        XCTAssertEqual(SnowfallDensity.count(intensity:1,area:area,mode:.play,limit:3600),2400)
        XCTAssertGreaterThan(SnowfallDensity.count(intensity:0.35,area:area,mode:.balanced,limit:3600),600)
        XCTAssertLessThan(SnowfallDensity.count(intensity:1,area:area,mode:.focus,limit:1200),60)
        XCTAssertTrue(SnowfallDensity.count(intensity:1,area:area*3,mode:.play,limit:1200)<=1200)
    }
    func testDensityIsMonotonicAndOlderStockSettingsAreUpgraded() throws {
        let area=1440.0*900
        let counts=(0...100).map { SnowfallDensity.count(intensity:Double($0)/100,area:area,mode:.play,limit:3600) }
        XCTAssertTrue(zip(counts,counts.dropFirst()).allSatisfy { $0 <= $1 })
        XCTAssertGreaterThan(counts[65],1300)
        for limit in [100,1200,700] {
            var config=Configuration.preset(.play);config.maxParticles=limit
            let decoded=try Configuration.decodeCompatible(JSONEncoder().encode(config))
            XCTAssertEqual(decoded.maxParticles,limit == 700 ? 700:3600)
        }
        var config=Configuration.preset(.focus);config.maxParticles=45
        let focus=try Configuration.decodeCompatible(JSONEncoder().encode(config))
        XCTAssertEqual(focus.maxParticles,45)
    }
    func testEntrancesAndLandingSettleAndReducedMotionStopsFlutter() {
        XCTAssertEqual(WinterMotion.appearance(elapsed:0).opacity,0)
        for time in [0.7,1,90] {
            XCTAssertEqual(WinterMotion.appearance(elapsed:time).scale,1)
            XCTAssertEqual(WinterMotion.appearance(elapsed:time).opacity,1)
            XCTAssertEqual(WinterMotion.landingLift(elapsed:time),0,accuracy:0.00001)
        }
        let normal=ParticleEngine(bounds:Rect(0,0,500,500),surfaces:SurfaceManager())
        let reduced=ParticleEngine(bounds:Rect(0,0,500,500),surfaces:SurfaceManager())
        normal.setCount(30);reduced.setCount(30)
        var c=Configuration();c.windStrength=0
        normal.step(dt:0.03,config:c);c.reducedMotion=true;reduced.step(dt:0.03,config:c)
        XCTAssertTrue(normal.particles.contains { abs($0.velocity.x)>0.01 })
        XCTAssertTrue(reduced.particles.allSatisfy { $0.velocity.x == 0 })
        XCTAssertTrue(normal.particles.allSatisfy { $0.size<=3 })
    }
    func testDockAccumulatesOverOrdinaryWindowsAndWhileAutoHidden() {
        let m=SurfaceManager(),r=Rect(100,500,600,80)
        m.surfaces["dock"]=SnowSurface(id:"dock",screenID:"1",frame:r)
        XCTAssertEqual(m.collision(from:Vec(200,490),to:Vec(200,510),occluders:[Rect(0,0,1000,800)])?.0,"dock")
        m.surfaces["dock"]?.renderVisible=false
        let e=ParticleEngine(bounds:Rect(0,0,900,700),surfaces:m,seed:9);e.setCount(1000)
        var config=Configuration();config.intensity=1
        for _ in 0..<160 { e.step(dt:0.05,config:config,occluders:[Rect(0,0,1000,800)]) }
        XCTAssertGreaterThan(m.surfaces["dock"]!.volume,100)
        XCTAssertTrue(e.particles.contains { $0.position.y>r.y && $0.position.y<700 })
    }
    func testCursorBrushRemovesOnlyNearbyRealMass() {
        var s=SnowSurface(id:"dock",screenID:"1",frame:Rect(0,500,600,80))
        for i in 0...100 { s.deposit(at:Double(i)/100,volume:40) }
        let before=s.volume,far=s.heights.first!
        let removed=s.brush(at:0.5,radius:30,strength:1)
        XCTAssertGreaterThan(removed,0);XCTAssertEqual(before-s.volume,removed,accuracy:0.0001)
        XCTAssertEqual(s.heights.first!,far);XCTAssertTrue(s.heights.allSatisfy { $0>=0 })
    }
}
