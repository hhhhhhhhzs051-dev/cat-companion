import Foundation

/// A finite, explicit-input response. Uses the existing animation clock and
/// never changes CatMotion's gesture, blink, breath or random scheduling.
struct CatAccessoryLook {
    struct Response:Equatable {
        var lookX=0.0
        var rightEar=0.0
    }
    static let duration=1.12
    static let cooldown=3.0
    private var start:Double?
    private var lastStart = -Double.infinity
    var isActive:Bool {start != nil}

    @discardableResult
    mutating func tap(at time:Double,allowed:Bool)->Bool {
        guard time.isFinite,allowed else{return false}
        if let start,time>=start+Self.duration {self.start=nil}
        guard start==nil,time>=lastStart+Self.cooldown else{return false}
        start=time;lastStart=time
        return true
    }
    mutating func sample(at time:Double,allowed:Bool)->Response {
        guard allowed,time.isFinite,let start,time>=start,time<start+Self.duration else {
            cancel();return Response()
        }
        let age=time-start
        return Response(lookX:0.28*Self.envelope(age,rise:0.24,hold:0.22,fall:0.66),
                        rightEar:0.18*Self.envelope(age,rise:0.16,hold:0.12,fall:0.50))
    }
    mutating func cancel() {
        start=nil // Cancelling never resets the cooldown or leaves a replay.
    }
    private static func envelope(_ age:Double,rise:Double,hold:Double,fall:Double)->Double {
        func smooth(_ t:Double)->Double {let v=max(0,min(1,t));return v*v*(3-2*v)}
        return smooth(age/rise)*(1-smooth((age-rise-hold)/fall))
    }
}
