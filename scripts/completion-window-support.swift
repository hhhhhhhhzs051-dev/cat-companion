import AppKit

// Test-only evidence. Query WindowServer at phase boundaries or AFTER a receipt
// decision, never from NativeCatView's visibility predicate. Only our own window
// metadata is logged; other apps' names, titles and content are not collected.
struct ReceiptWindowScene {
    let label: String
    let time = ProcessInfo.processInfo.systemUptime
    let windows: [[String: Any]]
    let ownFrontToBack: [Int]
    let coverErrors: [String]

    init(_ label: String, panel: NSWindow, cover: NSWindow) {
        self.label = label
        let probe = panel.childWindows?.first
        let owned = [panel, cover] + (probe.map { [$0] } ?? [])
        let infos = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let ids = infos.compactMap { $0[kCGWindowNumber as String] as? Int }
        ownFrontToBack = ids.filter { id in owned.contains { $0.windowNumber == id } }
        windows = owned.enumerated().map { index, window in
            let server = infos.first { ($0[kCGWindowNumber as String] as? Int) == window.windowNumber }
            return ["role": index == 0 ? "cat" : index == 1 ? "cover" : "probe",
             "id": window.windowNumber, "frame": NSStringFromRect(window.frame),
             "level": window.level.rawValue, "visible": window.isVisible,
             "activeSpace": window.isOnActiveSpace, "onScreen": ids.contains(window.windowNumber),
             "occlusion": window.occlusionState.rawValue, "opaque": window.isOpaque,
             "alpha": window.alphaValue, "serverBounds": server?[kCGWindowBounds as String] ?? [:],
             "serverAlpha": server?[kCGWindowAlpha as String] ?? -1] as [String: Any]
        }
        var errors: [String] = []
        if NSApp.isHidden { errors.append("app hidden") }
        if !panel.isOnActiveSpace || !ids.contains(panel.windowNumber) { errors.append("cat not on current screen") }
        if !cover.isOpaque || cover.alphaValue < 1 || cover.backgroundColor.alphaComponent < 1 { errors.append("cover not opaque") }
        if !cover.isOnActiveSpace || !ids.contains(cover.windowNumber) { errors.append("cover not on current screen") }
        if let probe {
            if !cover.frame.contains(probe.frame) { errors.append("cover does not contain whole probe") }
            func serverFrame(_ window: NSWindow) -> CGRect? {
                guard let row = infos.first(where: { ($0[kCGWindowNumber as String] as? Int) == window.windowNumber }),
                      let bounds = row[kCGWindowBounds as String] as? [String: Any],
                      let x = bounds["X"] as? NSNumber, let y = bounds["Y"] as? NSNumber,
                      let w = bounds["Width"] as? NSNumber, let h = bounds["Height"] as? NSNumber else { return nil }
                return CGRect(x: x.doubleValue, y: y.doubleValue, width: w.doubleValue, height: h.doubleValue)
            }
            if let c = serverFrame(cover), let p = serverFrame(probe) {
                if !c.contains(p) { errors.append("server cover bounds do not contain probe") }
            } else { errors.append("server bounds unavailable") }
            if !ids.contains(probe.windowNumber) { errors.append("probe not on current screen") }
            if let c = ids.firstIndex(of: cover.windowNumber), let p = ids.firstIndex(of: probe.windowNumber), c >= p { errors.append("cover not above probe") }
        } else { errors.append("pending probe missing") }
        coverErrors = errors
    }
    func emit() {
        let value: [String: Any] = ["phase": label, "uptime": time, "windows": windows,
                                    "ownFrontToBack": ownFrontToBack, "coverErrors": coverErrors]
        let data = try! JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
        print("[receipt-scene] " + String(decoding: data, as: UTF8.self)); fflush(stdout)
    }
    func requireCover() {
        emit()
        receiptCheck(coverErrors.isEmpty, "INVALID_SCENE: " + coverErrors.joined(separator: "; "), code: 2)
    }
}

final class ReceiptSolidCover: NSView {
    private(set) var drawCount = 0
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill(); drawCount += 1
    }
}

func receiptCheck(_ condition: @autoclosure () -> Bool, _ message: String, code: Int32 = 1) {
    guard condition() else {
        fputs("FAIL receipt-window: \(message)\n", stderr); fflush(stderr); exit(code)
    }
}
