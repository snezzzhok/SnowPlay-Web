import AppKit
import ApplicationServices
import SnowCore

final class TrackedWindow {
    let id: String; let number: CGWindowID; let pid: pid_t
    var frame: Rect; var z: Int; var isVisible=true; var state: WindowState
    var lastGeometryTime=0.0,nextFastAttempt=0.0
    var ax: AXUIElement?; var lastSeen: Double; var missingSince: Double?
    init(number: CGWindowID, pid: pid_t, frame: Rect, z: Int, now: Double) {
        self.number=number; self.pid=pid; id="window-\(pid)-\(number)"; self.frame=frame; self.z=z; lastSeen=now; state=WindowState(now:now); state.send(.show,now:now)
    }
}
func axValue(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?; return AXUIElementCopyAttributeValue(element,name as CFString,&value) == .success ? value : nil
}
func axFrame(_ element: AXUIElement) -> Rect? {
    guard let p=axValue(element,kAXPositionAttribute), let s=axValue(element,kAXSizeAttribute), CFGetTypeID(p)==AXValueGetTypeID(), CFGetTypeID(s)==AXValueGetTypeID() else { return nil }
    var point=CGPoint.zero, size=CGSize.zero
    guard AXValueGetValue(unsafeBitCast(p,to:AXValue.self),.cgPoint,&point), AXValueGetValue(unsafeBitCast(s,to:AXValue.self),.cgSize,&size) else { return nil }
    return Rect(point.x,point.y,size.width,size.height)
}
final class WindowObserver {
    private(set) var windows: [String: TrackedWindow] = [:]
    private var observers: [pid_t: AXObserver] = [:]
    private var watched: [String: AXUIElement] = [:]
    private var closed = Set<String>()
    private var dirtyGeometry=Set<String>()
    private var nextAXAttempt:[pid_t:Double]=[:]
    private var minimizedByAX = Set<String>()
    // CG may briefly keep the closing compositor image after AX confirms destruction.
    private var retired: [String:Double] = [:]
    private var tokens: [NSObjectProtocol] = []
    var onClose: ((TrackedWindow)->Void)?
    var onMinimize: ((TrackedWindow)->Void)?
    var onRestore: ((TrackedWindow)->Void)?
    var onGeometry: ((TrackedWindow, Rect, Double)->Void)?
    private(set) var snapshotRows: [[String:Any]] = []
    private(set) var hasAccessibility=false
    private(set) var fullscreen=false
    private var previousPoll=0.0
    private(set) var events: [String:Int] = [:]
    private func record(_ name: String) { events[name,default:0]+=1 }
    init() {
        tokens.append(NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.didTerminateApplicationNotification,object:nil,queue:.main) { [weak self] note in
            guard let app=note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, let self else { return }
            for w in self.windows.values where w.pid == app.processIdentifier { self.closed.insert(w.id) }
            if let observer=self.observers.removeValue(forKey:app.processIdentifier) { CFRunLoopRemoveSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(observer),.commonModes) }
        })
    }
    private var ordered:[TrackedWindow]=[]
    private var orderDirty=true,trackingAccessibility=true
    var sorted:[TrackedWindow] {if orderDirty {ordered=windows.values.sorted{$0.z<$1.z};orderDirty=false};return ordered}
    var activeFrame: Rect? { sorted.first { $0.state.phase == .active && $0.isVisible }?.frame }
    func permissionPrompt() { let options=[kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary; _=AXIsProcessTrustedWithOptions(options) }
    func poll(now: Double, screens: [Rect], trackAccessibility:Bool=true) {
        trackingAccessibility=trackAccessibility;orderDirty=true
        previousPoll=now
        hasAccessibility=AXIsProcessTrusted()
        // Associate cached, unwarped geometry before the compositor can replace it
        // with a miniature. Hidden/minimizing windows still expose public AX windows.
        if hasAccessibility && trackingAccessibility {attachAccessibility(now:now)}
        let rows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
        snapshotRows=rows
        let listedIDs=Set(rows.compactMap { row -> String? in
            guard let pid=row[kCGWindowOwnerPID as String] as? Int32, let number=row[kCGWindowNumber as String] as? UInt32 else { return nil }
            return "window-\(pid)-\(number)"
        })
        retired=retired.filter { listedIDs.contains($0.key) || now-$0.value<1 }
        let frontPID=NSWorkspace.shared.frontmostApplication?.processIdentifier
        var seen=Set<String>()
        for (z,row) in rows.enumerated() {
            guard (row[kCGWindowLayer as String] as? Int) == 0,
                  let pid=row[kCGWindowOwnerPID as String] as? Int32, pid != getpid(),
                  let number=row[kCGWindowNumber as String] as? UInt32,
                  let dictionary=row[kCGWindowBounds as String] as? NSDictionary,
                  let cg=CGRect(dictionaryRepresentation:dictionary), cg.width>=120,cg.height>=60,
                  (row[kCGWindowAlpha as String] as? Double ?? 1)>0 else { continue }
            var frame=Rect(cg.minX,cg.minY,cg.width,cg.height)
            let key="window-\(pid)-\(number)"
            guard retired[key] == nil else { continue }
            if windows[key] == nil { record("created") }
            let w=windows[key] ?? TrackedWindow(number:number,pid:pid,frame:frame,z:z,now:now)
            if closed.contains(key) { continue }
            let old=w.frame
            if trackingAccessibility,NSEvent.pressedMouseButtons != 0,let ax=w.ax,let actual=axFrame(ax) {frame=actual}
            if hasAccessibility && trackingAccessibility, minimizedByAX.contains(key),let ax=w.ax {
                if (axValue(ax,kAXMinimizedAttribute) as? Bool) == false {minimizedByAX.remove(key)}
                else {w.isVisible=false;windows[key]=w;continue}
            }
            // Use the public AX frame as one coherent position/size sample. A stale
            // compositor row must never move a freshly tracked cap back one step.
            if hasAccessibility && trackingAccessibility,old != frame,let ax=w.ax,let actual=axFrame(ax),actual.width>=120,actual.height>=60 {frame=actual}
            if w.state.phase == .minimized { record("restored"); w.state.send(.restore,now:now); onRestore?(w) }
            if old != frame {
                record(old.width != frame.width || old.height != frame.height ? "resized" : "moved")
                w.state.send(old.width != frame.width || old.height != frame.height ? .resize : .move,now:now)
                w.frame=frame; onGeometry?(w,old,max(1.0/120,now-w.lastGeometryTime));w.lastGeometryTime=now
            }
            w.z=z; w.isVisible=true; w.lastSeen=now; w.missingSince=nil
            windows[key]=w; seen.insert(key)
        }
        if hasAccessibility && trackingAccessibility { attachAccessibility(now:now) }
        else {
            for w in windows.values { w.ax=nil }
            for observer in observers.values { CFRunLoopRemoveSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(observer),.commonModes) }
            observers.removeAll(); watched.removeAll();minimizedByAX.removeAll()
        }
        let visible=sorted.filter { seen.contains($0.id) }
        let activeID=visible.first(where: { $0.pid == frontPID })?.id
        for w in Array(windows.values) {
            if closed.remove(w.id) != nil {
                record("confirmedClosed"); w.state.send(.close,now:now); onClose?(w); w.state.send(.closed,now:now)
                retired[w.id]=now;minimizedByAX.remove(w.id)
                windows.removeValue(forKey:w.id); watched.removeValue(forKey:w.id); continue
            }
            if !seen.contains(w.id) {
                w.isVisible=false
                if w.missingSince == nil { w.missingSince=now; record("visibilityLost") }
                if hasAccessibility && trackingAccessibility, let ax=w.ax, minimizedByAX.contains(w.id) || (axValue(ax,kAXMinimizedAttribute) as? Bool) == true, w.state.phase != .minimized {
                    record("minimized"); w.state.send(.minimize,now:now); onMinimize?(w); w.state.send(.minimized,now:now)
                }
                // A missing CG window can be another Space, hidden, or in a system transition.
                // Retire old ambiguity without a burst; keep explicitly minimized profiles.
                if now-w.lastSeen > 3600 && w.state.phase != .minimized { windows.removeValue(forKey:w.id); watched.removeValue(forKey:w.id) }
            } else if w.id == activeID {
                if w.state.inactiveSince != nil { w.state.send(.activate,now:now) }
            } else if w.state.inactiveSince == nil { w.state.send(.deactivate,now:now) }
        }
        orderDirty=true
        fullscreen=visible.first.map { w in screens.contains { abs(w.frame.x-$0.x)<3 && abs(w.frame.y-$0.y)<3 && w.frame.width >= $0.width-3 && w.frame.height >= $0.height-3 } } ?? false
    }
    @discardableResult func refreshGeometry(now:Double)->Bool {
        guard hasAccessibility,trackingAccessibility else{return false}
        let dragging=NSEvent.pressedMouseButtons != 0,front=NSWorkspace.shared.frontmostApplication?.processIdentifier
        var changed=false
        for w in windows.values where w.isVisible && (dirtyGeometry.contains(w.id) || (dragging && w.pid==front)) {
            guard now>=w.nextFastAttempt,let ax=w.ax else{continue}
            guard let frame=axFrame(ax),frame.width>=120,frame.height>=60 else{w.nextFastAttempt=now+0.2;continue}
            dirtyGeometry.remove(w.id)
            if w.frame != frame {
                let old=w.frame;w.frame=frame;let dt=max(1.0/120,now-w.lastGeometryTime);w.lastGeometryTime=now
                w.state.send(old.width != frame.width || old.height != frame.height ? .resize:.move,now:now)
                onGeometry?(w,old,dt);changed=true
            }
        };return changed
    }
    private func attachAccessibility(now: Double) {
        let front=NSWorkspace.shared.frontmostApplication?.processIdentifier
        let pending=Set(windows.values.filter{$0.ax == nil && now-$0.lastSeen<30}.map(\.pid)).filter{now>=(nextAXAttempt[$0] ?? 0)}.sorted{a,b in a==front ? true:b==front ? false:a<b}
        for pid in pending.prefix(1) {
            nextAXAttempt[pid]=now+1
            let app=AXUIElementCreateApplication(pid); AXUIElementSetMessagingTimeout(app,0.025)
            guard let list=axValue(app,kAXWindowsAttribute) as? [AXUIElement] else {record("axListUnavailable");continue}
            if observers[pid] == nil {
                var observer: AXObserver?
                if AXObserverCreate(pid,{ _,element,notification,context in
                    guard let context else { return }
                    let owner=Unmanaged<WindowObserver>.fromOpaque(context).takeUnretainedValue()
                    for (id,ax) in owner.watched where CFEqual(ax,element) {
                        owner.record("axNotification")
                        switch notification as String {
                        case kAXUIElementDestroyedNotification: owner.closed.insert(id)
                        case kAXWindowMiniaturizedNotification: owner.minimizedByAX.insert(id)
                        case kAXWindowDeminiaturizedNotification: owner.minimizedByAX.remove(id)
                        case kAXMovedNotification,kAXResizedNotification:owner.dirtyGeometry.insert(id)
                        default: break
                        }
                    }
                },&observer) == .success, let observer {
                    observers[pid]=observer; CFRunLoopAddSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(observer),.commonModes)
                }
            }
            for w in windows.values where w.pid == pid && w.ax == nil {
                guard let match=list.first(where: { element in
                    guard let f=axFrame(element) else { return false }
                    return abs(f.x-w.frame.x)<3 && abs(f.y-w.frame.y)<3 && abs(f.width-w.frame.width)<3 && abs(f.height-w.frame.height)<3 && !watched.values.contains(where: { CFEqual($0,element) })
                }) else {record("axUnmatched");continue}
                w.ax=match;AXUIElementSetMessagingTimeout(match,0.012);watched[w.id]=match;record("axAttached")
                if let observer=observers[pid] {
                    for notification in [kAXUIElementDestroyedNotification,kAXWindowMiniaturizedNotification,kAXWindowDeminiaturizedNotification,kAXMovedNotification,kAXResizedNotification] {
                        AXObserverAddNotification(observer,match,notification as CFString,Unmanaged.passUnretained(self).toOpaque())
                    }
                }
            }
        }
    }
    deinit { for token in tokens { NSWorkspace.shared.notificationCenter.removeObserver(token) }; for observer in observers.values { CFRunLoopRemoveSource(CFRunLoopGetMain(),AXObserverGetRunLoopSource(observer),.commonModes) } }
}
