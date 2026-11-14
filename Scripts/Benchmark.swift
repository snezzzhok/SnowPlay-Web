import Foundation
import SnowCore
let surfaces=SurfaceManager()
for i in 0..<40 {
    let x=Double(i%8)*170, y=Double(i/8)*160+90
    surfaces.surfaces["bench-\(i)"]=SnowSurface(id:"bench-\(i)",screenID:"bench",frame:Rect(x,y,150,100))
}
let engine=ParticleEngine(bounds:Rect(0,0,1440,900),surfaces:surfaces)
engine.setCount(400)
var config=Configuration(); config.windAngle=30; config.windStrength=0.4
for _ in 0..<120 { engine.step(dt:1/60,config:config) }
var samples: [Double] = []; samples.reserveCapacity(3600)
for _ in 0..<3600 {
    let t=DispatchTime.now().uptimeNanoseconds
    engine.step(dt:1/60,config:config)
    samples.append(Double(DispatchTime.now().uptimeNanoseconds-t)/1e6)
}
samples.sort()
let result: [String:Any] = ["frames":samples.count,"freeParticles":400,"surfaces":40,"meanStepMS":samples.reduce(0,+)/Double(samples.count),"p95StepMS":samples[Int(Double(samples.count)*0.95)],"maxStepMS":samples.last!,"note":"Release physics only. Not a renderer, GPU or app CPU measurement."]
let data=try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys])
print(String(data:data,encoding:.utf8)!)
