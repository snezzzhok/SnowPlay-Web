import Foundation
public struct StoryFootPose {public var x:Double,lift:Double,stance:Bool}
public enum StoryGait {
 public static func foot(distance:Double,leg:Int,stride:Double=18)->StoryFootPose {
  let phase=((distance/stride+Double(leg)*0.5).truncatingRemainder(dividingBy:1)+1).truncatingRemainder(dividingBy:1),span=stride*0.6
  if phase<0.6{return StoryFootPose(x:span/2-stride*phase,lift:0,stance:true)}
  let t=(phase-0.6)/0.4,s=t*t*(3-2*t);return StoryFootPose(x:-span/2+span*s,lift:sin(t*Double.pi)*4,stance:false)
 }
 public static func pointSegmentDistance(_ p:Vec,_ a:Vec,_ b:Vec)->Double {let d=b-a,t=clamp(((p.x-a.x)*d.x+(p.y-a.y)*d.y)/max(0.0001,d.x*d.x+d.y*d.y),0,1);return (p-(a+d*t)).length}
}
