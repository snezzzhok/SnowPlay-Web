import AppKit
import SpriteKit
import SnowCore

/// Bounded, pooled visual projection of ParticleEngine's weather. There is no second simulation.
/// Ground snow remains one heightfield/mesh; only airborne weather is batched by SpriteKit.
final class SnowSpriteCloud {
    let node=SKNode()
    private var sprites:[SKSpriteNode]=[]
    private let texture:SKTexture?
    private(set) var activeCount=0
    var pooledCount:Int {sprites.count}
    init(){
        node.name="desktop-snowfall";node.zPosition = -1000
        // Crop the transparent margin of the supplied standalone circle, never a concept image.
        if let source=AssetManager.shared.texture("snow_particle_1") {
            texture=SKTexture(rect:CGRect(x:11.5/32,y:11.5/32,width:9.0/32,height:9.0/32),in:source)
            texture?.filteringMode = .linear
        }else{texture=nil}
    }
    func present(particles:[Particle],bounds:Rect,menuInset:Double,config:Configuration,activeWindow:Rect?,ground:SnowSurface?,occluded:Bool){
        node.isHidden=occluded
        guard !occluded,let texture else{return}
        var count=0
        for particle in particles where particle.remaining<0 && particle.position.y>=bounds.y+menuInset {
            if config.mode == .focus,activeWindow?.contains(particle.position)==true {continue}
            let size=particle.size*config.snowSize
            if let ground,particle.position.y>ground.frame.y-ground.collisionHeight-5 {
                let top=ground.frame.y-ground.height(at:(particle.position.x-ground.frame.x)/max(1,ground.frame.width))
                if particle.position.y+size*0.42>=top {continue}
            }
            if count>=sprites.count {
                let sprite=SKSpriteNode(texture:texture);sprite.name="weather-flake";sprite.blendMode = .alpha;node.addChild(sprite);sprites.append(sprite)
            }
            let sprite=sprites[count]
            if sprite.isHidden {sprite.isHidden=false};sprite.position=CGPoint(x:particle.position.x-bounds.x,y:bounds.maxY-particle.position.y)
            let dimensions=CGSize(width:size*(size>4 ? 0.8:1),height:size)
            if sprite.size != dimensions {sprite.size=dimensions};if abs(Double(sprite.alpha)-particle.alpha)>0.0001 {sprite.alpha=particle.alpha}
            count+=1
        }
        if count<activeCount {for i in count..<min(activeCount,sprites.count) {sprites[i].isHidden=true}}
        activeCount=count
        // Small spare pool tolerates density-slider edits, while removed weather releases memory.
        while sprites.count>count+64 {sprites.removeLast().removeFromParent()}
    }
}
