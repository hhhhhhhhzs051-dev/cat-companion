#if CAT_EYE_INTERACTION_PREVIEW || CAT_EYE_INTERACTION
import Foundation

// Explicit toy-opening cue on the existing30Hz clock; accepted play behavior
// also admits explicit grabs. No saved state, delayed work or timer. A skipped
// or cancelled cue never replays without another eligible intentional input.
struct CatToyPupil {
    private var start:Double?
    private var sessionOpen=false
    #if CAT_PUPIL_RECOVERY_PREVIEW || CAT_PUPIL_RECOVERY
    private var recoveryStart:Double?
    private var recoveryWidth=1.0
    private var displayedWidth=1.0
    // Stop widening, not the cat's current action. Repeated busy ticks and
    // contact renewals never restart the exit. A fall already underway retains
    // its accepted curve and deadline instead of being stretched out.
    mutating func interrupt(at now:Double) {
        guard now.isFinite else {cancel();return}
        guard let start,recoveryStart == nil else{return}
        if now>=start+1.9 {return}
        guard displayedWidth>1 else {cancel();return}
        recoveryWidth=displayedWidth;recoveryStart=now
    }
    mutating func endSessionRecovering(at now:Double) {
        interrupt(at:now);sessionOpen=false
    }
    #endif
    #if CAT_PUPIL_PLAY_PREVIEW || CAT_PUPIL_PLAY
    private var fromWidth=1.0
    // One call per explicit grab, never per pointer-move or animation tick.
    // A new gesture blends from the currently visible width, not neutral.
    @discardableResult mutating func grab(at now:Double,allowed:Bool)->Bool {
        #if CAT_PUPIL_RECOVERY_PREVIEW || CAT_PUPIL_RECOVERY
        guard allowed,now.isFinite else {interrupt(at:now);return false}
        #else
        guard allowed,now.isFinite else {cancel();return false}
        #endif
        fromWidth=sample(at:now,allowed:true)
        #if CAT_PUPIL_RECOVERY_PREVIEW || CAT_PUPIL_RECOVERY
        recoveryStart=nil
        #endif
        start=now;return true
    }
    #endif
    var isActive:Bool {start != nil}
    @discardableResult mutating func beginSession(at now:Double,allowed:Bool)->Bool {
        guard !sessionOpen else{return false}
        sessionOpen=true
        guard allowed,now.isFinite else{return false}
        #if CAT_PUPIL_PLAY_PREVIEW || CAT_PUPIL_PLAY
        #if CAT_PUPIL_RECOVERY_PREVIEW || CAT_PUPIL_RECOVERY
        fromWidth=sample(at:now,allowed:true);recoveryStart=nil
        #else
        fromWidth=1
        #endif
        #endif
        start=now;return true
    }
    mutating func sample(at now:Double,allowed:Bool)->Double {
        #if CAT_PUPIL_RECOVERY_PREVIEW || CAT_PUPIL_RECOVERY
        guard let start,now.isFinite,now>=start else {cancel();return 1}
        if !allowed {interrupt(at:now)}
        guard isActive else{return 1}
        let width:Double
        if let recoveryStart {
            let t=max(0,(now-recoveryStart)/0.8)
            guard t<1 else {cancel();return 1}
            width=1+(recoveryWidth-1)*(1-t*t*(3-2*t))
        } else {
            width=sampleEnvelope(at:now,allowed:true)
        }
        displayedWidth=width
        return width
        #else
        return sampleEnvelope(at:now,allowed:allowed)
        #endif
    }
    private mutating func sampleEnvelope(at now:Double,allowed:Bool)->Double {
        guard allowed,let start,now.isFinite,now>=start else{cancel();return 1}
        let t=now-start
        #if CAT_PUPIL_PLAY_PREVIEW || CAT_PUPIL_PLAY
        guard t<2.7 else{cancel();return 1}
        func smooth(_ x:Double)->Double {x*x*(3-2*x)}
        if t<0.7 {return fromWidth+(1.5-fromWidth)*smooth(t/0.7)}
        return t<1.9 ? 1.5:1+0.5*(1-smooth((t-1.9)/0.8))
        #else
        guard t<2 else{cancel();return 1}
        func smooth(_ x:Double)->Double {x*x*(3-2*x)}
        let amount=t<0.7 ? smooth(t/0.7):(t<1.2 ? 1:1-smooth((t-1.2)/0.8))
        return 1+0.4*amount
        #endif
    }
    mutating func cancel(){
        start=nil
        #if CAT_PUPIL_RECOVERY_PREVIEW || CAT_PUPIL_RECOVERY
        recoveryStart=nil;displayedWidth=1
        #endif
    }
    mutating func endSession(){cancel();sessionOpen=false}
}
#endif
