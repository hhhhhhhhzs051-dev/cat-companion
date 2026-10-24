import Foundation

@main struct ToyRollInTests {
    static func check(_ condition:Bool,_ message:String) {
        if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)}
    }
    static func fresh(_ x:Double,high:Bool=false)->CatToy {
        var toy=CatToy(rollInEnabled:true)
        toy.start(0);toy.grab(1)
        toy.move(to:CGPoint(x:x,y:high ? 0.355:CatToy.groundY(x)),at:1.1)
        toy.release(1.2)
        return toy
    }
    static func matches(_ a:CatToyFrame,_ b:Build55ToyFrame)->Bool {
        let values=[a.position.x-b.position.x,a.position.y-b.position.y,a.opacity-b.opacity,
                    a.rotation-b.rotation,a.paw-b.paw,a.attention-b.attention,a.look-b.look,
                    a.pawElbow-b.pawElbow,a.pawWrist-b.pawWrist,
                    a.pawLift-b.pawLift,a.pawOffsetX-b.pawOffsetX]
        return values.allSatisfy{abs($0)<1e-9} && a.pawSide==b.pawSide && a.bodyRock==b.bodyRock
    }
    static func baselineComparisons() {
        for enabled in [false,true] {
            for n in 0...180 {
                let x=0.41+Double(n)*0.002
                if enabled && !(0.536...0.684).contains(x) && (0.478...0.742).contains(x) {continue}
                for high in [false,true] {
                    var toy=CatToy(rollInEnabled:enabled),old=Build55Toy()
                    toy.start(0);old.start(0);toy.grab(1);old.grab(1)
                    let p=CGPoint(x:x,y:high ? 0.355:CatToy.groundY(x))
                    toy.move(to:p,at:1.1);old.move(to:p,at:1.1)
                    toy.release(1.2);old.release(1.2)
                    for i in 0...180 {
                        let time=1.2+Double(i)/60
                        check(matches(toy.frame(time),old.frame(time)),"Accepted/default ball and cat frames unchanged at x=\(x), enabled=\(enabled), t=\(time)")
                    }
                }
            }
        }
        // Preserve the enter/leave buffer and handedness during a single drag.
        var toy=CatToy(rollInEnabled:true),old=Build55Toy()
        toy.start(0);old.start(0)
        for (turn,x) in [0.55,0.532,0.60,0.62,0.67,0.691,0.63,0.59].enumerated() {
            let t=1+Double(turn)*2
            toy.grab(t);old.grab(t)
            let p=CGPoint(x:x,y:CatToy.groundY(x))
            toy.move(to:p,at:t+0.1);old.move(to:p,at:t+0.1)
            if toy.dragZone == .watch {continue}
            toy.release(t+0.2);old.release(t+0.2)
            for i in 0...100 {
                let time=t+0.2+Double(i)/60
                check(matches(toy.frame(time),old.frame(time)),"Direct continuous switching retains original frames")
            }
        }
        print("PASS frozen build55: disabled path, direct push/pull/switch, accepted margins and extreme watch frames unchanged")
    }
    static func interruptions() {
        for x in [0.50,0.72] {
            for elapsed in [0.04,0.12,0.24] {
                var toy=fresh(x)
                let time=1.2+elapsed,before=toy.frame(time)
                toy.grab(time)
                let grabbed=toy.frame(time)
                check(before.position==grabbed.position && before.rotation==grabbed.rotation,"Regrab takes over the exact rolling position and rotation")
                let destination=x<0.61 ? 0.67:0.55
                toy.move(to:CGPoint(x:destination,y:CatToy.groundY(destination)),at:time+0.01);toy.release(time+0.02)
                for i in 0...200 {_=toy.frame(time+0.02+Double(i)/120)}
                check(toy.hits==1,"Cancelled roll cannot trigger a second stale strike")
                var parked=fresh(x)
                let at=parked.frame(time);parked.park(time)
                check(parked.frame(time).position==at.position && parked.frame(time).rotation==at.rotation,"Petting parks the moving ball without teleporting")
                for i in 0...300 {_=parked.frame(time+Double(i)/60)}
                check(parked.hits==0 && !parked.isEngaged(time+5),"Petting cancels rather than queues the roll/strike")
                var reduced=fresh(x)
                let visible=reduced.frame(time)
                let stopped=reduced.frame(time,reduced:true)
                check(stopped.position==visible.position && stopped.rotation==visible.rotation,"Reduced motion freezes the current surface position")
                for i in 0...180 {_=reduced.frame(time+Double(i)/60)}
                check(reduced.hits==0,"Restoring motion never resumes a cancelled assist")
            }
            var quiet=fresh(x)
            let reduced=quiet.frame(1.25,reduced:true)
            check(reduced.position.x==x && quiet.hits==0,"Reduced motion from the first frame never starts roll-in")
            var high=fresh(x,high:true)
            check(high.frame(1.2).position.y==0.355,"Accepted high release starts at the pointer")
            check(high.frame(1.28).position.x==x,"High release falls vertically before rolling")
            check((high.frame(1.4).position.x-x)*(x<0.61 ? 1:-1)>0,"Surface roll begins after the accepted 160ms fall")
            var busy=fresh(x)
            for i in 0...120 {_=busy.frame(1.2+Double(i)/120,canBat:false)}
            check(busy.hits==0,"Existing cat action is never interrupted by a new ball")
            for i in 0...180 {_=busy.frame(2.3+Double(i)/120)}
            check(busy.hits==1,"Cat can receive the now-grounded ball after its current action")
            var hidden=fresh(x);_=hidden.frame(1.3);hidden.finish(1.3,immediate:true)
            check(!hidden.isPresent && hidden.hits==0,"Hide/rest discards roll state")
            hidden.start(2);hidden.grab(2.1);hidden.move(to:CGPoint(x:x,y:CatToy.groundY(x)),at:2.2);hidden.release(2.3)
            for i in 0...180 {_=hidden.frame(2.3+Double(i)/120)}
            check(hidden.hits==1,"Preview remains enabled after taking the ball out again")
        }
        print("PASS roll-in interruption: regrab, reversal, pet park, reduced motion, falling, busy cat, hide and fresh session")
    }
    static func originalStrokeAfterRoll() {
        for x in [0.48,0.52,0.70,0.74] {
            var toy=fresh(x)
            var hitTime=0.0,landed=CatToyFrame()
            for i in 0...120 {
                let time=1.2+Double(i)/120,f=toy.frame(time)
                if toy.hits==1 {hitTime=time;landed=f;break}
            }
            check(hitTime>0,"Assisted release reaches the accepted strike phase")
            var old=Build55Toy();old.start(-2);old.grab(-1)
            old.move(to:landed.position,at:-0.5);old.release(0);_=old.frame(0.08)
            for i in 0...168 {
                let age=Double(i)/120,new=toy.frame(hitTime+age),baseline=old.frame(0.08+age)
                let deltas=[new.position.x-baseline.position.x,new.position.y-baseline.position.y,
                            new.paw-baseline.paw,new.pawElbow-baseline.pawElbow,new.pawWrist-baseline.pawWrist,
                            new.rotation-landed.rotation-baseline.rotation]
                check(deltas.allSatisfy{abs($0)<1e-9} && new.pawSide==baseline.pawSide,"After roll-in the original strike, ball trajectory and timing are unchanged")
            }
        }
        print("PASS assisted contact reuses exact build55 joint path, strike timing and post-contact ball motion")
    }
    static func main() {
        for x in [0.48,0.50,0.52,0.70,0.72,0.74] {
            var toy=fresh(x)
            let released=toy.frame(1.2),first=toy.frame(1.24)
            let direction=x<0.61 ? 1.0:-1.0
            check(released.position.x==x,"Release cannot teleport the ball")
            check((first.position.x-x)*direction>0.0001,"Slightly far ball begins rolling inward immediately after release: \(x)")
            check(abs(first.position.x-x)*290<4,"Roll-in has no multi-pixel snap")
            var prior=released,firstPaw:Double?=nil
            for i in 1...360 {
                let t=Double(i)/120,f=toy.frame(1.2+t)
                check(abs(f.position.y-CatToy.groundY(f.position.x))<1e-9,"Rolling stays on the bed surface")
                check(f.bodyRock==0 && f.pawOffsetX==0 && f.pawLift==0,"Roll-in never shifts the body or stretches the paw")
                check(abs(f.position.x-prior.position.x)*290<1.5,"Ball path remains continuous at 120Hz")
                if f.paw>0.001 && firstPaw==nil {
                    firstPaw=t
                    check(CatToyReach(f.position).contacts,"Paw starts only once the ball is truly reachable")
                    check(abs(f.position.x-x)*290<=18,"Assistance remains a short local roll, not a return to center")
                    check(f.pawSide == (x<0.61 ? -1:1),"The same-side paw receives the ball")
                    check(abs(f.rotation)>0.01,"Ball rotates with its inward travel")
                }
                prior=f
            }
            check(firstPaw != nil && firstPaw!<0.65,"One roll connects promptly to the original stroke")
            check(toy.hits==1 && abs(prior.position.x-0.61)<0.0001,"Original pull returns the ball and strikes only once")
            for i in 0...1200 {_=toy.frame(4.2+Double(i)/60)}
            check(toy.hits==1 && !toy.isEngaged(24.2),"No autonomous return loop or permanent active rendering")
        }
        print("PASS short roll-in: immediate continuous surface travel, true same-side contact, bounded distance, one strike and quiet idle")
        baselineComparisons()
        interruptions()
        originalStrokeAfterRoll()
    }
}
