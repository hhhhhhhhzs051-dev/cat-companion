// Frozen accepted b25cb99f preview. Do not modify to accommodate production changes.
import AppKit

private let acceptedPairInk = NSColor(calibratedRed: 0.26, green: 0.31, blue: 0.29, alpha: 1)
private let acceptedPairMuted = NSColor(calibratedRed: 0.43, green: 0.47, blue: 0.43, alpha: 1)
let acceptedPairSage = NSColor(calibratedRed: 0.49, green: 0.65, blue: 0.56, alpha: 1)

// Accessory artwork only; cat pixels and toy geometry are never changed here.
enum AcceptedPairArt {
    static func draw(_ reward: CatGrowthReward, in rect: NSRect, sway:Double=0) {
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
            ellipse(NSRect(x: 7, y: 8, width: 26, height: 26), acceptedPairSage)
            NSColor(calibratedRed: 0.90, green: 0.91, blue: 0.76, alpha: 1).setStroke()
            for offset in [-7.0, 0, 7] {
                let p = NSBezierPath(); p.lineWidth = 1.4
                p.move(to: NSPoint(x: 10, y: 16 + offset))
                p.curve(to: NSPoint(x: 30, y: 25 + offset), controlPoint1: NSPoint(x: 8, y: 26 + offset), controlPoint2: NSPoint(x: 28, y: 13 + offset)); p.stroke()
            }
        case .flower:
            ctx.saveGState()
            if sway != 0 {ctx.translateBy(x:20,y:28);ctx.rotate(by:sway);ctx.translateBy(x:-20,y:-28)}
            outline.setStroke()
            let stem = NSBezierPath(); stem.lineWidth = 1.5; stem.move(to: NSPoint(x: 20, y: 29)); stem.curve(to: NSPoint(x: 21, y: 13), controlPoint1: NSPoint(x: 18, y: 22), controlPoint2: NSPoint(x: 23, y: 20)); stem.stroke()
            ellipse(NSRect(x: 12, y: 20, width: 9, height: 4), acceptedPairSage)
            ellipse(NSRect(x: 21, y: 18, width: 8, height: 4), acceptedPairSage)
                        let petal = NSColor(calibratedRed: 1.00, green: 0.63, blue: 0.77, alpha: 1)
            let flowerCenter = NSColor(calibratedRed: 0.99, green: 0.84, blue: 0.31, alpha: 1)
            for i in 0..<5 {
                let a = Double(i) * .pi * 2 / 5
                ellipse(NSRect(x: 17 + cos(a) * 5, y: 9 + sin(a) * 5, width: 7, height: 7), petal)
            }
            ellipse(NSRect(x: 18, y: 10, width: 5, height: 5), flowerCenter)
            ctx.restoreGState() // The pot and its shadow remain planted.
            let pot = NSBezierPath(); pot.move(to: NSPoint(x: 12, y: 27)); pot.line(to: NSPoint(x: 28, y: 27)); pot.line(to: NSPoint(x: 26, y: 37)); pot.line(to: NSPoint(x: 14, y: 37)); pot.close()
            NSColor(calibratedRed: 0.72, green: 0.55, blue: 0.43, alpha: 1).setFill(); pot.fill()
            outline.setStroke(); pot.lineWidth = 0.8; pot.stroke()
        case .fish:
            if sway != 0 {ctx.translateBy(x:20,y:2);ctx.rotate(by:sway);ctx.translateBy(x:-20,y:-2)}
                        let fishInk = NSColor(calibratedRed:0.60,green:0.29,blue:0.25,alpha:1)
            let red = NSColor(calibratedRed:0.91,green:0.43,blue:0.36,alpha:1)
            let finRed = NSColor(calibratedRed:0.98,green:0.58,blue:0.44,alpha:1)
            // Keep the accepted cord and hinge; the ornament alone is a goldfish.
            NSColor(calibratedRed:0.52,green:0.31,blue:0.25,alpha:1).setStroke()
            let cord=NSBezierPath();cord.move(to:NSPoint(x:20,y:2));cord.line(to:NSPoint(x:20,y:15));cord.lineWidth=1;cord.stroke()
            func fin(_ path:NSBezierPath) {finRed.setFill();path.fill();fishInk.setStroke();path.lineWidth=0.65;path.stroke()}
            let tail=NSBezierPath();tail.move(to:NSPoint(x:16,y:23))
            tail.curve(to:NSPoint(x:4,y:13),controlPoint1:NSPoint(x:11,y:16),controlPoint2:NSPoint(x:7,y:13))
            tail.curve(to:NSPoint(x:7,y:24),controlPoint1:NSPoint(x:3,y:18),controlPoint2:NSPoint(x:5,y:22))
            tail.curve(to:NSPoint(x:4,y:34),controlPoint1:NSPoint(x:5,y:27),controlPoint2:NSPoint(x:3,y:31))
            tail.curve(to:NSPoint(x:16,y:25),controlPoint1:NSPoint(x:8,y:34),controlPoint2:NSPoint(x:12,y:30));tail.close();fin(tail)
            let dorsal=NSBezierPath();dorsal.move(to:NSPoint(x:18,y:17))
            dorsal.curve(to:NSPoint(x:18,y:11),controlPoint1:NSPoint(x:16,y:15),controlPoint2:NSPoint(x:17,y:12))
            dorsal.curve(to:NSPoint(x:27,y:16),controlPoint1:NSPoint(x:22,y:11),controlPoint2:NSPoint(x:26,y:13));dorsal.close();fin(dorsal)
            let lower=NSBezierPath();lower.move(to:NSPoint(x:21,y:29))
            lower.curve(to:NSPoint(x:18,y:34),controlPoint1:NSPoint(x:22,y:32),controlPoint2:NSPoint(x:20,y:34))
            lower.curve(to:NSPoint(x:28,y:29),controlPoint1:NSPoint(x:23,y:34),controlPoint2:NSPoint(x:27,y:32));lower.close();fin(lower)
            let body=NSBezierPath(ovalIn:NSRect(x:13.5,y:15,width:20.5,height:16.5));red.setFill();body.fill();fishInk.setStroke();body.lineWidth=0.8;body.stroke()
            let gill=NSBezierPath();gill.move(to:NSPoint(x:24,y:18.5));gill.curve(to:NSPoint(x:24,y:28.5),controlPoint1:NSPoint(x:21,y:21),controlPoint2:NSPoint(x:21.5,y:26));gill.lineWidth=0.7;gill.stroke()
            let rays=NSBezierPath();rays.move(to:NSPoint(x:13,y:22));rays.line(to:NSPoint(x:6,y:17));rays.move(to:NSPoint(x:13,y:26));rays.line(to:NSPoint(x:6,y:30));rays.lineWidth=0.5;rays.stroke()
            NSColor(calibratedRed:1,green:0.66,blue:0.48,alpha:0.8).setStroke()
            let glint=NSBezierPath();glint.move(to:NSPoint(x:17,y:20));glint.curve(to:NSPoint(x:24,y:18),controlPoint1:NSPoint(x:19,y:18),controlPoint2:NSPoint(x:21,y:17.5));glint.lineWidth=0.9;glint.stroke()
            ellipse(NSRect(x:28.5,y:20.5,width:2,height:2),NSColor(calibratedRed:0.35,green:0.15,blue:0.13,alpha:1))
        }
    }
}

final class AcceptedPairView: NSView {
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    var selection: CatGrowthReward? { didSet { if oldValue != selection {needsDisplay=true} } }
        var selections:Set<CatGrowthReward> = [] {didSet {
        guard oldValue != selections else{return}
        if !selections.contains(.flower) {flowerSway.cancel()}
        if !selections.contains(.fish) {fishSway.cancel()}
        needsDisplay=true
    }}
    private var flowerSway=CatAccessorySway(),fishSway=CatAccessorySway()
    func sway(for reward:CatGrowthReward)->CatAccessorySway {reward == .flower ? flowerSway:fishSway}
    func drawingRect(for reward:CatGrowthReward)->NSRect {
        let s=bounds.width/290
        // 34 * 1.25. Keep the original pot base at y=60+187.45*s;
        // shift inward so the larger flower and its sway stay inside the window.
        if reward == .flower {return NSRect(x:246.5*s,y:60+148.1375*s,width:42.5*s,height:42.5*s)}
        if reward == .fish {return NSRect(x:241*s,y:60+109*s,width:31*s,height:31*s)}
        return .zero
    }
    func interactionRect(for reward:CatGrowthReward)->NSRect {
        guard selections.contains(reward),reward != .sageBall else{return .zero}
        let padding=3*bounds.width/290
        return drawingRect(for:reward).insetBy(dx:-padding,dy:-padding).intersection(bounds)
    }
    func reward(at point:NSPoint)->CatGrowthReward? {
        [.flower,.fish].first {let r=interactionRect(for:$0);return !r.isEmpty && r.contains(point)}
    }
    func containsInteraction(_ point:NSPoint)->Bool {reward(at:point) != nil}
    func tap(_ reward:CatGrowthReward,at time:Double,reduced:Bool) {
        guard selections.contains(reward) else{return}
        if reward == .flower {flowerSway.tap(at:time,flower:true,reduced:reduced)}
        else if reward == .fish {fishSway.tap(at:time,flower:false,reduced:reduced)}
    }
    func cancelMotion() {
        let changed=flowerSway.angle != 0 || fishSway.angle != 0
        flowerSway.cancel();fishSway.cancel();if changed {needsDisplay=true}
    }
    func advance(to time:Double,enabled:Bool,reduced:Bool) {
        guard enabled,!reduced else {cancelMotion();return}
        guard flowerSway.isActive || fishSway.isActive else{return}
        let flowerBefore=flowerSway.angle,fishBefore=fishSway.angle
        flowerSway.advance(to:time);fishSway.advance(to:time)
        if flowerSway.angle != flowerBefore || fishSway.angle != fishBefore {needsDisplay=true}
    }

    override func draw(_ dirtyRect: NSRect) {
        let scale = bounds.width / 290
                for reward in [CatGrowthReward.fish,.flower] where selections.contains(reward) {
            if reward == .flower {
                NSColor(calibratedWhite:0.25,alpha:0.14).setFill()
                NSBezierPath(ovalIn:NSRect(x:255.25*scale,y:60+187*scale,width:25*scale,height:4*scale)).fill()
            }
            AcceptedPairArt.draw(reward,in:drawingRect(for:reward),sway:sway(for:reward).angle)
        }
    }
}
