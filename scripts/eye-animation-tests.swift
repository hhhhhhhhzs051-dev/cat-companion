import AppKit
import CoreImage

@main struct EyeAnimationTests {
    static func check(_ value: Bool, _ message: String) {
        if !value { fputs("FAIL eye animation: \(message)\n", stderr); exit(1) }
    }
    static func bitmap(_ view: NSView) -> NSBitmapImageRep {
        let b = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 580, pixelsHigh: 534,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        b.size = view.bounds.size; view.cacheDisplay(in: view.bounds, to: b); return b
    }
    static func pump(_ seconds: Double) { RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds)) }
    static func main() throws {
        _ = NSApplication.shared
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        let player = EyeAnimationPlayer()
        var samples: [CatEyeAim] = []
        player.onChange = { aim, _ in samples.append(aim) }
        check(!player.isPlaying && !player.hasActiveTimer, "no idle timer at startup")
        check(player.start(direction: -1), "real timer playback starts")
        check(!player.start(direction: 1), "repeated input must not queue")
        pump(1.65)
        check(samples.contains { $0.x < -0.99 }, "actual timer reaches approved left target")
        check(!player.isPlaying && !player.hasActiveTimer && player.aim == .neutral, "timer must finish at original and invalidate")
        let count = samples.count
        pump(0.25)
        check(samples.count == count, "no callbacks or repeated animation after completion")
        check(player.start(direction: 1), "manual restart works")
        pump(0.1); player.cancel()
        check(player.aim == .neutral && !player.hasActiveTimer, "visibility cancellation releases timer")
        player.reducedMotion = true
        check(!player.start(direction: 1) && !player.hasActiveTimer, "reduced motion never animates")
        player.reducedMotion = false
        check(!player.hasActiveTimer, "turning motion back on cannot resume")
        check(player.start(direction: 1), "explicit replay after reduced motion")
        pump(0.1); player.reducedMotion = true
        check(player.aim == .neutral && !player.isPlaying && !player.hasActiveTimer, "mid-play reduced motion cancels")
        print("PASS real preview timer: one shot, repeat input, idle silence, cancellation and reduced motion")

        let view = try NativeCatView(resources: URL(fileURLWithPath: "src"))
        view.frame = NSRect(x: 0, y: 0, width: 290, height: 267)
        view.update(CatPose())
        let base = bitmap(view)
        let original = Data(bytes: base.bitmapData!, count: base.bytesPerRow * base.pixelsHigh)
        let context = CIContext(options: [.cacheIntermediates: false])
        let source = CIImage(contentsOf: URL(fileURLWithPath: "src/assets/cat-d.png"))!
        let renderer = CatEyeGazeRenderer()
        let rawBase = NSBitmapImageRep(cgImage: context.createCGImage(source, from: source.extent)!)
        let staticRenderer = StaticRigidEyeRenderer()
        for x in [-1.0, 0, 1] {
            let frozen = NSBitmapImageRep(cgImage: context.createCGImage(
                staticRenderer.apply(to: source, aim: StaticRigidEyeAim(x: x)), from: source.extent)!)
            let animated = NSBitmapImageRep(cgImage: context.createCGImage(
                renderer.apply(to: source, aim: CatEyeAim(x: x, fixedApertureX: x)), from: source.extent)!)
            check(frozen.bytesPerRow == animated.bytesPerRow &&
                  Data(bytes: frozen.bitmapData!, count: frozen.bytesPerRow * frozen.pixelsHigh) ==
                  Data(bytes: animated.bitmapData!, count: animated.bytesPerRow * animated.pixelsHigh),
                  "animation endpoints must exactly preserve approved static original/left/right")
        }
        var maxChannelStep = 0, renderTimes: [Double] = [], largestStep = ""
        for (label, direction) in [("left", -1.0), ("right", 1.0)] {
            var timeline = EyeGazePlayback()
            _ = timeline.start(direction: direction, at: 0)
            var previous = original
            for frame in 0...86 {
                let aim = timeline.sample(at: Double(frame) / 60)
                view.eyeAim = aim
                let start = ProcessInfo.processInfo.systemUptime
                let image = bitmap(view)
                renderTimes.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
                let bytes = Data(bytes: image.bitmapData!, count: image.bytesPerRow * image.pixelsHigh)
                check(view.pose == CatPose(), "animation must not move head/body/ears or eyelids")
                for y in 0..<534 { for x in 0..<580 {
                    let p = CGPoint(x: Double(x) / 2, y: Double(y) / 2)
                    let inside = CGRect(x: 147, y: 126, width: 22, height: 18).contains(p)
                        || CGRect(x: 184, y: 126, width: 22, height: 18).contains(p)
                    let i = y * image.bytesPerRow + x * 4
                    if inside {
                        for channel in 0..<3 {
                            let delta = abs(Int(bytes[i+channel]) - Int(previous[i+channel]))
                            if delta > maxChannelStep {
                                maxChannelStep = delta
                                largestStep = "\(label) frame \(frame), pixel \(x),\(y), channel \(channel), \(previous[i+channel])->\(bytes[i+channel]), aim \(aim.x)"
                            }
                        }
                    } else {
                        check(bytes[i..<i+4] == original[i..<i+4], "intermediate \(label) frame \(frame) must preserve every outside-eye pixel")
                    }
                }}
                if aim == .neutral { check(bytes == original, "neutral/reset must be byte-exact original") }
                if [0, 14, 28, 48, 69, 86].contains(frame) {
                    try image.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(label)-\(frame)-290pt.png"))
                }
                previous = bytes
            }
            // Every intermediate fraction: preserve hand-calibrated eyelid
            // landmarks, not merely matching endpoints or pupil centroids.
            for step in 0...32 {
                let image = renderer.apply(to: source, aim: CatEyeAim(x: direction * Double(step) / 32, fixedApertureX: direction))
                let cg = context.createCGImage(image, from: source.extent)!
                let raw = NSBitmapImageRep(cgImage: cg)
                for (x,y) in [(674,529),(682,531),(690,533),(699,536),(700,536),(709,539),
                              (870,531),(872,532),(878,528),(886,526),(902,524),
                              (678,530),(680,531),(697,535),(702,536),(706,538),(874,531),(888,527),(890,526)] {
                    let a = rawBase.bitmapData!.advanced(by: y * rawBase.bytesPerRow + x * 4)
                    let b = raw.bitmapData!.advanced(by: y * raw.bytesPerRow + x * 4)
                    check((0..<4).allSatisfy { a[$0] == b[$0] }, "fixed eyelid moved at \(label) fraction \(step)/32, \(x),\(y)")
                }
                if [8,16,24].contains(step) {
                    let crop = cg.cropping(to: CGRect(x: 620, y: 510, width: 330, height: 90))!
                    try NSBitmapImageRep(cgImage: crop).representation(using: .png, properties: [:])!
                        .write(to: out.appendingPathComponent("\(label)-interior-\(step).png"))
                }
            }
        }
        var fineStep = 0
        for direction in [-1.0, 1.0] {
            var prior: Data?
            for step in 0...256 {
                view.eyeAim = CatEyeAim(x: direction * Double(step) / 256,
                    fixedApertureX: CommandLine.arguments.contains("--moving-aperture") ? nil : direction)
                let image = bitmap(view)
                let bytes = Data(bytes: image.bitmapData!, count: image.bytesPerRow * image.pixelsHigh)
                if let prior {
                    for y in 252..<288 { for x in 294..<412 {
                        let i = y * image.bytesPerRow + x * 4
                        for c in 0..<3 { fineStep = max(fineStep, abs(Int(bytes[i+c]) - Int(prior[i+c]))) }
                    }}
                }
                prior = bytes
            }
        }
        print("METRIC fine 1/256 aim steps: max channel change \(fineStep)/255")
        check(fineStep <= 4, "tiny movement must not toggle an eye-edge patch: \(fineStep)/255")
        // Also keep the chosen gentle playback speed below this deliberately
        // conservative normal-size per-frame visual-review threshold.
        check(maxChannelStep <= 16, "normal-size frame discontinuity: largest channel step \(maxChannelStep)/255; \(largestStep)")
        renderTimes.sort()
        print("METRIC native290: max adjacent channel step \(maxChannelStep)/255; raster median \(renderTimes[renderTimes.count/2]) ms, p95 \(renderTimes[Int(Double(renderTimes.count-1)*0.95)]) ms")
        print("PASS 174 native290 animation frames: fixed outside/pose, exact return, 66 fractional lid checks; user visual acceptance still required")
    }
}
