#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class ChristmasStoryTests:XCTestCase {
    func testSchedulerCountsOnlyEligibleTimeAndWaitsTenMinutes(){
        var s=ChristmasStoryScheduler(seed:7)
        for _ in 0..<1200 {s.advance(1,eligible:false)};XCTAssertEqual(s.eligibleSeconds,0);XCTAssertFalse(s.due)
        for _ in 0..<599 {s.advance(1,eligible:true)};XCTAssertFalse(s.due);s.advance(1,eligible:true);XCTAssertTrue(s.due)
        s.didStart(.snowmanParty,frequency:.normal);XCTAssertGreaterThanOrEqual(s.nextAt-s.eligibleSeconds,1800);XCTAssertLessThanOrEqual(s.nextAt-s.eligibleSeconds,2700)
    }
    func testFrequencyRangesAndNoImmediateRepeat(){
        var s=ChristmasStoryScheduler(seed:17)
        for frequency in StoryFrequency.allCases {for _ in 0..<40 {
            let choice=s.choose([.presentTheft,.lightRepair,.santaDrop],enabled:ChristmasStoryID.allCases.map(\.rawValue))!
            XCTAssertNotEqual(choice,s.recent.last);s.didStart(choice,frequency:frequency)
            XCTAssertTrue(frequency.interval.contains(s.nextAt-s.eligibleSeconds))
        }}
        XCTAssertNil(s.choose([.treeShake],enabled:[]));XCTAssertEqual(s.choose([.treeShake],enabled:["treeShake"]),.treeShake)
    }
    func testAtomicReservationsNeverPartiallyAcquire(){
        var leases=StoryReservations();let a=UUID(),b=UUID()
        XCTAssertTrue(leases.acquire(["tree","stage"],owner:a));XCTAssertFalse(leases.acquire(["gift","tree"],owner:b));XCTAssertFalse(leases.isReserved("gift"));leases.release(a);XCTAssertTrue(leases.owners.isEmpty);XCTAssertTrue(leases.acquire(["tree"],owner:b))
    }
    func testTimelineWaitsForContactRatherThanOnlyDuration(){
        var t=StoryTimeline([StoryBeat("walk",0.5,arrivals:["elf"]),StoryBeat("pick-up",0.2,arrivals:["hand"])])
        for _ in 0..<100 {t.step(0.05,arrived:[])};XCTAssertEqual(t.index,0)
        XCTAssertTrue(t.step(0.05,arrived:["elf"]));XCTAssertEqual(t.index,1)
        for _ in 0..<6 {t.step(0.05,arrived:[])};XCTAssertFalse(t.complete);t.step(0.05,arrived:["hand"]);XCTAssertTrue(t.complete)
    }
    func testLifecycleNormalAndInterruptedCleanup(){
        var normal=StoryLifecycleMachine();XCTAssertFalse(normal.transition(.playing))
        for p in [StoryLifecycle.validating,.reserving,.spawning,.playing,.finishing,.cleanup,.completed] {XCTAssertTrue(normal.transition(p))}
        var interrupted=StoryLifecycleMachine();for p in [StoryLifecycle.validating,.reserving,.spawning,.playing,.interrupted,.cleanup,.completed] {XCTAssertTrue(interrupted.transition(p))}
        XCTAssertFalse(interrupted.transition(.spawning))
    }
    func testStageNeverCrossesWindowsReservedIconsOrScreenEdges(){
        let screen=Rect(-900,0,900,600),point=Vec(-450,550)
        let stage=StoryStagePlanner.stage(bounds:screen,focus:point,blocked:[])!;XCTAssertFalse(StoryStagePlanner.clipped(stage,to:screen))
        XCTAssertNil(StoryStagePlanner.stage(bounds:screen,focus:point,blocked:[screen]))
        if let next=StoryStagePlanner.stage(bounds:screen,focus:point,blocked:[Rect(-900,0,100,600)]) {XCTAssertFalse(next.intersects(Rect(-900,0,100,600)))}
    }
    func testActorSeparationAndBounds(){
        let bodies=[StoryBody("a",Vec(120,100),radius:18),StoryBody("b",Vec(120,100),radius:18),StoryBody("c",Vec(124,100),radius:22)]
        let points=StoryCollisionAvoidance.resolve(bodies,bounds:Rect(0,0,500,200))
        for i in bodies.indices {for j in bodies.indices where j>i {XCTAssertGreaterThanOrEqual((points[i]-points[j]).length,bodies[i].radius+bodies[j].radius-0.1)}}
    }
    func testLegacyConfigurationAndPermanentDecorationsRoundTrip() throws {
        let encoder=JSONEncoder();var old=try JSONSerialization.jsonObject(with:encoder.encode(Configuration())) as! [String:Any];old.removeValue(forKey:"stories")
        var c=try Configuration.decodeCompatible(JSONSerialization.data(withJSONObject:old));XCTAssertTrue(c.stories.enabled);XCTAssertEqual(c.stories.frequency,.normal);XCTAssertFalse(c.stories.sounds);XCTAssertFalse(c.stories.allowSnowmanCreation)
        c.placements["screen"]=Placement();c.placements["screen"]?.storyPresents=[StoryPresentPlacement(id:"gift",position:Vec(0.4,0.9),variant:"blue")];c.stories.reservedZones=[StoryReservedZone(screen:"all",rect:Rect(0.84,0,0.16,1))]
        let decoded=try Configuration.decodeCompatible(encoder.encode(c));XCTAssertEqual(decoded.placements["screen"]?.storyPresents,c.placements["screen"]?.storyPresents);XCTAssertEqual(decoded.stories,c.stories)
    }
}
