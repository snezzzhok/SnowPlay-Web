#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class OptimizationTests:XCTestCase {
 func testWeatherTargetSurvivesFiniteEffectsAndReset(){
  let e=ParticleEngine(bounds:Rect(0,0,600,400),surfaces:SurfaceManager())
  e.setCount(40);e.dust(at:Vec(100,100),count:3);e.setCount(40)
  XCTAssertEqual(e.particles.filter{$0.remaining<0}.count,40)
  let first=UUID(),second=UUID();let event=SnowFallEvent([SnowChunk(Vec(100,100),Vec(),20)])
  _=e.emit(event,effectID:first);e.retainEffects([first]);_=e.emit(event,effectID:second);e.retainEffects([first])
  XCTAssertFalse(e.particles.contains{$0.effectID==second});XCTAssertTrue(e.particles.contains{$0.effectID==first})
  e.retainEffects([]);XCTAssertFalse(e.particles.contains{$0.effectID != nil});e.reset();e.setCount(40)
  XCTAssertEqual(e.particles.count,40)
 }
 func testBroadPhaseKeepsGroundMassAndVerticalCollisions(){
  for vertical in [false,true] {
   let surfaces=SurfaceManager(),id=vertical ? "side":"ground-1"
   surfaces.surfaces[id]=SnowSurface(id:id,screenID:"1",frame:vertical ? Rect(200,0,3,400):Rect(0,300,600,1),maxHeight:42,axis:vertical ? .verticalLeft:.horizontal)
   let e=ParticleEngine(bounds:Rect(0,0,600,400),surfaces:surfaces)
   _=e.emit(SnowFallEvent([SnowChunk(Vec(100,100),Vec(vertical ? 150:0,0),20,fallsToGround:!vertical)]))
   for _ in 0..<120 {e.step(dt:1.0/60,config:Configuration())}
   XCTAssertGreaterThan(surfaces.surfaces[id]!.volume,19.99)
   XCTAssertEqual(surfaces.surfaces[id]!.volume+e.particles.reduce(0){$0+$1.snowVolume}+e.escapedMass+e.dissipatedMass,20,accuracy:0.001)
  }
 }
}
