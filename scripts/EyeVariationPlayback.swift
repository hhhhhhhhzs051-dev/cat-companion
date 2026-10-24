import Foundation

enum EyeVariationAction:CaseIterable {
    case left,right,pupil,pupilWide
    var isPupil:Bool {self == .pupil || self == .pupilWide}
    var pupilPeak:Double {self == .pupilWide ? 1.4:1.25}
}

// Preview-only single shot: no queue, stacking, ambient playback or saved state.
struct EyeVariationPlayback {
    private(set) var isPlaying=false
    private var startTime=0.0
    private var action=EyeVariationAction.left
    mutating func start(_ action:EyeVariationAction,at now:Double)->Bool {
        guard !isPlaying,now.isFinite else{return false}
        self.action=action;startTime=now;isPlaying=true;return true
    }
    mutating func sample(at now:Double)->EyeVariation {
        guard isPlaying else{return .neutral}
        guard now.isFinite else{cancel();return .neutral}
        let t=max(0,now-startTime)
        let rise=action.isPupil ? 0.7:0.72
        let holdEnd=action.isPupil ? 1.2:1.18
        let end=action.isPupil ? 2.0:1.9
        guard t<end else{cancel();return .neutral}
        func smooth(_ x:Double)->Double {x*x*(3-2*x)}
        let a=t<rise ? smooth(t/rise):(t<holdEnd ? 1:1-smooth((t-holdEnd)/(end-holdEnd)))
        if action.isPupil {return EyeVariation(pupilWidth:1+(action.pupilPeak-1)*a,fixedAperture:true,pupilLimit:action.pupilPeak)}
        return EyeVariation(direction:(action == .left ? -1:1)*a,gain:1.5,fixedAperture:true)
    }
    mutating func cancel(){isPlaying=false}
}

final class EyeVariationPlayer {
    private var playback=EyeVariationPlayback()
    private var timer:Timer?
    private(set) var state=EyeVariation.neutral
    var onChange:((EyeVariation,Bool)->Void)?
    var reducedMotion=false {didSet{if reducedMotion {cancel()}}}
    var isPlaying:Bool {playback.isPlaying}
    var hasActiveTimer:Bool {timer?.isValid == true}
    @discardableResult func start(_ action:EyeVariationAction)->Bool {
        guard !reducedMotion,playback.start(action,at:ProcessInfo.processInfo.systemUptime) else{return false}
        publish(.neutral)
        let clock=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.tick()}
        clock.tolerance=0.001;timer=clock;RunLoop.main.add(clock,forMode:.common);return true
    }
    private func tick(){
        let next=playback.sample(at:ProcessInfo.processInfo.systemUptime)
        if !isPlaying {timer?.invalidate();timer=nil}
        if next != state || !isPlaying {publish(next)}
    }
    func cancel(){playback.cancel();timer?.invalidate();timer=nil;publish(.neutral)}
    private func publish(_ next:EyeVariation){state=next;onChange?(next,isPlaying)}
    deinit{timer?.invalidate()}
}
