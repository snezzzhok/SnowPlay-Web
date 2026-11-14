import Foundation

public struct BallisticSnowball {
    public var origin:Vec
    public var velocity:Vec
    public var gravity:Double
    public var time=0.0
    public var owner:Int
    public init(origin:Vec,velocity:Vec,gravity:Double=320,owner:Int=0){self.origin=origin;self.velocity=velocity;self.gravity=gravity;self.owner=owner}
    public func position(at t:Double)->Vec {origin+velocity*t+Vec(0,gravity*t*t/2)}
    public var position:Vec {position(at:time)}
    public static func intersects(from a:Vec,to b:Vec,rect:Rect)->Bool {
        var lo=0.0,hi=1.0;let v=b-a
        for (p,q) in [(-v.x,a.x-rect.x),(v.x,rect.maxX-a.x),(-v.y,a.y-rect.y),(v.y,rect.maxY-a.y)] {
            if abs(p)<0.000001 {if q<0{return false}}
            else if p<0 {lo=max(lo,q/p)}else{hi=min(hi,q/p)}
        }
        return lo<=hi && hi>=0 && lo<=1
    }
}
public enum DuelPhase:String {case introduction,playerAim,playerFlight,yetiPrepare,yetiFlight,reaction,victory,defeat,finished}
public enum DuelEvent:Equatable {case throwBall(Int),hit(Int),miss(Int),ground(Vec),timeout,victory,defeat,finished}
public struct DuelController {
    public private(set) var phase=DuelPhase.introduction
    public private(set) var elapsed=0.0,phaseTime=0.0
    public private(set) var playerHP=5,yetiHP=5
    public private(set) var ball:BallisticSnowball?
    public private(set) var power=0.5,turn=0
    public private(set) var angle=Double.pi/4
    public static let turnDuration=5.0
    public private(set) var hitAt = -100.0,hitOwner = -1
    public let area:Rect
    public let gravity=320.0
    private var nextOwner=1
    public init(area:Rect){self.area=area}
    public var playerFeet:Vec {Vec(area.x+60,area.maxY-16)}
    public var yetiFeet:Vec {Vec(area.maxX-60,area.maxY-16)}
    public var secondsLeft:Double {phase == .playerAim ? max(0,Self.turnDuration-phaseTime):0}
    public var active:Bool {phase != .finished}
    public var ended:Bool {phase == .victory || phase == .defeat || phase == .finished}
    public func hand(_ owner:Int)->Vec {owner == 0 ? playerFeet+Vec(12,-27):yetiFeet+Vec(-13,-29)}
    public func speed(for power:Double)->Double {
        let distance=abs(hand(1).x-hand(0).x),ideal=sqrt(gravity*distance)
        return ideal*(0.55+clamp(power,0,1)*0.9)
    }
    public mutating func aim(_ value:Double){if phase == .playerAim,value.isFinite {power=clamp(value,0,1)}}
    public mutating func aim(at point:Vec) {
        guard phase == .playerAim,point.x.isFinite,point.y.isFinite else{return}
        let delta=point-hand(0),dx=max(1,delta.x),dy=max(0,-delta.y)
        angle=clamp(atan2(dy,dx),Double.pi/36,Double.pi*4/9)
        let ideal=sqrt(gravity*abs(hand(1).x-hand(0).x))
        power=clamp((hypot(dx,dy)*1.75/ideal-0.55)/0.9,0,1)
    }
    public var aimedVelocity:Vec {let speed=speed(for:power);return Vec(cos(angle)*speed,-sin(angle)*speed)}
    private mutating func change(_ next:DuelPhase){phase=next;phaseTime=0}
    @discardableResult public mutating func fire()->Bool {
        guard phase == .playerAim else{return false};launch(owner:0,power:power);return true
    }
    private mutating func launch(owner:Int,power:Double){
        let speed=speed(for:power),sign=owner == 0 ? 1.0:-1.0
        ball=BallisticSnowball(origin:hand(owner),velocity:owner == 0 ? aimedVelocity:Vec(sign*speed/sqrt(2),-speed/sqrt(2)),gravity:gravity,owner:owner)
        change(owner == 0 ? .playerFlight:.yetiFlight)
    }
    public mutating func exit(){ball=nil;change(.finished)}
    public mutating func step(_ dt:Double,snowHeight:(Double)->Double={_ in 0})->[DuelEvent] {
        guard active else{return []};let dt=clamp(dt,0,0.05);elapsed+=dt;phaseTime+=dt
        var events:[DuelEvent]=[]
        switch phase {
        case .introduction:if phaseTime>=1.3 {change(.playerAim)}
        case .playerAim:if phaseTime>=Self.turnDuration {events.append(.timeout);change(.yetiPrepare)}
        case .yetiPrepare:
            if phaseTime>=1.2 {
                // Friendly opponent chooses a force, never an outcome. Every hit is a collision.
                let errors=[-0.17,0.13,0.0,-0.08,0.0,0.16]
                launch(owner:1,power:clamp(0.5+errors[turn%errors.count],0,1));turn+=1;events.append(.throwBall(1))
            }
        case .playerFlight,.yetiFlight:
            guard var shot=ball else{change(.playerAim);break}
            let old=shot.position;shot.time+=dt;let point=shot.position;ball=shot
            let target=shot.owner == 0 ? yetiFeet:playerFeet,index=1-shot.owner
            let body=Rect(target.x-15,target.y-45,30,45)
            if BallisticSnowball.intersects(from:old,to:point,rect:body.expanded(3)) {
                if index==0 {playerHP=max(0,playerHP-1)}else{yetiHP=max(0,yetiHP-1)}
                hitAt=elapsed;hitOwner=index;events.append(.hit(index));ball=nil
                if yetiHP==0 {change(.victory);events.append(.victory)}
                else if playerHP==0 {change(.defeat);events.append(.defeat)}
                else{nextOwner=1-shot.owner;change(.reaction)}
            } else if point.y>=area.maxY-16-snowHeight(point.x) || point.x<area.x-12 || point.x>area.maxX+12 || shot.time>4 {
                ball=nil;events.append(.miss(shot.owner))
                if point.y>=area.maxY-16-snowHeight(point.x) {events.append(.ground(Vec(clamp(point.x,area.x,area.maxX),area.maxY-16-snowHeight(point.x))))}
                nextOwner=1-shot.owner;change(.reaction)
            }
        case .reaction:if phaseTime>=0.45 {change(nextOwner == 0 ? .playerAim:.yetiPrepare)}
        case .victory:if phaseTime>=6.0 {change(.finished);events.append(.finished)}
        case .defeat:if phaseTime>=7.0 {change(.finished);events.append(.finished)}
        case .finished:break
        }
        return events
    }
}

public enum FreePlayArea {
    public static func floorX(near preferred:Double,in bounds:Rect,blocked:[Rect],left:Double=25,right:Double=25,groundY:(Double)->Double)->Double? {
        let low=bounds.x+left+8,high=bounds.maxX-right-8
        guard low<=high else{return nil}
        let candidates=[clamp(preferred,low,high)]+Array(stride(from:low,through:high,by:24)).sorted{abs($0-preferred)<abs($1-preferred)}
        return candidates.first {x in
            let footprint=Rect(x-left,groundY(x)-52,left+right,58)
            return !blocked.contains{$0.expanded(4).intersects(footprint)}
        }
    }
    public static func find(in bounds:Rect,blocked:[Rect])->Rect? {
        let width=min(660,bounds.width-32),height=210.0
        guard width>=360,bounds.height>=height+60 else{return nil}
        for y in stride(from:bounds.maxY-height-20,through:bounds.y+40,by:-32) {
            for x in [bounds.center.x-width/2,bounds.x+16,bounds.maxX-width-16] {
                let area=Rect(x,y,width,height)
                if !blocked.contains(where:{$0.expanded(8).intersects(area)}){return area}
            }
        };return nil
    }
}
