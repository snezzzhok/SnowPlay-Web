import AppKit
import SnowCore
struct CanvasSprite {
    var image: CGImage;var rect: CGRect;var transform: CGAffineTransform;var alpha: Double
}
enum HatPlacement {
    /// AX describes a Dock tile (including padding), not the opaque app-icon pixels.
    static func iconRect(in tile: Rect)->Rect {
        let side=min(tile.width,tile.height)*0.88
        return Rect(tile.center.x-side/2,tile.maxY-min(8,tile.height*0.08)-side,side,side)
    }
    static func frame(tile: Rect,anchor: Vec)->Rect {
        let icon=iconRect(in:tile),width=icon.width*1.08,height=width*220/256
        let brim=Vec(icon.center.x,icon.y+icon.height*0.22)
        return Rect(brim.x-width*anchor.x,brim.y-height*anchor.y,width,height)
    }
}
enum SnowCapGeometry {
    static func paths(surface s: SnowSurface,blocked: [Rect],progress: Double=1,local: (Vec)->CGPoint)->[CGPath] {
        var result:[CGPath]=[],run:[Int]=[]
        let n=s.heights.count
        func top(_ index: Int,_ fraction: Double?=nil,_ height: Double?=nil)->Vec {
            let p=s.point(at:fraction ?? Double(index)/Double(n-1)),h=(height ?? s.heights[index])*progress
            switch s.axis {case .horizontal:return Vec(p.x,p.y-h);case .verticalLeft:return Vec(p.x+h,p.y);case .verticalRight:return Vec(p.x-h,p.y)}
        }
        func finish() {
            guard run.count>=2 else {run=[];return}
            let path=CGMutablePath(),first=run[0],last=run.last!
            path.move(to:local(s.point(at:Double(first)/Double(n-1))));path.addLine(to:local(top(first)))
            for (a,b) in zip(run,run.dropFirst()) {
                let f1=Double(a)/Double(n-1),f2=Double(b)/Double(n-1)
                path.addCurve(to:local(top(b)),control1:local(top(a,f1+(f2-f1)/3,s.heights[a])),control2:local(top(b,f2-(f2-f1)/3,s.heights[b])))
            }
            path.addLine(to:local(s.point(at:Double(last)/Double(n-1))));path.closeSubpath();result.append(path);run=[]
        }
        for i in 0..<n-1 {
            let a=s.point(at:Double(i)/Double(n-1)),b=s.point(at:Double(i+1)/Double(n-1)),h=max(s.heights[i],s.heights[i+1])*progress
            let region=s.axis == .horizontal ? Rect(a.x,a.y-h,max(1,b.x-a.x),h+1):Rect(a.x-10,a.y,20,max(1,b.y-a.y))
            if h>0.03 && !blocked.contains(where: { $0.intersects(region) }) {
                if run.isEmpty {run.append(i)};run.append(i+1)
            } else {finish()}
        };finish();return result
    }
}
