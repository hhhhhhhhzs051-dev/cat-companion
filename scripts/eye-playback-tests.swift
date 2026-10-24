import Foundation

@main struct EyePlaybackTests {
    static func check(_ value: Bool, _ message: String) {
        if !value { fputs("FAIL eye playback: \(message)\n", stderr); exit(1) }
    }
    static func main() {
        var player = EyeGazePlayback()
        check(player.sample(at: 20) == .neutral && !player.isPlaying, "startup must not play")
        for direction in [-1.0, 1.0] {
            check(player.start(direction: direction, at: 100), "manual play must start")
            check(player.sample(at: 100) == .neutral, "must start at original, not teleport to target")
            check(!player.start(direction: -direction, at: 100.1), "busy click cannot interrupt or queue")
            let halfOut = player.sample(at: 100.23)
            check(abs(halfOut.x - direction * 0.5) < 1e-8, "halfway out is a small halfway translation")
            check(abs(player.sample(at: 100.46).x - direction) < 1e-8, "arrive at the approved static amplitude")
            check(abs(player.sample(at: 100.6).x - direction) < 1e-8, "brief hold has no jitter")
            check(abs(player.sample(at: 101.15).x - direction * 0.5) < 1e-8, "return moves smoothly through halfway")
            check(player.sample(at: 101.6) == .neutral && !player.isPlaying, "one look finishes at exact original")
            check(player.sample(at: 999) == .neutral, "no queued, looping or delayed playback")
            check(player.start(direction: direction, at: 200), "may manually replay after completion")
            var prior = 0.0
            for i in 0...100 {
                let t = Double(i) / 60
                let aim = player.sample(at: 200 + t)
                check(aim.y == 0 && abs(aim.x) <= 1, "no vertical aim or overshoot")
                check(abs(aim.x - prior) < 0.1, "60Hz samples must not jump or reverse abruptly")
                prior = aim.x
            }
            check(!player.isPlaying, "late tick must finish and stop")
        }
        check(!player.start(direction: .nan, at: 0), "invalid direction fails closed")
        check(!player.start(direction: 0, at: 0), "zero direction is not a playback")
        check(!player.start(direction: 1, at: .infinity), "invalid clock cannot start")
        check(player.start(direction: 1, at: 10), "fresh manual playback")
        _ = player.sample(at: 10.2)
        player.cancel()
        check(!player.isPlaying && player.sample(at: 10.3) == .neutral, "hide/reduce/cancel stops and resets")
        check(player.start(direction: -1, at: 20), "manual restart after cancellation")
        check(player.sample(at: .nan) == .neutral && !player.isPlaying, "invalid tick stops safely")
        print("PASS eye playback: exact original/approved endpoints, smooth bounded single play, no repeat/queue, cancellation")
    }
}
