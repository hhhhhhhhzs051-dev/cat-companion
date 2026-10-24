import Foundation

enum MouthGesture {case tongueTip, noseLick}
struct MouthPose:Equatable {
    var extensionAmount=0.0
    var curl=0.0
    var opening=0.0
    #if CAT_PAW_EXPERIMENT
    var grooming=false
    var sweep=0.0
    var fold=0.0
    #endif
}
enum CatMouth {
    static func pose(_ gesture:MouthGesture,elapsed:Double)->MouthPose {
        guard elapsed.isFinite,elapsed>0 else{return MouthPose()}
        func smooth(_ x:Double)->Double {let t=max(0,min(1,x));return t*t*(3-2*t)}
        if gesture == .noseLick {
            guard elapsed<1.08 else{return MouthPose()}
            // Mouth leads the tongue, then settles after it is fully hidden.
            let opening=smooth(elapsed/0.18)*(1-smooth((elapsed-0.80)/0.28))
            let amount=smooth((elapsed-0.08)/0.24)*(1-smooth((elapsed-0.44)/0.42))
            return MouthPose(extensionAmount:amount,curl:1,opening:opening)
        }
        let rise=gesture == .tongueTip ? 0.22:0.24
        let hold=gesture == .tongueTip ? 0.65:0.24
        let fall=gesture == .tongueTip ? 0.30:0.42
        guard elapsed<rise+hold+fall else{return MouthPose()}
        let amount=elapsed<rise ? smooth(elapsed/rise):1-smooth((elapsed-rise-hold)/fall)
        return MouthPose(extensionAmount:amount,curl:gesture == .noseLick ? 1:0)
    }
}
