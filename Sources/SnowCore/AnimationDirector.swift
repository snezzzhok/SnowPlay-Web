import Foundation

public enum EffectKind: String { case burst, collapse, plow, santa, fireworks, melt, character }

/// A visual-only clock field in global logical display coordinates.
/// Outside the feathered border the rest of the desktop keeps normal speed.
public struct SnowTimeRegion {
    public let bounds: Rect
    public let multiplier: Double
    public let feather: Double
    public init(bounds: Rect, multiplier: Double, feather: Double = 48) {
        self.bounds=bounds; self.multiplier=clamp(multiplier,0.35,1); self.feather=max(0,feather)
    }
    public func scale(at point: Vec) -> Double {
        let dx=max(bounds.x-point.x,point.x-bounds.maxX,0)
        let dy=max(bounds.y-point.y,point.y-bounds.maxY,0)
        let distance=hypot(dx,dy)
        if distance == 0 { return multiplier }
        guard feather>0, distance<feather else { return 1 }
        let f=distance/feather, smooth=f*f*(3-2*f)
        return multiplier+(1-multiplier)*smooth
    }
}

public struct Effect {
    public let id: UUID
    public let kind: EffectKind
    public let priority: Int
    public let duration: Double
    public let particleBudget: Int
    public let region: Rect?
    public let sourceID: String?
    public var elapsed: Double = 0
    public var timeMultiplier: Double = 1
    public var snowMultiplier: Double {
        guard region != nil else { return 1 }
        let attack=min(0.3,duration*0.1), recoveryStart=duration*0.5, recoveryEnd=duration*0.9
        if elapsed<attack {
            let f=clamp(elapsed/attack,0,1)
            return 1-0.65*f*f*(3-2*f)
        }
        if elapsed<recoveryStart { return 0.35 }
        let f=clamp((elapsed-recoveryStart)/(recoveryEnd-recoveryStart),0,1)
        return 0.35+0.65*f*f*(3-2*f)
    }
}

public final class AnimationDirector {
    public private(set) var active: [Effect] = []
    public var focus = false
    public var reducedMotion = false
    public var maxConcurrent = 3
    public var maxParticles = 80
    private var callbacks: [UUID: [(Bool)->Void]] = [:]
    public init() {}
    @discardableResult public func start(_ kind: EffectKind, duration: Double, priority: Int = 0, particles: Int = 0, region: Rect? = nil, sourceID: String? = nil, completion: ((Bool)->Void)? = nil) -> UUID? {
        if focus && kind != .melt { completion?(false); return nil }
        if reducedMotion && [.burst,.collapse,.fireworks,.santa,.character].contains(kind) { completion?(false); return nil }
        // Rapid overlapping close/minimize events share a clock and a particle budget.
        // Distant windows get independent bounded regions, never one screen-wide union.
        if let region, [.burst,.collapse].contains(kind), let existing=active.first(where: {
            [.burst,.collapse].contains($0.kind) && $0.elapsed<0.5 && ($0.region?.intersects(region) ?? false)
        }) {
            if let completion { callbacks[existing.id,default:[]].append(completion) }
            return existing.id
        }
        var victim: UUID?
        if active.count>=maxConcurrent {
            guard let lowest=active.min(by: { $0.priority<$1.priority }), lowest.priority<priority else { completion?(false); return nil }
            victim=lowest.id
        }
        let requested=max(0,particles)
        guard active.filter({ $0.id != victim }).reduce(0,{$0+$1.particleBudget})+requested<=maxParticles else { completion?(false); return nil }
        if let victim { cancel(victim) }
        let seconds=region == nil ? max(0.01,duration) : clamp(duration,3,5)
        let id=UUID()
        active.append(Effect(id:id,kind:kind,priority:priority,duration:seconds,particleBudget:requested,region:region,sourceID:sourceID))
        if let completion { callbacks[id]=[completion] }
        return id
    }
    public func setTimeMultiplier(_ id: UUID, to value: Double) {
        if let i=active.firstIndex(where: { $0.id == id }) { active[i].timeMultiplier=clamp(value,0,4) }
    }
    public func cancel(_ id: UUID) { finish(id,completed:false) }
    public func stop(_ id: UUID) { finish(id,completed:true) }
    private func finish(_ id: UUID, completed: Bool) {
        active.removeAll { $0.id == id }
        let completions=callbacks.removeValue(forKey:id) ?? []
        for callback in completions { callback(completed) }
    }
    public func cancelAll() { for id in active.map(\.id) { cancel(id) } }
    public func tick(_ dt: Double) {
        for i in active.indices { active[i].elapsed+=max(0,dt)*max(0,active[i].timeMultiplier) }
        for id in active.filter({ $0.elapsed >= $0.duration }).map(\.id) { stop(id) }
    }
    public var snowTimeRegions: [SnowTimeRegion] {
        active.compactMap { effect in
            guard let region=effect.region else { return nil }
            return SnowTimeRegion(bounds:region,multiplier:effect.snowMultiplier)
        }
    }
}
