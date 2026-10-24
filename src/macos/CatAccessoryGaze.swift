#if CAT_ACCESSORY_CONTINUOUS_PREVIEW || CAT_ACCESSORY_GAZE
import Foundation

/// Three bounded channels on the existing animation clock.
/// Repeated input updates one hold deadline; it never queues another action.
struct CatAccessoryGaze {
    struct Response:Equatable {
        var lookX=0.0
        var rightEar=0.0
        var eye=0.0
    }
    private struct Channel {
        let rise:Double,hold:Double,fall:Double
        var start:Double?
        var from=0.0,velocity=0.0,brake=0.0,riseTime=0.0,holdUntil=0.0
        var isActive:Bool {start != nil}
        func value(at time:Double)->(value:Double,velocity:Double) {
            guard let start,time>=start,time<holdUntil+fall else{return (0,0)}
            let age=time-start
            if brake>0 && age<brake {
                return (from+velocity*age-velocity*age*age/(2*brake),velocity*(1-age/brake))
            }
            let low=from+velocity*brake/2
            if age<brake+riseTime {
                let t=(age-brake)/riseTime,s=t*t*(3-2*t)
                return (low+(1-low)*s,(1-low)*6*t*(1-t)/riseTime)
            }
            if time<=holdUntil {return (1,0)}
            let t=(time-holdUntil)/fall
            return (1-t*t*(3-2*t),-6*t*(1-t)/fall)
        }
        mutating func tap(at time:Double) {
            if start != nil,time<=holdUntil {
                // Do not restart a rise (even at high click rates), or restart
                // braking. Only extend this same response's hold deadline.
                holdUntil=max(holdUntil,time+hold)
                return
            }
            let current=value(at:time)
            from=current.value;velocity=current.velocity;start=time
            // On a returning leg, first brake its existing velocity. Bound the
            // distance to half the remaining offset so reversal cannot cross 0.
            brake=velocity<0 ? min(0.08,from / -velocity):0
            let low=from+velocity*brake/2
            riseTime=rise*max(0.3,sqrt(max(0,1-low)))
            holdUntil=time+brake+riseTime+hold
        }
        mutating func sample(at time:Double)->Double {
            let result=value(at:time).value
            if start != nil,time>=holdUntil+fall {start=nil}
            return result
        }
        mutating func cancel() {start=nil}
    }
    private var head=Channel(rise:0.24,hold:0.22,fall:0.66)
    private var ear=Channel(rise:0.16,hold:0.12,fall:0.50)
    #if CAT_EYE_INTERACTION_PREVIEW || CAT_EYE_INTERACTION
    // Same envelope as the accepted head channel, including repeated-input
    // braking. Change neither the head motion nor the selected eye amplitude.
    private var eyes=Channel(rise:0.24,hold:0.22,fall:0.66)
    #else
    private var eyes=Channel(rise:0.46,hold:0.44,fall:0.50)
    #endif
    private var lastInput = -Double.infinity
    var isActive:Bool {head.isActive || ear.isActive || eyes.isActive}
    @discardableResult mutating func tap(at time:Double,allowed:Bool)->Bool {
        guard allowed,time.isFinite,time>=lastInput else{return false}
        head.tap(at:time);ear.tap(at:time);eyes.tap(at:time);lastInput=time
        return true
    }
    mutating func sample(at time:Double,allowed:Bool)->Response {
        guard allowed,time.isFinite,time>=lastInput else {cancel();return .init()}
        return Response(lookX:0.28*head.sample(at:time),rightEar:0.18*ear.sample(at:time),eye:eyes.sample(at:time))
    }
    mutating func cancel() {head.cancel();ear.cancel();eyes.cancel()}
}

#if CAT_GRAB_HANDOFF_PREVIEW || CAT_GRAB_HANDOFF
// A finite visual remainder, not another accessory action or a toy-physics
// input. It starts at the last displayed contribution and cannot be renewed
// by dragging/regrabbing. The accepted toy and pupil clocks keep running.
struct CatGrabHandoff {
    private var start:Double?
    private var from=CatAccessoryGaze.Response()
    static let duration=0.24
    var isActive:Bool {start != nil}
    mutating func begin(lookX:Double,rightEar:Double,eye:Double,at time:Double) {
        guard !isActive,time.isFinite,lookX.isFinite,rightEar.isFinite,eye.isFinite else{return}
        from = .init(lookX:max(0,min(0.28,lookX)),rightEar:max(0,min(0.18,rightEar)),eye:max(0,min(1,eye)))
        if from != .init() {start=time}
    }
    mutating func sample(at time:Double)->CatAccessoryGaze.Response {
        guard let start,time.isFinite,time>=start,time<start+Self.duration else {cancel();return .init()}
        let t=(time-start)/Self.duration,weight=1-t*t*(3-2*t)
        return .init(lookX:from.lookX*weight,rightEar:from.rightEar*weight,eye:from.eye*weight)
    }
    mutating func cancel() {start=nil;from = .init()}
}
#endif
#endif
