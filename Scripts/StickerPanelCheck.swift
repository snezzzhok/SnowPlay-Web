import AppKit
import WebKit
final class StickerPanelCheck:NSObject,WKNavigationDelegate {
 let view=WKWebView(frame:NSRect(x:0,y:0,width:390,height:800));var tries=0,reloaded=false
 func start(_ url:String){view.navigationDelegate=self;view.load(URLRequest(url:URL(string:url)!))}
 func later(_ block:@escaping()->Void){DispatchQueue.main.asyncAfter(deadline:.now()+0.8,execute:block)}
 func require(_ test:Bool,_ why:String){if !test {print("FAIL",why);exit(1)}}
 func eval(_ source:String,_ block:@escaping([String:Any])->Void){view.evaluateJavaScript(source){value,error in guard let o=value as? [String:Any],error==nil else{print("FAIL JS",String(describing:error));exit(1)};block(o)}}
 func webView(_ view:WKWebView,didFinish navigation:WKNavigation!){later{self.inspect()}}
 func inspect(){eval("tab('decorations');({ready:!!config&&document.querySelectorAll('.sticker-card').length===20,images:[...document.querySelectorAll('.sticker-card img')].every(i=>i.complete&&i.naturalWidth>0),fits:document.documentElement.scrollWidth<=innerWidth,tabs:document.querySelectorAll('[data-tab]').length})"){o in
  self.tries+=1;if o["ready"] as? Bool != true || o["images"] as? Bool != true {if self.tries<15{self.later{self.inspect()};return}}
  self.require(o["ready"] as? Bool==true && o["images"] as? Bool==true && o["fits"] as? Bool==true && o["tabs"] as? Int==7,"20 image cards and 390pt layout")
  if self.reloaded{self.finish();return}
  self.eval("document.querySelector('[data-sticker-category=lights]').click();({visible:[...document.querySelectorAll('.sticker-card')].filter(b=>!b.hidden).length})"){o in
   self.require(o["visible"] as? Int==2,"Lights category")
   self.eval("byId('sticker-snap').click();byId('sticker-animate').click();byId('sticker-quality').value='low';byId('sticker-quality').dispatchEvent(new Event('change'));byId('sticker-default-size').value=82;byId('sticker-default-size').dispatchEvent(new Event('change'));({ok:true})"){_ in self.later{self.settings()}}
  }
 }}
 func settings(){eval("({saved:config.stickers.defaultSize===82&&config.stickers.quality==='low'&&!config.stickers.autoSnap&&!config.stickers.animations})"){o in self.require(o["saved"] as? Bool==true,"settings through native API");self.view.frame.size.width=530;self.eval("({fits:document.documentElement.scrollWidth<=innerWidth})"){o in self.require(o["fits"] as? Bool==true,"530pt layout");self.reloaded=true;self.view.reload()}}}
 func finish(){eval("tab('decorations');({saved:config.stickers.defaultSize===82&&config.stickers.quality==='low'&&!config.stickers.autoSnap&&!config.stickers.animations})"){o in self.require(o["saved"] as? Bool==true,"reload persistence");self.later{self.view.takeSnapshot(with:nil){image,_ in
  if let tiff=image?.tiffRepresentation,let png=NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]){try? png.write(to:URL(fileURLWithPath:"Docs/Sticker-Studio-Panel.png"))}
  try! JSONSerialization.data(withJSONObject:["passed":true,"twentyImages":true,"sevenTabs":true,"categoryFilter":true,"settingsPersistence":true,"fits390And530":true,"scope":"Real WKWebView connected to a temporary native SnowPlay process"],options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/sticker-studio-panel-result.json"));print("PASS: twenty cards, categories, seven tabs, 390/530pt and saved settings");exit(0)
 }}}}
}
@main struct Run {static func main(){_=NSApplication.shared;let c=StickerPanelCheck();c.start(CommandLine.arguments[1]);DispatchQueue.main.asyncAfter(deadline:.now()+35){print("FAIL timeout");exit(1)};NSApp.run();withExtendedLifetime(c){}}}
