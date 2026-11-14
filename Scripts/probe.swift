import AppKit
import ApplicationServices
import SpriteKit
let screens=NSScreen.screens
let rows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
let ordinary=rows.filter { ($0[kCGWindowLayer as String] as? Int) == 0 }
let dock=rows.filter { ($0[kCGWindowOwnerName as String] as? String) == "Dock" }
let window=NSWindow(contentRect:NSRect(x:10,y:10,width:50,height:50),styleMask:.borderless,backing:.buffered,defer:false)
window.isOpaque=false; window.backgroundColor = .clear; window.ignoresMouseEvents=true
let view=SKView(frame:window.frame); view.allowsTransparency=true; window.contentView=view
print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
print("Displays: \(screens.count); scales: \(screens.map { $0.backingScaleFactor })")
print("CG normal-window geometry rows: \(ordinary.count); Dock-owned rows: \(dock.count)")
print("AX trusted: \(AXIsProcessTrusted())")
print("Transparent NSWindow + SKView constructed: \(!window.isOpaque && window.ignoresMouseEvents && view.allowsTransparency)")
print("Physical click-through, stacking and lifecycle transitions: require manual interaction")
window.close()
