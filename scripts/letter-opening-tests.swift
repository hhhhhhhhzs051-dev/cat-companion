import AppKit

@main struct LetterOpeningTests {
    static func check(_ value:Bool,_ message:String) {
        if !value {fputs("FAIL: \(message)\n",stderr);exit(1)}
    }
    static func main() {
        _=NSApplication.shared
        let url=URL(fileURLWithPath:"src/assets/letter-stationery-v1.png")
        let preferences=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
        var reduced=false
        let reader=CatLetterController(text:"",stationeryURL:url,reduceMotion:{reduced})
        check(!reader.window!.isVisible && !reader.openingDrift.isAnimating,"Construction does not show or play")
        reader.present()
        let count=reader.openingDrift.layer?.sublayers?.count ?? 0
        check(count==3,"The real production letter opening installs the three accepted decorations")
        let first=reader.openingDrift.layer?.sublayers?.first
        reader.present()
        check(reader.openingDrift.layer?.sublayers?.first === first,"Raising an open reader never restarts the fall")
        check(reader.window!.contentView!.subviews.compactMap{$0 as? NSButton}.count==1,
              "Production has only Close, with no replay or preview settings")
        RunLoop.current.run(until:Date(timeIntervalSinceNow:3.0))
        check(!reader.openingDrift.isAnimating && reader.openingDrift.layer?.sublayers?.isEmpty != false,
              "Opening finishes and removes all animated layers")
        reader.close();reader.present()
        check(reader.openingDrift.isAnimating,"A manual reopen plays once")
        reduced=true
        NSWorkspace.shared.notificationCenter.post(name:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil)
        check(!reader.openingDrift.isAnimating,"Live Reduce Motion stops the real reader immediately")
        reader.close();reader.present()
        check(!reader.openingDrift.isAnimating,"Reduce Motion opening is static")
        reduced=false
        NSWorkspace.shared.notificationCenter.post(name:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil)
        check(!reader.openingDrift.isAnimating,"Turning reduction off does not replay")
        reader.close();reader.present()
        reader.window!.orderOut(nil)
        check(!reader.openingDrift.isAnimating,"Hiding cancels rather than defers the fall")
        reader.present();reader.window!.setContentSize(NSSize(width:340,height:280))
        check(!reader.openingDrift.isAnimating,"Resize cancels, without crossing text")
        reader.close();reader.present()
        check(!reader.openingDrift.isAnimating,"An unsafe narrow gutter stays static")
        check(reader.textView.string.isEmpty,"Opening effects never add letter text")
        let missing=CatLetterController(text:"",stationeryURL:nil,reduceMotion:{false})
        missing.present();check(!missing.openingDrift.isAnimating,"Missing stationery remains a safe static reader")
        missing.close()
        reader.close()
        check(preferences==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,
              "No preferences or reading records are written")
        print("PASS production letter opening: one-shot, no preview controls, cleanup, reduced motion, hide/resize, blank text, no preferences")
    }
}
