import Foundation
public struct Particle {
    public var position: Vec
    public var velocity: Vec
    public var size: Double
    public var alpha: Double
    public var rotation: Double
    public var spin: Double
    public var phase: Double
    public var snowVolume: Double
    public var effectID: UUID?
    public var fallsToGround=false
    public var clump=false,splitGeneration=0
    public var clumpOriginY=0.0
    public var remaining: Double // negative means reusable snowfall
    public init(position: Vec, velocity: Vec, size: Double = 1.5, alpha: Double = 0.5, rotation: Double = 0, spin: Double = 0, phase: Double = 0, remaining: Double = -1, snowVolume: Double = 12, effectID: UUID? = nil) {
        self.position=position; self.velocity=velocity; self.size=size; self.alpha=alpha; self.rotation=rotation; self.spin=spin; self.phase=phase; self.remaining=remaining; self.snowVolume=max(0,snowVolume); self.effectID=effectID
    }
}
public struct Wind {
    public private(set) var velocity = Vec()
    public init() {}
    public mutating func update(angle: Double, strength: Double, dt: Double) {
        let a=clamp(angle,-90,90)*Double.pi/180
        let target=Vec(sin(a)*clamp(strength,0,1)*65, -cos(a)*clamp(strength,0,1)*3)
        velocity=velocity+(target-velocity)*(1-exp(-max(0,dt)*2))
    }
}
public final class ParticleEngine {
    public private(set) var particles: [Particle] = []
    public private(set) var wind = Wind()
    public let surfaces: SurfaceManager
    public var bounds: Rect
    private var random: SeededRandom
    private var elapsed = 0.0
    private var dead:[Int]=[]
    private var weatherTarget:Int?
    private var taggedEffectsMayExist=false
    public private(set) var dissipatedMass=0.0
    public private(set) var escapedMass=0.0
    private var effectRoom:Int {max(0,min(SnowfallDensity.maximumParticles+SnowfallDensity.effectReserve-particles.count,SnowfallDensity.effectReserve-particles.reduce(0){$0+($1.remaining>=0 ? 1:0)}))}
    public init(bounds: Rect, surfaces: SurfaceManager, seed: UInt64 = 42) {
        self.bounds=bounds; self.surfaces=surfaces; random=SeededRandom(seed:seed); particles.reserveCapacity(SnowfallDensity.maximumParticles+SnowfallDensity.effectReserve)
    }
    private func flake(randomY: Bool) -> Particle {
        let kind=random.unit(); let size=kind < 0.65 ? random.range(1,1.6) : kind < 0.93 ? random.range(1.6,2.1) : random.range(2.1,3)
        return Particle(position:Vec(random.range(bounds.x,bounds.maxX),randomY ? random.range(bounds.y,bounds.maxY) : bounds.y-4),velocity:Vec(0,random.range(28,52)),size:size,alpha:random.range(0.5,0.85),spin:random.range(-0.2,0.2),phase:random.range(0,6.28))
    }
    public func setCount(_ count: Int) {
        let n=min(SnowfallDensity.maximumParticles,max(0,count));guard weatherTarget != n else{return};weatherTarget=n;let free=particles.reduce(0) { $0+($1.remaining < 0 ? 1:0) }
        if free < n { for _ in free..<n { particles.append(flake(randomY:true)) } }
        if free > n { var removed=0; particles.removeAll { p in if p.remaining < 0 && removed < free-n { removed+=1; return true }; return false } }
    }
    public func burst(surface: SnowSurface, count: Int, collapse: Bool, volume: Double? = nil, duration: Double = 1.1, effectID: UUID? = nil) {
        let available=effectRoom
        let emitted=min(available,max(0,count))
        if emitted>0,effectID != nil {taggedEffectsMayExist=true}
        let mass=(volume ?? surface.volume*(collapse ? 0.25 : 1))/Double(max(1,emitted))
        for _ in 0..<emitted {
            let p=surface.point(at:random.unit())
            particles.append(Particle(position:p,velocity:Vec(random.range(-28,28),random.range(collapse ? -28 : -55,-12)),size:random.range(1,2.5),alpha:0.6,phase:random.range(0,6.28),remaining:max(0.01,duration),snowVolume:mass,effectID:effectID))
        }
    }
    public func step(dt rawDT: Double, config: Configuration, timeScale: Double = 1, occluders: [Rect] = [], timeRegions: [SnowTimeRegion] = []) {
        let dt=clamp(rawDT,0,0.05); elapsed+=dt
        wind.update(angle:config.windAngle,strength:config.windStrength,dt:dt)
        let calm=config.reducedMotion || config.mode == .focus
        // A shared, slow breeze gives the field coherent waves without extra nodes.
        let gust=calm ? 0 : (sin(elapsed*0.31)*0.7+sin(elapsed*0.67)*0.3)*(4+config.windStrength*8)
        dead.removeAll(keepingCapacity:true)
        // A conservative horizontal broad phase avoids dictionary/string/heightfield work
        // for flakes still high above every possible support. Vertical surfaces opt out.
        var collisionCeiling=Double.infinity
        for s in surfaces.surfaces.values where s.visible {
            if s.axis != .horizontal {collisionCeiling = -Double.infinity;break}
            collisionCeiling=min(collisionCeiling,s.frame.y-s.collisionHeight)
        }
        for i in particles.indices {
            let old=particles[i].position
            let free=particles[i].remaining < 0
            let localScale=timeRegions.reduce(clamp(timeScale,0,1)) { min($0,$1.scale(at:old)) }
            let visualDT=dt*(particles[i].fallsToGround ? 1:localScale)
            if free {
                // Small gravitational acceleration, limited to a gentle terminal speed.
                particles[i].velocity.y=min(30+particles[i].size*12,particles[i].velocity.y+2*dt)
                let depth=0.65+particles[i].size*0.22
                particles[i].velocity.x=wind.velocity.x+(calm ? 0 : gust*depth+sin(elapsed*0.7+particles[i].phase)*4*depth)
                particles[i].position=old+Vec(particles[i].velocity.x,particles[i].velocity.y*config.snowSpeed*(config.reducedMotion ? 0.4 : 1)+wind.velocity.y)*visualDT
            } else {
                particles[i].remaining-=dt
                particles[i].velocity.y+=(particles[i].fallsToGround ? 620:180)*visualDT
                particles[i].position=old+particles[i].velocity*visualDT
            }
            particles[i].rotation+=particles[i].spin*visualDT
            let contact=particles[i].clump ? Vec(0,particles[i].size*0.42):Vec()
            if max(old.y,particles[i].position.y)+contact.y>=collisionCeiling,let (id,f)=surfaces.collision(from:old+contact,to:particles[i].position+contact,occluders:occluders,groundOnly:particles[i].fallsToGround) {
                // Compensate visual slowdown: deposition stays continuous in real time.
                let accepted:Double
                if particles[i].fallsToGround {accepted=surfaces.surfaces[id]?.depositImpact(at:f,volume:particles[i].snowVolume) ?? 0}
                else {accepted=surfaces.surfaces[id]?.deposit(at:f,volume:free ? particles[i].size*24/max(0.35,localScale) : particles[i].snowVolume) ?? 0}
                if free { if (accepted>0 || id.hasPrefix("window-")) && surfaces.surfaces[id]?.renderVisible != false {particles[i]=flake(randomY:false)} }
                else {
                    if particles[i].clump,accepted>0 {dust(at:particles[i].position+contact,count:3)}
                    particles[i].snowVolume=max(0,particles[i].snowVolume-accepted)
                    if particles[i].snowVolume<0.00001 {dead.append(i)}
                    else if id.hasPrefix("window-"),let surface=surfaces.surfaces[id] {
                        // Undeposited material bounces and drifts toward the nearest
                        // edge. Its finite mass remains in the same particle ledger.
                        particles[i].position=surface.point(at:f)+Vec(0,-surface.height(at:f)-0.15)
                        particles[i].velocity.x=(f<0.5 ? -1:1)*max(25,abs(particles[i].velocity.x))
                        particles[i].velocity.y = -min(18,abs(particles[i].velocity.y)*0.3+3)
                    }
                }
            } else if particles[i].position.y > bounds.maxY+8 || (!free && particles[i].remaining <= 0) {
                if free { particles[i]=flake(randomY:false) } else { if particles[i].position.y>bounds.maxY+8 {escapedMass+=particles[i].snowVolume} else {dissipatedMass+=particles[i].snowVolume};dead.append(i) }
            } else if free {
                if particles[i].position.x < bounds.x-5 { particles[i].position.x=bounds.maxX+4 }
                if particles[i].position.x > bounds.maxX+5 { particles[i].position.x=bounds.x-4 }
            }
            if !free,particles[i].clump,particles[i].splitGeneration==0,particles[i].snowVolume>140,particles[i].position.y-particles[i].clumpOriginY>55 {
                particles[i].splitGeneration=1
                if random.unit()<0.4,effectRoom>=2,!dead.contains(i) {
                    let parent=particles[i]
                    for side in [-1.0,1.0] {var child=parent;child.position=parent.position+Vec(side*parent.size*0.3,0);child.velocity.x+=side*7;child.snowVolume=parent.snowVolume/2;child.size=parent.size/sqrt(2);child.spin=side*0.8;particles.append(child)}
                    dead.append(i)
                }
            }
        }
        for i in dead.reversed() { particles.remove(at:i) }
    }
    @discardableResult public func emit(_ event:SnowFallEvent,effectID:UUID?=nil,limit:Int=12)->Double {
        guard event.mass>0 else{return 0}
        let available=effectRoom,n=min(max(0,limit),available,event.chunks.count)
        guard n>0 else{return 0}
        var buckets=Array(repeating:SnowChunk(Vec(),Vec(),0),count:n)
        for (i,c) in event.chunks.enumerated(){let k=min(n-1,i*n/max(1,event.chunks.count));buckets[k].fallsToGround = buckets[k].fallsToGround || c.fallsToGround;let old=buckets[k].mass,total=old+c.mass;if total>0 {buckets[k].position=(buckets[k].position*old+c.position*c.mass)/total;buckets[k].velocity=(buckets[k].velocity*old+c.velocity*c.mass)/total;buckets[k].mass=total}}
        if effectID != nil {taggedEffectsMayExist=true}
        for c in buckets where c.mass>0 {var particle=Particle(position:c.position,velocity:c.fallsToGround ? Vec(0,max(15,c.velocity.y)):c.velocity,size:clamp(sqrt(c.mass)*0.5,3,c.fallsToGround ? 14:6),alpha:0.94,spin:random.range(-0.9,0.9),remaining:7,snowVolume:c.mass,effectID:effectID);particle.fallsToGround=c.fallsToGround;particle.clump=c.fallsToGround;particle.clumpOriginY=c.position.y;particles.append(particle)}
        return event.mass
    }
    public func retainEffects(_ activeIDs: Set<UUID>) {
        guard taggedEffectsMayExist else{return}
        var survivors=false
        particles.removeAll { particle in
            guard let id=particle.effectID else{return false}
            if activeIDs.contains(id) {survivors=true;return false};return true
        };taggedEffectsMayExist=survivors
    }
    public func reset() {particles.removeAll(keepingCapacity:true);weatherTarget=nil;taggedEffectsMayExist=false}
    public func dust(at point:Vec,count:Int=10) {
        let room=effectRoom
        for _ in 0..<min(count,room) {particles.append(Particle(position:point,velocity:Vec(random.range(-45,45),random.range(-65,-25)),size:random.range(1,2),alpha:0.8,remaining:0.65,snowVolume:0))}
    }
}
