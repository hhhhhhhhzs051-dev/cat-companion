import Foundation

// A finite, input-only impulse. It owns no timer, storage or cat animation.
struct CatAccessorySway {
    private(set) var angle=0.0
    private(set) var isActive=false
    private var velocity=0.0, last=0.0, end=0.0
    private var lastTap = -Double.infinity
    private var damping=3.8, frequency=9.0
    mutating func tap(at time:Double, flower:Bool, reduced:Bool) {
        guard time.isFinite,!reduced else {cancel();return}
        advance(to:time)
        guard time-lastTap>=0.16 else{return}
        damping=flower ? 4.5:3.8;frequency=flower ? 11:9
        velocity=min(flower ? 1.3:2.0,velocity+(flower ? 0.9:1.7))
        last=time;lastTap=time;end=time+(flower ? 1.4:1.8);isActive=true
    }
    mutating func advance(to time:Double) {
        guard isActive else{return}
        guard time.isFinite,time>=last,time<end else {cancel();return}
        let dt=time-last,decay=exp(-damping*dt),c=cos(frequency*dt),s=sin(frequency*dt)
        let a=angle,b=(velocity+damping*a)/frequency
        angle=decay*(a*c+b*s)
        velocity=decay*((-damping*a+frequency*b)*c+(-damping*b-frequency*a)*s)
        last=time
    }
    mutating func cancel() {angle=0;velocity=0;isActive=false;lastTap = -.infinity}
}
