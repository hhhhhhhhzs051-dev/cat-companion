import AppKit

@main struct LetterStationeryTests {
    static func check(_ condition:Bool,_ message:String) {
        if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)}
    }
    static func snapshot(_ view:NSView,scale:Int) -> (pixels:Data,stride:Int) {
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:Int(view.bounds.width)*scale,
            pixelsHigh:Int(view.bounds.height)*scale,bitsPerSample:8,samplesPerPixel:4,
            hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        bitmap.size=view.bounds.size
        view.cacheDisplay(in:view.bounds,to:bitmap)
        return (Data(bytes:bitmap.bitmapData!,count:bitmap.bytesPerRow*bitmap.pixelsHigh),bitmap.bytesPerRow)
    }
    static func main() throws {
        _=NSApplication.shared
        let url=URL(fileURLWithPath:"src/assets/letter-stationery-v1.png")
        let expectedImage=NSImage(contentsOf:url)!
        let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
        // Keep the approved empty-paper pixel baseline independent of the gift's text.
        let controller=CatLetterController(text:"",stationeryURL:url)
        let window=controller.window!,content=controller.window!.contentView!
        content.layoutSubtreeIfNeeded()
        check(!window.isVisible,"Creating a reader does not automatically show or remind")
        check(controller.textView.string.isEmpty,"The empty-paper fixture leaves the paper blank")
        check(controller.paperView.image != nil,"The approved image is loaded into the actual reader")
        check(content.bounds.size==NSSize(width:540,height:580),"Normal reader size stays unchanged: \(content.bounds.size)")
        check(controller.paperView.frame==NSRect(x:0,y:52,width:540,height:528),"Paper has the same normal-size layout as the accepted preview: \(controller.paperView.frame)")
        check(!controller.textView.drawsBackground && !controller.scrollView.drawsBackground && !controller.scrollView.contentView.drawsBackground,"Reader layers cannot obscure the paper")
        // Independent fixed layout from the user-approved standalone preview.
        let reference=NSView(frame:content.bounds)
        reference.appearance=NSAppearance(named:.darkAqua)
        let imageView=NSImageView(frame:NSRect(x:0,y:52,width:540,height:528))
        imageView.image=expectedImage;imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        reference.addSubview(imageView)
        let close=content.subviews.compactMap{$0 as? NSButton}.first!
        // Compare full actual paper composition, including the transparent reader,
        // with the approved image. Controls are verified separately below.
        close.isHidden=true
        for scale in [1,2] {
            check(snapshot(content,scale:scale).pixels==snapshot(reference,scale:scale).pixels,"Empty actual reader equals accepted paper pixels at \(scale)x")
        }
        close.isHidden=false
        for size in [NSSize(width:340,height:280),NSSize(width:540,height:580),NSSize(width:760,height:650)] {
            window.setContentSize(size);content.layoutSubtreeIfNeeded()
            check(controller.paperView.frame==controller.scrollView.frame,"Paper remains behind the readable area after resizing")
            check(content.bounds.contains(close.frame),"Close stays reachable on supported window sizes")
            check(controller.textView.string.isEmpty,"Resizing does not invent or persist text")
        }
        window.setContentSize(NSSize(width:540,height:580));controller.present()
        close.performClick(nil);check(!window.isVisible,"Actual close button dismisses the reader")
        controller.present();check(window.isVisible && controller.textView.string.isEmpty,"Rereading restores the same blank stationery")
        window.cancelOperation(nil);check(!window.isVisible,"Escape closes the stationery reader")
        check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"Reader interaction writes no cat settings or reading state")
        let populated=CatLetterController(text:String(repeating:"这只是本地排版测试。\n",count:160),stationeryURL:url)
        for size in [NSSize(width:340,height:280),NSSize(width:760,height:650)] {
            populated.window!.setContentSize(size)
            let view=populated.window!.contentView!
            view.layoutSubtreeIfNeeded()
            populated.textView.layoutManager!.ensureLayout(for:populated.textView.textContainer!)
            check(populated.textView.frame.height>populated.scrollView.contentSize.height,"Stationery retains long-letter scrolling after resize")
            // At these aspect ratios, x=8 is outside the centered image. Text
            // must not sit on the dark window matte after the reader resizes.
            let shot=snapshot(view,scale:1),pixels=shot.pixels
            if CommandLine.arguments.count>1 {
                let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds)!
                view.cacheDisplay(in:view.bounds,to:bitmap)
                try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
            }
            // NSBitmapImageRep pads each row (340px -> 1376 bytes, not 1360).
            let i=Int(size.height/2)*shot.stride+8*4
            check(pixels[i]>225 && pixels[i+1]>215 && pixels[i+2]>200,"Populated or error text has a light gutter behind it after resizing: \(size), \(Array(pixels[i..<i+4]))")
        }
        let fallback=CatLetterController(text:"本地读取测试",stationeryURL:URL(fileURLWithPath:"/does-not-exist/stationery.png"))
        check(fallback.paperView.image==nil && fallback.textView.drawsBackground && fallback.textView.string=="本地读取测试","A missing image preserves readable plain text rather than crashing")
        print("PASS stationery: approved 1x/2x pixels, blank draft, resize, close/reopen, no preference writes, safe missing-image fallback")
    }
}
