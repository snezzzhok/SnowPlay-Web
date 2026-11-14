import Foundation
public enum SurfaceAxis: String { case horizontal, verticalLeft, verticalRight }
public struct SnowSurface {
    public let id: String
    public let instanceID=UUID()
    public var screenID: String
    public var frame: Rect
    public var axis: SurfaceAxis
    public var visible = true
    public var renderVisible = true
    public var velocity = Vec()
    public var lastUpdate = 0.0
    private var filteredVelocity=Vec()
    private var lastShed = -1.0
    public private(set) var impactMounds:[Vec]=[]
    public var collisionHeight:Double {maxHeight+(id.hasPrefix("ground-") ? 16:0)}
    public var sweepFraction: Double?
    public var sweepReversed=false
    public var maxHeight: Double
    public private(set) var moundCenters: [Double]=[]
    public private(set) var heights: [Double]
    public private(set) var revision:UInt64=0
    public init(id: String, screenID: String, frame: Rect, maxHeight: Double = 5, axis: SurfaceAxis = .horizontal) {
        self.id=id; self.screenID=screenID; self.frame=frame; self.maxHeight=maxHeight; self.axis=axis
        heights=Array(repeating:0,count:Self.count(axis == .horizontal ? frame.width : frame.height));cacheCapacities()
    }
    private var capacities:[Double]=[]
    private var capacityLength=0.0,capacityMaximum=0.0
    private mutating func cacheCapacities(){capacities=[];capacityLength=length;capacityMaximum=maxHeight;capacities=heights.indices.map{computeCapacity(at:$0)}}
    private static func count(_ length: Double) -> Int { min(256,max(2,Int(max(0,length)/12)+1)) }
    public var length: Double { axis == .horizontal ? frame.width : frame.height }
    public var volume: Double { heights.reduce(0,+)*length/Double(heights.count) }
    public func capacity(at index:Int)->Double {if capacities.count==heights.count && capacityLength==length && capacityMaximum==maxHeight{return capacities[index]};return computeCapacity(at:index)}
    private func computeCapacity(at index: Int)->Double {
        if id.hasPrefix("duel-"){return maxHeight}
        let f=Double(index)/Double(heights.count-1),x=f*length
        let edge=sin(min(1,min(f,1-f)*length/12)*Double.pi/2)
        let shape: Double
        if !moundCenters.isEmpty {
            let radius=clamp(length/Double(moundCenters.count)*0.65,16,65)
            shape=moundCenters.map { center -> Double in
                let d=abs(x-center*length)/radius
                return d<1 ? pow(cos(d * .pi/2),2):0
            }.max() ?? 0
        } else { shape=0.35+0.65*pow((sin(x/24+Double(id.utf8.reduce(0) { ($0+Int($1))%31 }))+1)/2,1.3) }
        let bump=impactMounds.map { point in point.y*exp(-pow((f-point.x)*length/32,2)) }.max() ?? 0
        return maxHeight*edge*(0.05+0.95*shape)+bump*edge
    }
    public mutating func setMounds(_ centers: [Double]) {
        let next=centers.filter { $0>=0 && $0<=1 }.sorted()
        guard next != moundCenters else {return};moundCenters=next;cacheCapacities()
        heights=heights.enumerated().map { min($0.element,capacity(at:$0.offset)) }
    }
    public func canReceive(at fraction: Double)->Bool {
        let i=min(heights.count-1,max(0,Int(clamp(fraction,0,1)*Double(heights.count-1))))
        return heights[i]<capacity(at:i)-0.01
    }
    @discardableResult public mutating func deposit(at fraction: Double, volume amount: Double)->Double {
        guard maxHeight > 0, length > 0 else { return 0 }
        if let sweep=sweepFraction, sweepReversed ? fraction>=1-sweep : fraction<=sweep {return 0}
        let before=volume
        let i=min(heights.count-1,max(0,Int(clamp(fraction,0,1)*Double(heights.count-1))))
        heights[i]=min(capacity(at:i),heights[i]+max(0,amount)*Double(heights.count)/length)

        // Local relaxation prevents needle-shaped piles while conserving volume.
        for j in max(0,i-1)...min(heights.count-2,i) {
            let proposed=(heights[j]-heights[j+1])*0.16
            let transfer=proposed>=0 ? min(proposed,max(0,capacity(at:j+1)-heights[j+1])) : -min(-proposed,max(0,capacity(at:j)-heights[j]))
            heights[j]-=transfer;heights[j+1]+=transfer
        }

        let accepted=max(0,volume-before);if accepted>0 {revision &+= 1};return accepted
    }
    @discardableResult public mutating func depositImpact(at fraction:Double,volume amount:Double)->Double {
        let f=clamp(fraction,0.02,0.98)
        if id.hasPrefix("ground-") {
            if let i=impactMounds.indices.min(by:{abs(impactMounds[$0].x-f)<abs(impactMounds[$1].x-f)}),abs(impactMounds[i].x-f)*length<40 {impactMounds[i].y=min(16,impactMounds[i].y+sqrt(amount)*0.35)}
            else {if impactMounds.count>=24 {impactMounds.removeFirst()};impactMounds.append(Vec(f,min(16,max(5,sqrt(amount)*0.6))))}
            cacheCapacities()
        }
        var remaining=amount
        for offset in [0.0,-0.012,0.012,-0.024,0.024,-0.036,0.036] {remaining-=deposit(at:clamp(f+offset,0,1),volume:remaining)}
        return amount-remaining
    }
    @discardableResult public mutating func add(volume amount: Double)->Double {
        let before=volume
        for i in heights.indices {deposit(at:Double(i)/Double(heights.count-1),volume:max(0,amount)/Double(heights.count))}
        return max(0,volume-before)
    }
    @discardableResult public mutating func resize(to newFrame: Rect, dt: Double) -> Double {
        revision &+= 1
        let oldVolume=volume; let oldFrame=frame; let old=heights
        frame=newFrame; velocity=Vec(newFrame.x-oldFrame.x,newFrame.y-oldFrame.y)*(1/max(0.001,dt))
        heights=(0..<Self.count(length)).map { i in
            let f=Double(i)/Double(max(1,Self.count(length)-1))*Double(old.count-1)
            let a=min(old.count-1,Int(f)), b=min(old.count-1,a+1)
            return old[a]+(old[b]-old[a])*(f-Double(a))
        }
        cacheCapacities()
        let rawVolume=volume
        let retained=min(oldVolume,rawVolume)
        if rawVolume > 0 { let factor=retained/rawVolume; heights=heights.enumerated().map { min(capacity(at:$0.offset),$0.element*factor) } }
        return max(0,oldVolume-volume)
    }
    @discardableResult public mutating func remove(fraction: Double) -> Double {
        revision &+= 1
        let before=volume; let f=clamp(fraction,0,1); heights=heights.map { $0*(1-f) }; return before-volume
    }
    @discardableResult public mutating func extract(volume requested: Double, at fraction: Double) -> Double {
        revision &+= 1
        guard length>0, requested>0 else { return 0 }
        let cell=length/Double(heights.count)
        let center=min(heights.count-1,max(0,Int(clamp(fraction,0,1)*Double(heights.count-1))))
        var needed=requested
        // Remove nearest snow first; no invisible replacement mass is created.
        for i in heights.indices.sorted(by: { abs($0-center)<abs($1-center) }) {
            let amount=min(needed,heights[i]*cell)
            heights[i]-=amount/cell; needed-=amount
            if needed<=0.00001 { break }
        }
        return requested-needed
    }
    /// Local cursor brush; only nearby samples lose real stored mass.
    @discardableResult public mutating func brush(at fraction: Double, radius: Double, strength: Double) -> Double {
        revision &+= 1
        let before=volume, center=clamp(fraction,0,1)*length
        for i in heights.indices {
            let distance=abs(Double(i)/Double(heights.count-1)*length-center)
            if distance<radius { heights[i]*=1-clamp(strength,0,1)*(1-distance/max(1,radius)) }
        }
        return before-volume
    }
    /// A groove pushes material into its shoulders. Only the fast spray leaves
    /// the heightfield, and that exact mass is returned to the particle ledger.
    public mutating func displace(at fraction:Double,radius:Double,distance:Double,speed:Double)->SnowFallEvent {
        guard length>0,volume>0 else{return SnowFallEvent()}
        let before=heights,cell=length/Double(heights.count),centre=clamp(fraction,0,1)*length
        var removed=0.0
        for i in heights.indices {
            let x=Double(i)/Double(heights.count-1)*length,d=abs(x-centre)
            if d<radius {let amount=heights[i]*clamp(abs(distance)/30,0,0.8)*pow(1-d/radius,1.5);heights[i]-=amount;removed+=amount*cell}
        }
        let spray=removed*(speed>220 ? clamp((speed-220)/1800,0,0.22):0)
        if id.hasPrefix("ground-"),removed>0 {
            for side in [-1.0,1.0] {
                let shoulder=clamp(fraction+side*radius/length,0.01,0.99)
                if let i=impactMounds.indices.min(by:{abs(impactMounds[$0].x-shoulder)<abs(impactMounds[$1].x-shoulder)}),abs(impactMounds[i].x-shoulder)*length<20 {impactMounds[i].y=min(16,impactMounds[i].y+0.5)}
                else if impactMounds.count<32 {impactMounds.append(Vec(shoulder,3))}
            };cacheCapacities()
        }
        var toPlace=removed-spray
        let shoulders=heights.indices.sorted {a,b in abs(abs(Double(a)*cell-centre)-radius)<abs(abs(Double(b)*cell-centre)-radius)}
        for i in shoulders {
            let accepted=min(toPlace,max(0,capacity(at:i)-heights[i])*cell)
            heights[i]+=accepted/cell;toPlace-=accepted;if toPlace<0.000001 {break}
        }
        // If both shoulders are full, retain the material in its original cells.
        if toPlace>0 {for i in heights.indices {let room=max(0,before[i]-heights[i])*cell,taken=min(toPlace,room);heights[i]+=taken/cell;toPlace-=taken;if toPlace<0.000001 {break}}}
        revision &+= 1
        guard spray>0 else{return SnowFallEvent()}
        return SnowFallEvent([SnowChunk(point(at:fraction)+Vec(0,-height(at:fraction)),Vec(clamp(distance*6,-80,80),-45-min(65,speed/20)),spray)])
    }
    @discardableResult public mutating func clearThrough(_ fraction: Double)->Double {
        revision &+= 1
        guard fraction>0 else { return 0 };let before=volume
        for i in heights.indices {
            let f=Double(i)/Double(heights.count-1)
            if sweepReversed ? f>=1-fraction : f<=fraction { heights[i]=0 }
        };return max(0,before-volume)
    }
    public mutating func clear() { heights=heights.map { _ in 0 };impactMounds=[];cacheCapacities();revision &+= 1 }
    public mutating func seedArena(height:Double) {
        guard id.hasPrefix("duel-") else{return}
        heights=heights.map{_ in clamp(height,0,maxHeight)};revision &+= 1
    }
    public mutating func setMaximum(_ maximum: Double) { maxHeight=clamp(maximum,0,70);cacheCapacities(); heights=heights.enumerated().map { min($0.element,capacity(at:$0.offset)) } }
    public func height(at fraction:Double)->Double {
        let x=clamp(fraction,0,1)*Double(heights.count-1),a=Int(x),b=min(heights.count-1,a+1)
        return heights[a]+(heights[b]-heights[a])*(x-Double(a))
    }
    public mutating func relax(dt:Double) {
        guard volume>0 else{return};let cell=length/Double(heights.count)
        for i in 0..<heights.count-1 {
            let difference=heights[i]-heights[i+1],excess=max(0,abs(difference)-cell*0.35)
            let from=difference>0 ? i:i+1,to=difference>0 ? i+1:i
            let transfer=min(heights[from],max(0,capacity(at:to)-heights[to]),excess*min(0.4,dt*5))
            heights[from]-=transfer;heights[to]+=transfer;if transfer>0.000001 {revision &+= 1}
        }
    }
    /// Remap resizing cells by world-space overlap; emit every unit that lost its support.
    public mutating func updateWindow(to next:Rect,dt:Double,now:Double)->SnowFallEvent {
        revision &+= 1
        let old=self,delta=Vec(next.x-frame.x,next.y-frame.y),h=max(0.016,dt)
        var chunks:[SnowChunk]=[]
        if abs(next.width-frame.width)>0.5 {
            let oldCell=length/Double(heights.count)
            frame=next;heights=Array(repeating:0,count:Self.count(next.width));cacheCapacities()
            let cell=length/Double(heights.count)
            for i in old.heights.indices {
                let left=old.frame.x+Double(i)*oldCell,right=left+oldCell,mass=old.heights[i]*oldCell
                var accepted=0.0
                for j in heights.indices {
                    let x=frame.x+Double(j)*cell,overlap=max(0,min(right,x+cell)-max(left,x))
                    let offered=old.heights[i]*overlap,taken=min(offered,max(0,capacity(at:j)-heights[j])*cell)
                    heights[j]+=taken/cell;accepted+=taken
                }
                if mass-accepted>0.00001 {chunks.append(SnowChunk(Vec((left+right)/2,old.frame.y-old.heights[i]),Vec(0,20),mass-accepted,fallsToGround:true))}
            }
        } else {
            frame=next
            let raw=delta/h,v=filteredVelocity+(raw-filteredVelocity)*(1-exp(-h*10)),acc=(v-filteredVelocity)/h
            filteredVelocity=v;velocity=v
            if now-lastShed>0.085,raw.length>30,delta.length>1,delta.length<650 {
                lastShed=now
                let share=clamp(0.07+raw.length/2200+acc.length/100000,0.07,0.26)
                let cell=length/Double(heights.count)
                for i in heights.indices {
                    let m=heights[i]*cell*share;heights[i]*=1-share
                    if m>0 {chunks.append(SnowChunk(Vec(old.frame.x+(Double(i)+0.5)*cell,old.frame.y-old.heights[i]-2),Vec(0,20),m,fallsToGround:true))}
                }
            }
        }
        return SnowFallEvent(chunks)
    }
    public func point(at f: Double) -> Vec {
        switch axis {
        case .horizontal: return Vec(frame.x+frame.width*f,frame.y)
        case .verticalLeft: return Vec(frame.maxX,frame.y+frame.height*f)
        case .verticalRight: return Vec(frame.x,frame.y+frame.height*f)
        }
    }
}
public final class SurfaceManager {
    public var surfaces: [String: SnowSurface] = [:]
    private var windowOrder: [String:Int] = [:]
    /// IDs must match the front-to-back order of the rectangles supplied to collision.
    public func setWindowOrder(_ ids: [String]) {
        windowOrder=ids.enumerated().reduce(into:[:]) { $0[$1.element]=$1.offset }
    }
    public init() {}
    public func clear() { for key in Array(surfaces.keys) { surfaces[key]?.clear() } }
    public func collision(from a: Vec, to b: Vec, occluders: [Rect], groundOnly:Bool=false) -> (String,Double)? {
        var candidate: (String,Double,Double)?
        for (id,s) in surfaces where s.visible && (!groundOnly || id.hasPrefix("ground-")) {
            let f: Double; let t: Double
            switch s.axis {
            case .horizontal:
                guard b.y>a.y,a.y<=s.frame.y,b.y>=s.frame.y-s.collisionHeight,max(a.x,b.x)>=s.frame.x,min(a.x,b.x)<=s.frame.maxX else {continue}
                var hit=(s.frame.y-a.y)/(b.y-a.y)
                for _ in 0..<2 {let x=a.x+(b.x-a.x)*clamp(hit,0,1);let height=s.height(at:(x-s.frame.x)/max(1,s.frame.width));hit=(s.frame.y-height-a.y)/(b.y-a.y)}
                guard hit>=0 && hit<=1 else {continue};t=hit;f=(a.x+(b.x-a.x)*t-s.frame.x)/max(1,s.frame.width)
            case .verticalLeft, .verticalRight:
                let edge=s.axis == .verticalLeft ? s.frame.maxX : s.frame.x
                guard abs(b.x-a.x)>0.001, (a.x-edge)*(b.x-edge)<=0 else { continue }
                t=(edge-a.x)/(b.x-a.x); f=(a.y+(b.y-a.y)*t-s.frame.y)/max(1,s.frame.height)
            }
            // A saturated window remains a solid support. Dock/ground overflow can
            // leave their narrow decorative bank; it must not fall through a window.
            guard f >= 0, f <= 1,s.canReceive(at:f) || (id.hasPrefix("window-") && s.maxHeight>0) || (groundOnly && id.hasPrefix("ground-")) else { continue }
            let p=s.point(at:f)
            let blockers=(id == "dock" || id.hasPrefix("sculpt-") || id.hasPrefix("ground-") ? [] : occluders).prefix(windowOrder[id] ?? occluders.count)
            guard !blockers.contains(where: { $0.contains(Vec(p.x,p.y-1)) }) else { continue }
            if candidate == nil || t < candidate!.2 { candidate=(id,f,t) }
        }
        return candidate.map { ($0.0,$0.1) }
    }
}

public enum PlowSweep {
    public static func position(progress: Double, display: Rect, dock: Rect, axis: SurfaceAxis) -> Vec {
        let f=clamp(progress,0,1),p=f*f*(3-2*f)
        switch axis {
        case .horizontal: return Vec(display.x-45+(display.width+90)*p,dock.y-23)
        case .verticalLeft: return Vec(dock.maxX+23,display.y-45+(display.height+90)*p)
        case .verticalRight: return Vec(dock.x-23,display.maxY+45-(display.height+90)*p)
        }
    }
    /// A point in the bucket's snow-contact area follows the same global path as its model.
    public static func fraction(progress: Double, display: Rect, dock: Rect, axis: SurfaceAxis) -> Double {
        let body=position(progress:progress,display:display,dock:dock,axis:axis)
        switch axis {
        case .horizontal: return clamp((body.x+30-dock.x)/max(1,dock.width),0,1)
        case .verticalLeft: return clamp((body.y+30-dock.y)/max(1,dock.height),0,1)
        case .verticalRight: return clamp((dock.maxY-(body.y-30))/max(1,dock.height),0,1)
        }
    }
}
