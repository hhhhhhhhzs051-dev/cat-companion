import Foundation

@main struct HeadSteadyTests {
    static var checks=0
    static func check(_ condition:Bool,_ message:String) {
        checks += 1
        if !condition {print("FAIL: \(message)");exit(1)}
    }
    static func candidate(_ seed:UInt64=42)->CatMotion {
        CatMotion(now:0,seed:seed,refinedTouch:true,headPetLeans:false)
    }
    static func drive(_ m:inout CatMotion,_ scenario:String,_ i:Int,_ t:Double) {
        if i==120 {if scenario == "back" || scenario == "back-head" {m.touchBack(t)}else{m.pet(t)}}
        if scenario == "back-head" && i==180 {m.pet(t)}
        if scenario == "head-back" && i==180 {m.touchBack(t)}
        if scenario == "repeat" && [180,240,300,360].contains(i) {m.pet(t)}
        if scenario == "stroke" || scenario == "boundary" || scenario == "early-release" {
            let end=scenario == "early-release" ? 360:840
            if (121..<end).contains(i) {
                if scenario == "boundary" && i%90>60 {m.endStroke(t,releaseEyes:false)}
                else {m.stroke(.head,at:t)}
            }
            if i==end {m.endStroke(t)}
        }
        if scenario == "resume" && i==240 {m.resume(t)}
    }
    static func main() {
        for scenario in ["click","back","back-head","head-back","repeat","stroke","boundary","early-release","pause","reduced","resume"] {
            var next=candidate(),accepted=CatMotion(now:0,seed:42,refinedTouch:true)
            var previousLeanFound=false
            for i in 0...1200 {
                let t=Double(i)/120
                drive(&next,scenario,i,t);drive(&accepted,scenario,i,t)
                let reduced=scenario == "reduced" && i>=180,paused=scenario == "pause" && i>=180
                let p=next.frame(t,reduced:reduced,paused:paused)
                var q=accepted.frame(t,reduced:reduced,paused:paused)
                previousLeanFound = previousLeanFound || q.lean>0
                check(p.lean==0,"\(scenario): head input must not move the whole cat, including repeat or release")
                q.lean=0
                check(p==q,"\(scenario): all accepted local pose channels stay exact")
                check(next.petStart==accepted.petStart && next.petEnd==accepted.petEnd && next.nextBlink==accepted.nextBlink && next.nextGesture==accepted.nextGesture,"\(scenario): original timing and quiet scheduling stay exact")
            }
            check(scenario == "back" ? !previousLeanFound:previousLeanFound,"scenario actually exercises the old head lean")
        }
        for gesture in CatGesture.allCases {for interrupted in [false,true] {
            var next=candidate(73),accepted=CatMotion(now:0,seed:73,refinedTouch:true)
            next.begin(gesture,at:1);accepted.begin(gesture,at:1)
            for i in 0...720 {
                let t=Double(i)/120
                let p=next.frame(t,reduced:false,paused:false)
                var q=accepted.frame(t,reduced:false,paused:false)
                if interrupted && i>160 {q.lean=0;check(p.lean==0,"manual gesture interruption does not restart head lean")}
                check(p==q,"\(gesture) and its original head-pet interruption stay exact outside removed lean")
                if interrupted && i==160 {next.pet(t);accepted.pet(t)}
            }
        }}
        print("PASS steady head: \(checks) checks; no head lean, exact local response/clocks, repetitions, boundary, release and lifecycle")
    }
}
