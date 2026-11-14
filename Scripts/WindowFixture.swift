// Native integration fixture. Creates only its own disposable test window.
// --auto runs a timed lifecycle; otherwise use normal window controls manually.
import AppKit
import ApplicationServices
final class Fixture: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var observationTokens: [NSObjectProtocol] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        window=NSWindow(contentRect:NSRect(x:160,y:170,width:620,height:380),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title="SnowPlay — disposable window fixture"; window.isReleasedWhenClosed=false
        let label=NSTextField(wrappingLabelWithString:"SnowPlay native integration fixture\n\nMove, resize, minimize, restore and close this window.\nNo document content or screenshots are captured.\n\nWith --auto, a 15-second lifecycle runs on this window only.")
        label.frame=NSRect(x:32,y:80,width:550,height:220); label.font=NSFont.systemFont(ofSize:18); window.contentView?.addSubview(label)
        if CommandLine.arguments.contains("--controlled") {
            window.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
            for name in [NSWindow.didMiniaturizeNotification,NSWindow.didDeminiaturizeNotification,NSWindow.willCloseNotification] {
                observationTokens.append(NotificationCenter.default.addObserver(forName:name,object:window,queue:.main) { [weak self] note in self?.emit(note.name.rawValue) })
            }
            window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true);window.orderFrontRegardless()
            later(0.3) { self.window.orderFrontRegardless() }
            emit("ready")
            DispatchQueue.global(qos:.utility).async { [weak self] in
                while let command=readLine() { DispatchQueue.main.async { self?.command(command) } }
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
        } else { window.orderFrontRegardless() }
        if CommandLine.arguments.contains("--effects-auto") {
            window.collectionBehavior=[.canJoinAllSpaces,.fullScreenAuxiliary]
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps:true)
            // Allow actual falling particles to accumulate before real window events.
            later(20) { self.window.miniaturize(nil) }
            later(25) { self.window.deminiaturize(nil) }
            later(30) { self.window.close() }
            later(36) { NSApp.terminate(nil) }
        } else if CommandLine.arguments.contains("--auto") {
            later(2) { self.window.setFrameOrigin(NSPoint(x:240,y:210)) }
            later(3) { self.window.setContentSize(NSSize(width:500,height:340)) }
            later(5) { self.window.miniaturize(nil) }
            later(7) { self.window.deminiaturize(nil) }
            later(9) { self.window.orderOut(nil) }
            later(11) { self.window.orderFrontRegardless() }
            later(13) { self.window.close() }
            later(15) { NSApp.terminate(nil) }
        }
    }
    private func emit(_ event: String) {
        let frame=window.frame
        var payload: [String:Any] = ["event":event,"number":window.windowNumber,"miniaturized":window.isMiniaturized,"visible":window.isVisible,
                                   "frame":["x":frame.minX,"y":frame.minY,"width":frame.width,"height":frame.height]]
        if window.windowNumber>=0, let rows=CGWindowListCopyWindowInfo([.optionIncludingWindow],CGWindowID(window.windowNumber)) as? [[String:Any]], let bounds=rows.first?[kCGWindowBounds as String] { payload["cgFrame"]=bounds }
        if let data=try? JSONSerialization.data(withJSONObject:payload), let text=String(data:data,encoding:.utf8) { print(text); fflush(stdout) }
    }
    private func command(_ command: String) {
        switch command {
        case "status": emit("status")
        case "maximize": if let screen=NSScreen.main {window.setFrame(screen.visibleFrame,display:true)};emit("maximized")
        case "drag":
            for i in 1...40 {later(Double(i)*0.025) {self.window.setFrameOrigin(NSPoint(x:300+i*5,y:230));self.emit("drag-step")}}
        case "move": window.setFrameOrigin(NSPoint(x:300,y:230));emit("moved")
        case "minimize": window.miniaturize(nil); emit("minimizeRequested")
        case "restore": window.deminiaturize(nil); emit("restoreRequested")
        case "close": window.close(); emit("closeRequested")
        case "quit": NSApp.terminate(nil)
        default: break
        }
    }
    private func later(_ t: Double, _ action: @escaping ()->Void) { DispatchQueue.main.asyncAfter(deadline:.now()+t,execute:action) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !CommandLine.arguments.contains("--auto") && !CommandLine.arguments.contains("--effects-auto") && !CommandLine.arguments.contains("--controlled") }
}
let app=NSApplication.shared, delegate=Fixture()
app.delegate=delegate; app.setActivationPolicy(.regular); app.run()
