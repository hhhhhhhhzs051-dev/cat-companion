import AppKit

// An isolated, still-image pose study. The accepted pre-outer planner and
// original paw pixels are sampled once; no application controller is linked.
private struct Still {
    let image: NSImage
    let bitmap: NSBitmapImageRep
    let frame: PreOuterFrame
}

private enum PoseStudy {
    static let size = NSSize(width: 290, height: 267)
    static let ages = [0.3744, 0.52, 0.82]
    static let candidates = [0.535, 0.685]
    static let originals = [0.55, 0.67]

    static func frames(at x: Double) -> [PreOuterFrame] {
        var toy = PreOuterToy()
        toy.start(0); toy.grab(0.1)
        // Approach through the accepted pull corridor. This only samples its
        // existing buffered poses; it does NOT change the live reach classifier.
        let inside = x < 0.61 ? 0.55 : 0.67
        toy.move(to: CGPoint(x: inside, y: PreOuterToy.groundY(inside)), at: 0.2)
        toy.move(to: CGPoint(x: x, y: PreOuterToy.groundY(x)), at: 0.3)
        toy.release(1)
        _ = toy.frame(1.08)
        precondition(toy.hits == 1, "Static candidate must use an original reachable pose")
        return ages.map { toy.frame(1.08 + $0) }
    }

    static func render(resources: URL, x: Double) throws -> [Still] {
        let view = try NativeCatView(resources: resources)
        view.frame = NSRect(origin: .zero, size: size)
        guard let art = view.pawArt else {
            throw NSError(domain: "PawStudy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Original paw artwork unavailable"])
        }
        return try frames(at: x).map { f in
            var ball = CatToyFrame()
            ball.position = f.position; ball.opacity = 1; ball.rotation = f.rotation
            // The accepted renderer also uses this value for the small
            // paw/chest separation shadow; preserve it in the still study.
            ball.paw = f.paw; ball.pawSide = f.pawSide
            view.toyFrame = ball
            var pose = CatPose()
            pose.paw = PawPose(raise: f.paw, toyElbow: f.pawElbow,
                               toyWrist: f.pawWrist, toySide: f.pawSide)
            // No body deformation, gaze, new art, moved root or limb scaling.
            precondition(pose.breath == 0 && pose.lean == 0 && pose.lookX == 0)
            precondition(pose.paw.offsetX == 0 && pose.paw.lift == 0)
            guard art.overlay(pose.paw) != nil else {
                throw NSError(domain: "PawStudy", code: 2, userInfo: [NSLocalizedDescriptionKey: "Original paw overlay unavailable"])
            }
            view.update(pose)
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 580, pixelsHigh: 534,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.size = size
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let image = NSImage(size: size)
            image.addRepresentation(bitmap)
            return Still(image: image, bitmap: bitmap, frame: f)
        }
    }
}

private final class FlippedCanvas: NSView {
    override var isFlipped: Bool { true }
}

private final class StudyWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
}

private final class PawStudyApp: NSObject, NSApplicationDelegate {
    private var window: StudyWindow!
    private var sheets: [[Still]] = []
    private var pictures: [NSImageView] = []
    private var chooser: NSSegmentedControl!
    private var modeLabel: NSTextField!

    func applicationDidFinishLaunching(_ notification: Notification) {
        do { try start() }
        catch {
            fputs("FAIL static preview: \(error)\n", stderr)
            exit(1)
        }
    }

    private func label(_ text: String, _ rect: NSRect, size: CGFloat = 13,
                       color: NSColor = .secondaryLabelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.frame = rect; field.font = .systemFont(ofSize: size); field.textColor = color
        window.contentView!.addSubview(field)
        return field
    }

    private func start() throws {
        let resources = Bundle.main.resourceURL!
        precondition(Bundle.main.bundleIdentifier == "local.catcompanion.preview.original-paw-static")
        precondition(!FileManager.default.fileExists(atPath: resources.appendingPathComponent("assets/cat-paw-outer-v2.png").path))
        for xs in [PoseStudy.candidates, PoseStudy.originals] {
            var sheet: [Still] = []
            for x in xs { sheet += try PoseStudy.render(resources: resources, x: x) }
            sheets.append(sheet)
        }
        let menu = NSMenu(), appItem = NSMenuItem(), appMenu = NSMenu()
        menu.addItem(appItem); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "关闭静态预览", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApp.mainMenu = menu
        window = StudyWindow(contentRect: NSRect(x: 0, y: 0, width: 950, height: 740),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "原版爪形 · 静态姿势校准 · 未安装（每只 290pt）"
        window.isReleasedWhenClosed = false; window.isRestorable = false
        window.collectionBehavior = [.fullScreenNone]; window.animationBehavior = .none
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(srgbRed: 0.14, green: 0.16, blue: 0.17, alpha: 1)
        window.contentView = FlippedCanvas(frame: NSRect(x: 0, y: 0, width: 950, height: 740))
        _ = label("原版爪形 · 三个静态关键姿势", NSRect(x: 24, y: 18, width: 470, height: 28), size: 20, color: .labelColor)
        _ = label("每只猫均为 290pt；只看爪形与连接，不播放动作。", NSRect(x: 24, y: 52, width: 550, height: 22))
        chooser = NSSegmentedControl(labels: ["小幅外探候选", "原版对照"], trackingMode: .selectOne,
                                     target: self, action: #selector(changeMode))
        chooser.frame = NSRect(x: 648, y: 21, width: 276, height: 30)
        chooser.selectedSegment = 0
        window.contentView!.addSubview(chooser)
        for (column, title) in ["外伸", "接触", "收回"].enumerated() {
            let field = label(title, NSRect(x: 20 + column * 310, y: 86, width: 290, height: 24), size: 16, color: .labelColor)
            field.alignment = .center
        }
        for row in 0..<2 {
            _ = label(row == 0 ? "球在左侧 · 猫的右爪" : "球在右侧 · 猫的左爪",
                      NSRect(x: 26, y: 116 + row * 291, width: 400, height: 20))
            for column in 0..<3 {
                let picture = NSImageView(frame: NSRect(x: 20 + column * 310, y: 130 + row * 291, width: 290, height: 267))
                picture.imageScaling = .scaleNone; picture.imageAlignment = .alignCenter
                picture.setAccessibilityLabel("\(row == 0 ? "左侧猫右爪" : "右侧猫左爪") · \(["外伸", "接触", "收回"][column]) · 290pt 静态")
                window.contentView!.addSubview(picture); pictures.append(picture)
            }
        }
        modeLabel = label("", NSRect(x: 24, y: 707, width: 720, height: 22))
        let close = NSButton(title: "关闭预览", target: self, action: #selector(closePreview))
        close.bezelStyle = .rounded; close.frame = NSRect(x: 824, y: 702, width: 102, height: 30)
        close.keyEquivalent = "\u{1b}"; window.contentView!.addSubview(close)
        changeMode()

        if let index = CommandLine.arguments.firstIndex(of: "--render-only"), index + 1 < CommandLine.arguments.count {
            let output = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            for mode in 0..<2 {
                for (i, still) in sheets[mode].enumerated() {
                    let name = "\(mode == 0 ? "candidate" : "original")-\(i < 3 ? "left" : "right")-\(["extend", "contact", "retract"][i % 3]).png"
                    try still.bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name))
                }
            }
            print("PASS: twelve original-paw stills, 290x267pt at 2x, no new outer asset")
            for (i, still) in sheets[0].enumerated() {
                print("candidate \(i): side=\(still.frame.pawSide), elbow=\(still.frame.pawElbow), wrist=\(still.frame.pawWrist)")
            }
            NSApp.terminate(nil); return
        }

        window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if CommandLine.arguments.contains("--self-test") {
            precondition(pictures.count == 6 && sheets.allSatisfy { $0.count == 6 })
            precondition(pictures.allSatisfy { $0.frame.size == PoseStudy.size && $0.image?.size == PoseStudy.size })
            precondition(window.level == .normal && !window.isRestorable && window.isVisible)
            chooser.selectedSegment = 1; changeMode()
            precondition(pictures[0].image === sheets[1][0].image)
            chooser.selectedSegment = 0; changeMode()
            precondition(pictures[0].image === sheets[0][0].image)
            close.performClick(nil); precondition(!window.isVisible)
            print("PASS: actual window, 290pt cells, original/candidate switch, close; no timer or product controller")
            NSApp.terminate(nil)
        }
    }

    @objc private func changeMode() {
        let mode = chooser.selectedSegment
        for (i, picture) in pictures.enumerated() { picture.image = sheets[mode][i].image }
        modeLabel.stringValue = mode == 0 ? "候选只小幅外探；身体、爪长和连接点不变。正式 48 版未动。" : "对照：原版较靠中的勾近姿势，同样以静态显示。"
    }
    @objc private func closePreview() { window.performClose(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main private struct StaticPawPreview {
    static func main() {
        let app = NSApplication.shared
        let delegate = PawStudyApp()
        app.setActivationPolicy(.regular); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
