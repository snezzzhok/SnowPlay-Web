#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class StoryPerformanceTests:XCTestCase {
 func testPlantedFootCancelsBodyTravel(){for d in stride(from:1.0,through:8.0,by:0.25){let a=StoryGait.foot(distance:d,leg:0),b=StoryGait.foot(distance:d+0.1,leg:0);XCTAssertTrue(a.stance && b.stance);XCTAssertEqual(a.x+d,b.x+d+0.1,accuracy:0.0001);XCTAssertEqual(a.lift,0)}}
 func testBackwardCarryAlsoKeepsFootPlanted(){let a=StoryGait.foot(distance:3,leg:0),b=StoryGait.foot(distance:2.9,leg:0);XCTAssertTrue(a.stance && b.stance);XCTAssertEqual(-a.x,-b.x+0.1,accuracy:0.0001)}
 func testSwingLiftsAndAlternates(){let a=StoryGait.foot(distance:14,leg:0),b=StoryGait.foot(distance:14,leg:1);XCTAssertTrue(a.lift>0);XCTAssertTrue(b.stance);XCTAssertEqual(b.lift,0)}
 func testWholeStrandHitTesting(){XCTAssertEqual(StoryGait.pointSegmentDistance(Vec(40,8),Vec(0,0),Vec(100,0)),8,accuracy:0.001);XCTAssertEqual(StoryGait.pointSegmentDistance(Vec(-3,4),Vec(0,0),Vec(100,0)),5,accuracy:0.001)}
 func testNewStoriesAndMassStoryBudget(){XCTAssertEqual(ChristmasStoryID.allCases.count,11);XCTAssertTrue(ChristmasStoryID.starHat.needsTree);XCTAssertTrue(ChristmasStoryID.giftConveyor.needsTree);XCTAssertFalse(ChristmasStoryID.tinyGift.needsTree);XCTAssertFalse(ChristmasStoryID.garlandRemoval.automaticAllowed);XCTAssertFalse(ChristmasStoryID.snowballExchange.automaticAllowed);XCTAssertTrue(ChristmasStoryID.snowballExchange.maximumDuration>90)}
}
