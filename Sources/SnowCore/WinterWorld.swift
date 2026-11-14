import Foundation
public typealias SnowMass = Double
public typealias SnowParticle = Particle
public struct SnowAccumulation { public let heights:[Double]; public let mass:Double; public init(_ surface:SnowSurface){heights=surface.heights;mass=surface.volume} }
public struct SnowChunk { public var position:Vec; public var velocity:Vec; public var mass:Double; public var fallsToGround:Bool; public init(_ p:Vec,_ v:Vec,_ m:Double,fallsToGround:Bool=false){position=p;velocity=v;mass=max(0,m);self.fallsToGround=fallsToGround} }
public struct SnowFallEvent { public var chunks:[SnowChunk]; public var mass:Double {chunks.reduce(0){$0+$1.mass}}; public init(_ chunks:[SnowChunk]=[]){self.chunks=chunks} }
public struct SnowPile {
    public var mass=0.0, exported=0.0, melted=0.0
    public var position=Vec()
    public init(){}
    public mutating func collect(_ amount:Double){mass+=max(0,amount)}
    public mutating func export(){exported+=mass;mass=0}
    public mutating func take()->Double{let value=mass;mass=0;return value}
}
public struct GarlandPhysics {
    public private(set) var points:[Vec]=[]
    private var previous:[Vec]=[]
    private var anchors:[Vec]=[]
    private var rest:[Double]=[]
    public init(){}
    public mutating func reset(){points=[];previous=[];anchors=[];rest=[]}
    public mutating func step(anchors next:[Vec],sag:Double,dt:Double,reduced:Bool=false){
        guard next.count>=2 else {reset();return}
        let subdivisions=10
        if anchors.count != next.count || points.isEmpty {
            anchors=next;points=[];rest=[]
            for segment in 0..<next.count-1 {
                let a=next[segment],b=next[segment+1]
                var last=a
                for j in 0...subdivisions {
                    let f=Double(j)/Double(subdivisions),p=a+(b-a)*f+Vec(0,4*sag*f*(1-f))
                    if segment==0 || j>0 {points.append(p);if points.count>1 {rest.append((p-last).length)}}
                    last=p
                }
            };previous=points
        }
        // Updating an attachment carries the adjacent wire; gravity and constraints settle it.
        for k in next.indices {
            let i=k*subdivisions,delta=next[k]-anchors[k]
            if delta.length>0 {
                for j in max(0,i-subdivisions+1)...min(points.count-1,i+subdivisions-1){let w=1-Double(abs(j-i))/Double(subdivisions);points[j]=points[j]+delta*w;previous[j]=previous[j]+delta*w}
            }
        };anchors=next
        if reduced {
            for i in points.indices {let segment=min(next.count-2,i/subdivisions),f=Double(i-segment*subdivisions)/Double(subdivisions);points[i]=next[segment]+(next[segment+1]-next[segment])*f+Vec(0,4*sag*f*(1-f))};previous=points;return
        }
        let h=clamp(dt,0,0.033333)
        for i in points.indices where i%subdivisions != 0 {let p=points[i];points[i]=p+(p-previous[i])*exp(-h*5)+Vec(0,100*h*h);previous[i]=p}
        for _ in 0..<7 {
            for k in next.indices {points[k*subdivisions]=next[k]}
            for i in 0..<points.count-1 {
                let delta=points[i+1]-points[i],length=max(0.001,delta.length)
                // Rest lengths respond continuously to the requested slack.
                let segment=i/subdivisions,a=next[segment],b=next[segment+1]
                let f=Double(i%subdivisions)/Double(subdivisions),f2=f+1/Double(subdivisions)
                let target=((b-a)/Double(subdivisions)+Vec(0,4*sag*(f2*(1-f2)-f*(1-f)))).length
                rest[i]+=(target-rest[i])*min(1,h*8)
                let error=delta*((length-rest[i])/length)
                let left=i%subdivisions==0,right=(i+1)%subdivisions==0
                if !left {points[i]=points[i]+error*(right ? 1:0.5)}
                if !right {points[i+1]=points[i+1]-error*(left ? 1:0.5)}
            }
        }
        for k in next.indices {points[k*subdivisions]=next[k];previous[k*subdivisions]=next[k]}
    }
}
public extension Vec {static func / (a:Vec,b:Double)->Vec{a*(1/b)}}
public enum CharacterAction:String {case chopTree,throwSnowball,helpBuild,carryObject,playWithSnow,buildCastle}
public enum CharacterPhase:String {case idle,entering,walking,approachingTarget,preparingAction,performingAction,reacting,leaving,finished}
public enum CharacterContact:Equatable {case strike(Int),release,impact,help,carry,drop,play,build,finished}
public struct Projectile {
    public var origin:Vec,target:Vec,duration:Double,gravity:Double
    public init(from:Vec,to:Vec,duration:Double=0.65,gravity:Double=160){origin=from;target=to;self.duration=duration;self.gravity=gravity}
    public func position(_ t:Double)->Vec {
        BallisticSnowball(origin:origin,velocity:(target-origin)/max(0.001,duration)+Vec(0,-gravity*duration/2),gravity:gravity).position(at:clamp(t,0,duration))
    }
}
public struct CharacterController {
    public let action:CharacterAction
    public let target:Vec
    public let path:[Vec]
    public let speed:Double
    public private(set) var elapsed=0.0
    public private(set) var phase=CharacterPhase.entering
    public var position:Vec {if action == .carryObject && elapsed>=actionStart && elapsed<=actionEnd+0.65 {return (path.last ?? target)+Vec(-28*clamp(localTime/1.1,0,1),0)};if elapsed<approachDuration{return point(along:path,fraction:elapsed/approachDuration)};if elapsed>actionEnd+0.65{return point(along:(action == .carryObject ? [(path.last ?? target)+Vec(-28,0)]+Array(path.reversed()):Array(path.reversed())),fraction:(elapsed-actionEnd-0.65)/approachDuration)};return path.last ?? target}
    public var approachDuration:Double {clamp(pathLength/speed,1.2,6)}
    public var actionStart:Double {approachDuration+0.65}
    public var actionEnd:Double {actionStart+(action == .chopTree ? 3.4:action == .throwSnowball ? 2.5:action == .buildCastle ? 2.1:1.1)}
    public var duration:Double {actionEnd+0.65+approachDuration}
    public var localTime:Double {elapsed-actionStart}
    public var pathLength:Double {zip(path,path.dropFirst()).reduce(0){$0+($1.1-$1.0).length}}
    public init(action:CharacterAction,target:Vec,path:[Vec],speed:Double=150){self.action=action;self.target=target;self.path=path;self.speed=max(1,speed)}
    private func point(along p:[Vec],fraction:Double)->Vec {
        guard let first=p.first else{return target};let t=clamp(fraction,0,1),distance=(t*t*(3-2*t))*zip(p,p.dropFirst()).reduce(0){$0+($1.1-$1.0).length};var traversed=0.0
        for (a,b) in zip(p,p.dropFirst()){let n=(b-a).length;if traversed+n>=distance{return a+(b-a)*clamp((distance-traversed)/max(0.001,n),0,1)};traversed+=n};return p.last ?? first
    }
    public mutating func step(_ dt:Double)->[CharacterContact]{
        let before=elapsed;elapsed+=max(0,dt);var events:[CharacterContact]=[]
        func passed(_ t:Double)->Bool{before<t && elapsed>=t}
        if action == .chopTree {for (i,t) in [0.55,1.3,2.05].enumerated() where passed(actionStart+t){events.append(.strike(i))}}
        else if action == .throwSnowball {if passed(actionStart+0.55){events.append(.release)};if passed(actionStart+1.85){events.append(.impact)}}
        else if action == .buildCastle,passed(actionStart+0.4){events.append(.build)}
        else if action == .helpBuild,passed(actionStart+0.6){events.append(.help)}
        else if action == .carryObject {if passed(actionStart+0.1){events.append(.carry)};if passed(actionStart+1){events.append(.drop)}}
        else if action == .playWithSnow,passed(actionStart+0.3){events.append(.play)}
        if elapsed>=duration {phase = .finished;if before<duration {events.append(.finished)}}
        else if elapsed>actionEnd+0.65 {phase = .leaving}
        else if elapsed>actionEnd {phase = .reacting}
        else if elapsed>actionStart {phase = .performingAction}
        else if elapsed>approachDuration {phase = .preparingAction}
        else {phase = elapsed<0.15 ? .entering:elapsed>approachDuration-0.25 ? .approachingTarget:.walking}
        return events
    }
}
public enum CharacterNavigation {
    public static func path(from start:Vec,to end:Vec,bounds:Rect,obstacles:[Rect])->[Vec]? {
        let blocks=obstacles.map{$0.expanded(18)}
        func clear(_ a:Vec,_ b:Vec)->Bool {
            for r in blocks {
                var lo=0.0,hi=1.0
                let v=b-a
                for (p,q) in [(-v.x,a.x-r.x),(v.x,r.maxX-a.x),(-v.y,a.y-r.y),(v.y,r.maxY-a.y)] {
                    if abs(p)<0.00001 {if q<0 {lo=2;break}} else if p<0 {lo=max(lo,q/p)} else {hi=min(hi,q/p)}
                };if lo<hi && hi>0 && lo<1 {return false}
            };return true
        }
        guard !blocks.contains(where:{$0.contains(end)}) else{return nil}
        if clear(start,end){return [start,end]}
        var nodes=[start,end]
        for r in blocks.prefix(20){for p in [Vec(r.x-1,r.y-1),Vec(r.maxX+1,r.y-1),Vec(r.x-1,r.maxY+1),Vec(r.maxX+1,r.maxY+1)] where bounds.contains(p){nodes.append(p)}}
        var cost=Array(repeating:Double.infinity,count:nodes.count),prev=Array(repeating:-1,count:nodes.count),used=Set<Int>();cost[0]=0
        for _ in nodes.indices {
            guard let i=nodes.indices.filter({!used.contains($0)}).min(by:{cost[$0]<cost[$1]}),cost[i].isFinite else{break}
            if i==1 {var result=[nodes[1]],j=1;while prev[j]>=0 {j=prev[j];result.append(nodes[j])};return result.reversed()}
            used.insert(i)
            for j in nodes.indices where !used.contains(j) && clear(nodes[i],nodes[j]) {let c=cost[i]+(nodes[j]-nodes[i]).length;if c<cost[j]{cost[j]=c;prev[j]=i}}
        };return nil
    }
}
public enum GarlandAttachment {
    public static func resolve(_ p:Placement,bounds:Rect,window:Rect?,tree:Vec?,treeSize:Double)->[Vec] {
        let target=p.garlandTarget ?? (p.garlandWindow == nil ? "desktop":"window")
        switch target {
        case "window":guard let w=window else{return []};return p.garland.map{Vec(clamp(w.x+$0.x*w.width,w.x+76,w.maxX-8),w.y+5+$0.y*12)}
        case "tree":guard let t=tree else{return []};return p.garland.map{t+Vec(($0.x-0.5)*treeSize,($0.y-0.5)*treeSize)}
        default:return p.garland.map{Vec(bounds.x+$0.x*bounds.width,bounds.y+$0.y*bounds.height)}
        }
    }
}
/// Two-segment contact rig. The tool's blade and its grip stay registered through a strike.
public enum CharacterArmRig {
    public static func pose(goal:Vec,hand:Vec,tip:Vec)->(arm:Double,tool:Double) {
        let a=hand.length,b=tip.length,d=clamp(goal.length,abs(a-b)+0.001,a+b-0.001)
        let elbow=acos(clamp((d*d-a*a-b*b)/(2*a*b),-1,1))
        let upper=atan2(goal.y,goal.x)-atan2(b*sin(elbow),a+b*cos(elbow))
        let arm=upper-atan2(hand.y,hand.x)
        return (arm,upper+elbow-arm-atan2(tip.y,tip.x))
    }
}

public enum YetiGame:String {case snowball,castle
    public static func choose(unit:Double)->YetiGame {unit<0.5 ? .snowball:.castle}
}
