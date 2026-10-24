#if CAT_PAW_EXPERIMENT
import Foundation

struct PawPose:Equatable {var raise=0.0,lick=0.0,offsetX=0.0,lift=0.0;var toyElbow:Double?=nil;var toyWrist=0.0;var toySide=0}
enum CatPaw {
    static func pose(elapsed:Double)->PawPose {
        guard elapsed.isFinite,elapsed>0,elapsed<3.5 else{return PawPose()}
        func smooth(_ x:Double)->Double {let t=max(0,min(1,x));return t*t*(3-2*t)}
        let raised=elapsed<0.95 ? smooth(elapsed/0.95):1-smooth((elapsed-2.55)/0.95)
        func lick(_ start:Double)->Double {
            let t=elapsed-start
            if t<0 || t>=0.45 {return 0}
            return t<0.12 ? smooth(t/0.12):1-smooth((t-0.20)/0.25)
        }
        return PawPose(raise:raised,lick:lick(1.08)+lick(1.78))
    }
}
#endif
