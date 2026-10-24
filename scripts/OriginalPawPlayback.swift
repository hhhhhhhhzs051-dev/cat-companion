import Foundation

enum PawDemo: Int, CaseIterable {
    case outerLeft, outerRight, pushLeft, pushRight, pullLeft, pullRight
    var x: Double { [0.535, 0.685, 0.596, 0.624, 0.55, 0.67][rawValue] }
    var title: String { ["左侧勾近", "右侧勾近", "中心左推", "中心右推", "原版左勾", "原版右勾"][rawValue] }
    var isPush: Bool { self == .pushLeft || self == .pushRight }
}

// Preview-only playback clock. The frozen accepted planner still owns all
// timing and ball/elbow paths. Only the two candidate pulls get a small wrist
// refinement; center comparison clips remain the unchanged accepted motion.
struct OriginalPawPlayback {
    private(set) var frame = PreOuterFrame()
    private(set) var isPlaying = false
    private(set) var isPaused = false
    private(set) var elapsed = 0.0
    private(set) var demo = PawDemo.outerLeft
    private(set) var reduced = false
    private var toy = PreOuterToy()
    private var startedAt = 0.0, offset = 0.0
    static let duration = 1.30

    private func refined(_ original: PreOuterFrame, age: Double) -> PreOuterFrame {
        guard demo == .outerLeft || demo == .outerRight else { return original }
        func smooth(_ t: Double) -> Double {
            let x = max(0, min(1, t)); return x*x*(3-2*x)
        }
        // Same preparation/contact/follow-through boundaries as the frozen
        // pull. Rotate the existing hand, never translate its wrist/root or
        // change limb scale. At 290pt the pad moves ~3.0–3.5pt outward,
        // ~1.4–1.7pt beyond the first spacing preview, which felt too subtle.
        let preparation = smooth(age / (0.52 * 0.72))
        let follow = 1 - smooth((age - 0.52) / 0.18)
        let settle = 1 - smooth((age - 0.52 - 0.12) / 0.66)
        var result = original
        result.pawWrist -= 0.32 * preparation * follow * settle
        return result
    }

    private mutating func prepare() {
        toy = PreOuterToy(); toy.start(0); toy.grab(0.1)
        let inside = demo.x < 0.61 ? 0.55 : 0.67
        toy.move(to: CGPoint(x: inside, y: PreOuterToy.groundY(inside)), at: 0.2)
        toy.move(to: CGPoint(x: demo.x, y: PreOuterToy.groundY(demo.x)), at: 0.3)
        toy.release(1); frame = refined(toy.frame(1.08), age: 0)
        precondition(toy.hits == 1, "Preview preset must be reachable by the original paw")
    }
    @discardableResult mutating func play(_ demo: PawDemo, at now: Double, reduced: Bool = false) -> Bool {
        guard !isPlaying, now.isFinite else { return false }
        self.demo = demo; self.reduced = reduced
        elapsed = 0; offset = 0; startedAt = now
        prepare()
        isPlaying = !reduced; isPaused = false
        if reduced { seek(demo.isPush ? 0.32 : 0.52) }
        return true
    }
    mutating func tick(_ now: Double) {
        guard isPlaying, now.isFinite else { return }
        let age = min(Self.duration, max(elapsed, offset + max(0, now - startedAt)))
        // Repeated timestamps must not change filtered state on resume.
        if age != elapsed { elapsed = age; frame = refined(toy.frame(1.08 + age), age: age) }
        if age >= Self.duration { isPlaying = false; isPaused = false }
    }
    mutating func pause(_ now: Double) {
        guard isPlaying else { return }
        tick(now)
        if isPlaying { isPlaying = false; isPaused = true; offset = elapsed }
    }
    mutating func resume(_ now: Double) {
        guard isPaused, !reduced, now.isFinite, elapsed < Self.duration else { return }
        offset = elapsed; startedAt = now; isPlaying = true; isPaused = false
    }
    mutating func stop() { self = OriginalPawPlayback() }
    mutating func seek(_ age: Double) {
        guard age.isFinite else { return }
        prepare(); elapsed = min(Self.duration, max(0, age)); offset = elapsed
        frame = refined(toy.frame(1.08 + elapsed), age: elapsed)
        isPlaying = false; isPaused = elapsed < Self.duration
    }
    mutating func setReduced(_ value: Bool, at now: Double) {
        if value { pause(now) }
        reduced = value
    }
}
