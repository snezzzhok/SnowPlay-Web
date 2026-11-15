import AppKit
import SnowCore
@testable import SnowPlay
@main struct Stories3WindowCheck {static func main() throws {
 _=NSApplication.shared
 guard let index=CommandLine.arguments.firstIndex(of:"--window-pid"),let pid=Int32(CommandLine.arguments[index+1]) else{fatalError("Fixture pid required")}
 var checked:[String]=[]
 for id in ChristmasStoryID.allCases {
  let f=ChristmasStoryFixture(id);defer{f.close()};precondition(f.start(id)==nil);let run=f.w.decorations.stories.active!
  var windows:[TrackedWindow]=[]
  for _ in 0..<30 {f.w.observer.poll(now:ProcessInfo.processInfo.systemUptime,screens:[f.d.rect],trackAccessibility:false);windows=f.w.observer.sorted.filter{$0.pid==pid && $0.isVisible};if !windows.isEmpty {break};RunLoop.main.run(until:Date().addingTimeInterval(0.1))}
  precondition(!windows.isEmpty,"Actual WindowServer did not expose fixture; graphics session must be awake")
  precondition(windows.contains{$0.frame.intersects(run.stage.area)},"Fixture must cover own story stage")
  for _ in 0..<70 {f.step(windows)}
  precondition(run.finished && !run.succeeded && f.w.decorations.stories.reservations.owners.isEmpty)
  precondition(f.d.background.level.rawValue<NSWindow.Level.normal.rawValue && f.d.background.ignoresMouseEvents && f.d.foreground.ignoresMouseEvents)
  checked.append(id.rawValue)
 }
 try JSONSerialization.data(withJSONObject:["passed":true,"scope":"Real CGWindowList geometry from a separate owned AppKit test window, production observer and all eleven story controllers","stories":checked,"desktopLayerBelowApps":true,"clickThrough":true,"privateAPI":false],options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Docs/stories3-window-result.json"))
 print("PASS: eleven stories interrupt on actual WindowServer fixture geometry; desktop layers stay below apps and click through")
}}
