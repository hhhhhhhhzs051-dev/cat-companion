import Foundation
@main struct ToyPupilTests {
    static func main(){
        func check(_ ok:Bool,_ text:String){if !ok {print("FAIL toy pupil: \(text)");exit(1)}}
        var cue=CatToyPupil()
        check(cue.sample(at:0,allowed:true)==1,"no automatic start")
        check(cue.beginSession(at:10,allowed:true),"explicit eligible opening starts")
        for (t,w) in [(10.0,1.0),(10.35,1.2),(10.7,1.4),(11.2,1.4),(11.6,1.2),(12.0,1.0)] {
            check(abs(cue.sample(at:t,allowed:true)-w)<1e-8,"accepted timing \(t)")
        }
        check(!cue.isActive && !cue.beginSession(at:80,allowed:true),"no second response in same session")
        cue.endSession();check(cue.beginSession(at:54.99,allowed:true),"new explicit opening has no cooldown")
        cue.endSession();check(cue.beginSession(at:55.1,allowed:true),"next deliberate eligible session")
        check(cue.sample(at:55.5,allowed:false)==1 && !cue.isActive,"busy/reduced/lifecycle cancels")
        check(cue.sample(at:56,allowed:true)==1,"cancel never resumes")
        cue.endSession();check(!cue.beginSession(at:200,allowed:false),"busy start skips")
        check(!cue.beginSession(at:201,allowed:true),"busy skip consumes session, not queued")
        cue.endSession();check(cue.beginSession(at:202,allowed:true),"skipped session did not add cooldown")
        check(cue.sample(at:.nan,allowed:true)==1 && !cue.isActive,"nonfinite time fails safe")
        print("PASS toy cue accepted timing, no reopening cooldown, busy skip, cancellation, no delayed replay and neutral idle")
    }
}
