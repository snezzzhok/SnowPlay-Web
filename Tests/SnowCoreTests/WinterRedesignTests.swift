#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class WinterRedesignTests: XCTestCase {
    func testOpenedGiftHasFiniteBoxAndCelebrationLifetimes() {
        XCTAssertEqual(GiftLifecycle.boxOpacity(elapsed:0),1)
        XCTAssertGreaterThan(GiftLifecycle.boxOpacity(elapsed:2.2),0)
        XCTAssertEqual(GiftLifecycle.boxOpacity(elapsed:3.1),0)
        XCTAssertEqual(GiftLifecycle.celebrationOpacity(elapsed:12.1),0)
    }
    func testDeliveryChoosesDifferentFreePlacesWhenAvailable() {
        let bounds=Rect(0,0,1200,800),blocked=[Rect(0,0,400,400)]
        let candidates=PlacementPlanner.candidates(in:bounds,occupied:blocked,size:110)
        let first=PlacementPlanner.choose(from:candidates,bounds:bounds,recent:[])!
        let second=PlacementPlanner.choose(from:candidates,bounds:bounds,recent:[first])!
        let third=PlacementPlanner.choose(from:candidates,bounds:bounds,recent:[first,second])!
        XCTAssertFalse(first == second);XCTAssertFalse(third == first);XCTAssertFalse(third == second)
        let two=[first,second]
        XCTAssertEqual(PlacementPlanner.choose(from:two,bounds:bounds,recent:[first,second]),first)
        XCTAssertEqual(PlacementPlanner.choose(from:two,bounds:bounds,recent:[second,first]),second)
        XCTAssertTrue([first,second,third].allSatisfy { !blocked[0].intersects(Rect($0.x-55,$0.y-55,110,110)) })
    }
    func testFullSnowBankKeepsRoundedMoundsAndLetsOverflowFall() {
        var s=SnowSurface(id:"dock",screenID:"1",frame:Rect(0,100,500,80),maxHeight:8)
        s.setMounds([0.1,0.3,0.5,0.7,0.9])
        for _ in 0..<20 {s.add(volume:5000)}
        XCTAssertEqual(s.heights.first!,0);XCTAssertEqual(s.heights.last!,0)
        XCTAssertGreaterThan(s.heights.max()!-s.heights[s.heights.count/5],2)
        XCTAssertFalse(s.canReceive(at:0.5))
        let m=SurfaceManager();m.surfaces["dock"]=s
        XCTAssertNil(m.collision(from:Vec(250,90),to:Vec(250,110),occluders:[]))
    }
    func testWorkbenchAssemblyNeedsGrownBallsButNoPreciseStacking() {
        var s=SnowballSystem();s.balls=[Snowball(position:Vec(20,300),radius:4),Snowball(position:Vec(160,300),radius:4),Snowball(position:Vec(290,300),radius:4)]
        XCTAssertFalse(s.assemblePrepared(at:Vec(150,260)))
        s.balls[0].gather(volume:350);s.balls[1].gather(volume:200)
        XCTAssertTrue(s.assemblePrepared(at:Vec(150,260)));XCTAssertTrue(s.balls.isEmpty);XCTAssertEqual(s.assemblyBalls.count,3)
    }
    func testWindowSnowAndGarlandRemainUserControlled() {
        var c=Configuration();c.garland=true;c.validate()
        XCTAssertFalse(c.windowSnow);XCTAssertFalse(c.frost);XCTAssertFalse(c.yetiEnabled);XCTAssertTrue(c.garland)
        c.windowSnow=true;c.validate();XCTAssertTrue(c.windowSnow)
    }
}
