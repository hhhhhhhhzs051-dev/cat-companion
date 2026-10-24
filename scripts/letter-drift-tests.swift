import AppKit

@main struct LetterDriftTests {
    static func check(_ condition:Bool,_ message:String) {
        if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)}
    }
    static func paperPixels(_ reader:CatLetterController,scale:Int)->Data {
        let rect=reader.paperView.frame
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(rect.width)*scale,
            pixelsHigh:Int(rect.height)*scale,bitsPerSample:8,samplesPerPixel:4,
            hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        bitmap.size=rect.size
        reader.window!.contentView!.cacheDisplay(in:rect,to:bitmap)
        return Data(bytes:bitmap.bitmapData!,count:bitmap.bytesPerRow*bitmap.pixelsHigh)
    }
    static func main() {
        _=NSApplication.shared
        let plan=LetterDriftPlan(bounds:CGRect(x:0,y:0,width:540,height:528),
                                 imageSize:CGSize(width:1269,height:1240),textRight:512)
        let active=plan.frames(at:0.8)
        check(active.count==3,"Opening emits just two petals and one leaf")
        check(active.filter{$0.kind == .petal}.count==2 && active.filter{$0.kind == .leaf}.count==1,
              "The opening is a small mixed fall, not a particle shower")
        check(active.allSatisfy{$0.center.y>55 && $0.center.y<230},"Pieces come from the upper-right branch")
        // Literal artwork landmarks: the large flower's lower-right petal,
        // the small blossom below it, and the terminal leaf tip (540pt paper).
        let origins=[CGPoint(x:523.4,y:61.8),CGPoint(x:526.4,y:74.1),CGPoint(x:526.0,y:117.9)]
        let departures=[0.0,0.18,0.58]
        for piece in 0..<3 {
            let start=plan.sample(piece:piece,at:departures[piece])!
            let loosened=plan.sample(piece:piece,at:departures[piece]+0.12)!
            check(hypot(start.center.x-origins[piece].x,start.center.y-origins[piece].y)<1,
                  "Each piece starts on its specific flower or leaf landmark")
            check(loosened.center.y-start.center.y<1 && abs(loosened.angle-start.angle)>0.08,
                  "A brief visible turn precedes the fall rather than spawning below the branch")
            let fallen=plan.sample(piece:piece,at:departures[piece]+0.65)!
            check(fallen.center.y-loosened.center.y>10,"Release flows into a perceptible fall")
            let junction=departures[piece]+(piece==2 ? 0.18:0.16)
            let before=plan.sample(piece:piece,at:junction-0.001)!
            let after=plan.sample(piece:piece,at:junction+0.001)!
            check(hypot(after.center.x-before.center.x,after.center.y-before.center.y)<0.01
                  && abs(after.angle-before.angle)<0.001,
                  "The turn-to-fall junction has no position or rotation jump")
        }
        let petalStart=plan.sample(piece:0,at:0)!,leafStart=plan.sample(piece:2,at:0.58)!
        let petalMid=plan.sample(piece:0,at:1.2)!,leafMid=plan.sample(piece:2,at:1.64)!
        let petalFraction=(petalMid.center.y-petalStart.center.y)/156
        let leafFraction=(leafMid.center.y-leafStart.center.y)/145
        check(abs(petalFraction-leafFraction)>0.025,
              "Petals and leaf have distinct fall rhythms, not just delayed copies")
        for tick in 0...600 {
            let frames=plan.frames(at:Double(tick)/100)
            check(frames.count<=3,"No accumulating or repeated particles")
            for frame in frames {
                let radius=hypot(frame.size.width,frame.size.height)/2
                check(frame.center.x-radius>512 && frame.center.x+radius<540,
                      "The whole rotated shape stays outside the text lane and inside the paper")
                check(frame.opacity>=0 && frame.opacity<=0.76,"Decorations remain subdued")
            }
            if tick>=280 {check(frames.isEmpty,"Nothing restarts after the opening has finished")}
        }
        check(!plan.frames(at:2.1).isEmpty && plan.frames(at:2.8).isEmpty,
              "The complete opening ends within two to three seconds")
        for size in [CGSize(width:340,height:228),CGSize(width:760,height:598)] {
            let narrow=LetterDriftPlan(bounds:CGRect(origin:.zero,size:size),
                                      imageSize:CGSize(width:1269,height:1240),textRight:size.width-28)
            check(narrow.frames(at:0.8).isEmpty,"Unsafe aspect ratios stay static instead of drifting over text")
        }
        print("PASS drift geometry: three pieces, right-edge text clearance, 2–3 seconds, no loop")
        let imageURL=URL(fileURLWithPath:"src/assets/letter-stationery-v1.png")
        let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
        var reduced=false
        let controller=LetterDriftPreviewController(stationeryURL:imageURL,systemReduced:{reduced})
        let window=controller.reader.window!,content=window.contentView!
        content.layoutSubtreeIfNeeded()
        check(content.bounds.size==CGSize(width:540,height:580),"Preview uses the accepted normal reader size")
        check(!window.isVisible && !controller.drift.isAnimating,"Construction never opens or reminds")
        check(controller.reader.textView.string.isEmpty,"Real reader body stays empty")
        let reference=CatLetterController(text:"",stationeryURL:imageURL)
        reference.window!.contentView!.layoutSubtreeIfNeeded()
        for scale in [1,2] {
            check(paperPixels(controller.reader,scale:scale)==paperPixels(reference,scale:scale),
                  "Idle overlay keeps the approved static paper pixel-identical at \(scale)x")
        }
        check(controller.drift.hitTest(CGPoint(x:525,y:160))==nil,"Decoration never captures text selection or scrolling")
        window.setContentSize(window.contentMinSize);content.layoutSubtreeIfNeeded()
        let buttons=content.subviews.compactMap{$0 as? NSButton}
        check(buttons.count==3,"Tests exercise the actual three preview controls")
        for (index,button) in buttons.enumerated() {
            check(content.bounds.contains(button.frame),"Every control stays inside the minimum window")
            for other in buttons.dropFirst(index+1) {
                check(!button.frame.intersects(other.frame),"Preview controls never overlap the Close button")
            }
        }
        window.setContentSize(CGSize(width:540,height:580));content.layoutSubtreeIfNeeded()
        controller.present()
        check(controller.drift.isAnimating && controller.drift.layer?.sublayers?.count==3,
              "The real opening installs three animated layers")
        let original=controller.drift.layer?.sublayers?.first
        controller.present()
        check(controller.drift.layer?.sublayers?.first === original,"Raising an already-open letter does not replay")
        RunLoop.current.run(until:Date(timeIntervalSinceNow:3.1))
        check(!controller.drift.isAnimating && controller.drift.layer?.sublayers?.isEmpty != false,
              "Real animation completion removes all layers and leaves no running refresh")
        for scale in [1,2] {
            check(paperPixels(controller.reader,scale:scale)==paperPixels(reference,scale:scale),
                  "After the one-off opening the paper returns to the accepted pixels at \(scale)x")
        }
        controller.replay()
        reduced=true
        NSWorkspace.shared.notificationCenter.post(name:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil)
        check(!controller.drift.isAnimating,"Enabling system reduced motion cancels immediately")
        controller.replay()
        check(!controller.drift.isAnimating,"System reduced motion prevents new animations")
        reduced=false
        NSWorkspace.shared.notificationCenter.post(name:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil)
        check(!controller.drift.isAnimating,"Disabling reduction never automatically restarts")
        controller.replay()
        controller.reducedButton.performClick(nil)
        check(!controller.drift.isAnimating,"Preview-only reduced-motion control stops, without writing system settings")
        controller.reducedButton.performClick(nil)
        check(!controller.drift.isAnimating,"Preview reduction off does not replay")
        controller.replay()
        window.setContentSize(CGSize(width:550,height:580))
        check(!controller.drift.isAnimating,"Resize cancels instead of jumping paths")
        window.setContentSize(CGSize(width:540,height:580))
        controller.replay()
        window.performClose(nil)
        check(!window.isVisible && !controller.drift.isAnimating,"Close releases the active animation immediately")
        controller.present()
        check(controller.drift.isAnimating,"Closing then opening intentionally plays one new opening")
        window.orderOut(nil)
        RunLoop.current.run(until:Date(timeIntervalSinceNow:0.15))
        check(!controller.drift.isAnimating,"An invisible letter cannot keep animating")
        reduced=true
        controller.present()
        check(!controller.drift.isAnimating && controller.reader.textView.string.isEmpty,"Reduced-motion reopen is the blank static reader")
        window.performClose(nil)
        check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,
              "Preview writes no formal preferences or reading state")
        print("PASS real reader lifecycle: once per open, cleanup, close/reopen, resize, occlusion, live reduced motion, input passthrough, no preferences")
    }
}
