import Foundation

@main struct ToyContinuityTests {
    static func main() {
        var failures=0
        func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);failures += 1}}
        var toy=CatToy();toy.start(0)
        toy.grab(0.3);toy.move(to:CGPoint(x:0.57,y:0.395),at:0.4);toy.release(0.5)
        for n in 31...180 {_=toy.frame(Double(n)/60)}
        toy.grab(3.01);toy.move(to:CGPoint(x:0.77,y:0.38),at:3.02);toy.release(3.03)
        for n in 182...390 {_=toy.frame(Double(n)/60)}
        let before=toy.frame(6.501);toy.grab(6.501)
        let grabbed=toy.frame(6.501)
        check(abs(grabbed.look-before.look)<0.0001 && abs(grabbed.attention-before.attention)<0.0001,"Regrabbing after near/far/rest preserves visible head and ear attention")
        var previous=grabbed
        for n in 1...30 {
            let f=toy.frame(6.501+Double(n)/60)
            check(abs(f.look-previous.look)<0.16 && abs(f.attention-previous.attention)<0.16,"Renewed attention is continuous at display cadence")
            previous=f
        }
        check(previous.look>0.8,"Continuity must not remove the visible far-side response")
        for pause in [0.1,1.8,3.0] {
            toy.start(0);toy.grab(0.3);toy.move(to:CGPoint(x:0.77,y:0.38),at:0.3);toy.release(0.4)
            let end=Int((0.4+pause)*120)
            for n in 49...end {_=toy.frame(Double(n)/120)}
            let before=toy.frame(Double(end)/120)
            toy.grab(Double(end)/120);toy.move(to:CGPoint(x:0.41,y:0.38),at:Double(end)/120)
            let after=toy.frame(Double(end)/120)
            check(abs(before.look-after.look)<0.0001 && abs(before.attention-after.attention)<0.0001,"Reversing direction preserves the current pose during active and fading attention")
            var prior=after
            for n in 1...24 {
                let f=toy.frame(Double(end)/120+Double(n)/30)
                check(abs(f.look-prior.look)<0.39 && abs(f.attention-prior.attention)<0.25,"Reversal stays continuous through center at the app's 30Hz cadence")
                prior=f
            }
            check(prior.look < -0.8,"Direction reversal remains clearly visible after the smooth transition")
        }

        // Hand-checked support heights from the authored rim; center plus the
        // ball's radius must meet the rim, not sit at an arbitrary drag height.
        // At the user's 290pt size, a high release must visibly descend on the
        // next 30Hz frame, even while the cat is finishing a petting response.
        for canBat in [false,true] {
            for (x,ground) in [(0.41,0.39422),(0.61,0.39307),(0.77,0.37629)] {
                toy.start(8);toy.grab(8.3);toy.move(to:CGPoint(x:x,y:0),at:8.3)
                let held=toy.frame(8.4,canBat:canBat);toy.release(8.4)
                check(toy.frame(8.4,canBat:canBat).position==held.position,"Release cannot teleport before the first animation frame")
                let first=toy.frame(8.4+1.0/30,canBat:canBat)
                check((first.position.y-held.position.y)*290>=1,"High release visibly descends at least one point on the first 30Hz frame")
                check(first.position.y<ground && first.paw==0,"Immediate descent must not snap to the surface or start a paw response")
                let landed=toy.frame(8.58,canBat:canBat)
                check(abs(landed.position.y-ground)<0.0001 && landed.paw==0,"Short drop settles promptly without waiting for or advancing the cat response")
            }
        }
        for (x,ground) in [(0.41,0.39422),(0.61,0.39307),(0.77,0.37629)] {
            toy.start(10);toy.grab(11);toy.move(to:CGPoint(x:x,y:0),at:11)
            let held=toy.frame(11.01);toy.release(11.02)
            check(toy.frame(11.02).position==held.position,"Release begins at the held position without snapping")
            var last=held.position.y
            for n in 1...20 {
                let f=toy.frame(11.02+Double(n)/60)
                check(f.position.y>=last-0.00001 && f.position.y<=ground+0.0001,"Released ball descends monotonically without hovering, bouncing or crossing the surface")
                if Double(n)/60<=0.16 {check(f.paw==0,"Paw does not strike while the ball is landing")}
                last=f.position.y
            }
            check(abs(last-ground)<0.0001,"High drop lands on the visible bed surface")
            let middle=toy.frame(11.36);toy.grab(11.36)
            check(toy.frame(11.36).position==middle.position,"Regrab retains the current ball location")
        }
        toy.start(20);toy.grab(21);toy.move(to:CGPoint(x:0.61,y:0),at:21);toy.release(21.1)
        let falling=toy.frame(21.22);toy.grab(21.22)
        check(toy.frame(21.22).position==falling.position,"Regrab mid-fall cannot teleport to the destination")
        check(toy.frame(21.8).position==falling.position,"Holding cancels the pending fall")
        toy.release(22);_=toy.frame(22.1,reduced:true)
        let reduced=toy.frame(22.4,reduced:true)
        check(abs(reduced.position.y-0.39307)<0.0001 && reduced.paw==0 && reduced.look==0,"Reduced motion places on the surface without a fall or response")
        toy.finish(22.5,immediate:true)
        check(toy.frame(30).opacity==0 && !toy.isPresent,"Hide/rest cannot restore a pending fall")
        toy.start(40);toy.grab(40.1);toy.move(to:CGPoint(x:0.77,y:0.37),at:40.1);toy.release(40.2)
        for n in 7...30 {
            let f=toy.frame(40+Double(n)/30,canBat:false)
            check(f.look==0 && f.attention==0 && f.paw==0,"Ball can be present while the cat finishes its current action without preparing a hidden head jump")
        }
        let ready=toy.frame(41.033,canBat:true)
        check(ready.look>=0 && ready.look<0.25,"After petting, the toy response begins smoothly instead of revealing a fully turned head")
        toy.start(50);toy.grab(51);toy.move(to:CGPoint(x:0.62,y:0.395),at:51);toy.release(51.1);_=toy.frame(51.6)
        toy.finish(52.1)
        let exiting=toy.frame(52.15)
        toy.start(52.15)
        let reopened=toy.frame(52.15)
        check(abs(exiting.pawElbow-reopened.pawElbow)<0.00001 && abs(exiting.pawWrist-reopened.pawWrist)<0.00001,"Immediate take-out during old toy exit keeps the current retracting paw pose")
        toy.start(60);toy.grab(60.1);toy.move(to:CGPoint(x:0.77,y:0.37),at:60.1);toy.release(60.2)
        for n in 7...25 {_=toy.frame(60+Double(n)/30)}
        toy.finish(60.85)
        let turning=toy.frame(60.9);toy.start(60.9)
        let restarted=toy.frame(60.9)
        check(abs(turning.look-restarted.look)<0.00001 && abs(turning.attention-restarted.attention)<0.00001,"Closing and immediately reopening during a far look preserves head and ears as well as the paw")
        let next=toy.frame(60.9+1.0/30)
        check(next.look>=0 && next.look<=restarted.look && restarted.look-next.look<0.2,"Inherited attention relaxes continuously instead of snapping after restart")
        if failures>0 {exit(1)}
        print("PASS toy continuity: near/far regrab, visible attention, supported landing, interruption and reduced motion")
    }
}
