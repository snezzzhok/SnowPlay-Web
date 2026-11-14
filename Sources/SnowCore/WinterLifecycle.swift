import Foundation
public enum WinterMotion {
    /// Finite, uniform-scale entrance. No lingering action after it settles.
    public static func appearance(elapsed: Double)->(opacity: Double,scale: Double) {
        let t=clamp(elapsed/0.7,0,1)
        let fade=clamp(t/0.45,0,1)
        return (fade,1-0.18*exp(-6*t)*cos(t*Double.pi*2.5)*(1-t))
    }
    public static func landingLift(elapsed: Double)->Double {
        let t=clamp(elapsed/0.65,0,1)
        return sin(t*Double.pi*2)*exp(-3*t)*(1-t)*3
    }
}
public enum GiftLifecycle {
    public static let boxLifetime=3.0, celebrationLifetime=12.0, unopenedLifetime=90.0
    public static func boxOpacity(elapsed: Double)->Double { 1-clamp((elapsed-1.8)/1.2,0,1) }
    public static func celebrationOpacity(elapsed: Double)->Double { 1-clamp((elapsed-10)/2,0,1) }
}
public enum PlacementPlanner {
    public static func candidates(in bounds: Rect,occupied: [Rect],size: Double)->[Vec] {
        var result:[Vec]=[]
        for y in stride(from:bounds.maxY-100,through:bounds.y+100,by:-90) {
            for x in stride(from:bounds.x+70,through:bounds.maxX-70,by:90) {
                let box=Rect(x-size/2,y-size/2,size,size)
                if !occupied.contains(where: { $0.intersects(box) }) {result.append(Vec(x,y))}
            }
        };return result
    }
    public static func choose(from candidates: [Vec],bounds: Rect,recent: [Vec])->Vec? {
        guard !candidates.isEmpty else {return nil}
        if recent.isEmpty { let aim=Vec(bounds.center.x,bounds.center.y+80);return candidates.min { ($0-aim).length<($1-aim).length } }
        let last=recent.last!
        let separated=candidates.filter { ($0-last).length>80 }
        let different=candidates.filter { $0 != last }
        let usable = !separated.isEmpty ? separated : !different.isEmpty ? different:candidates
        return usable.max { a,b in
            recent.map { (a-$0).length }.min()! < recent.map { (b-$0).length }.min()!
        }
    }
}

public extension WinterMotion {
    static func flightProgress(_ t:Double)->Double {let f=clamp(t,0,1);return f*f*(3-2*f)}
    static func flightTime(fraction:Double)->Double {var lo=0.0,hi=1.0;for _ in 0..<20 {let m=(lo+hi)/2;if flightProgress(m)<fraction {lo=m}else {hi=m}};return (lo+hi)*3.5}
}
