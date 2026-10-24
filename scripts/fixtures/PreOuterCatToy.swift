// Frozen 2026-10-16 simplified preview before outer-reach work.
import Foundation
import CoreGraphics

struct PreOuterFrame: Equatable {
    var position=CGPoint(x:0.61,y:0.395)
    var opacity=0.0, paw=0.0, attention=0.0, rotation=0.0
    var pawLift=0.0, pawOffsetX=0.0
    var pawElbow=1.5, pawWrist=0.0, look=0.0
    var bodyRock:Double {0}
    // Screen-relative side, fixed for the complete strike and its retraction.
    var pawSide=1
    static func pawTransform(_ side:Int)->CGAffineTransform {
        // The source is the cat's right paw, attached on screen left. Keep it
        // untouched there; reflect only the paw for screen right about the
        // existing chest pocket (0.61 * 1525 - 135 = 795.25 art units).
        side<0 ? .identity:CGAffineTransform(translationX:1590.5,y:0).scaledBy(x:-1,y:1)
    }
}

// Two-link reach from the existing hidden forearm attachment, in original-art
// coordinates. A target outside the limb's comfortable range is not a contact.
struct PreOuterReach {
    enum Kind {case watch, tap, reach}
    enum Stroke {case push, pull}
    enum Zone {case watch, push, pull}
    var kind=Kind.watch
    var stroke=Stroke.push
    var elbow=1.5, wrist=0.0
    var approachElbow=1.5, approachWrist=0.0
    var followElbow=1.5, followWrist=0.0
    var direction=1.0
    var travel=0.0
    var pawSide=1
    var zone:Zone {contacts ? (stroke == .push ? .push:.pull):.watch}
    var contactTime:Double {kind == .tap ? 0.32:0.52}
    var contacts:Bool {kind == .tap || kind == .reach}
    // Sample the same grounded planner once, never on every pointer event.
    private static let guideSpans:[ClosedRange<Double>] = [Zone.watch,.push,.pull].map { previous in
        let xs=(0...360).map{0.41+Double($0)/1000}.filter {
            PreOuterReach(CGPoint(x:$0,y:PreOuterToy.groundY($0)),previous:previous).contacts
        }
        return (xs.first ?? 0.61)...(xs.last ?? 0.61)
    }
    static func guideSpan(for zone:Zone)->ClosedRange<Double> {
        guideSpans[zone == .watch ? 0:(zone == .push ? 1:2)]
    }
    private static let workspace:[(elbow:Double,wrist:Double,pad:CGPoint)] = {
        var points:[(Double,Double,CGPoint)]=[]
        // Original limb dimensions and root, in the cat's own coordinate space.
        for i in 0...18 {
            let e=0.04+Double(i)*0.025
            for j in 0...20 {
                let w = -1.15+Double(j)*0.065
                let pad=CGPoint(x:605+148*cos(e)+58*sin(e)+47*cos(e+w)+42*sin(e+w),
                                y:850+148*sin(e)-58*cos(e)+47*sin(e+w)-42*cos(e+w))
                guard pad.y>=735 else{continue}
                points.append((e,w,pad))
            }
        }
        return points
    }()
    private static func solve(_ target:CGPoint,approaching contact:CGPoint?=nil)->(elbow:Double,wrist:Double,pad:CGPoint) {
        var best=Double.infinity,bestPad=CGPoint.zero,bestElbow=0.0,bestWrist=0.0
        for (e,w,pad) in workspace {
            // Joint limits must not collapse the over-ball preparation and
            // contact into the same pose (notably on left-side pulls).
            if let contact, (hypot(pad.x-contact.x,pad.y-contact.y)<18 || pad.y>contact.y+6) {continue}
            let cost=hypot(pad.x-target.x,pad.y-target.y)
            if cost<best {best=cost;bestPad=pad;bestElbow=e;bestWrist=w}
        }
        return (bestElbow,bestWrist,bestPad)
    }
    init(_ ball:CGPoint,previous:Zone?=nil,previousSide:Int?=nil) {
        let worldCenter=CGPoint(x:ball.x*1525-135,y:ball.y*1525+165)
        // The chest-front pocket is the reference, not a screen edge. Choose
        // once per release; the ball crossing this boundary never replans it.
        let pocket=previous == .push ? 0.030:(previous == .pull ? 0.018:0.024)
        stroke=abs(ball.x-0.61)<=pocket ? .push:.pull
        direction=(ball.x<0.61 ? -1.0:1.0)*(stroke == .push ? 1:-1)
        let corridor=previous == .pull ? 0.475...0.715:0.49...0.705
        guard corridor.contains(ball.x) else{return}
        pawSide=abs(ball.x-0.61)<0.010 ? (previousSide ?? (ball.x<0.61 ? -1:1)):(ball.x<0.61 ? -1:1)
        let center=worldCenter.applying(PreOuterFrame.pawTransform(pawSide).inverted())
        let localDirection=direction*(pawSide<0 ? 1.0:-1.0)
        let contact=Self.solve(CGPoint(x:center.x-localDirection*12,y:center.y-14))
        // Keep a small enter/leave buffer inside the original 70-unit physical
        // contact limit, rather than extending the limb at the outer boundary.
        guard hypot(contact.pad.x-center.x,contact.pad.y-center.y)<=(previous == .pull ? 70:60) else{return}
        let originalReach=Self.solve(CGPoint(x:center.x-12,y:center.y-14))
        kind=stroke == .pull || hypot(originalReach.pad.x-605,originalReach.pad.y-850)>=200 ? .reach:.tap
        elbow=contact.elbow;wrist=contact.wrist
        travel=stroke == .pull ? abs(ball.x-0.61):(kind == .tap ? 0.085:0.13)
        let approach=Self.solve(CGPoint(x:center.x-localDirection*18,y:center.y-32),approaching:contact.pad)
        approachElbow=approach.elbow;approachWrist=approach.wrist
        let follow=Self.solve(CGPoint(x:contact.pad.x+localDirection*35,y:contact.pad.y+6))
        followElbow=follow.elbow;followWrist=follow.wrist
        if stroke == .pull {
            // A small wrist turn presents the paw slightly farther outside the
            // ball (about 2–3pt at normal size), without moving the root or
            // stretching the limb. The unchanged follow-through brings it back
            // inward smoothly; push poses and all timing stay untouched.
            wrist -= 0.22
            approachWrist -= 0.22
        }
    }
}

// Positions are normalized to artwork width, below the 60pt speech area.
struct PreOuterToy {
    private(set) var isOut=false
    private(set) var dragging=false
    private(set) var hits=0
    private var position=PreOuterFrame().position
    private var started=0.0, lastInput=0.0, movedAt = -Double.infinity
    private var releasedAt=Double.infinity, hitAt = -Double.infinity
    private var moved=false, armed=false, rolling=false
    private var hitFrom=CGPoint.zero
    private var exitAt=Double.infinity
    private var exitFrame=PreOuterFrame()
    private var retractAt=Double.infinity, rotation=0.0
    private var retractFrame=PreOuterFrame()
    private var reach=PreOuterReach(PreOuterFrame().position)
    private var dragPlan=PreOuterReach(PreOuterFrame().position)
    private var gaze=0.0,gazeAt=0.0,attentionValue=0.0
    private var fallAt=Double.infinity,fallFrom=CGPoint.zero
    private var parked=false,parkAt=Double.infinity
    private var parkFrame=PreOuterFrame()
    private static let fallDuration=0.16
    var isPresent:Bool {isOut || exitAt.isFinite}
    var guide:ClosedRange<Double>? {isOut && dragging ? PreOuterReach.guideSpan(for:dragPlan.zone):nil}
    func isEngaged(_ now:Double)->Bool {
        isPresent && (!isOut || dragging || armed || (!parked && now<lastInput+4.5) || (parked && now<parkAt+0.5))
    }
    var dragZone:PreOuterReach.Zone? {isOut && dragging ? dragPlan.zone:nil}
    private static func smooth(_ t:Double)->Double {let x=max(0,min(1,t));return x*x*(3-2*x)}
    static func groundY(_ x:Double)->Double {
        // Existing cubic front rim: M-98 625 C-98 872 1348 872 1348 625.
        let rimX=(x*1525-37)/1446
        var lo=0.0,hi=1.0
        for _ in 0..<16 {let t=(lo+hi)/2;if smooth(t)<rimX {lo=t}else{hi=t}}
        let t=(lo+hi)/2,rimY=(625+741*t*(1-t)-165)/1525
        return rimY-0.027
    }
    private static func grounded(_ point:CGPoint)->CGPoint {
        let x=max(0.41,min(0.77,point.x))
        return CGPoint(x:x,y:groundY(x))
    }
    private static func bounded(_ point:CGPoint)->CGPoint {
        let ground=grounded(point)
        return CGPoint(x:ground.x,y:max(0.355,min(ground.y,point.y)))
    }
    private func visual(_ now:Double,reduced:Bool)->PreOuterFrame {
        if !isOut {
            var f=exitFrame
            let weight=1-Self.smooth((now-exitAt)/0.5)
            f.opacity *= weight;f.paw *= weight;f.pawLift *= weight;f.attention *= weight
            f.pawElbow=1.5+(f.pawElbow-1.5)*weight;f.pawWrist *= weight;f.look *= weight
            return exitAt.isFinite && !reduced ? f:PreOuterFrame()
        }
        if parked {
            var f=parkFrame
            if fallAt.isFinite && !reduced {
                let t=max(0,min(1,(now-fallAt)/Self.fallDuration)),fall=t+t*t-t*t*t
                f.position=CGPoint(x:position.x,y:fallFrom.y+(position.y-fallFrom.y)*fall)
            }
            // Same half-second paw/attention exit as the accepted finish path;
            // only the ball remains on the bed instead of disappearing.
            let weight=reduced ? 0:1-Self.smooth((now-parkAt)/0.5)
            f.opacity=1;f.paw *= weight;f.pawLift *= weight;f.attention *= weight
            f.pawElbow=1.5+(f.pawElbow-1.5)*weight;f.pawWrist *= weight;f.look *= weight
            return f
        }
        let age=now-hitAt
        let rollAge=max(0,min(1,(age-reach.contactTime)/0.65))
        let roll=rolling && !reduced ? 1-pow(1-rollAge,3):0
        // The direction and joint path were planned together at release.
        let destination=Self.grounded(CGPoint(x:hitFrom.x+reach.direction*reach.travel,y:hitFrom.y))
        var p=rolling && !reduced ? Self.grounded(CGPoint(x:hitFrom.x+(destination.x-hitFrom.x)*roll,y:hitFrom.y)):position
        if fallAt.isFinite && !reduced {
            let t=max(0,min(1,(now-fallAt)/Self.fallDuration))
            // A visible initial velocity removes the apparent hover at normal
            // size; accelerate briefly, then settle softly without a bounce.
            let fall=t+t*t-t*t*t
            p=CGPoint(x:position.x,y:fallFrom.y+(position.y-fallFrom.y)*fall)
        }
        let start=0.0
        let extend=Self.smooth((age-start)/(reach.contactTime-start))
        let settle=1-Self.smooth((age-reach.contactTime-0.12)/(reach.kind == .tap ? 0.48:0.66))
        let strength=reduced || reach.kind == .watch ? 0:extend*settle
        var elbow=reach.elbow,wrist=reach.wrist
        if reach.stroke == .pull && age<reach.contactTime {
            // Reach over the ball, then settle the wrist onto it before drawing
            // back. This is a distinct hook, not a reversed push animation.
            let progress=max(0,(age-start)/(reach.contactTime-start))
            if progress<0.72 {
                let t=Self.smooth(progress/0.72)
                elbow=1.5+(reach.approachElbow-1.5)*t
                wrist=reach.approachWrist*t
            } else {
                let t=Self.smooth((progress-0.72)/0.28)
                elbow=reach.approachElbow+(reach.elbow-reach.approachElbow)*t
                wrist=reach.approachWrist+(reach.wrist-reach.approachWrist)*t
            }
        } else {
            let t=Self.smooth((age-reach.contactTime)/0.18)
            elbow += (reach.followElbow-reach.elbow)*t
            wrist += (reach.followWrist-reach.wrist)*t
            elbow=1.5+(elbow-1.5)*extend;wrist *= extend
        }
        var f=PreOuterFrame(position:p,opacity:reduced ? 1:Self.smooth((now-started)/0.22),paw:strength,attention:reduced ? 0:attentionValue,
                          rotation:rotation+roll*(destination.x-hitFrom.x)/0.027,
                          pawElbow:reduced ? 1.5:1.5+(elbow-1.5)*settle,pawWrist:reduced ? 0:wrist*settle,
                          look:reduced ? 0:gaze,pawSide:reach.pawSide)
        if retractAt.isFinite {
            let weight=reduced ? 0:1-Self.smooth((now-retractAt)/0.35)
            f.paw=retractFrame.paw*weight;f.pawLift=retractFrame.pawLift*weight;f.pawOffsetX=retractFrame.pawOffsetX
            f.pawElbow=1.5+(retractFrame.pawElbow-1.5)*weight;f.pawWrist=retractFrame.pawWrist*weight
            f.pawSide=retractFrame.pawSide
        }
        return f
    }
    mutating func start(_ now:Double) {
        let previous=isPresent && !isOut ? visual(now,reduced:false):nil
        self=PreOuterToy();isOut=true;started=now;lastInput=now;gazeAt=now
        position=Self.grounded(position)
        if let previous {
            retractAt=now;retractFrame=previous
            gaze=previous.look;attentionValue=previous.attention
        }
    }
    mutating func grab(_ now:Double) {
        guard isOut else{return}
        let current=visual(now,reduced:false)
        parked=false
        position=current.position;rotation=current.rotation;rolling=false;fallAt = .infinity
        retractAt=now;retractFrame=current
        dragging=true;armed=true;lastInput=now
        dragPlan=PreOuterReach(Self.grounded(position))
        if !moved {movedAt=now};moved=true
    }
    mutating func move(to point:CGPoint,at now:Double) {
        guard isOut,dragging,point.x.isFinite,point.y.isFinite else{return}
        let p=Self.bounded(point)
        guard hypot(p.x-position.x,p.y-position.y)>0.002 else{return}
        if now-lastInput>1 || !moved {movedAt=now}
        position=p;lastInput=now;moved=true;armed=true
        dragPlan=PreOuterReach(Self.grounded(position),previous:dragPlan.zone,previousSide:dragPlan.pawSide)
    }
    mutating func release(_ now:Double) {
        guard isOut,dragging else{return}
        dragging=false;lastInput=now;releasedAt=now
        fallFrom=position;position=Self.grounded(position)
        fallAt=abs(position.y-fallFrom.y)>0.00001 ? now:.infinity
    }
    mutating func park(_ now:Double,reduced:Bool=false) {
        guard isOut else{return}
        lastInput=now
        guard !parked else{return}
        parkFrame=visual(now,reduced:reduced)
        position=Self.grounded(parkFrame.position);rotation=parkFrame.rotation
        if reduced || !fallAt.isFinite {parkFrame.position=position}
        parkAt=now;parked=true;dragging=false;armed=false;rolling=false;moved=true
        releasedAt = .infinity;hitAt = -.infinity
    }
    mutating func finish(_ now:Double,immediate:Bool=false) {
        if immediate {self=PreOuterToy();return}
        guard isOut else{return}
        exitFrame=visual(now,reduced:false);exitAt=now
        isOut=false;dragging=false;armed=false
    }
    mutating func frame(_ now:Double,reduced:Bool=false,canBat:Bool=true)->PreOuterFrame {
        let attentionTarget=reduced || !canBat || !isOut || !moved ? 0:Self.smooth((now-movedAt)/0.2)*(1-Self.smooth((now-lastInput-1.5)/1.2))
        let target=max(-1,min(1,(visual(now,reduced:reduced).position.x-0.61)/0.12))*attentionTarget
        let dt=max(0,min(0.1,now-gazeAt));gazeAt=now
        // Filter the visible response, not a latent direction multiplied by a
        // resetting envelope. Regrab then starts from the current head/ears.
        gaze=reduced ? 0:gaze+(target-gaze)*(1-exp(-dt/0.16))
        attentionValue=reduced ? 0:attentionValue+(attentionTarget-attentionValue)*(1-exp(-dt/0.12))
        // A settled ball must not keep microscopic gaze deltas invalidating the
        // cat-only idle cache forever. This is after the accepted active response.
        if !isEngaged(now) {gaze=0;attentionValue=0}
        if fallAt.isFinite && (reduced || now>=fallAt+Self.fallDuration) {
            fallAt = .infinity
            if parked {parkFrame.position=position}
        }
        if isOut && !dragging && now>=lastInput+30 {finish(lastInput+30,immediate:reduced)}
        if exitAt.isFinite && now>=exitAt+0.5 {exitAt = .infinity;exitFrame=PreOuterFrame()}
        if reduced {armed=false;rolling=false;hitAt = -.infinity}
        // A fresh gesture replaces the old cooldown. Only wait for physical
        // landing/retraction, never a stale hit timestamp from a cancelled stroke.
        let retracted = !retractAt.isFinite || retractFrame.paw==0 || now>=retractAt+0.35
        if isOut && !dragging && !fallAt.isFinite && armed && !reduced && canBat && now>=releasedAt+0.08 && retracted {
            armed=false;hitAt=now;hitFrom=position;reach=dragPlan
            rolling=reach.contacts;retractAt = .infinity
            if reach.contacts {hits += 1}
        }
        return visual(now,reduced:reduced)
    }
}
