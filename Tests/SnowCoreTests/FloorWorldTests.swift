#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class FloorWorldTests:XCTestCase {
    func testOrdinaryWindowDragDetachesVerticalSnowAndKeepsAllMass() {
        var s=SnowSurface(id:"window-1",screenID:"1",frame:Rect(100,120,480,250),maxHeight:9);s.add(volume:1300)
        let before=s.volume,event=s.updateWindow(to:Rect(112,120,480,250),dt:0.033,now:1)
        XCTAssertGreaterThan(event.mass,50)
        XCTAssertTrue(event.chunks.allSatisfy{$0.fallsToGround && $0.velocity.x==0 && $0.velocity.y>0})
        XCTAssertEqual(s.volume+event.mass,before,accuracy:0.0001)
    }
    func testFallenWindowSnowMakesLocalMoundEvenOnFullGround() {
        let manager=SurfaceManager();var ground=SnowSurface(id:"ground-1",screenID:"1",frame:Rect(0,500,800,1),maxHeight:18)
        for _ in 0..<30 {ground.add(volume:10000)}
        let before=ground.volume,oldHeight=ground.height(at:0.5);manager.surfaces[ground.id]=ground
        let engine=ParticleEngine(bounds:Rect(0,0,800,510),surfaces:manager)
        engine.emit(SnowFallEvent([SnowChunk(Vec(400,150),Vec(0,15),300,fallsToGround:true)]))
        for _ in 0..<80 {engine.step(dt:0.025,config:Configuration())}
        XCTAssertGreaterThan(manager.surfaces[ground.id]!.height(at:0.5),oldHeight+2)
        XCTAssertGreaterThan(manager.surfaces[ground.id]!.volume,before+100)
        XCTAssertEqual(manager.surfaces[ground.id]!.volume-before+engine.particles.reduce(0){$0+$1.snowVolume}+engine.dissipatedMass+engine.escapedMass,300,accuracy:0.0001)
        XCTAssertLessThan(manager.surfaces[ground.id]!.height(at:0.1),oldHeight+15)
    }
    func testVerticalFallIgnoresWindAndOtherWindows() {
        let manager=SurfaceManager();manager.surfaces["window-9"]=SnowSurface(id:"window-9",screenID:"1",frame:Rect(0,150,800,200),maxHeight:8)
        let engine=ParticleEngine(bounds:Rect(0,0,800,600),surfaces:manager);engine.emit(SnowFallEvent([SnowChunk(Vec(300,80),Vec(40,15),100,fallsToGround:true)]))
        var config=Configuration();config.windAngle=90;config.windStrength=1
        for _ in 0..<20 {engine.step(dt:0.03,config:config)}
        XCTAssertEqual(engine.particles.first!.position.x,300,accuracy:0.0001)
        XCTAssertGreaterThan(engine.particles.first!.position.y,150)
    }
    func testGroundWorldMigrationAndThreeTreeHooks() throws {
        var old=try JSONSerialization.jsonObject(with:JSONEncoder().encode(Configuration())) as! [String:Any]
        old.removeValue(forKey:"floorWorldVersion");old["dockSnow"]=true;old.removeValue(forKey:"treeSize");old["bulbSize"]=4
        old["placements"]=["1":["tree":["x":0.4,"y":0.8],"garland":[],"ornaments":[["id":"tree_toy_0","anchor":["x":0.4,"y":0.4],"hidden":false]]]]
        let c=try Configuration.decodeCompatible(JSONSerialization.data(withJSONObject:old))
        XCTAssertFalse(c.dockSnow);XCTAssertTrue(c.groundSnow);XCTAssertEqual(c.treeSize,"medium");XCTAssertEqual(c.treeStar,"none");XCTAssertEqual(c.bulbSize,10)
        XCTAssertEqual(TreeOrnament.branchAnchors.count,3)
        XCTAssertEqual(c.placements["1"]?.ornaments?.map(\.id),["tree_slot_0","tree_slot_1","tree_slot_2"])
    }
    func testYetiGamesDivideRandomDomainEquallyAndFlightDropIsExact() {
        XCTAssertEqual(YetiGame.choose(unit:0),.snowball);XCTAssertEqual(YetiGame.choose(unit:0.49999),.snowball)
        XCTAssertEqual(YetiGame.choose(unit:0.5),.castle);XCTAssertEqual(YetiGame.choose(unit:0.99999),.castle)
        for f in [0.1,0.3,0.7,0.9] {XCTAssertEqual(WinterMotion.flightProgress(WinterMotion.flightTime(fraction:f)/7),f,accuracy:0.00001)}
    }
}
