#if CAT_PAW_EXPERIMENT
import Foundation

struct GroomingPose:Equatable {
    var cat=CatPose()
    var paw=PawPose()
}

enum CatGrooming {
    static func pose(elapsed:Double)->GroomingPose {
        guard elapsed.isFinite,elapsed>0,elapsed<3.9 else{return GroomingPose()}
        func smooth(_ x:Double)->Double {let t=max(0,min(1,x));return t*t*(3-2*t)}
        let approach=smooth(elapsed/0.75)*(1-smooth((elapsed-3.1)/0.8))
        let raised=smooth((elapsed-0.28)/0.95)*(1-smooth((elapsed-2.85)/0.8))
        var mouth=MouthPose()
        var contact=0.0
        for start in [1.38,2.10] {
            let t=elapsed-start
            if t>0 && t<0.5 {
                mouth.extensionAmount=smooth(t/0.12)*(1-smooth((t-0.30)/0.20))
                mouth.grooming=true
                mouth.sweep=smooth((t-0.12)/0.18)
                mouth.fold=smooth((t-0.30)/0.20)
                contact=sin(.pi*t/0.5)
            }
        }
        // Grooming does not own the eyelids: retain the accepted V1 eye shape.
        return GroomingPose(cat:CatPose(head:3.4*approach+0.25*contact,mouth:mouth,groomingProfile:true),
                            paw:PawPose(raise:raised-0.006*contact,lick:mouth.extensionAmount,offsetX:-12*raised))
    }
}
#endif
