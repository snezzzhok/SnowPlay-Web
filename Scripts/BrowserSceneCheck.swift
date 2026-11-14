// An owned, visible WebKit fixture. Mobile dimensions are layout checks, not a phone.
import AppKit
import WebKit
final class BrowserSceneCheck:NSObject,WKNavigationDelegate {
 let window=NSWindow(contentRect:NSRect(x:80,y:60,width:1200,height:900),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
 let view:WKWebView
 let origin=CommandLine.arguments[1],out=CommandLine.arguments[2]
 var phase=0,checks:[String:Any]=[:],results:[[String:Any]]=[]
 var started=Date()
 override init(){let config=WKWebViewConfiguration();config.websiteDataStore = .nonPersistent();view=WKWebView(frame:NSRect(x:0,y:0,width:1200,height:900),configuration:config);super.init()}
 func start(){window.title="SnowPlay · проверка браузерной сцены";window.contentView=view;window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);view.navigationDelegate=self;view.load(URLRequest(url:URL(string:origin+"?renderer=baseline")!))}
 func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){pollReady()}
 func later(_ delay:Double=0.15,_ block:@escaping()->Void){DispatchQueue.main.asyncAfter(deadline:.now()+delay,execute:block)}
 func js(_ code:String,_ block:@escaping([String:Any])->Void){view.evaluateJavaScript(code){value,error in if let error {self.fail("JavaScript: \(error)")};guard let value=value as? [String:Any] else{self.fail("Unexpected JS result");return};block(value)}}
 func require(_ condition:Bool,_ why:String){if !condition{fail(why)}}
 func fail(_ why:String){print("FAIL: "+why);exit(1)}
 func pollReady(){js("({ready:!!window.SnowPlay,failed:document.getElementById('loading').textContent.includes('Не удалось')})"){o in if o["failed"] as? Bool == true{self.fail("Asset loading")};if o["ready"] as? Bool == true {self.inspect()}else{self.later{self.pollReady()}}}}
 func inspect(){
  if phase==0 {js("({assets:SnowPlay.registry.assets.length,errors:SnowPlay.assetErrors,images:[...document.images].every(i=>i.complete&&i.naturalWidth>0),clean:!SnowPlay.snapshot.settings.windowSnow,amount:SnowPlay.snapshot.settings.amount,noYeti:!document.body.textContent.toLowerCase().includes('йети'),fits:document.documentElement.scrollWidth<=innerWidth})"){o in
    self.require(o["assets"] as? Int == 23 && (o["errors"] as? [String])?.isEmpty == true && o["images"] as? Bool == true,"All source graphics load on first opening")
    self.require(o["clean"] as? Bool == true && o["amount"] as? Int == 35 && o["noYeti"] as? Bool == true && o["fits"] as? Bool == true,"Defaults, clean windows, no Yeti, no overflow")
    self.checks["firstOpen"]=o
    self.js("(()=>{const a=document.getElementById('amount');a.value=62;a.dispatchEvent(new Event('input',{bubbles:true}));document.querySelector('[data-action=cut]').click();for(let i=0;i<12;i++)document.querySelector('[data-action=cut]').click();document.querySelector('[data-action=throw]').click();for(let i=0;i<12;i++)document.querySelector('[data-action=throw]').click();return {ok:true}})()"){_ in self.waitForActions()}
  };return}
  if phase==1 {js("({images:[...document.images].every(i=>i.complete&&i.naturalWidth>0),amount:SnowPlay.snapshot.settings.amount,tree:SnowPlay.snapshot.tree})"){o in
    self.require(o["amount"] as? Int == 62 && o["tree"] as? Bool == false && o["images"] as? Bool == true,"Reload persists settings and reloads graphics: \(o)")
    self.checks["reload"]=o
    self.js("document.getElementById('reset').click();({amount:SnowPlay.snapshot.settings.amount,clean:!SnowPlay.snapshot.settings.windowSnow,tree:SnowPlay.snapshot.tree})"){o in self.require(o["amount"] as? Int == 35 && o["clean"] as? Bool == true && o["tree"] as? Bool == true,"Reset actual settings");self.checks["reset"]=o;self.later(0.3){self.snapshot("desktop"){self.beginBenchmark()}}}
  };return}
  if phase==2 {beginBenchmark();return}
 }
 func waitForActions(){js("({tree:SnowPlay.snapshot.tree,snowman:SnowPlay.snapshot.snowman,projectile:SnowPlay.snapshot.projectile,fx:SnowPlay.snapshot.particles,storedTree:JSON.parse(localStorage.getItem('snowplay.web.settings.v1')).tree})"){o in
   if o["tree"] as? Bool == false && o["snowman"] as? Bool == false && o["projectile"] as? Bool == false {self.require(o["storedTree"] as? Bool == false,"Completed fall is persisted in the same frame");self.checks["repeatActions"]=o;self.phase=1;self.view.reload()}
   else{self.later(0.025){self.waitForActions()}}
 }}
 func snapshot(_ name:String,_ completion:@escaping()->Void){view.takeSnapshot(with:nil){image,error in if let image,let data=image.tiffRepresentation,let bitmap=NSBitmapImageRep(data:data),let png=bitmap.representation(using:.png,properties:[:]) {try? png.write(to:URL(fileURLWithPath:self.out+"-"+name+".png"))};completion()}}
 func beginBenchmark(){if CommandLine.arguments.contains("--checks-only"){mobile();return};js("SnowPlay.startBenchmark();({started:true})"){_ in self.started=Date();self.waitBenchmark()}}
 func waitBenchmark(){js("({done:!!SnowPlay.result,result:SnowPlay.result})"){o in
   if o["done"] as? Bool == true,let r=o["result"] as? [String:Any]{self.require(r["invalidated"] as? Bool == false,"Visible benchmark remains valid");self.require((r["concurrencySamples"] as? Int ?? 0)>200,"Santa, plow and snow actually overlap");self.results.append(r);print("MEASURED: \(r["renderer"] ?? "?") \(r["metrics"] ?? "?")");fflush(stdout)
     if self.phase==1{self.phase=2;self.view.load(URLRequest(url:URL(string:self.origin)!))}
     else{self.mobile()}
   }else{if Date().timeIntervalSince(self.started)>40{self.fail("Benchmark timed out")};self.later(1){self.waitBenchmark()}}
 }}
 func mobile(){window.setContentSize(NSSize(width:390,height:844));view.frame=NSRect(x:0,y:0,width:390,height:844);later(0.6){self.js("({width:innerWidth,fits:document.documentElement.scrollWidth<=innerWidth,images:[...document.images].every(i=>i.complete&&i.naturalWidth>0),sceneWidth:document.getElementById('scene').clientWidth,panelWidth:document.querySelector('.panel').clientWidth})"){o in self.require(o["fits"] as? Bool == true && o["images"] as? Bool == true,"Mobile-width layout and images");self.checks["mobileViewportOnly"]=o;self.snapshot("mobile"){self.finish()}}}}
 func finish(){let result:[String:Any]=["passed":true,"checks":checks,"performance":results,"measurementHost":"Actual Mac Apple M1, visible WKWebView, 1200x900 CSS pixels; Low Power Mode enabled","physicalPhoneTested":false,"mobileViewportIsNotPhoneBenchmark":true]
  do{try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:out+".json"))}catch{fail(error.localizedDescription)}
  print("PASS: cold image load, immediate reload, settings/reset, repeated actions, desktop + narrow layout; performance runs: \(results.count)");exit(0)
 }
}
@main struct BrowserSceneCheckMain{static func main(){let app=NSApplication.shared;app.setActivationPolicy(.regular);let check=BrowserSceneCheck();check.start();DispatchQueue.main.asyncAfter(deadline:.now()+95){print("FAIL: overall browser timeout");exit(1)};app.run();_=check}}
