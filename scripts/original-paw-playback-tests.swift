import Foundation

@main struct OriginalPawPlaybackTests {
    static func check(_ ok: Bool, _ message: String) {
        if !ok { fputs("FAIL: \(message)\n", stderr); exit(1) }
    }
    static func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-10 }
    static func visible(_ a: PreOuterFrame, _ b: Accepted48Frame) -> Bool {
        a.position == b.position && a.opacity == b.opacity && a.rotation == b.rotation &&
        a.paw == b.paw && a.pawElbow == b.pawElbow && a.pawWrist == b.pawWrist &&
        a.pawSide == b.pawSide && a.pawLift == b.pawLift && a.pawOffsetX == b.pawOffsetX
    }
    // Independent forward geometry of the unchanged original two-link limb.
    static func tip(_ f: PreOuterFrame) -> CGPoint {
        let e = f.pawElbow, a = e + f.pawWrist
        let x = 605 + 148*cos(e) + 58*sin(e) + 47*cos(a) + 42*sin(a)
        let y = 850 + 148*sin(e) - 58*cos(e) + 47*sin(a) - 42*cos(a)
        return CGPoint(x: (f.pawSide < 0 ? x : 1590.5-x)*290/1525, y: y*290/1525)
    }
    static func original(_ demo: PawDemo) -> PreOuterToy {
        var toy = PreOuterToy(); toy.start(0); toy.grab(0.1)
        let inside = demo.x < 0.61 ? 0.55 : 0.67
        toy.move(to: CGPoint(x: inside, y: PreOuterToy.groundY(inside)), at: 0.2)
        toy.move(to: CGPoint(x: demo.x, y: PreOuterToy.groundY(demo.x)), at: 0.3)
        toy.release(1); _ = toy.frame(1.08)
        return toy
    }
    static func checkSpacing() {
        for demo in [PawDemo.outerLeft, .outerRight] {
            var player = OriginalPawPlayback(), old = original(demo)
            _ = player.play(demo, at: 0)
            for age in [0.3744, 0.52] {
                player.tick(age)
                let before = old.frame(1.08 + age), a = tip(before), b = tip(player.frame)
                let outward = (b.x-a.x) * (demo == .outerLeft ? -1 : 1)
                check(outward > 2.8 && outward < 3.8, "Pull tip must have the slightly wider requested spacing at 290pt: \(demo), \(age), \(outward)pt")
                // Turning a fixed-length hand follows an arc, with no added lift.
                check(abs(b.y-a.y) < 2.5, "Wrist arc must stay low beside the ball")
            }
            old = original(demo); player.stop(); _ = player.play(demo, at: 0)
            for n in 0...156 {
                let age = Double(n)/120
                player.tick(age)
                let before = old.frame(1.08 + age)
                var after = player.frame
                let correction = after.pawWrist-before.pawWrist
                after.pawWrist = before.pawWrist
                check(after == before, "Only the wrist may change, not attachment, elbow, body, ball or timing")
                check(correction <= 1e-10 && correction >= -0.33, "No reversed or excessive wrist correction")
                if age == 0 || age >= 0.70 { check(abs(correction) < 1e-10, "Original rest/follow-through must be exact") }
            }
            // No extra cusp at preparation, contact, or rejoining the old path.
            for boundary in [0.3744, 0.52, 0.70] {
                var deltas: [Double] = []
                for age in [boundary-0.0001, boundary, boundary+0.0001] {
                    player.seek(age); var baseline = original(demo)
                    deltas.append(player.frame.pawWrist-baseline.frame(1.08+age).pawWrist)
                }
                check(abs(deltas[1]-deltas[0]) < 0.000002 && abs(deltas[2]-deltas[1]) < 0.000002,
                      "Wrist refinement must join smoothly at \(boundary)")
            }
        }
    }
    static func main() {
        checkSpacing()
        var player = OriginalPawPlayback()
        check(!player.isPlaying, "Opening preview must not autoplay")
        check(player.play(.outerLeft, at: 10), "Explicit play starts a one-shot clip")
        check(player.isPlaying && player.frame.paw == 0, "Clip begins with resting original paw")
        // Original elbow and return poses stay exact. Only preparation/contact
        // wrist angles have the newly requested, preview-only outward turn.
        for demo in [PawDemo.outerLeft, .outerRight] {
            player.stop(); _ = player.play(demo, at: 0)
            let expected: [(Double, Double, Double)] = [
                (0.3744, 0.09, -1.495), (0.52, 0.04, -1.69),
                (0.82, 0.3474229902329071, -0.5681141998497371)]
            for (age, elbow, wrist) in expected {
                player.tick(age)
                check(near(player.frame.pawElbow, elbow) && near(player.frame.pawWrist, wrist), "Pull-only refinement at keypose \(demo), \(age)")
                check(player.frame.pawSide == (demo == .outerLeft ? -1 : 1), "Correct anatomical paw stays selected")
                check(player.frame.pawLift == 0 && player.frame.pawOffsetX == 0 && player.frame.bodyRock == 0, "No stretched/shifted limb or body sway")
            }
        }
        player.stop(); _ = player.play(.outerLeft, at: 0)
        player.tick(0.51)
        check(near(player.frame.position.x, 0.535), "Ball remains still before original contact time")
        player.tick(0.52)
        check(near(player.frame.position.x, 0.535) && near(player.frame.paw, 1), "Contact precedes ball rolling")
        player.tick(0.70)
        check(player.frame.position.x > 0.535 && player.frame.position.x < 0.61, "Ball moves inward after contact")
        player.tick(1.3)
        check(!player.isPlaying && player.frame.paw == 0 && near(player.frame.position.x, 0.61), "One-shot ends at rest; does not loop")
        let ended = player.frame; player.tick(100)
        check(player.frame == ended, "Long idle cannot schedule another action")

        _ = player.play(.outerRight, at: 200); player.pause(200.4)
        let held = player.frame
        check(player.isPaused && !player.isPlaying, "Pause stops the playback clock")
        player.tick(999)
        check(player.frame == held, "Background time cannot advance a paused pose")
        player.resume(1000); player.tick(1000)
        check(player.frame == held, "Resume has no elapsed-time jump")
        player.tick(1000.1)
        check(near(player.elapsed, 0.5), "Resume continues from the paused age")
        let active = player.frame
        check(!player.play(.outerLeft, at: 1000.1) && player.frame == active, "Repeated play does not snap an active paw")
        player.setReduced(true, at: 1000.1)
        check(!player.isPlaying, "Reduced motion immediately stops the timer contract")
        let reduced = player.frame; player.tick(4000)
        check(player.frame == reduced, "Reduced motion stays static")
        player.setReduced(false, at: 4000)
        check(!player.isPlaying, "Disabling reduced motion never auto-restarts")
        player.stop()
        check(!player.isPlaying && !player.isPaused, "Closing the preview cancels playback")

        // Accepted central gestures must retain the formal48 ball and paw path.
        for demo in [PawDemo.pushLeft, .pushRight, .pullLeft, .pullRight] {
            var old = Accepted48Toy(); old.start(0); old.grab(0.1)
            let inside = demo.x < 0.61 ? 0.55 : 0.67
            old.move(to: CGPoint(x: inside, y: Accepted48Toy.groundY(inside)), at: 0.2)
            old.move(to: CGPoint(x: demo.x, y: Accepted48Toy.groundY(demo.x)), at: 0.3)
            old.release(1); _ = old.frame(1.08)
            player.stop(); _ = player.play(demo, at: 0)
            for n in 0...156 {
                let age = Double(n) / 120
                player.tick(age)
                check(visible(player.frame, old.frame(1.08 + age)), "Central frame differs from formal48: \(demo), \(age)")
            }
        }
        print("PASS small outward tip displacement, wrist-only smooth joins, unchanged return, contact-before-roll, central48 frames, one-shot, pause/resume, repeat-input and reduced-motion clock")
    }
}
