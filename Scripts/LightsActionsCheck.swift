import AppKit
import SnowCore
@testable import SnowPlay
// Compile alongside ChristmasStoryFixture.swift.
@main struct LightsCheck {static func main(){
 _=NSApplication.shared;let f=ChristmasStoryFixture(.garlandRemoval),w=f.w
 w.config.placements["offline"]=Placement(garland:[Vec(0.1,0.1)])
 w.config.placements[f.d.id]?.extraGarlands=[GarlandStrand(anchors:[Vec(0.2,0.2),Vec(0.8,0.2)])]
 w.garlandRemoval.deleteAll();w.garlandRemoval.deleteAll()
 precondition(!w.config.garland && w.config.placements.values.allSatisfy{$0.garland.isEmpty && ($0.extraGarlands ?? []).isEmpty})
 precondition(w.garlandRemoval.queue.isEmpty && w.garlandRemoval.reserved.isEmpty && w.decorations.stories.removalTarget==nil)
 w.config.garland=true;w.input.mode = .garland;w.input.addingGarlandAnchor=true
 precondition(w.handleWorldInput("garland-place:down",p:Vec(300,150),display:f.d,state:f.s))
 precondition(w.config.placements[f.d.id]?.garland.count==1 && w.input.mode == .none)
 w.garlandRemoval.deleteAll()
 precondition(w.config.placements[f.d.id]?.garland.isEmpty == true)
 print("PASS immediate deletion, repeated Delete All, off-screen/unfinished anchors, one anchor per Add");f.close()
}}
