import Foundation

@main struct TouchResponseTests {
    static var checks=0
    static func check(_ condition:Bool,_ message:String) {
        checks += 1
        if !condition {print("FAIL: \(message)");exit(1)}
    }
    static func preview(_ seed:UInt64=42)->CatMotion {CatMotion(now:0,seed:seed,refinedTouch:true)}
    static func frame(_ m:inout CatMotion,_ t:Double)->CatPose {m.frame(t,reduced:false,paused:false)}
    static func begin(_ m:inout CatMotion,_ region:CatTouchRegion,_ t:Double=1) {
        if region == .back {m.touchBack(t)}else{m.pet(t);m.stroke(.head,at:t)}
    }
    static func protected(_ pose:CatPose)->CatPose {
        var p=pose;p.leftEar=0;p.rightEar=0;p.head=0;return p
    }
    static func main() {
        for region in [CatTouchRegion.head,.back] {
            for hz in [20,30,60,120,240] {
                var m=preview();begin(&m,region)
                for i in 1...Int(Double(hz)*0.2) {let t=1+Double(i)/Double(hz);m.stroke(region,at:t);_ = frame(&m,t)}
                let p=frame(&m,1.2), target=region == .back ? 0.85:0.25
                check(abs(p.leftEar-target)<1e-10,"\(region) arrival must not restart at \(hz) input events/s")
                check(abs(p.head-(region == .back ? -0.55:0.35))<1e-10,"head reaches its original target at every input rate")
                check(p.rightEar>0 && p.rightEar<p.leftEar*0.5,"secondary ear is present but weaker")
                check(p.lookX==0,"no horizontal follow")
            }
            var m=preview();begin(&m,region)
            check(frame(&m,1.05).rightEar==0,"secondary ear starts a little later")
            check(frame(&m,1.12).rightEar>0,"secondary ear arrives during the same transition")
            for i in 15...120 {m.stroke(region,at:1+Double(i)/120)}
            let held=frame(&m,2);m.endStroke(2)
            for i in 0...108 {
                let t=2+Double(i)/120,p=frame(&m,t)
                let tail=1-CatMotion.smooth((t-2.08)/0.8)
                check(abs(p.leftEar-held.leftEar*tail)<1e-10,"original 80ms grace + 800ms release retained")
                check(abs(p.rightEar-held.rightEar*tail)<1e-10,"both ears settle once, without oscillation")
                check(abs(p.head-held.head*tail)<1e-10,"head keeps the original release curve")
            }
            check(frame(&m,2.9).leftEar==0 && frame(&m,2.9).rightEar==0,"finite tail reaches exact idle zero")
            check(frame(&m,2.9).head==0,"head tail reaches exact idle zero")
            // Re-entry samples the fading pose even when the region is unchanged.
            begin(&m,region,4);m.stroke(region,at:4.2);_ = frame(&m,4.3)
            m.endStroke(4.3,releaseEyes:false)
            let before=frame(&m,4.65);m.stroke(region,at:4.65)
            let after=frame(&m,4.65)
            check(before==after,"same-region re-entry must not snap")
            m.stroke(region,at:4.75)
            check(frame(&m,4.84).leftEar>before.leftEar,"re-entry smoothly returns to contact")
            // A natural event gap lets the response relax, then resumes continuously.
            let gap=frame(&m,5.3);m.stroke(region,at:5.3)
            check(frame(&m,5.3)==gap,"sparse input resumes from current pose")
        }
        var changed=preview();begin(&changed,.back)
        let previous=frame(&changed,1.2);changed.stroke(.head,at:1.2)
        check(frame(&changed,1.2)==previous,"explicit region change starts from the current pose")
        changed.stroke(.head,at:1.3)
        check(abs(frame(&changed,1.4).head-0.35)<1e-10,"new region reaches its own unchanged target")
        // Eye channels, quiet scheduling and all other motion channels remain exact.
        for region in [CatTouchRegion.head,.back] {
            var a=preview(73),b=CatMotion(now:0,seed:73)
            for i in 0...1800 {
                let t=Double(i)/120
                if i==120 || i==1080 {begin(&a,region,t);begin(&b,region,t)}
                if (121...1040).contains(i) || (1081...1250).contains(i) {
                    if i%60<45 {a.stroke(region,at:t);b.stroke(region,at:t)}
                    else {a.endStroke(t,releaseEyes:false);b.endStroke(t,releaseEyes:false)}
                }
                if i==1050 || i==1260 {a.endStroke(t);b.endStroke(t)}
                if i==1500 {a.pet(t);b.pet(t)}
                let p=frame(&a,t),q=frame(&b,t)
                check(protected(p)==protected(q),"eyes, lean, breath, gaze and mouth match baseline")
                check(a.petStart==b.petStart && a.petEnd==b.petEnd && a.nextBlink==b.nextBlink && a.nextGesture==b.nextGesture,"scheduling unchanged")
                if i==750 {check(p.eyes==0,"five-second cap is not extended by strokes or boundary crossing")}
            }
        }
        for reduced in [false,true] {
            var m=preview();begin(&m,.back);_ = frame(&m,1.2)
            let cancelled=m.frame(1.3,reduced:reduced,paused:!reduced)
            check(cancelled.leftEar==0 && cancelled.rightEar==0,"pause/reduced motion cancels contact")
            m.resume(2);check(frame(&m,2)==CatPose(),"resume does not replay contact")
        }
        // Inactivity and all standalone accepted gestures are bit-for-bit unchanged.
        for gesture in CatGesture.allCases {
            var a=preview(99),b=CatMotion(now:0,seed:99)
            a.begin(gesture,at:1);b.begin(gesture,at:1)
            for i in 0...600 {let t=Double(i)/60;check(frame(&a,t)==frame(&b,t),"standalone \(gesture) unchanged")}
        }
        var a=preview(5),b=CatMotion(now:0,seed:5)
        for i in 0...10800 {let t=Double(i)/30;check(frame(&a,t)==frame(&b,t),"six minutes of quiet motion unchanged")}
        print("PASS touch response: \(checks) checks; 20–240Hz input, re-entry, release, protected channels, 5s eyes and idle")
    }
}
