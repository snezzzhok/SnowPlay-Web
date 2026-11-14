import AppKit
import SpriteKit
import SnowCore
extension DecorationManager {
    @discardableResult func startYetiActivity(_ kind:String,display d:DisplayOverlay,target:Vec,surfaces:SurfaceManager,feetAt x:Double?=nil)->Bool {
        guard !livingBusy,let s=states[d.id] else{return false}
        let l=s.living,feetX=clamp(x ?? (target.x-60),d.rect.x+55,d.rect.maxX-55)
        var feet=Vec(feetX,groundY(feetX,display:d,surfaces:surfaces))
        if kind=="feed" {
            guard (surfaces.surfaces["ground-"+d.id]?.volume ?? 0)>=Double.pi*16 else{return false}
            l.activityMass=surfaces.surfaces["ground-"+d.id]?.extract(volume:Double.pi*16,at:(feet.x-d.rect.x)/d.rect.width) ?? 0
            feet.y=groundY(feet.x,display:d,surfaces:surfaces)
        }
        l.activity=kind;l.activityElapsed=0;l.activityTarget=target;l.activityOrigin=feet;l.activityReleased=false;l.activityResult="";l.feedCaughtAt=nil
        let actor=LivingActor(yeti:true);l.activityActor=actor;s.root.addChild(actor.node)
        if kind=="feed" {let ball=Resources.layer("snowball_small",size:11);ball.position=d.local(feet+Vec(-50,-6));s.root.addChild(ball);l.activityBall=ball}
        else if kind=="dodge" {let marker=SKShapeNode(circleOfRadius:22);marker.strokeColor=NSColor(calibratedRed:0.5,green:0.79,blue:0.86,alpha:0.8);marker.fillColor=NSColor(calibratedRed:0.5,green:0.79,blue:0.86,alpha:0.08);marker.lineWidth=1.5;marker.position=d.local(target);s.root.addChild(marker);l.activityMarker=marker}
        return true
    }
    func updateYetiActivity(state s:DecorationState,display d:DisplayOverlay,dt:Double,now:Double,config:Configuration,surfaces:SurfaceManager,mouse:Vec) {
        let l=s.living
        guard let kind=l.activity,let actor=l.activityActor else{return}
        l.activityElapsed+=dt*0.4;let t=l.activityElapsed,feet=l.activityOrigin
        let entry=Vec(feet.x<d.rect.center.x ? d.rect.x-50:d.rect.maxX+50,feet.y)
        func ease(_ t:Double)->Double{let f=clamp(t,0,1);return f*f*(3-2*f)}
        let leave=max(3,kind=="feed" ? (l.feedCaughtAt.map{$0+1.7} ?? 8):3.0)
        var p=t<1 ? entry+(feet-entry)*ease(t):t>leave ? feet+(entry-feet)*ease((t-leave)/1.2):feet
        p.y=groundY(clamp(p.x,d.rect.x,d.rect.maxX),display:d,surfaces:surfaces)
        actor.node.position=d.local(p)
        let poseTime=t<1 || t>leave ? t:t<1.6 ? (t-1)*0.8/0.6:t<2.4 ? t-1.6:t-2.4
        actor.pose(t<1 || t>leave ? .run:t<1.6 ? .makeSnowball:kind=="feed" ? .idle:t<2.4 ? .throwBall:.celebrate,time:poseTime,facing:t<1 ? (feet.x>=entry.x ? 1:-1):t>leave ? (entry.x>=feet.x ? 1:-1):(l.activityTarget.x>=feet.x ? 1:-1),emotion:l.activityResult=="Nice dodge!" ? "surprised":"happy")
        if kind=="feed" {
            if let caught=l.feedCaughtAt {
                let age=t-caught,hand=actor.hand(in:s.root),handPoint=Vec(d.rect.x+hand.x,d.rect.maxY-hand.y)
                let destination=handPoint+Vec(-8,-2),f=ease(age/0.4),point=l.feedCaughtFrom+(destination-l.feedCaughtFrom)*f+Vec(0,-sin(min(1,age/0.8)*Double.pi)*12)
                l.activityBall?.position=d.local(point);l.activityBall?.setScale(1-clamp((age-0.7)/0.4,0,1))
                if age>=1.1,l.activityMass>0 {consumedSnowMass+=l.activityMass;l.activityMass=0;l.activityBall?.removeFromParent();l.activityBall=nil;l.activityResult="Yeti loved that!"}
            }
        }else{
            if t>=1.6 && !l.activityReleased {
                l.activityReleased=true;actor.held.isHidden=true
                let hand=actor.hand(in:s.root),from=Vec(d.rect.x+hand.x,d.rect.maxY-hand.y)
                l.activityShot=Projectile(from:from,to:l.activityTarget,duration:0.8,gravity:320)
                let ball=Resources.layer("snowball_small",size:8);l.activityBall=ball;s.root.addChild(ball)
            }
            if t>=1.6 && t<2.4,let path=l.activityShot {l.activityBall?.position=d.local(path.position(t-1.6))}
            if t>=2.4,l.activityBall != nil {
                l.activityBall?.removeFromParent();l.activityBall=nil;l.activityMarker?.removeFromParent();l.activityMarker=nil
                onDust?(l.activityTarget,d.id);l.activityResult=kind=="dodge" ? ((mouse-l.activityTarget).length>22 ? "Nice dodge!":"The snowball landed in the circle."):"Snow surprise!"
            }
        }
        appendSprites(from:actor.node,reference:s.root,to:d.actionCanvas);actor.node.isHidden=true
        if let ball=l.activityBall {appendSprites(from:ball,reference:s.root,to:d.actionCanvas);ball.isHidden=true}
        if t>=leave+1.2 {
            if l.activityMass>0 {onSnowFall?(SnowFallEvent([SnowChunk(feet,Vec(0,10),l.activityMass,fallsToGround:true)]),d.id);l.activityMass=0}
            l.activityActor?.node.removeFromParent();l.activityBall?.removeFromParent();l.activityMarker?.removeFromParent();l.activity=nil;l.activityActor=nil;l.activityBall=nil;l.activityMarker=nil
        }
    }
    func feedInput(_ event:String,p:Vec,display d:DisplayOverlay) {
        guard let s=states[d.id],s.living.activity=="feed",let actor=s.living.activityActor else{return}
        let l=s.living
        if event.hasSuffix(":down"){l.feedDragging=true}
        if l.feedDragging {l.activityBall?.position=d.local(p)}
        if event.hasSuffix(":up") {
            l.feedDragging=false;let hand=actor.hand(in:s.root),point=Vec(d.rect.x+hand.x,d.rect.maxY-hand.y)
            if (p-point).length<28 {l.feedCaughtAt=l.activityElapsed;l.feedCaughtFrom=p}
            else {l.activityBall?.position=d.local(l.activityOrigin+Vec(-50,-6))}
        }
    }
}
