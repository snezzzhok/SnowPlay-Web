import AppKit
import SnowCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var winter: WinterCoordinator!
    var control:ControlPopover?
    var contextMenu:NSMenu?
    func applicationDidFinishLaunching(_ notification: Notification) {
        winter=WinterCoordinator()
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        if let icon=AssetManager.shared.image("snowflake_icon") {let image=NSImage(cgImage:icon,size:NSSize(width:16,height:16));image.isTemplate=true;status.button?.image=image} else { status.button?.title="SnowPlay" }; status.button?.toolTip="SnowPlay"
        winter.statusChanged={ [weak self] in self?.updateMenu() }
        winter.start();control=ControlPopover(url:winter.server.url);winter.onWorldInteraction={ [weak self] in self?.control?.close() };updateMenu()
        status.button?.target=self;status.button?.action=#selector(statusPressed);status.button?.sendAction(on:[.leftMouseUp,.rightMouseUp])
        if let i=CommandLine.arguments.firstIndex(of:"--diagnostic-run"), i+1<CommandLine.arguments.count, let seconds=Double(CommandLine.arguments[i+1]) {
            DispatchQueue.main.asyncAfter(deadline:.now()+seconds) { [weak self] in
                if let state=self?.winter.stateJSON() { var safe=state; safe.removeValue(forKey:"sessionToken"); if let data=try? JSONSerialization.data(withJSONObject:safe,options:[.prettyPrinted,.sortedKeys]), let string=String(data:data,encoding:.utf8) { print(string) } }
                NSApp.terminate(nil)
            }
        }
    }
    func updateMenu() {
        guard status != nil, winter != nil else { return }
        let menu=NSMenu()
        func item(_ title: String, _ action: Selector, _ key: String = "", checked: Bool = false) {
            let i=menu.addItem(withTitle:title,action:action,keyEquivalent:key); i.target=self; i.state=checked ? .on:.off
        }
        let header=menu.addItem(withTitle:"SnowPlay · a little winter",action:nil,keyEquivalent:""); header.isEnabled=false
        item("Open Control Panel…",#selector(panel),",")
        item(winter.paused ? "Resume All Effects":"Pause All Effects",#selector(pause),"p")
        item("Snowfall",#selector(snow),checked:winter.config.snow)
        menu.addItem(.separator())
        item("Focus",#selector(focus),checked:winter.config.mode == .focus)
        item("Balanced",#selector(balanced),checked:winter.config.mode == .balanced)
        item("Play",#selector(play),checked:winter.config.mode == .play)
        menu.addItem(.separator())
        item("Place Garland…",#selector(garland)); item("Place Tree…",#selector(tree)); item("Gather Snowballs…",#selector(snowballs))
        if winter.input.mode != .none { item("Done Editing",#selector(done),".") }
        item("Santa Delivery",#selector(delivery)); item("Clear Snow",#selector(clean)); item("Reset Winter",#selector(reset))
        menu.addItem(.separator())
        item("Enable Window Accessibility…",#selector(permission))
        item("Quit SnowPlay",#selector(quit),"q")
        contextMenu=menu
        status.button?.appearsDisabled=winter.paused
    }
    @objc func panel() {if let button=status.button {control?.show(relativeTo:button)}}
    @objc func statusPressed(){if let event=NSApp.currentEvent,event.type == .rightMouseUp,let menu=contextMenu,let button=status.button {NSMenu.popUpContextMenu(menu,with:event,for:button)}else{panel()}}
    @objc func pause() { winter.togglePause() }
    @objc func snow() { winter.config.snow.toggle(); winter.persist(); winter.applySettings() }
    func preset(_ mode: WinterMode) { winter.applyPreset(mode) }
    @objc func focus() { preset(.focus) }; @objc func balanced() { preset(.balanced) }; @objc func play() { preset(.play) }
    @objc func tree() { winter.beginEditor(.tree) }
    @objc func garland() { for key in Array(winter.config.placements.keys) { winter.config.placements[key]?.garland=[]; winter.config.placements[key]?.garlandWindow=nil }; winter.beginEditor(.garland) }
    @objc func snowballs() { winter.beginEditor(.snow) }
    @objc func done() { winter.finishSculpting(); winter.input.stop(); winter.config.interaction=false; winter.persist(); updateMenu() }
    @objc func delivery() { if !winter.decorations.livingBusy,!winter.paused,!winter.sleeping,winter.config.mode != .focus,!winter.director.reducedMotion {winter.decorations.pendingDelivery=true} }
    @objc func clean() { winter.clean() }
    @objc func reset() { winter.reset() }
    @objc func permission() { winter.observer.permissionPrompt() }
    @objc func quit() { NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { winter?.stop() }
}
let app=NSApplication.shared
let delegate=AppDelegate()
app.setActivationPolicy(.accessory); app.delegate=delegate; app.run()
