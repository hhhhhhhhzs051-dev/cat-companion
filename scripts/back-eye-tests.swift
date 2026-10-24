import Foundation

@main struct BackEyeTests {
    static func frame(_ motion:inout CatMotion,_ time:Double)->CatPose {
        motion.frame(time,reduced:false,paused:false)
    }
    static func main() {
        // Five seconds belongs to one eye-hold gesture, not to each drag/re-entry.
        for region in [CatTouchRegion.head,.back] {
            for moving in [false,true] {
                var capped=CatMotion(now:0,seed:42)
                let start=region == .head ? 1.75:1.0
                if region == .head {capped.pet(1);_ = frame(&capped,start);capped.stroke(.head,at:start)}
                else {capped.touchBack(start)}
                // Isolate pet-eye ownership from unrelated ordinary idle blinks.
                capped.nextBlink=100;capped.nextGesture=100
                for i in 1...49 {
                    let t=start+Double(i)/10
                    if moving {
                        if i%2==0 {capped.endStroke(t,releaseEyes:false)}
                        else {capped.continueContactEyes(t);capped.stroke(region,at:t)}
                    }
                    let eyes=frame(&capped,t).eyes
                    if i>=2 {precondition(eyes==1,"Hold stays fully closed before its five-second limit")}
                }
                precondition(frame(&capped,start+5).eyes==1,"Limit starts the existing smooth release without a jump")
                let midpoint=frame(&capped,start+5.12).eyes
                precondition(abs(midpoint-0.5)<0.000001,"Five-second limit must begin reopening, even without input")
                precondition(frame(&capped,start+5.25).eyes==0,"Timed release finishes fully open")
                for i in 53...90 {
                    let t=start+Double(i)/10
                    capped.endStroke(t,releaseEyes:false);capped.continueContactEyes(t);capped.stroke(region,at:t)
                    precondition(frame(&capped,t).eyes==0,"Expired held gesture cannot replay closure on re-entry or movement")
                }
                capped.endStroke(start+9)
                if region == .head {capped.pet(start+10);capped.stroke(.head,at:start+10)}
                else {capped.touchBack(start+10)}
                precondition(frame(&capped,start+10.2).eyes==1,"Fresh press gets a new eye-hold allowance")
            }
            // A late frame or mouseUp must not move the original deadline later.
            for releaseFirst in [false,true] {
                var late=CatMotion(now:0,seed:4)
                if region == .head {late.pet(1);late.stroke(.head,at:1)}else{late.touchBack(1)}
                _ = frame(&late,1.2)
                if releaseFirst {late.releaseContactEyes(6.4)}
                precondition(frame(&late,6.4).eyes==0,"Late frame/release must respect the original deadline")
            }
        }
        // Surface departure keeps only eyes held; every other field settles exactly as before.
        for region in [CatTouchRegion.head,.back] {
            var held=CatMotion(now:0,seed:73)
            if region == .head {held.pet(1)}else{held.touchBack(1)}
            _ = frame(&held,1.1);held.stroke(region,at:1.1);_ = frame(&held,1.4)
            var released=held
            held.endStroke(1.4,releaseEyes:false);released.endStroke(1.4)
            for i in 0...60 {
                let t=1.4+Double(i)/60
                var actual=frame(&held,t),expected=frame(&released,t)
                precondition(actual.eyes==1,"Outside hold stays fully closed")
                actual.eyes=0;expected.eyes=0
                precondition(actual==expected,"Surface departure must preserve non-eye settling")
                precondition(held.petEnd==released.petEnd && held.nextGesture==released.nextGesture && held.nextBlink==released.nextBlink)
            }
            held.endStroke(2.4)
            precondition(frame(&held,2.65).eyes==0,"Actual release still reopens outside")
        }
        // A head click stays brief; moving that held press becomes sustained petting.
        for start in [1.02,1.4,1.75] {
            var head=CatMotion(now:0,seed:42);head.pet(1)
            let before=frame(&head,start).eyes
            head.stroke(.head,at:start)
            precondition(frame(&head,start).eyes==before,"Head stroke begins at the displayed eye pose")
            for i in 1...180 {
                let time=start+Double(i)/60
                if i<180 && i%3==0 {head.stroke(.head,at:time)}
                let eyes=frame(&head,time).eyes
                if i>=9 {precondition(eyes==1,"Head stroking and stationary contact must keep fully closed eyes")}
            }
            head.endStroke(start+3)
            var previous=1.0
            for i in 0...36 {
                let eyes=frame(&head,start+3+Double(i)/120).eyes
                precondition(eyes<=previous+0.000001,"Head release must not reveal a leftover blink or squint")
                previous=eyes
            }
            precondition(previous==0)
            head.pet(start+11)
            precondition(frame(&head,start+11.12).eyes==1)
            precondition(frame(&head,start+11.71).eyes==0,"Fresh head click is still 700ms")
        }
        for reduced in [false,true] {
            var head=CatMotion(now:0,seed:7);head.pet(1);head.stroke(.head,at:1.1)
            _ = frame(&head,1.3)
            precondition(head.frame(1.31,reduced:reduced,paused:!reduced).eyes==0)
            head.stroke(.head,at:1.32)
            precondition(frame(&head,1.33).eyes==0,"Cancelled head hold cannot be restarted by stale input")
        }
        // Holding still and sparse/frequent drag events have the same complete closure.
        for interval in [Double.infinity,1.0/60,1.0/30,0.1,0.25] {
            var motion=CatMotion(now:0,seed:42)
            motion.touchBack(1)
            var previous=0.0
            for index in 0...180 {
                let time=1+Double(index)/60
                if interval.isFinite && index>0 && Int(Double(index-1)/60/interval) != Int(Double(index)/60/interval) {
                    motion.stroke(.back,at:time)
                }
                let eyes=frame(&motion,time).eyes
                precondition(eyes.isFinite && (0...1).contains(eyes))
                precondition(abs(eyes-previous)<0.2,"Body eyes stay continuous at 60Hz")
                if index>=9 {precondition(eyes==1,"Hold must reach and keep fully closed eyes, not a squint")}
                previous=eyes
            }
            motion.endStroke(4)
            precondition(frame(&motion,4).eyes==1,"Early release starts without a jump")
            for i in 1...30 {
                let eyes=frame(&motion,4+Double(i)/120).eyes
                precondition(eyes<=previous && previous-eyes<0.07,"Release reopens smoothly")
                previous=eyes
            }
            precondition(previous==0)
        }
        // A scheduled blink must not surface halfway through releasing a long hold.
        var overlap=CatMotion(now:0,seed:42);overlap.touchBack(1)
        let releaseAt=overlap.nextBlink-0.2
        for i in 0...Int((releaseAt-1)*120) {_ = frame(&overlap,1+Double(i)/120)}
        overlap.endStroke(releaseAt)
        var previous=1.0
        for i in 0...84 {
            let eyes=frame(&overlap,releaseAt+Double(i)/120).eyes
            precondition(eyes<=previous+0.000001,"An overlapping idle blink must not reclose released eyes")
            previous=eyes
        }
        precondition(previous==0)
        // Short contact, release without another rendered frame, and re-entry.
        var short=CatMotion(now:0,seed:9)
        short.touchBack(1);short.endStroke(1.05)
        let release=frame(&short,1.05).eyes
        precondition(release>0 && release<1)
        let before=frame(&short,1.12).eyes
        short.stroke(.back,at:1.12)
        precondition(frame(&short,1.12).eyes==before,"Re-entry starts at the current eye state")
        precondition(frame(&short,1.3).eyes==1)
        short.endStroke(1.3);short.endStroke(1.4)
        precondition(frame(&short,1.55).eyes==0,"Repeated release cannot prolong the eye tail")
        // Head keeps its original 700ms response, including interruptions.
        var switching=CatMotion(now:0,seed:1);switching.touchBack(1)
        let back=frame(&switching,1.12);switching.pet(1.12)
        precondition(frame(&switching,1.12).eyes==back.eyes)
        precondition(frame(&switching,1.3).eyes>0.95)
        precondition(frame(&switching,1.821).eyes==0)
        switching.pet(3);let head=frame(&switching,3.1);switching.touchBack(3.1)
        precondition(frame(&switching,3.1).eyes==head.eyes)
        precondition(frame(&switching,3.7).eyes==1)
        for reduced in [false,true] {
            var cancelled=CatMotion(now:0,seed:4);cancelled.touchBack(1)
            _ = frame(&cancelled,1.2)
            precondition(cancelled.frame(1.21,reduced:reduced,paused:!reduced).eyes==0)
            cancelled.stroke(.back,at:1.22)
            precondition(frame(&cancelled,1.23).eyes==0,"Cancelled hold must not replay on stale input")
            cancelled.resume(2)
            precondition(frame(&cancelled,2).eyes==0)
        }
        // Frozen pre-change non-eye behavior and scheduling remain exact.
        var current=CatMotion(now:0,seed:73),legacy=LegacyCatMotion(now:0,seed:73)
        for i in 0...1200 {
            let t=Double(i)/60
            if [60,660].contains(i) {current.pet(t);legacy.pet(t)}
            if [72,420,675].contains(i) {current.touchBack(t);legacy.touchBack(t)}
            if (80...380).contains(i) && i%3==0 {current.stroke(.back,at:t);legacy.stroke(.back,at:t)}
            if (610...640).contains(i) && i%3==0 {current.stroke(.head,at:t);legacy.stroke(.head,at:t)}
            if i==390 {current.endStroke(t);legacy.endStroke(t)}
            if i==720 {current.resume(t);legacy.resume(t)}
            if i==900 {current.pet(t);legacy.pet(t)}
            var actual=current.frame(t,reduced:i==690,paused:i==700)
            var expected=legacy.frame(t,reduced:i==690,paused:i==700)
            if i>=900 {precondition(actual.eyes==expected.eyes,"Head-click and idle eyes remain identical")}
            actual.eyes=0;expected.eyes=0
            precondition(actual==expected,"Every non-eye motion field must match the frozen baseline")
            precondition(current.petEnd==legacy.petEnd && current.nextGesture==legacy.nextGesture && current.nextBlink==legacy.nextBlink,"Busy periods and quiet scheduling remain unchanged")
        }
        print("PASS held eyes: five-second cap, no retrigger, boundary/late frame, early release, head700ms, cancellation, non-eye baseline")
    }
}
