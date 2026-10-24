import AppKit

// Frozen 137d8a07: accepted flower and the original red goldfish geometry.
enum PairPreviewGoldfishArt {
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
            ellipse(NSRect(x: 7, y: 8, width: 26, height: 26), growthSage)
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
            ellipse(NSRect(x: 12, y: 20, width: 9, height: 4), growthSage)
            ellipse(NSRect(x: 21, y: 18, width: 8, height: 4), growthSage)
            #if CAT_ACCESSORY_PREVIEW
            let petal = NSColor(calibratedRed: 1.00, green: 0.63, blue: 0.77, alpha: 1)
            let flowerCenter = NSColor(calibratedRed: 0.99, green: 0.84, blue: 0.31, alpha: 1)
            #else
            let petal = NSColor(calibratedRed: 0.91, green: 0.77, blue: 0.68, alpha: 1)
            let flowerCenter = NSColor(calibratedRed: 0.75, green: 0.60, blue: 0.36, alpha: 1)
            #endif
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
            #if CAT_ACCESSORY_PREVIEW
            let fishInk = NSColor(calibratedRed:0.60,green:0.19,blue:0.16,alpha:1)
            let red = NSColor(calibratedRed:0.95,green:0.23,blue:0.20,alpha:1)
            let finRed = NSColor(calibratedRed:0.99,green:0.38,blue:0.30,alpha:1)
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
            #else
            let blue = NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.75, alpha: 1)
            let cord = NSBezierPath(); cord.move(to: NSPoint(x: 20, y: 2)); cord.line(to: NSPoint(x: 20, y: 15)); cord.lineWidth = 1; outline.setStroke(); cord.stroke()
            let tail = NSBezierPath(); tail.move(to: NSPoint(x: 12, y: 24)); tail.line(to: NSPoint(x: 5, y: 18)); tail.line(to: NSPoint(x: 5, y: 30)); tail.close(); blue.setFill(); tail.fill()
            ellipse(NSRect(x: 10, y: 16, width: 24, height: 16), blue)
            let seam = NSBezierPath(); seam.move(to: NSPoint(x: 23, y: 18)); seam.curve(to: NSPoint(x: 23, y: 30), controlPoint1: NSPoint(x: 20, y: 21), controlPoint2: NSPoint(x: 20, y: 27)); seam.lineWidth = 0.8; outline.setStroke(); seam.stroke()
            ellipse(NSRect(x: 28, y: 21, width: 1.8, height: 1.8), outline)
            #endif
        }
    }
}
