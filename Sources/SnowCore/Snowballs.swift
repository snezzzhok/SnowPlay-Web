import Foundation
public struct Snowball {
    public let id: UUID
    public var position: Vec
    public var rotation=0.0
    public var radius: Double
    public init(position: Vec, radius: Double = 4) { id=UUID(); self.position=position; self.radius=clamp(radius,4,26) }
    public mutating func gather(volume: Double) { radius=min(26,sqrt(radius*radius+max(0,volume)/Double.pi)) }
}
public struct DesktopSnowman:Codable,Equatable {
    public var id:UUID,position:Vec,radii:[Double]
    public init(id:UUID=UUID(),position:Vec,radii:[Double]){self.id=id;self.position=position;self.radii=Array(radii.prefix(3)).map{clamp($0.isFinite ? $0:4,4,26)}}
    public var mass:Double {radii.reduce(0){$0+Double.pi*$1*$1}}
    public var height:Double {clamp(56*sqrt(max(1,mass)/(Double.pi*261)),35,96)}
    public var hitbox:Rect {Rect(position.x-height*0.28,position.y-height*0.5,height*0.56,height*0.95)}
}
public struct SnowballSystem {
    public static let maximumSnowmen=5
    public var primaryID=UUID()
    public var additionalSnowmen:[DesktopSnowman]=[]
    public var snowmen:[DesktopSnowman] {additionalSnowmen+(snowman.map{[DesktopSnowman(id:primaryID,position:$0,radii:assemblyBalls.map(\.radius))]} ?? [])}
    public var canBuild:Bool {snowmen.count<Self.maximumSnowmen}
    private mutating func archivePrimary(){if let p=snowman {additionalSnowmen.append(DesktopSnowman(id:primaryID,position:p,radii:assemblyBalls.map(\.radius)))};primaryID=UUID()}
    public mutating func select(_ id:UUID){
        guard id != primaryID,let i=additionalSnowmen.firstIndex(where:{$0.id==id}) else{return}
        let selected=additionalSnowmen.remove(at:i);if let p=snowman{additionalSnowmen.append(DesktopSnowman(id:primaryID,position:p,radii:assemblyBalls.map(\.radius)))}
        primaryID=selected.id;snowman=selected.position;assemblyBalls=selected.radii.map{Snowball(position:selected.position,radius:$0)}
    }
    @discardableResult public mutating func remove(_ id:UUID)->DesktopSnowman? {
        if id==primaryID,let p=snowman {let model=DesktopSnowman(id:id,position:p,radii:assemblyBalls.map(\.radius));snowman=nil;assemblyBalls=[];primaryID=UUID();return model}
        guard let i=additionalSnowmen.firstIndex(where:{$0.id==id}) else{return nil};return additionalSnowmen.remove(at:i)
    }
    public mutating func clearSnowmen(){snowman=nil;assemblyBalls=[];additionalSnowmen=[];primaryID=UUID()}

    public var balls: [Snowball] = []
    public var snowman: Vec?
    public var assemblyBalls: [Snowball] = []
    public init() {}
    public mutating func assemblePrepared(at p: Vec)->Bool {
        let sorted=balls.sorted { $0.radius>$1.radius }
        guard canBuild,sorted.count==3,sorted[0].radius>=10,sorted[1].radius>=7,sorted[2].radius>=4 else {return false}
        archivePrimary();assemblyBalls=sorted;balls=[];snowman=p;return true
    }
    public mutating func assemble(near p: Vec) -> Bool {
        guard canBuild,balls.count >= 3 else { return false }
        let nearby=balls.filter { ($0.position-p).length < 55 }.sorted { $0.radius > $1.radius }
        guard nearby.count >= 3, nearby[0].radius >= 10, nearby[1].radius >= 7, nearby[2].radius >= 4,
              nearby[0].radius >= nearby[1].radius, nearby[1].radius >= nearby[2].radius else { return false }
        archivePrimary();assemblyBalls=Array(nearby.prefix(3)); let ids=Set(assemblyBalls.map(\.id)); balls.removeAll { ids.contains($0.id) }; snowman=p; return true
    }
}
