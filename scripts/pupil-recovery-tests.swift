import Foundation
@main struct PupilRecoveryTests {
    static func main() {
        func check(_ value:Bool,_ message:String) {if !value {print("FAIL recovery: \(message)");exit(1)}}
        var cue=CatToyPupil()
        _=cue.beginSession(at:0,allowed:true)
        check(cue.sample(at:0.8,allowed:true)==1.5,"accepted peak")
        check(cue.sample(at:0.82,allowed:false)==1.5,"interruption preserves last displayed width, not instant neutral")
        var previous=1.5
        for i in 1...48 {
            let width=cue.sample(at:0.82+Double(i)/60,allowed:i>12)
            check(width<=previous+1e-9 && previous-width<0.025,"monotone bounded recovery, no resumption when priority clears")
            previous=width
        }
        check(abs(previous-1)<1e-9 && !cue.isActive,"finite exit without per-frame restart")
        check(cue.sample(at:4,allowed:true)==1,"no queued replay")
        _=cue.grab(at:5,allowed:true)
        check(abs(cue.sample(at:5.35,allowed:true)-1.25)<1e-9,"accepted half-rise")
        check(!cue.grab(at:5.36,allowed:false),"busy regrab does not start a new cue")
        check(abs(cue.sample(at:5.36,allowed:true)-1.25)<1e-9,"busy grab blends out from existing width")
        let partial=cue.sample(at:5.6,allowed:true)
        _=cue.grab(at:5.6,allowed:true)
        check(abs(cue.sample(at:5.6,allowed:true)-partial)<1e-9,"eligible regrab during exit has no reset")
        cue.cancel();check(cue.sample(at:6,allowed:true)==1 && !cue.isActive,"hard lifecycle cleanup remains immediate")
        var natural=CatToyPupil();_=natural.beginSession(at:10,allowed:true)
        for (t,w) in [(10.0,1.0),(10.35,1.25),(10.7,1.5),(11.9,1.5),(12.3,1.25),(12.7,1.0)] {
            check(abs(natural.sample(at:t,allowed:true)-w)<1e-9,"original 0.7/1.2/0.8 envelope unchanged")
        }
        var falling=CatToyPupil();_=falling.beginSession(at:0,allowed:true)
        _=falling.sample(at:2.2,allowed:true)
        check(abs(falling.sample(at:2.3,allowed:false)-1.25)<1e-9,"already shrinking keeps normal recovery rhythm")
        check(falling.sample(at:2.71,allowed:false)==1,"interruption never stretches existing fall")
        print("PASS pupil interruption continuity, busy/eligible regrab, no replay and original envelope")
    }
}
