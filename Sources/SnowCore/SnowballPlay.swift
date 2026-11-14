import Foundation
public struct LooseSnowball {
    public let id:UUID
    public var position:Vec,mass:Double
    public var flight:BallisticSnowball?
    public var radius:Double {sqrt(max(0,mass)/Double.pi)}
    public init(position:Vec,mass:Double){id=UUID();self.position=position;self.mass=mass}
}
public enum SnowballPlayEvent {case hit(UUID,Vec,Double),land(Vec,Double)}
public struct SnowballPlay {
    public private(set) var balls:[LooseSnowball]=[]
    public private(set) var held:UUID?
    private var gathering:UUID?,lastPointer:Vec?,lastTime=0.0,velocity=Vec()
    public init(){}
    public mutating func gather(at p:Vec,extract:(Double)->Double){
        guard p.x.isFinite,p.y.isFinite else{return}
        defer{lastPointer=p};guard held==nil,let old=lastPointer else{return};let travel=(p-old).length
        guard travel>1,travel<180 else{return}
        if gathering==nil || !balls.contains(where:{$0.id==gathering && $0.mass<Double.pi*14*14-0.01}) {
            guard balls.count<5 else{return};let mass=extract(Double.pi*16);guard mass>0 else{return};let b=LooseSnowball(position:p,mass:mass);balls.append(b);gathering=b.id
        }
        guard let i=balls.firstIndex(where:{$0.id==gathering}) else{return}
        balls[i].mass+=max(0,extract(min(travel*3,max(0,Double.pi*196-balls[i].mass))))
        balls[i].position=Vec(p.x,p.y-balls[i].radius)
    }
    @discardableResult public mutating func grab(at p:Vec,now:Double)->Bool {
        guard p.x.isFinite,p.y.isFinite,now.isFinite,held==nil,let b=balls.filter({$0.flight==nil && ($0.position-p).length<$0.radius+18}).min(by:{($0.position-p).length<($1.position-p).length}) else{return false}
        held=b.id;gathering=nil;lastPointer=p;lastTime=now;velocity=Vec();return true
    }
    public mutating func drag(to p:Vec,now:Double){
        guard p.x.isFinite,p.y.isFinite,now.isFinite,let i=balls.firstIndex(where:{$0.id==held}) else{return}
        let dt=clamp(now-lastTime,1.0/240,0.2),v=(p-(lastPointer ?? p))/dt
        if v.x.isFinite && v.y.isFinite {velocity=velocity*0.3+v*0.7}
        balls[i].position=p;lastPointer=p;lastTime=now
    }
    public mutating func release(at p:Vec,now:Double){
        guard p.x.isFinite,p.y.isFinite,now.isFinite,let i=balls.firstIndex(where:{$0.id==held}) else{return}
        // Preserve the last motion when mouseUp repeats the final drag coordinate.
        if (p-(lastPointer ?? p)).length>1 {drag(to:p,now:now)}
        let stale=now-lastTime>0.22,v=stale ? Vec():velocity,speed=v.length
        let launch=speed>850 ? v*(850/speed):v
        balls[i].flight=BallisticSnowball(origin:balls[i].position,velocity:launch,gravity:300);held=nil;lastPointer=nil;velocity=Vec()
    }
    public mutating func step(_ dt:Double,bounds:Rect,targets:[DesktopSnowman],ground:(Double)->Double)->[SnowballPlayEvent]{
        var events:[SnowballPlayEvent]=[],kept:[LooseSnowball]=[]
        for var b in balls {
            guard var shot=b.flight else {kept.append(b);continue}
            let old=b.position;shot.time+=clamp(dt,0,0.05);b.position=shot.position;b.flight=shot
            if let hit=targets.first(where:{BallisticSnowball.intersects(from:old,to:b.position,rect:$0.hitbox.expanded(b.radius))}){events.append(.hit(hit.id,b.position,b.mass))}
            else if b.position.y+b.radius>=ground(clamp(b.position.x,bounds.x,bounds.maxX)) || shot.time>6 || b.position.x<bounds.x-80 || b.position.x>bounds.maxX+80 {events.append(.land(Vec(clamp(b.position.x,bounds.x,bounds.maxX),min(bounds.maxY-3,b.position.y)),b.mass))}
            else{kept.append(b)}
        };balls=kept;return events
    }
    public mutating func cancel()->[(Vec,Double)] {let mass=balls.map{($0.position,$0.mass)};self=SnowballPlay();return mass}
}
