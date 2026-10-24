import Foundation
@main struct EyeCoordinationTests {
    static func main(){
        var failures=0
        func check(_ ok:Bool,_ text:String){if !ok {print("FAIL \(text)");failures+=1}}
        var gaze=CatAccessoryGaze();_=gaze.tap(at:0,allowed:true)
        for t in [0.12,0.24,0.46,0.9,1.12] {
            let response=gaze.sample(at:t,allowed:true)
            check(abs(response.eye-response.lookX/0.28)<1e-9,"eye/head synchronization at \(t)")
        }
        for index in 0..<200 {
            let t=2+Double(index)/60
            if index%11==0 {_=gaze.tap(at:t,allowed:true)}
            let response=gaze.sample(at:t,allowed:true)
            check(abs(response.eye-response.lookX/0.28)<1e-9,"repeated input remains coordinated \(index)")
        }
        var pupil=CatToyPupil();_=pupil.beginSession(at:0,allowed:true)
        pupil.endSession();check(pupil.beginSession(at:0.1,allowed:true),"new explicit opening has no cooldown")
        check(abs(pupil.sample(at:0.8,allowed:true)-1.4)<1e-9,"new opening still reaches accepted40")
        check(!pupil.beginSession(at:0.9,allowed:true),"no timer-driven repeat within same opening")
        if failures>0 {print("FAILURES \(failures)");exit(1)}
        print("PASS synchronized eye/head timing including repeated reversals, no pupil reopening cooldown, unchanged width")
    }
}
