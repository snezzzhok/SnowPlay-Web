import AppKit
import SnowCore
@testable import SnowPlay
@main struct ManualStoryCheck {static func main(){
 _=NSApplication.shared
 for id in ChristmasStoryID.allCases {
  guard let p=ManualStoryPlayback(id:id,variant:0,screen:NSScreen.screens.first!) else{fatalError("Cannot launch \(id)")}
  precondition(p.display.background.ignoresMouseEvents)
  let run=p.manager.stories.active!;var n=0
  while !p.closed && n<12000 {p.tick(dt:1.0/60);n+=1}
  precondition(run.succeeded,"Story failed \(id): \(run.interruption)")
  precondition(p.closed && p.manager.stories.active==nil)
  print("PASS manual",id.rawValue,n);fflush(stdout)
 }
}}
