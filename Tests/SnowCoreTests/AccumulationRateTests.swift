#if canImport(XCTest)
import XCTest
#else
import Foundation
#endif
@testable import SnowCore
final class AccumulationRateTests:XCTestCase {
 func testOldSettingsDefaultAndLimits() throws {
  var object=try JSONSerialization.jsonObject(with:JSONEncoder().encode(Configuration())) as! [String:Any]
  object.removeValue(forKey:"accumulationRate")
  let restored=try Configuration.decodeCompatible(JSONSerialization.data(withJSONObject:object))
  XCTAssertEqual(restored.accumulationRate,1)
  var c=Configuration();c.accumulationRate=999;c.validate();XCTAssertEqual(c.accumulationRate,5)
  c.accumulationRate = .nan;c.validate();XCTAssertEqual(c.accumulationRate,1)
 }
 func testMoreAccumulationWithoutMoreParticles() {
  func simulate(_ rate:Double)->Double {
   let surfaces=SurfaceManager();surfaces.surfaces["ground-test"]=SnowSurface(id:"ground-test",screenID:"test",frame:Rect(0,98,1000,1),maxHeight:70)
   let engine=ParticleEngine(bounds:Rect(0,0,1000,100),surfaces:surfaces,seed:44);engine.setCount(30)
   var config=Configuration();config.accumulationRate=rate
   for _ in 0..<120 {engine.step(dt:1.0/60,config:config)}
   XCTAssertEqual(engine.particles.count,30)
   return surfaces.surfaces["ground-test"]!.volume
  }
  let slow=simulate(0.1),fast=simulate(5)
  XCTAssertGreaterThan(slow,0);XCTAssertGreaterThan(fast,slow*5)
 }
}
