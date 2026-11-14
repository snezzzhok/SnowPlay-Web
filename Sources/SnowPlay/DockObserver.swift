import AppKit
import ApplicationServices
import SnowCore

struct DockGeometry {
    let frame: Rect; let axis: SurfaceAxis; let screenID: String
    var isVisible=true
    var slots: [Rect]=[]
    var snowFrame: Rect {
        let images=slots.map { HatPlacement.iconRect(in:$0) };guard !images.isEmpty else {return frame}
        let x=images.map(\.x).min()!,right=images.map(\.maxX).max()!,y=images.map(\.y).min()!,bottom=images.map(\.maxY).max()!
        switch axis {
        case .horizontal:
            let top=images.map { $0.y+$0.height*0.10 }.min()!;return Rect(x,top,right-x,max(1,frame.maxY-top))
        case .verticalLeft:
            let edge=images.map { $0.maxX-$0.width*0.10 }.max()!;return Rect(frame.x,y,edge-frame.x,bottom-y)
        case .verticalRight:
            let edge=images.map { $0.x+$0.width*0.10 }.min()!;return Rect(edge,y,frame.maxX-edge,bottom-y)
        }
    }
}
struct DockIcon { let id: String; let frame: Rect }
final class DockObserver {
    private(set) var icons: [DockIcon]=[]
    private var cachedPID: pid_t?, cachedList: AXUIElement?
    private var rawSlots: [Rect]=[]
    private var rawIcons: [DockIcon]=[]
    private var previous: DockGeometry?
    private var knownIcons:[(String,AXUIElement)]=[]
    private var lastInventory = -1000.0
    private(set) var inventoryScans=0,frameQueries=0
    private func readFrame(_ element:AXUIElement)->Rect? {frameQueries+=1;return axFrame(element)}
    private func projectSlots(from source: Rect,to destination: Rect)->[Rect] { rawSlots.map { Rect($0.x+destination.x-source.x,$0.y+destination.y-source.y,$0.width,$0.height) } }
    func clearIcons() { icons=[] }
    func updateIcons(dock: DockGeometry?) { icons=dock?.isVisible == true ? rawIcons : [] }
    func detect(displays: [DisplayOverlay], rows: [[String:Any]], wantedIDs:Set<String>?=nil, now:Double=ProcessInfo.processInfo.systemUptime) -> DockGeometry? {
        guard let pid=NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.dock").first?.processIdentifier else { icons=[]; return nil }
        if cachedPID != pid { cachedPID=pid; cachedList=nil; previous=nil;knownIcons=[];lastInventory = -1000 }
        rawIcons=[];rawSlots=[]
        if wantedIDs?.isEmpty != true && AXIsProcessTrusted() {
            var listFrame:Rect?
            if now-lastInventory>=2 || (cachedList==nil && now-lastInventory>=0.5) {
                lastInventory=now;inventoryScans+=1;knownIcons=[]
                let app=AXUIElementCreateApplication(pid);AXUIElementSetMessagingTimeout(app,0.015)
                var queue=cachedList.map { [$0] } ?? [app],index=0
                while index<queue.count && index<128 {
                    let element=queue[index];index+=1;AXUIElementSetMessagingTimeout(element,0.008)
                    let role=axValue(element,kAXRoleAttribute) as? String
                    if role==kAXListRole,let frame=readFrame(element),frame.width>40,frame.height>8 {cachedList=element;listFrame=frame}
                    let tile=role=="AXDockItem" ? readFrame(element):nil
                    if let tile,tile.width>4,tile.height>4 {rawSlots.append(tile)}
                    if let url=axValue(element,kAXURLAttribute) as? URL,url.pathExtension=="app",let frame=tile ?? readFrame(element),frame.width>4,frame.height>4 {
                        let id=url.standardizedFileURL.absoluteString;knownIcons.append((id,element))
                        if wantedIDs?.contains(id) != false {rawIcons.append(DockIcon(id:id,frame:frame))};continue
                    }
                    if let children=axValue(element,kAXChildrenAttribute) as? [AXUIElement] {queue+=children.prefix(64)}
                }
                if listFrame==nil {cachedList=nil}
            } else if let list=cachedList {
                listFrame=readFrame(list)
                // Hidden Dock does not need per-icon IPC. Keep the cached references for its next reveal.
                if let frame=listFrame,displays.contains(where:{frame.intersects($0.rect) && frame.y<$0.rect.maxY-8}) {
                    for (id,element) in knownIcons where wantedIDs?.contains(id) != false {
                        if let frame=readFrame(element),frame.width>4,frame.height>4 {rawIcons.append(DockIcon(id:id,frame:frame))}
                    }
                    rawSlots=rawIcons.map(\.frame)
                }
            }
            if let frame=listFrame {
                for d in displays {
                    let r=d.rect
                    let horizontal=frame.width>frame.height*2
                    if horizontal,frame.x<r.maxX,frame.maxX>r.x,(abs(frame.maxY-r.maxY)<frame.height+120 || abs(frame.y-r.maxY)<4) {
                        let visible=frame.y<r.maxY-8 && frame.maxY>r.y
                        let canonical=visible ? frame : Rect(frame.x,r.maxY-frame.height,frame.width,frame.height)
                        let geometry=DockGeometry(frame:canonical,axis:.horizontal,screenID:d.id,isVisible:visible,slots:projectSlots(from:frame,to:canonical))
                        previous=geometry; return geometry
                    }
                    if !horizontal,frame.y<r.maxY,frame.maxY>r.y {
                        if abs(frame.x-r.x)<frame.width+40 || abs(frame.maxX-r.x)<8 {
                            let visible=frame.maxX>r.x+8
                            let canonical=visible ? frame:Rect(r.x,frame.y,frame.width,frame.height)
                            let g=DockGeometry(frame:canonical,axis:.verticalLeft,screenID:d.id,isVisible:visible,slots:projectSlots(from:frame,to:canonical)); previous=g;return g
                        }
                        if abs(frame.maxX-r.maxX)<frame.width+40 || abs(frame.x-r.maxX)<8 {
                            let visible=frame.x<r.maxX-8
                            let canonical=visible ? frame:Rect(r.maxX-frame.width,frame.y,frame.width,frame.height)
                            let g=DockGeometry(frame:canonical,axis:.verticalRight,screenID:d.id,isVisible:visible,slots:projectSlots(from:frame,to:canonical));previous=g;return g
                        }
                    }
                }
            }
        }
        // Public CG fallback when AX is unavailable. Never invent individual icon frames.
        for row in rows where (row[kCGWindowOwnerPID as String] as? Int32) == pid {
            guard let b=row[kCGWindowBounds as String] as? NSDictionary,let cg=CGRect(dictionaryRepresentation:b) else { continue }
            let frame=Rect(cg.minX,cg.minY,cg.width,cg.height)
            for d in displays {
                let r=d.rect
                if frame.width>150,frame.height>8,frame.height<180,abs(frame.maxY-r.maxY)<100,frame.intersects(r) { let g=DockGeometry(frame:frame,axis:.horizontal,screenID:d.id);previous=g;return g }
                if frame.height>150,frame.width>8,frame.width<180,frame.intersects(r) {
                    if abs(frame.x-r.x)<40 { let g=DockGeometry(frame:frame,axis:.verticalLeft,screenID:d.id);previous=g;return g }
                    if abs(frame.maxX-r.maxX)<40 { let g=DockGeometry(frame:frame,axis:.verticalRight,screenID:d.id);previous=g;return g }
                }
            }
        }
        if var previous { previous.isVisible=false; icons=[]; return previous }
        icons=[];return nil
    }
}
