import AppKit
import SpriteKit
import SnowCore

final class StickerRaster:NSObject {let image:CGImage;init(_ image:CGImage){self.image=image}}
struct StickerDrawing {
 let id:String,image:CGImage,transform:CGAffineTransform,rect:CGRect,clips:[CGRect],alpha:Double,bounds:Rect,window:Bool
 func draw(_ c:CGContext){c.saveGState();if !clips.isEmpty {c.addRects(clips);c.clip()};c.concatenate(transform);c.setAlpha(alpha);c.draw(image,in:rect);c.restoreGState()}
}
struct StickerResolved {
 var point:Vec,angle:Double=0,height:Double=64,window:TrackedWindow?=nil,valid:Bool=true
}
final class StickerStudio {
 weak var owner:WinterCoordinator?
 let session=UUID().uuidString
 var selected:String?,placing:String?,reattaching:String?,editing=false,history=StickerHistory()
 var panels:[InputPanel]=[]
 var candidate:StudioSticker?,drawings:[String:StickerDrawing]=[:]
 var lastSettings:StickerStudioSettings?
 var lastGeometry:Int?
 var drawRevision=0,renderPasses=0,lastSignature:Int?,lastAnimation=0.0
 var dragBefore:StickerStudioSettings?,dragID:String?,dragOffset=Vec()
 var pendingImport:StickerStudioSettings?,importStarted=0.0
 private var oldWindowFrames:[String:Rect]=[:],windowImpulses:[String:(Double,Double)]=[:]
 private var hiddenAccessories:[ObjectIdentifier:(SKNode,Bool)]=[:]
 private var windowInstances:[String:String]=[:],signImages=NSCache<NSString,StickerRaster>()
 var status="",lastMouse=Vec()
 init(_ owner:WinterCoordinator){self.owner=owner;signImages.totalCostLimit=8*1024*1024;signImages.countLimit=24}
 var settings:StickerStudioSettings {owner?.config.stickers ?? StickerStudioSettings()}
 func commit(_ before:StickerStudioSettings){guard let w=owner else{return};w.config.stickers.validate();history.record(before,w.config.stickers);drawRevision+=1;w.persist();w.statusChanged?()}
 func mutate(_ body:(inout StickerStudioSettings)->Void){guard let w=owner else{return};let old=w.config.stickers;body(&w.config.stickers);commit(old)}
 func finish(cancelDrag:Bool=false){
  if cancelDrag,let before=dragBefore {owner?.config.stickers=before}
  panels.forEach{$0.close()};panels=[];editing=false;placing=nil;reattaching=nil;candidate=nil;dragBefore=nil;dragID=nil;NSCursor.arrow.set();drawRevision+=1
  if owner?.input.mode == .decorations {owner?.input.stop()};owner?.persist()
 }
 @discardableResult func begin(_ asset:String?=nil)->Bool {
  guard let w=owner,!w.paused,!w.sleeping,!w.sessionInactive,w.config.mode != .focus,!w.observer.fullscreen,!w.decorations.livingBusy else{status="Finish the current activity and resume effects first.";return false}
  guard asset==nil || StickerAsset.find(asset!) != nil else{return false}
  finish();w.beginEditor(.decorations);guard w.input.mode == .decorations else{return false}
  editing=true;placing=asset;status=asset==nil ? "Edit mode · Esc to finish":"Click to place · Esc to cancel";w.config.stickers.hidden=false
  for d in w.displays {
   var frame=d.screen.frame;frame.size.height-=max(32,d.screen.frame.maxY-d.screen.visibleFrame.maxY)
   let panel=InputPanel(contentRect:frame,styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
   panel.placement=true;panel.isOpaque=false;panel.backgroundColor = .clear;panel.hasShadow=false;panel.isReleasedWhenClosed=false;panel.hidesOnDeactivate=false;panel.level = .floating;panel.acceptsMouseMovedEvents=true;panel.collectionBehavior=[.canJoinAllSpaces,.stationary,.ignoresCycle]
   let view=StickerEditorView(frame:NSRect(origin:.zero,size:frame.size));view.studio=self;view.display=d;panel.contentView=view;panel.orderFrontRegardless();panel.makeFirstResponder(view);panel.makeKey();panels.append(panel)
  };drawRevision+=1;w.statusChanged?();return true
 }
 func apply(_ op:String,_ body:[String:Any]=[:])->Bool {
  switch op {
  case "add":return begin(body["assetID"] as? String ?? "sticker_wreath")
  case "edit":return begin()
  case "reattach":guard let item=settings.items.first(where:{$0.id==selected && !$0.locked}),begin(item.assetID) else{return false};reattaching=item.id;return true
  case "done":finish()
  case "hide":mutate{$0.hidden.toggle()};finish()
  case "clear":mutate{$0.items=[]};selected=nil;finish()
  case "select":selected=body["id"] as? String;drawRevision+=1
  case "undo":if let next=history.undo(settings){owner?.config.stickers=next;drawRevision+=1;owner?.persist()}
  case "redo":if let next=history.redo(settings){owner?.config.stickers=next;drawRevision+=1;owner?.persist()}
  case "duplicate":
   guard let item=settings.items.first(where:{$0.id==selected}) else{return false};var copy=item;copy.id=UUID().uuidString;copy.anchor.local.x+=copy.anchor.kind == .desktop ? 0.015:0.08;copy.z+=1;copy.locked=false
   guard settings.items.filter({$0.anchor.screen==copy.anchor.screen}).count<settings.limit else{status="Decoration limit reached. Choose High quality or remove an item.";return false};mutate{$0.items.append(copy)};selected=copy.id
  case "delete":
   guard let id=selected,settings.items.first(where:{$0.id==id})?.locked != true else{return false}
   mutate{value in var removed=Set([id]);for _ in 0..<value.items.count {for item in value.items where item.anchor.kind == .decoration && removed.contains(item.anchor.parent ?? ""){removed.insert(item.id)}};value.items.removeAll{removed.contains($0.id)}};selected=nil
  case "transform":
   guard let id=selected else{return false};mutate{value in guard let i=value.items.firstIndex(where:{$0.id==id}) else{return};if let lock=body["locked"] as? Bool{value.items[i].locked=lock};guard !value.items[i].locked else{return};if let v=body["scale"] as? Double{value.items[i].scale=v};if let v=body["rotation"] as? Double{value.items[i].rotation=v};if let v=body["flipX"] as? Bool{value.items[i].flipX=v};if let v=body["flipY"] as? Bool{value.items[i].flipY=v};if let v=body["animation"] as? String{value.items[i].animation=v};if let v=body["segments"] as? Int{value.items[i].segments=v};if let v=body["text"] as? String{value.items[i].text=v};if let v=body["visible"] as? Bool{value.items[i].visible=v};if let v=body["z"] as? Int{value.items[i].z=v}}
  case "settings":mutate{value in if let v=body["defaultSize"] as? Double{value.defaultSize=v};if let v=body["autoSnap"] as? Bool{value.autoSnap=v};if let v=body["animations"] as? Bool{value.animations=v};if let v=body["reduceMotion"] as? Bool{value.reduceMotion=v};if let v=body["quality"] as? String{value.quality=v}}
  default:return false
  };panels.forEach{$0.contentView?.needsDisplay=true};return true
 }
 func snapshot()->[String:Any]{
  let encoder=JSONEncoder();let catalogue=(try? JSONSerialization.jsonObject(with:encoder.encode(StickerAsset.all))) ?? []
  let selection=settings.items.first{$0.id==selected}.flatMap{try? JSONSerialization.jsonObject(with:encoder.encode($0))}
  let instances=settings.items.map{["id":$0.id,"title":StickerAsset.find($0.assetID)?.title ?? $0.assetID,"inactive":drawings[$0.id]==nil] as [String:Any]}
  return ["instances":instances,"catalogue":catalogue,"editing":editing,"placing":placing ?? "","selected":selection ?? [:],"status":status,"undo":!history.undoStack.isEmpty,"redo":!history.redoStack.isEmpty,"renderPasses":renderPasses,"visible":drawings.count,"inactive":settings.items.filter{drawings[$0.id]==nil}.count,"limit":settings.limit]
 }
 func resolve(_ item:StudioSticker,depth:Int=0)->StickerResolved? {
  guard let w=owner,depth<12,let d=w.displays.first(where:{$0.id==item.anchor.screen}) ?? (item.anchor.kind == .desktop ? w.displays.first:nil),let asset=StickerAsset.find(item.assetID) else{return nil}
  let a=item.anchor;var r=StickerResolved(point:Vec(),height:64*item.scale)
  switch a.kind {
  case .desktop:
   // Clamp the complete rotated image, including long repeated strands, after a display change.
   let angle=item.rotation*Double.pi/180
   func offsets(_ height:Double)->[Vec]{let width=height*asset.width/asset.height*Double(item.segments);return [Vec(-asset.pivot.x*width,-asset.pivot.y*height),Vec((1-asset.pivot.x)*width,-asset.pivot.y*height),Vec(-asset.pivot.x*width,(1-asset.pivot.y)*height),Vec((1-asset.pivot.x)*width,(1-asset.pivot.y)*height)].map{Vec($0.x*cos(angle)-$0.y*sin(angle),$0.x*sin(angle)+$0.y*cos(angle))}}
   var points=offsets(r.height);var minX=points.map(\.x).min()!,maxX=points.map(\.x).max()!,minY=points.map(\.y).min()!,maxY=points.map(\.y).max()!
   let fit=min(1,(d.rect.width-8)/max(1,maxX-minX),(d.rect.height-44)/max(1,maxY-minY));r.height*=fit
   if fit<1{points=offsets(r.height);minX=points.map(\.x).min()!;maxX=points.map(\.x).max()!;minY=points.map(\.y).min()!;maxY=points.map(\.y).max()!}
   r.point=Vec(clamp(d.rect.x+a.local.x*d.rect.width,d.rect.x+4-minX,d.rect.maxX-4-maxX),clamp(d.rect.y+a.local.y*d.rect.height,d.rect.y+36-minY,d.rect.maxY-4-maxY))
  case .window:
   guard a.session==session,let window=w.interactionWindows.first(where:{$0.id==a.parent && $0.isVisible}),windowInstances[window.id]==window.attachmentIdentity else{return nil};r.point=StickerGeometry.windowPoint(a.local,frame:window.frame);r.window=window
  case .tree:
   guard let s=w.decorations.states[d.id],let node=s.tree,!s.treeRemoving,w.config.tree,w.config.placements[d.id]?.treeIdentity==a.parent else{return nil}
   let local=CGPoint(x:(a.local.x-0.5)*s.treeHeight,y:(0.5-a.local.y)*s.treeHeight),p=node.convert(local,to:s.root);r.point=Vec(d.rect.x+p.x,d.rect.maxY-p.y);r.angle = -Double(node.zRotation)*180 / .pi
  case .snowman:
   guard let s=w.decorations.states[d.id],let m=s.snowballs.snowmen.first(where:{$0.id.uuidString==a.parent}),let node=s.snowmanVisualID==m.id ? s.snowmanNode:s.extraSnowmanNodes[m.id] else{return nil}
   let p=node.convert(CGPoint(x:(a.local.x-0.5)*m.height,y:(0.5-a.local.y)*m.height),to:s.root);r.point=Vec(d.rect.x+p.x,d.rect.maxY-p.y);r.angle = -Double(node.zRotation)*180 / .pi
   if asset.id=="sticker_hat"{r.height=m.height*0.45*item.scale};if asset.id=="sticker_scarf"{r.height=m.height*0.23*item.scale}
  case .gift:
   guard let s=w.decorations.states[d.id],let gift=s.treePresents.first(where:{$0.id==a.parent && $0.openedAt==nil}) else{return nil};let p=gift.node.convert(CGPoint(x:(a.local.x-0.5)*30,y:(0.5-a.local.y)*32),to:s.root);r.point=Vec(d.rect.x+p.x,d.rect.maxY-p.y)
  case .character:
   guard a.session==session,let run=w.decorations.stories.active,let key=a.parent?.components(separatedBy:"/").last,a.parent?.hasPrefix(run.owner.uuidString+"/")==true,let actor=run.actors[key] else{return nil}
   let node=actor.actor.node,p=node.convert(CGPoint(x:(a.local.x-0.5)*48.0,y:(0.5-a.local.y)*48.0),to:run.state.root);r.point=Vec(d.rect.x+p.x,d.rect.maxY-p.y);r.height=48.0*(asset.id=="sticker_scarf" ? 0.23:0.45)*item.scale
  case .decoration:
   guard let parent=settings.items.first(where:{$0.id==a.parent && $0.visible}),let pose=resolve(parent,depth:depth+1),let pa=StickerAsset.find(parent.assetID) else{return nil}
   let x=(a.local.x-pa.pivot.x)*pose.height*pa.width/pa.height,y=(a.local.y-pa.pivot.y)*pose.height,angle=(pose.angle+parent.rotation)*Double.pi/180
   r.point=pose.point+Vec(x*cos(angle)-y*sin(angle),x*sin(angle)+y*cos(angle));r.angle=pose.angle+parent.rotation;r.window=pose.window
  }
  return r
 }
 func attachment(_ assetID:String,at point:Vec,display d:DisplayOverlay,strong:Bool=false,excluding:String?=nil)->StudioSticker {
  guard let w=owner else{return StudioSticker(assetID:assetID,anchor:StickerAnchor(screen:d.id,local:Vec(0.5,0.5)))}
  let snap=settings.autoSnap || strong,radius=strong ? 65.0:32.0
  var anchor=StickerAnchor(screen:d.id,local:Vec((point.x-d.rect.x)/d.rect.width,(point.y-d.rect.y)/d.rect.height)),best=radius
  func offer(_ p:Vec,_ a:StickerAnchor){let distance=(p-point).length;if distance<best {best=distance;anchor=a}}
  if snap {
   for window in w.interactionWindows where window.isVisible && window.frame.expanded(radius).contains(point) {
    // Public z-order: do not attach through a window in front. Keep traffic-light controls clear.
    if w.interactionWindows.contains(where:{$0.isVisible && $0.z<window.z && $0.frame.contains(point)}){continue}
    let f=window.frame
    let points=[Vec(f.x+max(88,f.width*0.13),f.y+12),Vec(f.maxX-20,f.y+12),Vec(point.x,f.y+12),Vec(f.x+12,point.y),Vec(f.maxX-12,point.y),Vec(point.x,f.maxY-12)].filter{f.contains($0) && !Rect(f.x,f.y,80,28).contains($0)}
    for p in points {windowInstances[window.id]=window.attachmentIdentity;offer(p,StickerAnchor(kind:.window,screen:d.id,local:Vec((p.x-f.x)/f.width,(p.y-f.y)/f.height),parent:window.id,session:session))}
   }
   if let s=w.decorations.states[d.id] {
    if let tree=s.tree,w.config.tree,!s.treeRemoving {
     if w.config.placements[d.id]?.treeIdentity==nil {if w.config.placements[d.id]==nil{w.config.placements[d.id]=Placement()};w.config.placements[d.id]?.treeIdentity=UUID().uuidString}
     let anchors=[Vec(0.5,0.1)]+TreeOrnament.branchAnchors+[Vec(0.5,0.68)]
     for a in anchors {let p=tree.convert(CGPoint(x:(a.x-0.5)*s.treeHeight,y:(0.5-a.y)*s.treeHeight),to:s.root);offer(Vec(d.rect.x+p.x,d.rect.maxY-p.y),StickerAnchor(kind:.tree,screen:d.id,local:a,parent:w.config.placements[d.id]?.treeIdentity))}
    }
    for m in s.snowballs.snowmen {let a=Vec(0.5,assetID=="sticker_hat" ? 0.09:assetID=="sticker_scarf" ? 0.32:0.52),item=StudioSticker(assetID:assetID,anchor:StickerAnchor(kind:.snowman,screen:d.id,local:a,parent:m.id.uuidString));if let r=resolve(item){offer(r.point,item.anchor)}}
    for gift in s.treePresents where gift.openedAt==nil {offer(gift.position+Vec(0,-10),StickerAnchor(kind:.gift,screen:d.id,local:Vec(0.5,0.19),parent:gift.id))}
   }
   for parent in settings.items where parent.id != excluding && parent.anchor.kind != .decoration && parent.visible {
    if let r=resolve(parent){offer(r.point,StickerAnchor(kind:.decoration,screen:d.id,local:Vec(0.5,0.5),parent:parent.id))}
   }
  }
  var item=StudioSticker(assetID:assetID,anchor:anchor);item.scale=settings.defaultSize/64;item.z=(settings.items.map(\.z).max() ?? 0)+1;return item
 }
 func pointer(_ kind:String,at p:Vec,display d:DisplayOverlay,shift:Bool=false){
  lastMouse=p
  if kind=="move",let asset=placing {candidate=attachment(asset,at:p,display:d,strong:shift);panels.forEach{$0.contentView?.needsDisplay=true};return}
  if kind=="down" {
   if let asset=placing {
    guard reattaching != nil || settings.items.filter({$0.anchor.screen==d.id}).count<settings.limit else{status="Decoration limit reached";return}
    let item=attachment(asset,at:p,display:d,strong:shift)
    if let id=reattaching {mutate{value in if let i=value.items.firstIndex(where:{$0.id==id}){value.items[i].anchor=item.anchor;value.items[i].visible=true}};selected=id}else{mutate{$0.items.append(item)};selected=item.id}
    reattaching=nil;placing=nil;candidate=nil;status="Placed · drag to move";return
   }
   selected=settings.items.sorted{$0.z>$1.z}.first{item in drawings[item.id].map{$0.bounds.contains(p)} == true}?.id
   guard let id=selected,let item=settings.items.first(where:{$0.id==id}),!item.locked,let pose=resolve(item) else{return}
   dragBefore=settings;dragID=id;dragOffset=pose.point-p
  }
  if kind=="drag",let id=dragID,let i=owner?.config.stickers.items.firstIndex(where:{$0.id==id}),let item=owner?.config.stickers.items[i] {
   let next=attachment(item.assetID,at:p+dragOffset,display:d,strong:shift,excluding:id);owner?.config.stickers.items[i].anchor=next.anchor;drawRevision+=1
  }
  if kind=="up",let before=dragBefore {commit(before);dragBefore=nil;dragID=nil}
  panels.forEach{$0.contentView?.needsDisplay=true}
 }
 func makeDrawing(_ item:StudioSticker,now:Double,animated:Bool,preview:Bool=false)->StickerDrawing? {
  guard let w=owner,let d=w.displays.first(where:{$0.id==item.anchor.screen}) ?? w.displays.first,let a=StickerAsset.find(item.assetID),let pose=resolve(item),let image=art(item,master:pose.height>96) else{return nil}
  var movement=0.0
  if !settings.reduceMotion,!w.director.reducedMotion,settings.animations,let window=pose.window,let impulse=windowImpulses[window.id],["sticker_wreath","sticker_bells"].contains(item.assetID){let age=max(0,now-impulse.1);movement=impulse.0*sin(age*8)*exp(-age*2.5)}
  let h=pose.height,width=h*a.width/a.height,angle=movement+(item.rotation+pose.angle+(animated && item.animation=="rotate" ? now*3:0))*Double.pi/180
  var transform=CGAffineTransform(translationX:pose.point.x-d.rect.x,y:d.rect.maxY-pose.point.y);transform=transform.rotated(by:-angle).scaledBy(x:item.flipX ? -1:1,y:item.flipY ? -1:1)
  let totalWidth=width*Double(item.segments),rect=CGRect(x:-a.pivot.x*totalWidth,y:-(1-a.pivot.y)*h,width:totalWidth,height:h)
  // Repeated strands are raster-composed once by art(), preserving the width of each icicle/lamp.
  let global=rect.applying(transform),box=Rect(d.rect.x+global.minX,d.rect.maxY-global.maxY,global.width,global.height)
  var blocked=(preview ? []:w.interactionWindows).filter{window in window.isVisible && (pose.window==nil || window.z<pose.window!.z)}.map(\.frame)
  // Clear traffic lights and menu/Dock areas; system menu surfaces suppress the complete decoration layer.
  if let window=pose.window {blocked.append(Rect(window.frame.x,window.frame.y,80,30))}
  if let dock=w.dock,dock.isVisible{blocked.append(dock.frame.expanded(3))}
  let pieces=StickerGeometry.visiblePieces(box,blocking:blocked)
  guard !pieces.isEmpty else{return nil}
  let clips=pieces.map{CGRect(x:$0.x-d.rect.x,y:d.rect.maxY-$0.maxY,width:$0.width,height:$0.height)}
  let alpha=preview ? 0.55:animated && ["glow","shimmer"].contains(item.animation) ? 0.88+0.1*sin(now*(item.animation=="glow" ? 1.3:0.55)+Double(item.z)):1
  return StickerDrawing(id:item.id,image:image,transform:transform,rect:rect,clips:clips,alpha:alpha,bounds:box,window:pose.window != nil)
 }
 private func art(_ item:StudioSticker,master:Bool)->CGImage? {
  let masterKey=(item.assetID+"/master") as NSString
  let original:CGImage
  if master,let cached=signImages.object(forKey:masterKey){original=cached.image}
  else if master,let img=NSImage(contentsOf:Resources.root.appendingPathComponent("SnowPlayAssets/Stickers/"+item.assetID+".png")),let cg=img.cgImage(forProposedRect:nil,context:nil,hints:nil){original=cg;signImages.setObject(StickerRaster(cg),forKey:masterKey,cost:cg.bytesPerRow*cg.height)}
  else if let img=AssetManager.shared.image(item.assetID){original=img}else{return nil}
  guard item.segments>1 || (item.assetID=="sticker_sign" && !item.text.isEmpty) else{return original}
  let key=(item.assetID+"/\(item.segments)/\(master)/"+item.text) as NSString;if let image=signImages.object(forKey:key){return image.image}
  let count=item.segments,width=original.width*count,height=original.height
  guard let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
  for i in 0..<count {c.draw(original,in:CGRect(x:i*original.width,y:0,width:original.width,height:height))}
  if item.assetID=="sticker_sign" {
   NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false);let font=NSFont.systemFont(ofSize:CGFloat(height)*0.1,weight:.semibold),attrs:[NSAttributedString.Key:Any]=[.font:font,.foregroundColor:NSColor(calibratedRed:0.3,green:0.22,blue:0.18,alpha:1)],text=item.text as NSString,size=text.size(withAttributes:attrs)
   text.draw(in:NSRect(x:max(12,(CGFloat(width)-size.width)/2),y:CGFloat(height)*0.37,width:CGFloat(width)-24,height:CGFloat(height)*0.23),withAttributes:attrs);NSGraphicsContext.restoreGraphicsState()
  };guard let image=c.makeImage() else{return nil};signImages.setObject(StickerRaster(image),forKey:key,cost:image.bytesPerRow*image.height);return image
 }
 func prepareAccessories(){
  for (_,value) in hiddenAccessories {value.0.isHidden=value.1};hiddenAccessories=[:]
  guard let w=owner,!settings.hidden else{return}
  for item in settings.items where item.visible && item.anchor.kind == .snowman && ["sticker_hat","sticker_scarf"].contains(item.assetID) {
   guard resolve(item) != nil,let s=w.decorations.states[item.anchor.screen],let m=s.snowballs.snowmen.first(where:{$0.id.uuidString==item.anchor.parent}),let node=s.snowmanVisualID==m.id ? s.snowmanNode:s.extraSnowmanNodes[m.id],let old=node.childNode(withName:item.assetID=="sticker_hat" ? "snowman_hat":"snowman_scarf") else{continue}
   let key=ObjectIdentifier(old);if hiddenAccessories[key]==nil{hiddenAccessories[key]=(old,old.isHidden)};old.isHidden=true
  }
 }
 func update(now:Double){
  guard let w=owner else{return}
  if editing,w.input.mode != .decorations || w.paused || w.sleeping || w.sessionInactive || w.observer.fullscreen {finish(cancelDrag:true)}
  if pendingImport != nil,now-importStarted>60 {pendingImport=nil}
  for window in w.interactionWindows {if let old=oldWindowFrames[window.id],abs(old.x-window.frame.x)>1 {windowImpulses[window.id]=(clamp((window.frame.x-old.x)*0.15,-7,7),now)};oldWindowFrames[window.id]=window.frame}
  windowImpulses=windowImpulses.filter{now-$0.value.1<2}
  let items=settings.items.sorted{$0.z<$1.z},motion=settings.animations && !settings.hidden && !settings.reduceMotion && !w.director.reducedMotion
  let active=Array(items.filter{$0.visible && $0.animation != "none" && (drawings[$0.id] != nil || lastGeometry==nil)}.prefix(settings.animationLimit)).map(\.id)
  if lastSettings != settings {lastSettings=settings;drawRevision+=1}
  var hash=Hasher();hash.combine(drawRevision);hash.combine(w.config.mode);hash.combine(w.observer.fullscreen)
  for d in w.displays {hash.combine(d.rect.x);hash.combine(d.rect.y);hash.combine(d.rect.width);hash.combine(d.rect.height)}
  for window in w.interactionWindows {hash.combine(window.frame.x);hash.combine(window.frame.y);hash.combine(window.frame.width);hash.combine(window.frame.height);hash.combine(window.z);hash.combine(window.isVisible);hash.combine(window.attachmentIdentity)}
  if let dock=w.dock {hash.combine(dock.frame.x);hash.combine(dock.frame.y);hash.combine(dock.frame.width);hash.combine(dock.frame.height);hash.combine(dock.isVisible)}
  // Parent poses only; static sticker transforms and clipping remain cached until a dependency changes.
  for item in items where item.anchor.kind != .desktop {if let p=resolve(item){hash.combine(p.point.x);hash.combine(p.point.y);hash.combine(p.angle)}else{hash.combine(item.id)}}
  let systemMenu=w.observer.snapshotRows.contains{row in let layer=row[kCGWindowLayer as String] as? Int ?? 0;let pid=row[kCGWindowOwnerPID as String] as? Int32 ?? 0;return pid != getpid() && layer>=Int(CGWindowLevelForKey(.popUpMenuWindow)) && layer<Int(CGWindowLevelForKey(.screenSaverWindow))}
  hash.combine(systemMenu)
  let geometry=hash.finalize();var frameHash=Hasher();frameHash.combine(geometry)
  if motion && (!active.isEmpty || !windowImpulses.isEmpty) {frameHash.combine(Int(now*30))}
  let full=geometry != lastGeometry;let previous=drawings;lastGeometry=geometry
  let signature=frameHash.finalize();guard signature != lastSignature else{return};lastSignature=signature;renderPasses+=1;drawings=[:]
  for d in w.displays {d.canvas.stickers=[];d.desktopCanvas.stickers=[]}
  if !settings.hidden && !w.observer.fullscreen && !systemMenu && w.config.mode != .focus {
   var counts:[String:Int]=[:]
   for item in items where item.visible {guard counts[item.anchor.screen,default:0]<settings.limit else{continue};counts[item.anchor.screen,default:0]+=1;let animated=motion && active.contains(item.id),responding=item.anchor.kind == .window && !windowImpulses.isEmpty
    guard let drawing=(!full && !animated && !responding ? previous[item.id]:makeDrawing(item,now:now,animated:animated)),let d=w.displays.first(where:{$0.id==item.anchor.screen}) ?? (item.anchor.kind == .desktop ? w.displays.first:nil) else{continue};drawings[item.id]=drawing;if drawing.window {d.canvas.stickers.append(drawing)}else{d.desktopCanvas.stickers.append(drawing)}}
  }
  for d in w.displays {d.canvas.invalidateFrame();d.desktopCanvas.invalidateFrame()}
  if settings.items.isEmpty {signImages.removeAllObjects()}
 }
}
