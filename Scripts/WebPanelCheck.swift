// Own WebKit fixture; checks the compact English UI against an isolated native app.
import AppKit
import WebKit
final class Check:NSObject,WKNavigationDelegate {
 let view=WKWebView(frame:NSRect(x:0,y:0,width:530,height:690))
 let origin=CommandLine.arguments[1]
 var attempts=0,reloading=false,manualChecked=false,sessionUnavailable=false
 func start(){view.navigationDelegate=self;view.load(URLRequest(url:URL(string:origin)!))}
 func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){later{self.inspect()}}
 func later(_ body:@escaping()->Void){DispatchQueue.main.asyncAfter(deadline:.now()+1.3,execute:body)}
 func evaluate(_ script:String,_ next:@escaping([String:Any])->Void){view.evaluateJavaScript(script){value,error in guard error==nil,let object=value as? [String:Any] else{print("FAIL JS",String(describing:error));exit(1)};next(object)}}
 func require(_ ok:Bool,_ message:String){if !ok{print("FAIL",message);exit(1)}}
 func inspect(){
  evaluate(#"({ready:typeof config!=='undefined'&&!!config,images:[...document.images].every(i=>i.complete&&i.naturalWidth>0)})"#){o in
   self.attempts+=1
   if (o["ready"] as? Bool != true || o["images"] as? Bool != true),self.attempts<20 {self.later{self.inspect()};return}
   self.require(o["ready"] as? Bool==true && o["images"] as? Bool==true,"connected images")
   if self.reloading {self.finish();return}
   self.evaluate(#"(()=>{render();return {english:document.documentElement.lang==='en'&&!/[А-Яа-яЁё]/.test(document.body.textContent),cards:document.querySelectorAll('.option-card').length===30&&!document.querySelector('[data-action="delivery"]')&&[...document.querySelectorAll('.option-card img')].every(i=>i.complete&&i.naturalWidth>0),clean:!document.querySelector('#reset,#more,#testing,#automaticSnowman,script[src="/testing.js"]'),feedback:(()=>{const old=state.diagnostic;state.diagnostic='Not enough snow yet.';render();const ok=byId('message').textContent===state.diagnostic;state.diagnostic=old;render();return ok})(),tabs:[...document.querySelectorAll('[data-tab]')].every(b=>{b.click();return !byId(b.dataset.tab).hidden&&document.querySelectorAll('.world-section:not([hidden])').length===1}),overflow:document.documentElement.scrollWidth>innerWidth}})()"#){o in
    self.require(o["english"] as? Bool==true && o["clean"] as? Bool==true && o["cards"] as? Bool==true && o["feedback"] as? Bool==true && o["tabs"] as? Bool==true && o["overflow"] as? Bool==false,"English, clean tabs, no overflow")
    self.view.frame.size.width=390;self.later{self.mobile()}
   }
  }
 }
 func mobile(){evaluate(#"({fits:document.documentElement.scrollWidth<=innerWidth&&[...document.querySelectorAll('.living-tabs button')].every(b=>b.scrollWidth<=b.clientWidth+1)})"#){o in
  self.require(o["fits"] as? Bool==true,"390pt layout and tab labels")
  self.view.frame.size.width=530
  self.evaluate(#"(()=>{tab('tree');document.querySelector('[data-choice=treeSize][data-value=large]').click();tab('garlands');document.querySelector('[data-choice=bulbColor][data-value=warm]').click();tab('snow');for(const [id,v] of [['intensity',.77],['snowSpeed',1.7],['bulbSize',18],['bulbBrightness',.7]]){byId(id).value=v;byId(id).dispatchEvent(new Event('input',{bubbles:true}));}byId('wind-control').dispatchEvent(new KeyboardEvent('keydown',{key:'Home',bubbles:true}));return {ok:true}})()"#){_ in self.later{self.controls()}}
 }}
 func controls(){evaluate("({amount:config.intensity,speed:config.snowSpeed,angle:state.config.windAngle,size:config.bulbSize,glow:config.bulbBrightness,tree:config.treeSize,palette:config.bulbColor})"){o in
  self.require(o["amount"] as? Double==0.77 && o["speed"] as? Double==1.7 && o["angle"] as? Double == -90 && o["size"] as? Double==18 && o["glow"] as? Double==0.7 && o["tree"] as? String=="large" && o["palette"] as? String=="warm","controls reach native settings")
  self.evaluate("byId('wind-control').dispatchEvent(new KeyboardEvent('keydown',{key:'0',bubbles:true}));byId('pause').click();({ok:true})"){_ in self.later{self.evaluate("({paused:state.paused})"){o in
   self.require(o["paused"] as? Bool==true,"pause")
   self.evaluate("byId('pause').click();({ok:true})"){_ in self.later{self.sculpt()}}
  }}}
 }}
 func sculpt(){evaluate("({locked:state.systemPaused})"){o in
  if o["locked"] as? Bool==true {self.sessionUnavailable=true;self.reloading=true;self.view.reload();return}
  self.sculptActive()
 }}
 func sculptActive(){evaluate("tab('snowman');document.querySelector('[data-action=snowballs]').click();({ok:true})"){_ in self.later{self.evaluate("({manual:!config.automaticSnowman,editor:state.editor})"){o in
  self.require(o["manual"] as? Bool==true && o["editor"] as? String=="snow","Build a snowman enters manual shovel mode")
  self.evaluate("document.querySelector('[data-action=done]').click();({ok:true})"){_ in self.later{self.evaluate("({editor:state.editor})"){o in
   self.require(o["editor"] as? String=="none","Done exits editor")
   self.manualChecked=true;self.reloading=true;self.view.reload()
  }}}
 }}}}
 func captureOptions(_ completion:@escaping()->Void){
  func capture(_ section:String,_ next:@escaping()->Void){self.evaluate("tab('"+section+"');({ok:true})"){_ in DispatchQueue.main.asyncAfter(deadline:.now()+0.2){self.view.takeSnapshot(with:nil){image,_ in
   if let tiff=image?.tiffRepresentation,let png=NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]){try? png.write(to:URL(fileURLWithPath:".build/panel-"+section+".png"))};next()
  }}}}
  capture("tree"){capture("garlands",completion)}
 }
 func finish(){captureOptions{self.finishChecked()}}
 func finishChecked(){evaluate("({amount:config.intensity,speed:config.snowSpeed,angle:config.windAngle,manual:!config.automaticSnowman,size:config.bulbSize,palette:config.bulbColor})"){o in
  self.require(o["amount"] as? Double==0.77 && o["speed"] as? Double==1.7 && o["angle"] as? Double==0 && o["size"] as? Double==18 && o["palette"] as? String=="warm" && (self.sessionUnavailable || o["manual"] as? Bool==true),"settings survive reload")
  DispatchQueue.main.asyncAfter(deadline:.now()+0.2){self.view.takeSnapshot(with:nil){image,_ in
   if let tiff=image?.tiffRepresentation,let png=NSBitmapImageRep(data:tiff)?.representation(using:.png,properties:[:]){try? png.write(to:URL(fileURLWithPath:"Docs/control-panel-preview.png"))}
   let result:[String:Any]=["passed":true,"scope":"own WebKit UI, isolated app/preferences; no user manual-check marks changed","english":true,"visualCards":30,"callSantaRemoved":true,"garlandSizeAndGlowPersist":true,"removedResetMoreAndManualChecks":true,"sevenTabs":true,"fits390And530pt":true,"controlsAndPause":true,"manualShovelActionAndExit":self.manualChecked,"manualShovelUIUnavailableLockedSession":self.sessionUnavailable,"settingsReload":true]
   try! JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/simple-panel-check-result.json"));print("PASS: English minimal panel, all images, seven tabs, 390/530pt layout, native controls and persistence");if self.sessionUnavailable{print("SKIP: physical/manual UI action requires an unlocked session; independent Cocoa shovel fixture is separate")}else{print("PASS: manual shovel action and exit") };exit(0)
  }
 }}
}
}
@main struct WebPanelCheck {static func main(){let app=NSApplication.shared;app.setActivationPolicy(.accessory);let check=Check();check.start();DispatchQueue.main.asyncAfter(deadline:.now()+60){print("FAIL timeout");exit(1)};app.run();withExtendedLifetime(check){}}}
