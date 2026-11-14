#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class AssetIntegrationTests: XCTestCase {
    func testLegacySettingsKeepValuesButExcludedEffectsStayDisabled() throws {
        var c=Configuration(); c.intensity=0.77; c.windowSnow=true; c.mascot="mochi"
        var object=try JSONSerialization.jsonObject(with:JSONEncoder().encode(c)) as! [String:Any]
        for key in ["dockHats","snowSpeed","windowEffectDuration"] { object.removeValue(forKey:key) }
        let migrated=try Configuration.decodeCompatible(JSONSerialization.data(withJSONObject:object))
        XCTAssertEqual(migrated.intensity,0.77); XCTAssertTrue(migrated.windowSnow); XCTAssertEqual(migrated.mascot,"none")
        XCTAssertEqual(migrated.snowSpeed,1); XCTAssertTrue(migrated.dockHats.isEmpty)
    }
    func testSweepClearsOnlyBehindBladeAndResumesDepositionAfterPass() {
        var surface=SnowSurface(id:"dock",screenID:"1",frame:Rect(100,700,600,80))
        for i in 0...100 { surface.deposit(at:Double(i)/100,volume:40) }
        let before=surface.volume
        surface.sweepFraction=0.4; surface.clearThrough(0.4)
        XCTAssertLessThan(surface.volume,before); XCTAssertGreaterThan(surface.volume,0)
        let split=Int(Double(surface.heights.count-1)*0.4)
        XCTAssertTrue(surface.heights.prefix(split+1).allSatisfy { $0 == 0 })
        surface.deposit(at:0.1,volume:40)
        XCTAssertTrue(surface.heights.prefix(split+1).allSatisfy { $0 == 0 })
        surface.clearThrough(1); surface.sweepFraction=nil; XCTAssertEqual(surface.volume,0)
        surface.deposit(at:0.1,volume:40); XCTAssertGreaterThan(surface.volume,0)
    }
    func testBladeProgressMatchesHorizontalAndVerticalDockGeometry() {
        let display=Rect(0,0,1000,800)
        XCTAssertEqual(PlowSweep.fraction(progress:0,display:display,dock:Rect(200,700,600,80),axis:.horizontal),0)
        XCTAssertEqual(PlowSweep.fraction(progress:1,display:display,dock:Rect(200,700,600,80),axis:.horizontal),1)
        let f=PlowSweep.fraction(progress:0.5,display:display,dock:Rect(200,700,600,80),axis:.horizontal)
        XCTAssertEqual(f,330.0/600,accuracy:0.0001)
        for axis in [SurfaceAxis.verticalLeft,.verticalRight] {
            let dock=Rect(axis == .verticalLeft ? 0 : 920,100,80,600)
            XCTAssertEqual(PlowSweep.fraction(progress:0,display:display,dock:dock,axis:axis),0)
            XCTAssertEqual(PlowSweep.fraction(progress:1,display:display,dock:dock,axis:axis),1)
            XCTAssertEqual(PlowSweep.fraction(progress:0.5,display:display,dock:dock,axis:axis),0.55,accuracy:0.0001)
        }
        var vertical=SnowSurface(id:"right",screenID:"1",frame:Rect(920,100,80,600),axis:.verticalRight)
        for i in 0...100 { vertical.deposit(at:Double(i)/100,volume:40) }
        vertical.sweepReversed=true; vertical.sweepFraction=0.4; vertical.clearThrough(0.4)
        XCTAssertTrue(vertical.heights.suffix(10).allSatisfy { $0 == 0 }); XCTAssertGreaterThan(vertical.heights[3],0)
        vertical.deposit(at:0.9,volume:40); XCTAssertTrue(vertical.heights.suffix(10).allSatisfy { $0 == 0 })
    }
    func testRegistryRejectsTraversalAndSnowmanRetainsAssemblyOrigins() {
        for path in ["../bad.svg","/tmp/bad.svg","Snow/../../bad.svg","Snow//bad.svg","Snow\\bad.svg"] { XCTAssertFalse(AssetManifest.safeRelativePath(path)) }
        XCTAssertTrue(AssetManifest.safeRelativePath("Snowman/snowman_body.svg"))
        var system=SnowballSystem(); system.balls=[Snowball(position:Vec(100,100),radius:12),Snowball(position:Vec(110,100),radius:9),Snowball(position:Vec(120,100),radius:6)]
        let originals=system.balls.map(\.position)
        XCTAssertTrue(system.assemble(near:Vec(110,100))); XCTAssertEqual(system.assemblyBalls.map(\.position),originals); XCTAssertTrue(system.balls.isEmpty)
    }
}
