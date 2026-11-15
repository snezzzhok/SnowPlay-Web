import AppKit
import WebKit
final class StoriesPanelCheck:NSObject,WKNavigationDelegate {
 let view=WKWebView(frame:NSRect(x:0,y:0,width:390,height:760));var tries=0,reloaded=false
 func start(_ url:String){view.navigationDelegate=self;view.load(URLRequest(url:URL(string:url)!))}
 func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){later{self.inspect()}}
 func later(_ block:@escaping()->Void){DispatchQueue.main.asyncAfter(deadline:.now()+1.1,execute:block)}
 func eval(_ source:String,_ block:@escaping([String:Any])->Void){view.evaluateJavaScript(source){value,error in guard let object=value as? [String:Any],error==nil else{print("FAIL JS",String(describing:error));exit(1)};block(object)}}
 func require(_ test:Bool,_ why:String){if !test {print("FAIL",why);exit(1)}}
 func inspect(){eval("({ready:typeof config!=='undefined'&&!!config&&byId('story-cards').children.length===11,images:[...document.images].every(i=>i.complete&&i.naturalWidth>0)})"){o in
  self.tries+=1;if o["ready"] as? Bool != true || o["images"] as? Bool != true {if self.tries<20 {self.later{self.inspect()};return}}
  self.require(o["ready"] as? Bool==true && o["images"] as? Bool==true,"seven cards and native asset previews")
  if self.reloaded {self.finish();return}
  self.eval("tab('stories');({tabs:document.querySelectorAll('[data-tab]').length,cards:byId('story-cards').children.length,defaultNormal:config.stories.enabled&&config.stories.frequency==='normal'&&!config.stories.allowSnowmanCreation&&!config.stories.sounds,unavailable:[...document.querySelectorAll('.story-card')].filter(c=>c.id!=='story-tinyGift').every(c=>c.querySelector('.story-play').disabled&&c.querySelector('.story-reason').textContent),fits:document.documentElement.scrollWidth<=innerWidth})"){o in
   self.require(o["tabs"] as? Int==7 && o["cards"] as? Int==11 && o["defaultNormal"] as? Bool==true && o["unavailable"] as? Bool==true && o["fits"] as? Bool==true,"390pt layout, safe defaults and unavailable reasons")
   self.eval("(()=>{byId('storiesEnabled').click();document.querySelector('[data-frequency=rare]').click();byId('storiesCreation').click();byId('storiesKeep').click();byId('story-icon-zone').value='right';byId('story-icon-zone').dispatchEvent(new Event('change',{bubbles:true}));document.querySelector('.story-auto input').click();return {ok:true}})()"){_ in self.later{self.settings()}}
  }
 }}
 func settings(){eval("({off:!config.stories.enabled,rare:config.stories.frequency==='rare',creation:config.stories.allowSnowmanCreation,keep:config.stories.keepDecorations,zones:config.stories.reservedZones.length,auto:config.stories.enabledStories.length})"){o in
  self.require(o["off"] as? Bool==true && o["rare"] as? Bool==true && o["creation"] as? Bool==true && o["keep"] as? Bool==true && o["zones"] as? Int==1 && o["auto"] as? Int==8,"story settings save through native API")
  self.view.frame.size.width=530;self.eval("({fits:document.documentElement.scrollWidth<=innerWidth})"){o in self.require(o["fits"] as? Bool==true,"530pt layout");self.reloaded=true;self.view.reload()}
 }}
 func finish(){eval("tab('stories');({saved:!config.stories.enabled&&config.stories.frequency==='rare'&&config.stories.allowSnowmanCreation&&config.stories.keepDecorations&&config.stories.enabledStories.length===8&&config.stories.reservedZones[0].rect.x===.84})"){o in
  self.require(o["saved"] as? Bool==true,"story settings survive reload")
  self.later{self.view.takeSnapshot(with:nil){image,_ in
   if let tiff=image?.tiffRepresentation,let png=NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]){try? png.write(to:URL(fileURLWithPath:"Docs/christmas-stories-panel.png"))}
   let result:[String:Any]=["passed":true,"scope":"Real WebKit panel with isolated native app and preferences","elevenCards":true,"sevenTabs":true,"allImagesLoad":true,"fits390And530":true,"unavailableReasons":true,"settingsPersist":true,"reservedDesktopIconEdge":true]
   try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/christmas-stories-panel-result.json"));print("PASS: eleven stories, seven tabs, images, 390/530pt, safe defaults, per-story switches, frequency, icon zones, settings persist");exit(0)
  }}
 }}
}
@main struct Run {static func main(){_=NSApplication.shared;let check=StoriesPanelCheck();check.start(CommandLine.arguments[1]);DispatchQueue.main.asyncAfter(deadline:.now()+45){print("FAIL timeout");exit(1)};NSApp.run();withExtendedLifetime(check){}}}
