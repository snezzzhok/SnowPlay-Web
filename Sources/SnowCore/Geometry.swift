import Foundation
public struct Vec: Codable, Equatable {
    public var x: Double; public var y: Double
    public init(_ x: Double = 0, _ y: Double = 0) { self.x = x; self.y = y }
    public static func + (a: Vec, b: Vec) -> Vec { Vec(a.x+b.x, a.y+b.y) }
    public static func - (a: Vec, b: Vec) -> Vec { Vec(a.x-b.x, a.y-b.y) }
    public static func * (a: Vec, b: Double) -> Vec { Vec(a.x*b, a.y*b) }
    public var length: Double { hypot(x,y) }
}
public struct Rect: Codable, Equatable {
    public var x: Double; public var y: Double; public var width: Double; public var height: Double
    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) { self.x=x; self.y=y; self.width=width; self.height=height }
    public var maxX: Double { x+width }; public var maxY: Double { y+height }
    public var center: Vec { Vec(x+width/2,y+height/2) }
    public func contains(_ p: Vec) -> Bool { p.x >= x && p.x <= maxX && p.y >= y && p.y <= maxY }
    public func intersects(_ r: Rect) -> Bool { x < r.maxX && maxX > r.x && y < r.maxY && maxY > r.y }
    public func expanded(_ d: Double) -> Rect { Rect(x-d,y-d,width+2*d,height+2*d) }
}
public struct SeededRandom {
    private var state: UInt64
    public init(seed: UInt64 = 0x51A0F1A) { state = max(1,seed) }
    public mutating func unit() -> Double { state = state &* 6364136223846793005 &+ 1442695040888963407; return Double(state >> 11)/9007199254740992 }
    public mutating func range(_ a: Double, _ b: Double) -> Double { a+(b-a)*unit() }
}
public func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double { v.isFinite ? min(hi,max(lo,v)) : lo }
public enum DesktopVisibility {
    /// Subtract window rectangles without reading their contents; overlapping windows count once.
    public static func exposedFraction(in bounds:Rect,blocked:[Rect])->Double {
        guard bounds.width>0,bounds.height>0 else{return 0}
        var pieces=[bounds]
        for b in blocked {
            var next:[Rect]=[]
            for r in pieces {
                if !r.intersects(b){next.append(r);continue}
                let l=max(r.x,b.x),right=min(r.maxX,b.maxX),top=max(r.y,b.y),bottom=min(r.maxY,b.maxY)
                if l>r.x {next.append(Rect(r.x,r.y,l-r.x,r.height))}
                if right<r.maxX {next.append(Rect(right,r.y,r.maxX-right,r.height))}
                if top>r.y {next.append(Rect(l,r.y,right-l,top-r.y))}
                if bottom<r.maxY {next.append(Rect(l,bottom,right-l,r.maxY-bottom))}
            }
            pieces=next;if pieces.isEmpty{return 0}
        }
        return pieces.reduce(0){$0+$1.width*$1.height}/(bounds.width*bounds.height)
    }
}
