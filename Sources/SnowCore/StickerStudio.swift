import Foundation
public enum StickerAnchorKind:String,Codable,CaseIterable {case desktop,window,tree,snowman,gift,character,decoration}
public struct StickerAsset:Codable,Equatable {
 public var id:String,title:String,categories:[String],width:Double,height:Double,pivot:Vec,animation:String
 public var repeatable:Bool
 public init(_ id:String,_ title:String,_ categories:[String],_ width:Double=256,_ height:Double=256,_ pivot:Vec=Vec(0.5,0.5),_ animation:String="none",_ repeatable:Bool=false){self.id="sticker_"+id;self.title=title;self.categories=categories;self.width=width;self.height=height;self.pivot=pivot;self.animation=animation;self.repeatable=repeatable}
 public static let all:[StickerAsset]=[
 .init("wreath","Christmas Wreath",["windows","tree"]),.init("icicles","Icicle Garland",["windows"],320,100,Vec(0.5,0.15),"shimmer",true),
 .init("ice_cluster","Ice Cluster",["windows","tree"],180,280,Vec(0.5,0.08),"shimmer"),.init("frost","Frost Corner",["windows"],256,256,Vec(0.1,0.1)),
 .init("fir_branch","Snowy Fir Branch",["windows","tree"],320,160),.init("stocking","Christmas Stocking",["windows","tree"],200,280,Vec(0.4,0.08)),
 .init("hat","Santa Hat",["characters"],280,220,Vec(0.5,0.84)),.init("scarf","Winter Scarf",["characters"],260,150,Vec(0.5,0.26)),
 .init("bow","Festive Bow",["tree","windows"]),.init("star","Golden Star",["tree","windows"],256,256,Vec(0.5,0.8),"shimmer"),
 .init("bells","Golden Bells",["tree","windows"],256,256,Vec(0.5,0.12),"sway"),.init("candy","Candy Cane",["tree","other"],180,280,Vec(0.5,0.1)),
 .init("gingerbread","Gingerbread Man",["tree","other"],220,280),.init("holly","Holly Berries",["windows","tree"],280,180),
 .init("mistletoe","Mistletoe",["windows","tree"],220,280,Vec(0.5,0.1)),.init("lights","Mini Fairy Lights",["lights","windows","tree"],320,110,Vec(0.5,0.12),"glow",true),
 .init("lantern","Christmas Lantern",["lights","other"],200,280,Vec(0.5,0.88),"glow"),.init("present","Wrapped Present",["other","tree"],256,256,Vec(0.5,0.86)),
 .init("sign","Snowy Wooden Sign",["other"],320,210,Vec(0.5,0.88)),.init("snowflake","Crystal Snowflake",["tree","windows"],256,256,Vec(0.5,0.5),"none")]
 public static func find(_ id:String)->StickerAsset? {all.first{$0.id==id}}
}
public struct StickerAnchor:Codable,Equatable {
 public var kind:StickerAnchorKind,screen:String,parent:String?,session:String?,local:Vec
 public init(kind:StickerAnchorKind = .desktop,screen:String,local:Vec,parent:String?=nil,session:String?=nil){self.kind=kind;self.screen=screen;self.local=local;self.parent=parent;self.session=session}
}
public struct StudioSticker:Codable,Equatable {
 public var id:String,assetID:String,anchor:StickerAnchor,scale:Double=1,rotation:Double=0,z:Int=0,animation:String="none",visible:Bool=true,locked:Bool=false,flipX:Bool=false,flipY:Bool=false,segments:Int=1,text:String=""
 public init(assetID:String,anchor:StickerAnchor,id:String=UUID().uuidString){self.id=id;self.assetID=assetID;self.anchor=anchor;self.animation=StickerAsset.find(assetID)?.animation ?? "none"}
 public mutating func validate(){
  scale=clamp(scale.isFinite ? scale:1,0.2,4);rotation=(rotation.isFinite ? rotation:0).truncatingRemainder(dividingBy:360);z=min(10000,max(-10000,z));segments=min(12,max(1,segments));text=String(text.filter{!$0.isNewline && !$0.isASCIIControl}.prefix(24));anchor.local=Vec(clamp(anchor.local.x.isFinite ? anchor.local.x:0.5,-2,3),clamp(anchor.local.y.isFinite ? anchor.local.y:0.5,-2,3));anchor.screen=String(anchor.screen.prefix(80));anchor.parent=anchor.parent.map{String($0.prefix(160))};anchor.session=anchor.session.map{String($0.prefix(80))}
  if !["none","shimmer","glow","sway","rotate"].contains(animation){animation="none"}
  if StickerAsset.find(assetID)?.repeatable != true{segments=1}
 }
}
private extension Character {var isASCIIControl:Bool {unicodeScalars.contains{$0.value<32 || $0.value==127}}}
public struct StickerStudioSettings:Codable,Equatable {
 public var items:[StudioSticker]=[],hidden=false,autoSnap=true,animations=true,defaultSize=64.0,quality="balanced",reduceMotion=false
 public init(){}
 public var limit:Int {quality=="low" ? 40:quality=="high" ? 180:100}
 public var animationLimit:Int {quality=="low" ? 6:quality=="high" ? 20:12}
 public mutating func validate(){
  if !["low","balanced","high"].contains(quality){quality="balanced"};defaultSize=clamp(defaultSize.isFinite ? defaultSize:64,24,150)
  var ids=Set<String>(),counts:[String:Int]=[:]
  items=Array(items.prefix(720)).compactMap{old in var item=old;guard StickerAsset.find(item.assetID) != nil,item.id.count<100,ids.insert(item.id).inserted else{return nil};item.validate();let key=item.anchor.screen;guard counts[key,default:0]<180 else{return nil};counts[key,default:0]+=1;return item}
  // Imported decorative parent graphs must be acyclic and refer to retained IDs.
  let parents=Dictionary(uniqueKeysWithValues:items.map{($0.id,$0.anchor)})
  for i in items.indices where items[i].anchor.kind == .decoration {
   var seen=Set([items[i].id]),next=items[i].anchor.parent,valid=true
   while let id=next {guard seen.insert(id).inserted,let a=parents[id] else{valid=false;break};next=a.kind == .decoration ? a.parent:nil}
   if !valid {items[i].visible=false}
  }
 }
}
public struct StickerHistory {
 public private(set) var undoStack:[StickerStudioSettings]=[],redoStack:[StickerStudioSettings]=[]
 public init(){}
 public mutating func record(_ before:StickerStudioSettings,_ after:StickerStudioSettings){guard before != after else{return};undoStack.append(before);if undoStack.count>60{undoStack.removeFirst()};redoStack=[]}
 public mutating func undo(_ current:StickerStudioSettings)->StickerStudioSettings?{guard let next=undoStack.popLast() else{return nil};redoStack.append(current);return next}
 public mutating func redo(_ current:StickerStudioSettings)->StickerStudioSettings?{guard let next=redoStack.popLast() else{return nil};undoStack.append(current);return next}
}
public enum StickerGeometry {
 public static func windowPoint(_ local:Vec,frame:Rect)->Vec{Vec(frame.x+frame.width*local.x,frame.y+frame.height*local.y)}
 public static func desktopPoint(_ local:Vec,frame:Rect,margin:Double)->Vec{Vec(clamp(frame.x+frame.width*local.x,frame.x+margin,frame.maxX-margin),clamp(frame.y+frame.height*local.y,frame.y+32+margin,frame.maxY-margin))}
 public static func visiblePieces(_ rect:Rect,blocking:[Rect])->[Rect]{
  var pieces=[rect]
  for b in blocking {var next:[Rect]=[];for r in pieces {if !r.intersects(b){next.append(r);continue};let l=max(r.x,b.x),rr=min(r.maxX,b.maxX),t=max(r.y,b.y),bb=min(r.maxY,b.maxY);if l>r.x{next.append(Rect(r.x,r.y,l-r.x,r.height))};if rr<r.maxX{next.append(Rect(rr,r.y,r.maxX-rr,r.height))};if t>r.y{next.append(Rect(l,r.y,rr-l,t-r.y))};if bb<r.maxY{next.append(Rect(l,bb,rr-l,r.maxY-bb))}};pieces=Array(next.prefix(96));if pieces.isEmpty{break}}
  return pieces
 }
}
