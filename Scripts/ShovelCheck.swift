import AppKit
import SnowCore
@testable import SnowPlay
@main struct ShovelCheck {
 static func main() throws {
  precondition(CommandLine.arguments.contains("--config"));_=NSApplication.shared
  let w=WinterCoordinator();w.config=Configuration.preset(.play);w.config.automaticSnowman=true;w.config.tree=false;w.config.garland=false;w.config.placements=[:];w.rebuildDisplays();defer{w.stop()}
  let d=w.displays[0],state=w.decorations.states[d.id]!;d.hide(true);w.interactionWindowSource={[]}
  let key="ground-"+d.id;var ground=SnowSurface(id:key,screenID:d.id,frame:Rect(d.rect.x,d.rect.maxY-2,d.rect.width,1),maxHeight:42);ground.add(volume:18000);w.surfaces.surfaces[key]=ground
  w.beginEditor(.snow);precondition(!w.config.automaticSnowman && w.input.mode == .snow)
  precondition(AssetManager.shared.image("shovel_cursor") != nil)
  var panel=w.input.panels.first!,view=panel.contentView as! InputView
  precondition(view.glove && view.acceptsFirstResponder && panel.level.rawValue>Int(CGWindowLevelForKey(.dockWindow)))
  func send(_ type:NSEvent.EventType,_ x:Double){let p=panel.convertPoint(fromScreen:NSPoint(x:x,y:w.input.primaryHeight-d.rect.maxY+26));let e=NSEvent.mouseEvent(with:type,location:p,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:panel.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:type == .leftMouseUp ? 0:1)!;switch type{case .leftMouseDown:view.mouseDown(with:e);case .leftMouseDragged:view.mouseDragged(with:e);default:view.mouseUp(with:e)}}
  let before=w.surfaces.surfaces[key]!.volume
  send(.leftMouseDown,d.rect.x+d.rect.width*0.2);send(.leftMouseDragged,d.rect.x+d.rect.width*0.2+95)
  let esc=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:panel.windowNumber,context:nil,characters:"\u{1b}",charactersIgnoringModifiers:"\u{1b}",isARepeat:false,keyCode:53)!
  view.keyDown(with:esc);precondition(w.input.mode == .none && state.sculptArea==nil && state.snowballs.balls.isEmpty);precondition(abs(w.surfaces.surfaces[key]!.volume-before)<0.001,"Cancel lost snow")
  w.beginEditor(.snow);panel=w.input.panels.first!;view=panel.contentView as! InputView
  for f in [0.2,0.5,0.8] {let x=d.rect.x+d.rect.width*f;send(.leftMouseDown,x);send(.leftMouseDragged,x+95);send(.leftMouseUp,x+95)}
  precondition(state.snowballs.snowman != nil && state.snowballs.assemblyBalls.count==3 && state.snowballs.balls.isEmpty)
  precondition(w.input.mode == .none && state.sculptArea==nil && !w.config.interaction && w.input.panels.isEmpty,"Shovel did not exit after third ball")
  let mass=state.snowballs.assemblyBalls.reduce(0){$0+Double.pi*$1.radius*$1.radius}
  precondition(abs(w.surfaces.surfaces[key]!.volume+mass-before)<0.001,"Assembly lost snow")
  let result:[String:Any]=["passed":true,"scope":"Own Cocoa mouse/key events through actual InputView and coordinator; seeded real snow physics, controlled session independent of desktop lock; no physical desktop gesture claim","manualFromLegacyAutomaticPreference":true,"shovelAssetLoaded":true,"aboveDockInput":true,"escapeReturnsMass":true,"threeDraggedBallsAssemble":true,"automaticCursorAndPanelExit":true,"massConserved":true]
  try JSONSerialization.data(withJSONObject:result,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/shovel-result.json"));print("PASS: manual shovel, actual Cocoa event routing, 3 rolled balls, mass, Escape and automatic exit")
 }
}
