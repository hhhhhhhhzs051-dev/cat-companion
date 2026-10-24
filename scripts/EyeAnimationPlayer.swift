import Foundation

// The independent preview owns this timer. No production lifecycle or stores.
final class EyeAnimationPlayer {
    private var playback = EyeGazePlayback()
    private var timer: Timer?
    private(set) var aim = CatEyeAim.neutral
    var onChange: ((CatEyeAim, Bool) -> Void)?
    var reducedMotion = false { didSet { if reducedMotion { cancel() } } }
    var isPlaying: Bool { playback.isPlaying }
    var hasActiveTimer: Bool { timer?.isValid == true }

    @discardableResult func start(direction: Double) -> Bool {
        guard !reducedMotion,
              playback.start(direction: direction, at: ProcessInfo.processInfo.systemUptime) else { return false }
        publish(.neutral)
        let clock = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        clock.tolerance = 0.001
        timer = clock
        RunLoop.main.add(clock, forMode: .common)
        return true
    }
    private func tick() {
        let next = playback.sample(at: ProcessInfo.processInfo.systemUptime)
        if !playback.isPlaying { stopTimer() }
        // Holding and stopped states do not request repeated redraws.
        if next != aim || !playback.isPlaying { publish(next) }
    }
    func cancel() {
        playback.cancel()
        stopTimer()
        publish(.neutral)
    }
    private func stopTimer() { timer?.invalidate(); timer = nil }
    private func publish(_ next: CatEyeAim) {
        aim = next
        onChange?(next, playback.isPlaying)
    }
    deinit { timer?.invalidate() }
}
