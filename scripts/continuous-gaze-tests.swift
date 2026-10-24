import Foundation
#if CAT_OLD_GAZE_REPRO
typealias TestedGaze = CatAccessoryLook
#else
typealias TestedGaze = CatAccessoryGaze
#endif

@main struct ContinuousGazeTests {
    static func check(_ ok:Bool,_ message:String) {if !ok {print("FAIL continuous gaze: \(message)");exit(1)}}
    static func main() {
        var gaze=TestedGaze()
        check(gaze.tap(at:0,allowed:true),"first click starts")
        _=gaze.sample(at:1.4,allowed:true)
        check(gaze.tap(at:1.41,allowed:true),"a click after return must start immediately, not wait for three seconds")
        #if !CAT_OLD_GAZE_REPRO
        gaze.cancel()
        var oldHead=CatAccessoryLook(),oldEyes=EyeGazePlayback()
        _=gaze.tap(at:10,allowed:true);_=oldHead.tap(at:10,allowed:true);_=oldEyes.start(direction:1,at:10)
        for i in 0...180 {
            let t=10+Double(i)/120,got=gaze.sample(at:t,allowed:true),old=oldHead.sample(at:t,allowed:true)
            check(abs(got.lookX-old.lookX)<1e-12 && abs(got.rightEar-old.rightEar)<1e-12 && abs(got.eye-oldEyes.sample(at:t).x)<1e-12,
                  "an isolated click preserves accepted head/ear/eye curves")
        }
        // Every animation phase, including the eye-only tail: position and
        // velocity are continuous across an explicit re-engagement.
        for phase in [0.01,0.12,0.24,0.46,0.65,0.90,1.0,1.119,1.25,1.399] {
            var g=CatAccessoryGaze();_=g.tap(at:0,allowed:true)
            let eps=0.000001,before=g.sample(at:phase-eps,allowed:true),at=g.sample(at:phase,allowed:true)
            check(g.tap(at:phase,allowed:true),"repeated input remains responsive at \(phase)")
            let after=g.sample(at:phase,allowed:true),next=g.sample(at:phase+eps,allowed:true)
            check(at==after,"input cannot reset any channel to neutral at \(phase)")
            for values in [(before.eye,at.eye,next.eye),(before.lookX,at.lookX,next.lookX),(before.rightEar,at.rightEar,next.rightEar)] {
                check(abs((values.1-values.0)/eps-(values.2-values.1)/eps)<0.002,"reversal must not snap velocity at \(phase)")
            }
            for i in 0...180 {
                let r=g.sample(at:phase+Double(i)/100,allowed:true)
                check((0...1).contains(r.eye) && (0...0.28).contains(r.lookX) && (0...0.18).contains(r.rightEar),"re-engagement remains bounded")
            }
            check(!g.isActive && g.sample(at:phase+2,allowed:true) == .init(),"stop input yields one finite return with no backlog")
        }
        gaze=CatAccessoryGaze();_=gaze.tap(at:0,allowed:true)
        for i in 1...1000 {
            let t=Double(i)/100
            _=gaze.sample(at:t,allowed:true);check(gaze.tap(at:t,allowed:true),"rapid input admitted without a queue")
        }
        check(gaze.sample(at:10.1,allowed:true).eye>0.99,"repeated rising input cannot stall progress")
        check(gaze.sample(at:11.5,allowed:true) == .init() && !gaze.isActive,"1000 inputs cannot create 1000 future actions")
        _=gaze.tap(at:12,allowed:true)
        check(gaze.sample(at:12.3,allowed:false) == .init() && !gaze.isActive,"priority/reduced/hidden gate cancels")
        check(gaze.sample(at:13,allowed:true) == .init(),"unblocking does not replay")
        check(!gaze.tap(at:.nan,allowed:true) && !gaze.tap(at:.infinity,allowed:true),"invalid clocks cannot start")
        _=gaze.tap(at:20,allowed:true)
        check(!gaze.tap(at:19,allowed:true),"backward input cannot reset time")
        print("PASS continuous gaze: exact isolated curves, immediate replay, position/velocity continuity, bounded rapid input, finite settle, cancellation and no queue")
        #endif
    }
}
