import Foundation
@main struct PupilPlayTests {
    static func main() {
        func check(_ v:Bool,_ s:String){if !v {print("FAIL pupil play: \(s)");exit(1)}}
        var cue=CatToyPupil()
        check(cue.sample(at:0,allowed:true)==1,"no spontaneous widening")
        check(cue.beginSession(at:10,allowed:true),"explicit opening")
        check(abs(cue.sample(at:10.7,allowed:true)-1.5)<1e-8,"opening reaches requested50 percent")
        check(abs(cue.sample(at:11.8,allowed:true)-1.5)<1e-8,"visible peak remains beyond old1.2s endpoint")
        check(abs(cue.sample(at:12.3,allowed:true)-1.25)<1e-8,"natural halfway recovery")
        check(cue.sample(at:12.71,allowed:true)==1 && !cue.isActive,"finite recovery without loop")
        check(cue.grab(at:20,allowed:true),"new grab in same ball session is eligible")
        let half=cue.sample(at:20.35,allowed:true)
        check(abs(half-1.25)<1e-8,"grab gradually widens original pupil")
        check(cue.grab(at:20.35,allowed:true),"quick regrab")
        check(abs(cue.sample(at:20.35,allowed:true)-half)<1e-8,"regrab never resets to original")
        check(abs(cue.sample(at:21.1,allowed:true)-1.5)<1e-8,"regrab reaches bounded peak")
        check(cue.sample(at:23.1,allowed:true)==1,"regrab finite, no queue")
        check(!cue.grab(at:24,allowed:false) && cue.sample(at:25,allowed:true)==1,"busy grab skips, no delayed replay")
        _=cue.grab(at:30,allowed:true)
        check(cue.sample(at:30.2,allowed:false)==1 && !cue.isActive,"priority and reduced-motion cancellation")
        check(cue.sample(at:31,allowed:true)==1,"cancel never resumes")
        print("PASS pupil50 peak, longer hold, finite recovery and idle")
    }
}
