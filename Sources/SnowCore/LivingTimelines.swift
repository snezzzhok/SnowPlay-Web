import Foundation
public enum LivingPose:String {case idle,run,stop,pickSnow,makeSnowball,throwBall,dodge,hit,fall,celebrate,chop,carry,lift,aim,drive,load,unload,walk,sneak,pickUp,putDown,repair,climb,point,surprised,angry,recover,dance,brush,bow,shake}
public enum VehiclePhase:String {case idle,drive,brake,load,unload,exit}
public struct VehiclePose {
    public var position:Vec;public var wheelAngle:Double;public var tilt:Double;public var phase:VehiclePhase
    public init(position:Vec,distance:Double,phase:VehiclePhase){self.position=position;wheelAngle=distance/7;tilt=phase == .brake ? -0.035:sin(distance/12)*0.008;self.phase=phase}
}
public struct TreeSceneController {
    public let entry:Vec,target:Vec,stop:Vec,exit:Vec
    public let treeHeight:Double
    public private(set) var elapsed=0.0,installed=false
    public var complete:Bool {elapsed>=6.5}
    public var heading:Double {entry.x<target.x ? 1:-1}
    public init(entry:Vec,target:Vec,exit:Vec?=nil,treeHeight:Double=132){self.treeHeight=treeHeight;self.entry=entry;self.target=target;let direction=entry.x<target.x ? 1.0:-1.0;stop=target+Vec(direction*140,0);self.exit=exit ?? target+Vec(direction*1200,0)}
    private func ease(_ t:Double)->Double{let f=clamp(t,0,1);return f*f*(3-2*f)}
    public var vehicle:VehiclePose {
        let p:Vec,phase:VehiclePhase
        if elapsed<1.25 {p=entry+(stop-entry)*ease(elapsed/1.25);phase=elapsed>0.95 ? .brake:.drive}
        else if elapsed<3.9 {p=stop;phase=elapsed<2.9 ? .unload:.idle}
        else{p=stop+(exit-stop)*ease((elapsed-3.9)/2.6);phase = .exit}
        return VehiclePose(position:p,distance:p.x-entry.x,phase:phase)
    }
    public var gripOffset:Vec {Vec(-heading*treeHeight*0.3,treeHeight*0.11)}
    public var gripDisplacement:Vec {let p=gripOffset,a=treeAngle;return Vec(cos(a)*p.x-sin(a)*p.y,-sin(a)*p.x-cos(a)*p.y)}
    public var gnome:Vec {
        let cab=vehicle.position+Vec(heading*21,0),feet=target+Vec(-heading*(treeHeight*0.3+16),0)
        if elapsed<1.25{return cab}
        let bed=stop+Vec(-heading*78,-8),angle = 0.0
        let p=gripOffset,pickup=Vec(bed.x+cos(angle)*p.x-sin(angle)*p.y-heading*16,target.y)
        if elapsed<1.8 {return cab+(pickup-cab)*ease((elapsed-1.25)/0.55)}
        if elapsed<3.1 {return Vec(treeBase.x+gripDisplacement.x-heading*16,target.y)}
        return feet+(entry-feet)*ease((elapsed-3.1)/3.4)
    }
    public var treeBase:Vec {
        let cargo=vehicle.position+Vec(-heading*22,-23),pickup=stop+Vec(-heading*78,-8)
        if elapsed<1.25{return cargo}
        if elapsed<1.8{return cargo+(pickup-cargo)*ease((elapsed-1.25)/0.55)}
        return pickup+(target-pickup)*ease((elapsed-1.8)/1.1)
    }
    public var treeAngle:Double {-heading*0.55*(1-ease((elapsed-1.25)/0.55))}
    public mutating func step(_ dt:Double)->Bool {let old=installed;elapsed+=max(0,dt);installed=elapsed>=2.9;return installed && !old}
}
public enum RescueRig {
    /// One carrier group owns both helper hands and the carried body.
    public static func victory(elapsed:Double,feet:Vec,exitX:Double)->(left:Vec,right:Vec,body:Vec) {
        let lift=clamp((elapsed-1.7)/0.6,0,1),leave=clamp((elapsed-2.6)/2.9,0,1),f=leave*leave*(3-2*leave)
        let centre=feet+Vec(18+(exitX-feet.x)*f,-lift*24)
        return (centre+Vec(-31,lift*24),centre+Vec(31,lift*24),centre)
    }
}
