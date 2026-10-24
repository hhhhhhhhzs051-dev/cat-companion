import Foundation

// Preview-only, one manually requested look; no queue or automatic restart.
struct EyeGazePlayback {
    private(set) var isPlaying = false
    private var startTime: TimeInterval = 0
    private var direction = 0.0
    mutating func start(direction: Double, at now: TimeInterval) -> Bool {
        guard !isPlaying, direction.isFinite, direction != 0, now.isFinite else { return false }
        self.direction = direction < 0 ? -1 : 1
        startTime = now
        isPlaying = true
        return true
    }
    mutating func sample(at now: TimeInterval) -> CatEyeAim {
        guard isPlaying else { return .neutral }
        guard now.isFinite else { cancel(); return .neutral }
        let elapsed = max(0, now - startTime)
        guard elapsed < 1.4 else { cancel(); return .neutral }
        func smooth(_ t: Double) -> Double { t * t * (3 - 2 * t) }
        let amount: Double
        if elapsed < 0.46 { amount = smooth(elapsed / 0.46) }
        else if elapsed < 0.9 { amount = 1 }
        else { amount = 1 - smooth((elapsed - 0.9) / 0.5) }
        return CatEyeAim(x: direction * amount, fixedApertureX: direction)
    }
    mutating func cancel() { isPlaying = false }
}
