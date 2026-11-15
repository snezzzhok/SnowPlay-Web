import Foundation

public enum ChristmasStoryID:String,Codable,CaseIterable {
    case presentTheft,lightRepair,snowballExchange,snowmanBuild,treeShake,santaDrop,snowmanParty,starHat,giftConveyor,tinyGift,garlandRemoval
    public var title:String {
        switch self {
        case .presentTheft:return "Yeti Steals a Present"
        case .lightRepair:return "Elves Fix the Lights"
        case .snowballExchange:return "Friendly Snowball Fight"
        case .snowmanBuild:return "Elves Build a Snowman"
        case .treeShake:return "Yeti Shakes the Tree"
        case .santaDrop:return "Santa Drops a Present"
        case .snowmanParty:return "Snowman Party"
        case .starHat:return "The Star and the Missing Hat"
        case .giftConveyor:return "Elves’ Gift Conveyor"
        case .tinyGift:return "Giant Yeti, Tiny Present"
        case .garlandRemoval:return "Garland Take-down"
        }
    }
    public var icon:String {
        switch self {case .presentTheft:return "gift_closed";case .lightRepair:return "story_toolbox";case .snowballExchange:return "snowball_large";case .snowmanBuild:return "snowman_stage_2";case .treeShake:return "tree_bare";case .santaDrop:return "santa_sleigh";case .snowmanParty:return "snowman_complete";case .starHat:return "story_star";case .giftConveyor:return "story_present_green";case .tinyGift:return "story_friend_red";case .garlandRemoval:return "fairy_bulb_gold"}
    }
    public var summary:String {
        switch self {
        case .presentTheft:return "A sneaky Yeti, two elves, and a very tempting present."
        case .lightRepair:return "A wobbly ladder and a little Christmas repair."
        case .snowballExchange:return "Five elves, ten Yetis, and two very big friends."
        case .snowmanBuild:return "Three real snowballs become a new winter friend."
        case .treeShake:return "Yeti shakes the branches — and gets a snowy surprise."
        case .santaDrop:return "Two helpful elves rescue Santa’s fallen present."
        case .snowmanParty:return "Warm lights, snowy hops, and a proper little dance."
        case .starHat:return "A big elf places a star and loses his hat."
        case .giftConveyor:return "A five-elf relay meets an oversized present."
        case .tinyGift:return "A giant opens a tiny box with a very small scarf."
        case .garlandRemoval:return "A high snowball unhooks one whole strand."
        }
    }
    public var needsTree:Bool {[.presentTheft,.lightRepair,.treeShake,.santaDrop,.starHat,.giftConveyor].contains(self)}
    public var automaticAllowed:Bool {self != .snowballExchange && self != .garlandRemoval}
    public var maximumDuration:Double {self == .snowballExchange ? 160:self == .giftConveyor ? 110:90}
    public var needsSnowman:Bool {[.snowballExchange,.snowmanParty].contains(self)}
}
public enum StoryFrequency:String,Codable,CaseIterable {
    case rare,normal,often
    public var interval:ClosedRange<Double> {switch self {case .rare:return 3600...5400;case .normal:return 1800...2700;case .often:return 600...1200}}
}
public struct StorySettings:Codable,Equatable {
    public var enabled=true,frequency=StoryFrequency.normal,sounds=false,allowSnowmanCreation=false,keepDecorations=false,pauseInFullscreen=true,pauseOnBattery=true
    public var enabledStories=ChristmasStoryID.allCases.filter(\.automaticAllowed).map(\.rawValue).sorted()
    public var reservedZones:[StoryReservedZone]=[]
    public init(){}
    public mutating func validate(){enabledStories=Array(Set(enabledStories).intersection(Set(ChristmasStoryID.allCases.map(\.rawValue)))).sorted();reservedZones=Array(reservedZones.prefix(16)).filter{$0.screen.count<128 && $0.rect.width>0 && $0.rect.height>0}.map{StoryReservedZone(screen:$0.screen,rect:Rect(clamp($0.rect.x,0,1),clamp($0.rect.y,0,1),clamp($0.rect.width,0,1),clamp($0.rect.height,0,1)))}}
}
public struct StoryReservedZone:Codable,Equatable {
    public var screen:String,rect:Rect
    public init(screen:String,rect:Rect){self.screen=screen;self.rect=rect}
}
public enum StoryLifecycle:String,Codable {case waiting,validating,reserving,spawning,playing,finishing,cleanup,completed,interrupted,failed}
public struct StoryLifecycleMachine {
    public private(set) var phase=StoryLifecycle.waiting
    public private(set) var transitions:[StoryLifecycle]=[.waiting]
    public init(){}
    @discardableResult public mutating func transition(_ next:StoryLifecycle)->Bool {
        let allowed:Bool
        switch (phase,next) {
        case (.waiting,.validating),(.validating,.reserving),(.reserving,.spawning),(.spawning,.playing),(.playing,.finishing),(.spawning,.interrupted),(.playing,.interrupted),(.finishing,.interrupted),(.interrupted,.cleanup),(.finishing,.cleanup),(.cleanup,.completed),(.validating,.failed),(.reserving,.failed),(.spawning,.failed),(.playing,.failed),(.failed,.cleanup):allowed=true
        default:allowed=false
        }
        guard allowed else{return false};phase=next;transitions.append(next);return true
    }
}
/// An exclusive lease covers both the stage and each persistent object, not just the actor.
public struct StoryReservations {
    public private(set) var owners:[String:UUID]=[:]
    public init(){}
    public mutating func acquire(_ keys:[String],owner:UUID)->Bool {
        guard keys.allSatisfy({owners[$0]==nil || owners[$0]==owner}) else{return false}
        for key in keys {owners[key]=owner};return true
    }
    public mutating func release(_ owner:UUID){owners=owners.filter{$0.value != owner}}
    public func isReserved(_ key:String)->Bool {owners[key] != nil}
}
public struct ChristmasStoryScheduler {
    public private(set) var eligibleSeconds=0.0,nextAt=600.0
    public private(set) var recent:[ChristmasStoryID]=[]
    private var random:SeededRandom
    public init(seed:UInt64=UInt64.random(in:1...UInt64.max)){random=SeededRandom(seed:seed)}
    public mutating func advance(_ dt:Double,eligible:Bool){if eligible,dt.isFinite,dt>0 {eligibleSeconds+=min(dt,1)}}
    public var due:Bool {eligibleSeconds>=nextAt}
    public mutating func choose(_ available:[ChristmasStoryID],enabled:[String])->ChristmasStoryID? {
        let allowed=available.filter{enabled.contains($0.rawValue)}
        guard !allowed.isEmpty else{return nil}
        let alternatives=allowed.filter{$0 != recent.last},pool=alternatives.isEmpty ? allowed:alternatives
        let fresh=pool.filter{!recent.suffix(3).contains($0)},choices=fresh.isEmpty ? pool:fresh
        return choices[min(choices.count-1,Int(random.unit()*Double(choices.count)))]
    }
    public mutating func didStart(_ id:ChristmasStoryID,frequency:StoryFrequency){recent.append(id);recent=Array(recent.suffix(5));schedule(frequency)}
    public mutating func schedule(_ frequency:StoryFrequency){let range=frequency.interval;nextAt=eligibleSeconds+range.lowerBound+random.unit()*(range.upperBound-range.lowerBound)}
    public mutating func retryLater(){nextAt=eligibleSeconds+30}
}
public struct StoryBeat {
    public let id:String,minimumDuration:Double,arrivals:Set<String>
    public init(_ id:String,_ duration:Double,arrivals:[String]=[]){self.id=id;minimumDuration=duration;self.arrivals=Set(arrivals)}
}
/// Contact events are emitted by arrival/prop logic. A beat cannot finish on a clock alone if it requires contact.
public struct StoryTimeline {
    public let beats:[StoryBeat]
    public private(set) var index=0,elapsed=0.0,totalElapsed=0.0
    public init(_ beats:[StoryBeat]){self.beats=beats}
    public var current:StoryBeat? {index<beats.count ? beats[index]:nil}
    public var complete:Bool {index>=beats.count}
    @discardableResult public mutating func step(_ dt:Double,arrived:Set<String>)->Bool {
        guard let beat=current else{return false};let h=max(0,min(dt,0.1));elapsed+=h;totalElapsed+=h
        if elapsed+0.00001>=beat.minimumDuration,beat.arrivals.isSubset(of:arrived){index+=1;elapsed=0;return true};return false
    }
}
public enum StoryStagePlanner {
    /// A single unobstructed stage avoids routing characters through real applications.
    public static func stage(bounds:Rect,focus:Vec,width:Double=620,height:Double=230,blocked:[Rect])->Rect? {
        guard bounds.width>=420,bounds.height>=height+40 else{return nil}
        let w=min(width,bounds.width-24),h=min(height,bounds.height-52)
        for fraction in [0.5,0.25,0.75,0.0,1.0] {
            let x=clamp(focus.x-w*fraction,bounds.x+12,bounds.maxX-w-12),y=min(bounds.maxY-h-3,max(bounds.y+30,focus.y-h+34))
            let rect=Rect(x,y,w,h)
            if rect.contains(focus),!blocked.contains(where:{$0.intersects(rect)}){return rect}
        };return nil
    }
    public static func clipped(_ rect:Rect,to bounds:Rect)->Bool {rect.x<bounds.x || rect.maxX>bounds.maxX || rect.y<bounds.y || rect.maxY>bounds.maxY}
}
public struct StoryBody {
    public var id:String,position:Vec,radius:Double
    public init(_ id:String,_ position:Vec,radius:Double=16){self.id=id;self.position=position;self.radius=radius}
}
public enum StoryCollisionAvoidance {
    /// Deterministic separation; performed only for the at most three story actors.
    public static func resolve(_ bodies:[StoryBody],bounds:Rect)->[Vec] {
        var p=bodies.map(\.position)
        for _ in 0..<4 {for i in p.indices {for j in p.indices where j>i {
            let delta=p[j]-p[i],gap=bodies[i].radius+bodies[j].radius+5,length=delta.length
            if length<gap {let direction=length>0.001 ? delta/length:Vec(1,0),push=direction*((gap-length)/2);p[i]=p[i]-push;p[j]=p[j]+push}
        }}}
        for i in p.indices {p[i].x=clamp(p[i].x,bounds.x+bodies[i].radius,bounds.maxX-bodies[i].radius)};return p
    }
}
