import AppKit

func runMenuTests(_ app:PetApp) {
    // Exercise the actual preview initializer before the shared suite replaces
    // models for deterministic input tests. A missing feature flag must fail.
    let start=app.now
    var configured=app.motion;configured.pet(start)
    precondition(configured.frame(start+0.2,reduced:false,paused:false).lean==0,"actual app must disable head lean")
    configured.touchBack(start+1)
    let body=configured.frame(start+1.2,reduced:false,paused:false)
    precondition(body.leftEar>0 && body.rightEar>0 && body.lean==0,"actual app must retain the accepted paired ears")
    for i in 1...24 {configured.stroke(.back,at:start+1.2+Double(i)/120)}
    let following=configured.frame(start+1.4,reduced:false,paused:false)
    precondition(abs(following.head+0.55)<1e-10 && abs(following.leftEar-0.85)<1e-10,"actual app must retain continuous following")
    print("PASS app initialization: stationary head pet, continuous following and accepted paired ears enabled together")
    // The shipped --self-test deliberately treats its window as visible. Only
    // check production initialization in that mode; native occlusion assertions
    // run separately with preview storage isolation and normal visibility.
    if app.selfTest {
        precondition(!app.isPlayPreview && app.growthStore==nil)
        return
    }
    runExistingMenuTests(app)
}
