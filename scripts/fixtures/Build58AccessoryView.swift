import AppKit

private let growthInk = NSColor(calibratedRed: 0.26, green: 0.31, blue: 0.29, alpha: 1)
private let growthMuted = NSColor(calibratedRed: 0.43, green: 0.47, blue: 0.43, alpha: 1)
let build58Sage = NSColor(calibratedRed: 0.49, green: 0.65, blue: 0.56, alpha: 1)

// Small static accessories. Neither cat pixels nor the toy's geometry are changed.
enum Build58GrowthArt {
    static func draw(_ reward: CatGrowthReward, in rect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState(); defer { ctx.restoreGState() }
        ctx.translateBy(x: rect.minX, y: rect.minY)
        ctx.scaleBy(x: rect.width / 40, y: rect.height / 40)
        let outline = NSColor(calibratedRed: 0.40, green: 0.47, blue: 0.41, alpha: 0.85)
        func ellipse(_ rect: NSRect, _ color: NSColor) {
            color.setFill(); let path = NSBezierPath(ovalIn: rect); path.fill()
        }
        switch reward {
        case .sageBall:
            ellipse(NSRect(x: 7, y: 8, width: 26, height: 26), build58Sage)
            NSColor(calibratedRed: 0.90, green: 0.91, blue: 0.76, alpha: 1).setStroke()
            for offset in [-7.0, 0, 7] {
                let p = NSBezierPath(); p.lineWidth = 1.4
                p.move(to: NSPoint(x: 10, y: 16 + offset))
                p.curve(to: NSPoint(x: 30, y: 25 + offset), controlPoint1: NSPoint(x: 8, y: 26 + offset), controlPoint2: NSPoint(x: 28, y: 13 + offset)); p.stroke()
            }
        case .flower:
            outline.setStroke()
            let stem = NSBezierPath(); stem.lineWidth = 1.5; stem.move(to: NSPoint(x: 20, y: 29)); stem.curve(to: NSPoint(x: 21, y: 13), controlPoint1: NSPoint(x: 18, y: 22), controlPoint2: NSPoint(x: 23, y: 20)); stem.stroke()
            ellipse(NSRect(x: 12, y: 20, width: 9, height: 4), build58Sage)
            ellipse(NSRect(x: 21, y: 18, width: 8, height: 4), build58Sage)
            let petal = NSColor(calibratedRed: 0.91, green: 0.77, blue: 0.68, alpha: 1)
            for i in 0..<5 {
                let a = Double(i) * .pi * 2 / 5
                ellipse(NSRect(x: 17 + cos(a) * 5, y: 9 + sin(a) * 5, width: 7, height: 7), petal)
            }
            ellipse(NSRect(x: 18, y: 10, width: 5, height: 5), NSColor(calibratedRed: 0.75, green: 0.60, blue: 0.36, alpha: 1))
            let pot = NSBezierPath(); pot.move(to: NSPoint(x: 12, y: 27)); pot.line(to: NSPoint(x: 28, y: 27)); pot.line(to: NSPoint(x: 26, y: 37)); pot.line(to: NSPoint(x: 14, y: 37)); pot.close()
            NSColor(calibratedRed: 0.72, green: 0.55, blue: 0.43, alpha: 1).setFill(); pot.fill()
            outline.setStroke(); pot.lineWidth = 0.8; pot.stroke()
        case .fish:
            let cord = NSBezierPath(); cord.move(to: NSPoint(x: 20, y: 2)); cord.line(to: NSPoint(x: 20, y: 15)); cord.lineWidth = 1; outline.setStroke(); cord.stroke()
            let blue = NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.75, alpha: 1)
            let tail = NSBezierPath(); tail.move(to: NSPoint(x: 12, y: 24)); tail.line(to: NSPoint(x: 5, y: 18)); tail.line(to: NSPoint(x: 5, y: 30)); tail.close(); blue.setFill(); tail.fill()
            ellipse(NSRect(x: 10, y: 16, width: 24, height: 16), blue)
            let seam = NSBezierPath(); seam.move(to: NSPoint(x: 23, y: 18)); seam.curve(to: NSPoint(x: 23, y: 30), controlPoint1: NSPoint(x: 20, y: 21), controlPoint2: NSPoint(x: 20, y: 27)); seam.lineWidth = 0.8; outline.setStroke(); seam.stroke()
            ellipse(NSRect(x: 28, y: 21, width: 1.8, height: 1.8), outline)
        }
    }
}

final class Build58AccessoryView: NSView {
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    var selection: CatGrowthReward? { didSet { if oldValue != selection { needsDisplay = true } } }
    override func draw(_ dirtyRect: NSRect) {
        guard let selection else { return }
        let scale = bounds.width / 290
        // Outside the reach surface and original printed cat motif. The fish's
        // cord starts at the visible rim; the pot rests beside the bed's base.
        if selection == .flower {
            NSColor(calibratedWhite: 0.25, alpha: 0.14).setFill()
            NSBezierPath(ovalIn: NSRect(x: 263 * scale, y: 60 + 187 * scale, width: 20 * scale, height: 4 * scale)).fill()
            Build58GrowthArt.draw(selection, in: NSRect(x: 255 * scale, y: 60 + 156 * scale, width: 34 * scale, height: 34 * scale))
        } else {
            Build58GrowthArt.draw(selection, in: NSRect(x: 241 * scale, y: 60 + 109 * scale, width: 31 * scale, height: 31 * scale))
        }
    }
}


