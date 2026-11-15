import AppKit
import SnowCore
@testable import SnowPlay
// Compile alongside Scripts/ChristmasStoryFixture.swift.
@main struct StoryItemPreparationCheck {
 static func main() {
  _=NSApplication.shared
  for id in ChristmasStoryID.allCases {
   let f=ChristmasStoryFixture(.tinyGift),w=f.w
   w.config.tree=false;w.config.garland=false;w.config.stories.allowSnowmanCreation=false
   w.prepareStoryItems(id)
   let check=w.decorations.stories.availability(id,manager:w.decorations,displays:[f.d],config:w.config,windows:[],dock:nil,surfaces:w.surfaces)
   precondition(check.available,"Preparation failed for \(id): \(check.reason)")
   let count=f.s.snowballs.snowmen.count,gifts=f.s.treePresents.count
   w.prepareStoryItems(id)
   precondition(count==f.s.snowballs.snowmen.count && gifts==f.s.treePresents.count,"Duplicate items")
   precondition(f.start(id)==nil,"Start after preparation")
   w.decorations.stories.stop(immediately:true)
   print("PASS",id.rawValue);f.close()
  }
 }
}
