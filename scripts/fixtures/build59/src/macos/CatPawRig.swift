#if CAT_PAW_EXPERIMENT
import Foundation

// Two local joints, blended across the wrist on one continuous texture.
struct CatPawRig {
    let elbowAngle:Double
    let wristAngle:Double
    init(raise:Double,lift:Double=0,elbow:Double?=nil,wrist:Double=0) {
        if let elbow {elbowAngle=elbow;wristAngle=wrist;return}
        let r=max(0,min(1,raise))
        // Toy anticipation rotates the same paw around its hidden elbow; no scaling
        // or upward translation of the cut root. Grooming retains its original rig.
        elbowAngle=1.5*(1-r)-0.38*max(-0.4,min(2,lift))*r
        wristAngle = -0.65*sin(.pi*r)
    }
    func sourcePoint(_ p:CGPoint)->CGPoint {
        func rotate(_ point:CGPoint,around pivot:CGPoint,by a:Double)->CGPoint {
            let x=point.x-pivot.x,y=point.y-pivot.y
            return CGPoint(x:pivot.x+cos(a)*x-sin(a)*y,y:pivot.y+sin(a)*x+cos(a)*y)
        }
        let q=rotate(p,around:CGPoint(x:605,y:850),by:-elbowAngle)
        let projection=((q.x-753)*0.594+(q.y-792)*(-0.804)+20)/50
        let t=max(0,min(1,projection)),weight=t*t*(3-2*t)
        return rotate(q,around:CGPoint(x:753,y:792),by:-wristAngle*weight)
    }
}
#endif
