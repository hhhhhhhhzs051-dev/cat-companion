#if CAT_PERF_PREVIEW
import AppKit

// This controller is absent from formal builds. All modes retain the original
// 30 Hz simulation, input handlers, speech receipts, growth and cooldown clocks.
// The 60 Hz mode only evaluates copies midway between committed model ticks.
final class CatPerformancePreview:NSObject {
    enum Mode:Int,CaseIterable {
        case baseline,bed,look,smooth
        var title:String {switch self {
        case .baseline:return "原版对照 · 30Hz"
        case .bed:return "只开猫窝缓存 · 30Hz"
        case .look:return "只开视线量化 · 30Hz（实验）"
        case .smooth:return "猫窝缓存＋活跃 60Hz"
        }}
    }
    weak var owner:PetApp?
    private(set) var mode=Mode.smooth
    private var presentationTimer:Timer?
    private(set) var modelTicks=0,presentationFrames=0
    #if CAT_RENDER_TEST
    var reducedForTest=false
    #endif
    init(owner:PetApp) {self.owner=owner;super.init();applyMode()}
    deinit {presentationTimer?.invalidate()}
    private func applyMode() {
        presentationTimer?.invalidate();presentationTimer=nil
        updateBedCache()
        owner?.art.lookQuantizationEnabled=mode == .look
    }
    private func updateBedCache() {
        // Do not retain extra idle memory for the active-only experiment.
        // Release the two bed bitmaps once the accepted interaction tail ends.
        let enabled=(mode == .bed || mode == .smooth) && interacting
        if owner?.art.bedCacheEnabled != enabled {owner?.art.bedCacheEnabled=enabled}
    }
    func activityChanged() {
        presentationTimer?.invalidate();presentationTimer=nil
        updateBedCache()
    }
    func choose(_ mode:Mode) {self.mode=mode;applyMode();owner?.tick()}
    @objc private func selectMode(_ item:NSMenuItem) {if let mode=Mode(rawValue:item.tag) {choose(mode)}}
    func menuItem()->NSMenuItem {
        let parent=NSMenuItem(title:"性能对照（仅预览）",action:nil,keyEquivalent:"")
        let menu=NSMenu();menu.autoenablesItems=false
        for value in Mode.allCases {
            let item=NSMenuItem(title:value.title,action:#selector(selectMode),keyEquivalent:"")
            item.target=self;item.tag=value.rawValue;item.state=value == mode ? .on:.off;menu.addItem(item)
        }
        parent.submenu=menu;return parent
    }
    private var interacting:Bool {
        #if CAT_RENDER_TEST
        if reducedForTest {return false}
        #endif
        guard let owner,owner.active,!owner.paused else{return false}
        let time=owner.now
        guard owner.toy.isEngaged(time) || owner.touch.playing || owner.touch.region == .head || owner.touch.region == .back || time<owner.motion.petEnd else{return false}
        // Do not poll the accessibility service for an idle-only extra frame
        // that will never be scheduled; the original idle policy is unchanged.
        return !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    private var eligible:Bool {mode == .smooth && interacting}
    func didTick(at time:Double) {
        modelTicks += 1
        presentationTimer?.invalidate();presentationTimer=nil
        updateBedCache()
        guard eligible,let owner else{return}
        let delay=1.0/60-(owner.now-time)
        // If the main thread has already spent the intermediate frame's budget,
        // skip it rather than queue work or delay the next accepted model tick.
        guard delay>0 else{return}
        let timer=Timer(timeInterval:delay,repeats:false) {[weak self] _ in self?.present()}
        timer.tolerance=0
        presentationTimer=timer
        RunLoop.main.add(timer,forMode:.common)
    }
    private func present() {
        presentationTimer=nil
        guard eligible,let owner else{return}
        let time=owner.now
        var motion=owner.motion
        var pose=motion.frame(time,reduced:false,paused:false,engaged:owner.toy.isEngaged(time))
        let canBat=motion.canPlayWithToy(time) && !owner.art.useV1Rendering
        let frame=owner.toy.presentationFrame(time,canBat:canBat)
        if canBat {
            let side=max(-1,min(1,frame.look*3))
            pose.leftEar=max(pose.leftEar,frame.attention*(0.675-0.425*side))
            pose.rightEar=max(pose.rightEar,frame.attention*(0.675+0.425*side))
            pose.lookX=frame.look
        }
        #if CAT_PAW_EXPERIMENT
        if frame.paw>0 {pose.paw=PawPose(raise:frame.paw,toyElbow:frame.pawElbow,toyWrist:frame.pawWrist,toySide:frame.pawSide)}
        #endif
        owner.art.toyFrame=frame;owner.art.update(pose)
        presentationFrames += 1
    }
}
#endif
