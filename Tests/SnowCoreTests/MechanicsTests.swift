#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class MechanicsTests:XCTestCase {
 func testFiveIndependentSnowmenCanBeSelectedRemovedAndReplaced(){
  var world=SnowballSystem()
  for i in 0..<5 {world.balls=[26,18,9].map{Snowball(position:Vec(50,500),radius:$0)};XCTAssertTrue(world.assemblePrepared(at:Vec(Double(i)*100+50,480)))}
  let ids=world.snowmen.map(\.id);XCTAssertEqual(Set(ids).count,5);XCTAssertFalse(world.canBuild)
  world.balls=[20,14,8].map{Snowball(position:Vec(),radius:$0)};XCTAssertFalse(world.assemblePrepared(at:Vec()))
  world.select(ids[1]);XCTAssertEqual(world.primaryID,ids[1]);world.snowman=Vec(700,450)
  XCTAssertEqual(world.snowmen.first{$0.id==ids[1]}?.position,Vec(700,450));XCTAssertEqual(world.snowmen.first{$0.id==ids[0]}?.position.x,50)
  XCTAssertNotNil(world.remove(ids[3]));XCTAssertNil(world.remove(ids[3]));XCTAssertEqual(world.snowmen.count,4);XCTAssertTrue(world.assemblePrepared(at:Vec(800,480)));XCTAssertEqual(world.snowmen.count,5)
 }
 func testFiveModelPersistenceAndGlobalLimit() throws {
  var c=Configuration(),p=Placement();p.snowmen=(0..<7).map{DesktopSnowman(position:Vec(Double($0)/7,0.9),radii:[26,18,9])};c.placements["1"]=p;c.placements["2"]=p;c.validate()
  XCTAssertEqual(c.placements.values.reduce(0){$0+($1.snowmen?.count ?? 0)},5)
  let saved=try Configuration.decodeCompatible(JSONEncoder().encode(c));XCTAssertEqual(saved.placements["1"]?.snowmen?.count,5);XCTAssertEqual(saved.placements["1"]?.snowmen?.first?.radii,[26,18,9])
 }
 func testEmptyNewCollectionCannotResurrectLegacySnowman() throws {
  var c=Configuration(),p=Placement(snowman:Vec(0.3,0.9),snowmanRadii:[12,9,6]);p.snowmen=[];c.placements["1"]=p;c.validate()
  XCTAssertNil(c.placements["1"]?.snowman);XCTAssertNil(c.placements["1"]?.snowmanRadii)
  let saved=try Configuration.decodeCompatible(JSONEncoder().encode(c));XCTAssertEqual(saved.placements["1"]?.snowmen?.count,0);XCTAssertNil(saved.placements["1"]?.snowman)
 }
 func testGatheringAndCancellationConserveFiniteSnowAndBoundPool(){
  var play=SnowballPlay(),stock=10000.0
  func take(_ n:Double)->Double {let amount=min(max(0,n),stock);stock-=amount;return amount}
  for i in 0..<300 {play.gather(at:Vec(Double(i)*8,500),extract:take)}
  XCTAssertEqual(play.balls.count,5);XCTAssertTrue(play.balls.allSatisfy{$0.radius<=14.001});XCTAssertEqual(stock+play.balls.reduce(0){$0+$1.mass},10000,accuracy:0.001)
  let returned=play.cancel().reduce(0){$0+$1.1};XCTAssertEqual(stock+returned,10000,accuracy:0.001);XCTAssertTrue(play.balls.isEmpty)
 }
 func testFlickHitsBySweptCollisionAndRestingReleaseLands(){
  var play=SnowballPlay();play.gather(at:Vec(100,500),extract:{$0});play.gather(at:Vec(120,500),extract:{$0})
  let p=play.balls[0].position;XCTAssertTrue(play.grab(at:p,now:0));play.drag(to:Vec(180,490),now:0.2);play.release(at:Vec(180,490),now:0.2)
  let model=DesktopSnowman(position:Vec(280,480),radii:[12,9,6]);var hits=0
  for _ in 0..<120 {for e in play.step(1.0/60,bounds:Rect(0,0,900,600),targets:[model],ground:{_ in 550}){if case .hit(let id,_,_)=e {XCTAssertEqual(id,model.id);hits+=1}}}
  XCTAssertEqual(hits,1);XCTAssertTrue(play.balls.isEmpty)
  play.gather(at:Vec(100,500),extract:{$0});play.gather(at:Vec(120,500),extract:{$0});let mass=play.balls[0].mass
  XCTAssertTrue(play.grab(at:play.balls[0].position,now:1));play.drag(to:Vec(170,450),now:1.1);play.release(at:Vec(170,450),now:2)
  var landed=0.0;for _ in 0..<180{for e in play.step(1.0/60,bounds:Rect(0,0,900,600),targets:[],ground:{_ in 550}){if case .land(_,let m)=e{landed+=m}}}
  XCTAssertEqual(landed,mass,accuracy:0.001)
 }
 func testCarrierStaysOutsideTruckWhileHoldingTree(){
  for from in [Vec(-170,500),Vec(1170,500)] {
   var scene=TreeSceneController(entry:from,target:Vec(500,500))
   for _ in 0..<420 {_=scene.step(1.0/60);if scene.elapsed>=1.8 && scene.elapsed<=3.1 {XCTAssertGreaterThan(abs(scene.gnome.x-scene.vehicle.position.x),80)}}
   XCTAssertTrue(scene.complete)
  }
 }
 func testYetiActionHasReadablePreparationFlightAndNoDuplicateContact(){
  var c=CharacterController(action:.throwSnowball,target:Vec(500,500),path:[Vec(0,500),Vec(400,500)],speed:165)
  XCTAssertGreaterThan(c.approachDuration,2);var releaseTime=0.0,impactTime=0.0,releases=0,hits=0
  for _ in 0..<1800 {for e in c.step(1.0/60){if e == .release {releaseTime=c.elapsed;releases+=1};if e == .impact{impactTime=c.elapsed;hits+=1}}}
  XCTAssertEqual(releases,1);XCTAssertEqual(hits,1);XCTAssertGreaterThan(impactTime-releaseTime,1.2)
 }
}
