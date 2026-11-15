import AppKit
import SpriteKit
import SnowCore
enum StoryDecorationsArt {
    static let footprint:CGImage? = {
        guard let source=AssetManager.shared.image("snow_clump_0"),let context=CGContext(data:nil,width:64,height:32,bitsPerComponent:8,bytesPerRow:256,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
        context.draw(source,in:CGRect(x:0,y:0,width:64,height:32));context.setBlendMode(.sourceIn);context.setFillColor(CGColor(red:0.42,green:0.61,blue:0.73,alpha:1));context.fill(CGRect(x:0,y:0,width:64,height:32));return context.makeImage()
    }()

    static func partyLights(height h:Double)->SKNode {
        let lights=SKNode();lights.name="story-party-lights"
        for i in 0..<5 {let node=Resources.layer(i%2==0 ? "fairy_bulb_gold":"fairy_bulb_blue",size:7);node.position=CGPoint(x:Double(i-2)*h*0.075,y:-h*0.15-abs(Double(i-2))*h*0.025);lights.addChild(node)}
        return lights
    }
}
extension DecorationManager {
    func restoreStoryDecorations(state s:DecorationState,display d:DisplayOverlay,config:Configuration,now:Double,surfaces:SurfaceManager){
        let placement=config.placements[d.id]
        if !s.storyGiftsRestored {
            s.storyGiftsRestored=true
            if config.tree {for saved in placement?.storyPresents ?? [] {
                let x=d.rect.x+saved.position.x*d.rect.width,p=Vec(x,groundY(x,display:d,surfaces:surfaces)-(saved.height ?? 26)*0.425)
                let node=Resources.layer("story_present_"+saved.variant,size:saved.height ?? 26);node.position=d.local(p);s.root.addChild(node)
                s.treePresents.append(TreePresent(id:saved.id,node:node,position:p,placedAt:now-1,variant:saved.variant,artHeight:saved.height ?? 26))
            }}
        }
        for m in s.snowballs.snowmen where (placement?.storyPartySnowmen ?? []).contains(m.id.uuidString) {
            guard let node=s.snowmanVisualID==m.id ? s.snowmanNode:s.extraSnowmanNodes[m.id],node.childNode(withName:"story-party-hat")==nil else{continue}
            let hat=Resources.layer("story_party_hat",size:18);hat.name="story-party-hat";hat.position=CGPoint(x:0,y:m.height*0.38);node.addChild(hat);node.childNode(withName:"snowman_hat")?.alpha=0
            let scarf=Resources.layer("story_scarf",size:9);scarf.name="story-party-scarf";scarf.position=CGPoint(x:0,y:m.height*0.03);node.addChild(scarf);node.addChild(StoryDecorationsArt.partyLights(height:m.height))
        }
    }
}
