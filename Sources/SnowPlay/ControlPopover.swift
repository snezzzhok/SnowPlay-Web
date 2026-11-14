import AppKit
import WebKit
final class ControlPopover:NSObject {
    let popover=NSPopover()
    let webView=WKWebView()
    init(url:URL){
        super.init();let controller=NSViewController();controller.view=webView
        popover.contentViewController=controller;popover.behavior = .transient;popover.animates=false
        popover.contentSize=NSSize(width:530,height:min(690,(NSScreen.main?.visibleFrame.height ?? 800)-70))
        webView.load(URLRequest(url:url))
    }
    func show(relativeTo button:NSStatusBarButton){
        if popover.isShown {popover.performClose(nil);return}
        NSApp.activate(ignoringOtherApps:true);popover.show(relativeTo:button.bounds,of:button,preferredEdge:.minY)
        webView.window?.makeKey()
    }
    func close(){popover.performClose(nil)}
}
