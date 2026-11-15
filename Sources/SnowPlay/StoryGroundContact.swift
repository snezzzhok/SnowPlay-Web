import AppKit
import SpriteKit
/// Painted outlines are prepared offline. No per-frame bitmap readback or image conversion.
enum StoryGroundContact {
 static let outlines:[String:[CGPoint]] = {
  let url=Resources.root.appendingPathComponent("SnowPlayAssets/Prepared/opaque-hulls.json")
  guard let data=try? Data(contentsOf:url),let rows=try? JSONDecoder().decode([String:[[Double]]].self,from:data) else{return [:]}
  return rows.mapValues{$0.compactMap{$0.count==2 ? CGPoint(x:$0[0],y:$0[1]):nil}}
 }()
 static func lift(_ actor:LivingActor)->Double {
  var bottom=0.0;let angle=Double(actor.node.zRotation),sx=Double(actor.node.xScale),sy=Double(actor.node.yScale),sinA=sin(angle),cosA=cos(angle)
  func visit(_ node:SKNode){guard !node.isHidden,node.alpha>0.05 else{return}
   if let sprite=node as? SKSpriteNode,let id=sprite.userData?["assetID"] as? String {
    let points=outlines[id] ?? [CGPoint(x:0,y:0),CGPoint(x:1,y:0),CGPoint(x:0,y:1),CGPoint(x:1,y:1)]
    let origin=sprite.convert(.zero,to:actor.node),dx=sprite.convert(CGPoint(x:1,y:0),to:actor.node),dy=sprite.convert(CGPoint(x:0,y:1),to:actor.node)
    for p in points {let x=(p.x-sprite.anchorPoint.x)*sprite.size.width,y=(p.y-sprite.anchorPoint.y)*sprite.size.height,qx=origin.x+(dx.x-origin.x)*x+(dy.x-origin.x)*y,qy=origin.y+(dx.y-origin.y)*x+(dy.y-origin.y)*y;bottom=min(bottom,sinA*Double(qx)*sx+cosA*Double(qy)*sy)}
   };for child in node.children{visit(child)}
  };for n in actor.node.children{visit(n)};return max(0,-bottom)
 }
}
