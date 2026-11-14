#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class LivingWinterTests:XCTestCase {
    func testFeedFootprintStaysOutsideDockAndWorkingWindows() {
        let bounds=Rect(0,0,1000,600),dock=Rect(300,520,600,80)
        let x=FreePlayArea.floorX(near:500,in:bounds,blocked:[dock],left:65,groundY:{_ in 590})
        XCTAssertNotNil(x)
        XCTAssertFalse(Rect(x!-65,538,90,58).intersects(dock.expanded(4)))
        XCTAssertNil(FreePlayArea.floorX(near:500,in:bounds,blocked:[bounds],left:65,groundY:{_ in 590}))
    }
    func testDesktopOcclusionCountsOverlappingWindowsOnce() {
        let screen=Rect(-100,20,200,100)
        XCTAssertEqual(DesktopVisibility.exposedFraction(in:screen,blocked:[]),1)
        XCTAssertEqual(DesktopVisibility.exposedFraction(in:screen,blocked:[Rect(-100,20,100,100),Rect(-100,20,100,100)]),0.5)
        XCTAssertEqual(DesktopVisibility.exposedFraction(in:screen,blocked:[Rect(-100,20,100,100),Rect(0,20,100,100)]),0)
        XCTAssertEqual(DesktopVisibility.exposedFraction(in:screen,blocked:[Rect(500,500,20,20)]),1)
    }
    private let area=Rect(100,200,660,210)
    private func ready()->DuelController {var game=DuelController(area:area);for _ in 0..<90 {_=game.step(1.0/60)};return game}
    func testDuelFiveHPAndActualHit() {
        var game=ready();XCTAssertEqual(game.playerHP,5);XCTAssertEqual(game.yetiHP,5);XCTAssertEqual(game.phase,.playerAim)
        game.aim(0.5);XCTAssertTrue(game.fire());XCTAssertFalse(game.fire())
        var hits=0
        for _ in 0..<160 {for e in game.step(1.0/60) {if e == .hit(1){hits+=1}};if game.phase == .reaction{break}}
        XCTAssertEqual(hits,1);XCTAssertEqual(game.yetiHP,4);XCTAssertEqual(game.playerHP,5)
    }
    func testUnderAndOverThrowDoNotFakeHits() {
        for power in [0.0,1.0] {
            var game=ready();game.aim(power);_ = game.fire();var missed=false,ground=false
            for _ in 0..<240 {for e in game.step(1.0/60){if e == .miss(0){missed=true};if case .ground=e{ground=true}};if game.phase == .reaction{break}}
            XCTAssertTrue(missed);XCTAssertEqual(game.yetiHP,5)
            if power==0{XCTAssertTrue(ground)}else{XCTAssertFalse(ground)}
        }
    }
    func testTurnTimeoutAndExitDuringFlight() {
        var game=ready()
        for _ in 0..<310 {_=game.step(1.0/60)}
        XCTAssertEqual(game.phase,.yetiPrepare);XCTAssertEqual(game.playerHP,5)
        game.exit();XCTAssertFalse(game.active);XCTAssertNil(game.ball);XCTAssertTrue(game.step(0.05).isEmpty)
        game=ready();_ = game.fire();XCTAssertNotNil(game.ball);game.exit();XCTAssertNil(game.ball)
    }
    func testFiveSecondTurnAndCursorDirectionDriveActualBallistics() {
        var game=ready()
        XCTAssertGreaterThan(game.secondsLeft,4.7)
        for _ in 0..<210 {_=game.step(1.0/60)}
        XCTAssertEqual(game.phase,.playerAim)
        let hand=game.hand(0)
        game.aim(at:hand+Vec(160,-40));let low=game.angle,near=game.power
        game.aim(at:hand+Vec(160,-150));XCTAssertGreaterThan(game.angle,low);XCTAssertGreaterThan(game.power,near)
        let velocity=game.aimedVelocity
        XCTAssertTrue(game.fire());XCTAssertEqual(game.ball?.velocity,velocity);XCTAssertFalse(game.fire())
        game=ready();for _ in 0..<310 {_=game.step(1.0/60)};XCTAssertEqual(game.phase,.yetiPrepare)
    }
    func testBothEndingsReachFinishedWithoutLeakingProjectile() {
        for playerTries in [true,false] {
            var game=DuelController(area:area),win=false,lose=false
            for _ in 0..<6000 {
                if playerTries && game.phase == .playerAim {game.aim(0.5);_ = game.fire()}
                for event in game.step(0.05){if event == .victory{win=true};if event == .defeat{lose=true}}
                if !game.active{break}
            }
            XCTAssertEqual(game.phase,.finished);XCTAssertNil(game.ball)
            XCTAssertEqual(win,playerTries);XCTAssertEqual(lose,!playerTries)
            if playerTries {XCTAssertEqual(game.yetiHP,0)}else{XCTAssertEqual(game.playerHP,0)}
        }
    }
    func testProjectileIsAnalyticAndSweepsThinTargets() {
        let shot=BallisticSnowball(origin:Vec(10,20),velocity:Vec(200,-100),gravity:320)
        XCTAssertEqual(shot.position(at:0.5),Vec(110,10))
        XCTAssertTrue(BallisticSnowball.intersects(from:Vec(0,5),to:Vec(100,5),rect:Rect(45,0,2,10)))
        XCTAssertFalse(BallisticSnowball.intersects(from:Vec(0,-5),to:Vec(100,-5),rect:Rect(45,0,2,10)))
        let path=Projectile(from:Vec(10,20),to:Vec(100,80),duration:0.8,gravity:320)
        XCTAssertEqual(path.position(0),Vec(10,20));XCTAssertEqual(path.position(0.8).x,100,accuracy:0.00001);XCTAssertEqual(path.position(0.8).y,80,accuracy:0.00001)
    }
    func testTreeDeliveryInstallsExactlyOnceWithContinuousMotion() {
        var story=TreeSceneController(entry:Vec(-170,500),target:Vec(400,500)),installs=0,last=story.vehicle.position
        for _ in 0..<420 {if story.step(1.0/60){installs+=1};let p=story.vehicle.position;XCTAssertLessThan((p-last).length,16);last=p}
        XCTAssertTrue(story.complete);XCTAssertEqual(installs,1);XCTAssertEqual(story.treeBase,Vec(400,500));XCTAssertEqual(story.treeAngle,0)
    }
    func testSlowBrushPushesMassAndFastBrushReturnsExactSprayMass() {
        var snow=SnowSurface(id:"ground-1",screenID:"1",frame:Rect(0,600,900,1),maxHeight:42);snow.add(volume:18000)
        let before=snow.volume,h=snow.height(at:0.5),slow=snow.displace(at:0.5,radius:28,distance:6,speed:70)
        XCTAssertEqual(slow.mass,0);XCTAssertEqual(snow.volume,before,accuracy:0.000001);XCTAssertLessThan(snow.height(at:0.5),h)
        let fast=snow.displace(at:0.5,radius:28,distance:20,speed:1100)
        XCTAssertGreaterThan(fast.mass,0);XCTAssertEqual(snow.volume+fast.mass,before,accuracy:0.000001)
        let settled=snow.volume;for _ in 0..<300 {snow.relax(dt:1.0/60)}
        XCTAssertEqual(snow.volume,settled,accuracy:0.000001);XCTAssertTrue(snow.heights.allSatisfy{$0.isFinite && $0>=0})
    }
    func testClumpsAccelerateAndReturnTheirMassToGround() {
        let surfaces=SurfaceManager();surfaces.surfaces["ground-1"]=SnowSurface(id:"ground-1",screenID:"1",frame:Rect(0,598,900,1),maxHeight:42)
        let engine=ParticleEngine(bounds:Rect(0,0,900,600),surfaces:surfaces)
        XCTAssertEqual(engine.emit(SnowFallEvent([SnowChunk(Vec(400,80),Vec(0,15),500,fallsToGround:true)])),500)
        XCTAssertTrue(engine.particles[0].clump);let start=engine.particles[0].velocity.y
        engine.step(dt:0.05,config:Configuration());XCTAssertGreaterThan(engine.particles[0].velocity.y,start)
        for _ in 0..<180 {engine.step(dt:1.0/60,config:Configuration())}
        let airborne=engine.particles.filter{$0.remaining>=0}.reduce(0){$0+$1.snowVolume}
        XCTAssertEqual((surfaces.surfaces["ground-1"]?.volume ?? 0)+airborne+engine.escapedMass+engine.dissipatedMass,500,accuracy:0.00001)
        XCTAssertGreaterThan(surfaces.surfaces["ground-1"]!.volume,490)
    }
    func testFreeAreaSupportsNegativeMonitorCoordinatesAndOcclusion() {
        let bounds=Rect(-1440,-200,1440,900)
        XCTAssertNotNil(FreePlayArea.find(in:bounds,blocked:[]));XCTAssertNil(FreePlayArea.find(in:bounds,blocked:[bounds]))
        let area=FreePlayArea.find(in:bounds,blocked:[Rect(-1440,-200,1440,400)])!
        XCTAssertFalse(area.intersects(Rect(-1440,-200,1440,400)))
    }
    func testRescueHandsAndBodyShareTheCarrierFrame() {
        let feet=Vec(500,600)
        for i in 102..<330 {
            let pose=RescueRig.victory(elapsed:Double(i)/60,feet:feet,exitX:1100)
            XCTAssertEqual(pose.left.y,feet.y,accuracy:0.00001);XCTAssertEqual(pose.right.y,feet.y,accuracy:0.00001)
            XCTAssertEqual(pose.right.x-pose.left.x,62,accuracy:0.00001)
            XCTAssertEqual((pose.left.x+pose.right.x)/2,pose.body.x,accuracy:0.00001)
        }
    }
    func testNewDefaultsMigrationAndMultipleGarlandsPersist() throws {
        var config=Configuration();XCTAssertEqual(config.snowSize,2.5);XCTAssertEqual(config.groundHeight,42);XCTAssertFalse(config.windowSnow);XCTAssertEqual(config.automaticCleaning,0)
        var placement=Placement();placement.extraGarlands=[GarlandStrand(anchors:[Vec(0.1,0.2),Vec(0.8,0.3)],palette:"warm")];config.placements["1"]=placement;config.validate()
        let decoded=try Configuration.decodeCompatible(JSONEncoder().encode(config));XCTAssertEqual(decoded.placements["1"]?.extraGarlands?.count,1)
        var old=try JSONSerialization.jsonObject(with:JSONEncoder().encode(config)) as! [String:Any]
        old.removeValue(forKey:"livingWorldVersion");old.removeValue(forKey:"snowSize");old.removeValue(forKey:"automaticSnowman");old["groundHeight"]=18;old["automaticCleaning"]=300
        let migrated=try Configuration.decodeCompatible(JSONSerialization.data(withJSONObject:old));XCTAssertEqual(migrated.groundHeight,42);XCTAssertEqual(migrated.automaticCleaning,0);XCTAssertTrue(migrated.automaticSnowman)
    }
}
