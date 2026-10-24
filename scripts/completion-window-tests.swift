import AppKit

// A real 290pt NSWindow and a second window covering only the bubble. No input
// synthesis, production app launch, or production user-data access is involved.
func runMenuTests(_ app: PetApp) {
    func metadata(_ id:Int,_ rect:CGRect,_ alpha:Double=1)->[String:Any] {
        [kCGWindowNumber as String:id,kCGWindowAlpha as String:alpha,
         kCGWindowBounds as String:["X":rect.minX,"Y":rect.minY,"Width":rect.width,"Height":rect.height]]
    }
    let region=CGRect(x:-190,y:-90,width:150,height:31)
    let probeRow=metadata(2,region),parentRow=metadata(1,CGRect(x:-220,y:-100,width:290,height:267))
    let coverRow=metadata(3,CGRect(x:-190,y:-90,width:20,height:31))
    func clear(_ rows:[[String:Any]],_ empty:Set<Int>=[])->Bool {
        NativeCatView.receiptRegionIsClear(windowID:1,probeID:2,windows:rows,knownEmpty:empty)
    }
    receiptCheck(clear([probeRow,parentRow]),"clear region, including negative screen coordinates")
    receiptCheck(!clear([coverRow,probeRow,parentRow]),"visible flag cannot override partial coverage")
    receiptCheck(clear([coverRow,probeRow,parentRow],[3]),"known-empty surface is transparent")
    receiptCheck(clear([probeRow,parentRow,coverRow]),"window behind cat cannot cover text")
    receiptCheck(clear([metadata(3,region,0),probeRow,parentRow]),"zero-alpha surface")
    receiptCheck(!clear([parentRow,probeRow]) && !clear([probeRow]),"missing or stale window order fails closed")
    receiptCheck(!clear([[kCGWindowNumber as String:3],probeRow,parentRow]),"unknown covering bounds fail closed")
    NSApp.setActivationPolicy(.accessory)
    NSApp.finishLaunching()
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    #if CAT_BUILD56_REFERENCE
    let art = try! Build56NativeCatView(resources: source)
    #else
    let art = try! NativeCatView(resources: source)
    art.bedCacheEnabled=ProcessInfo.processInfo.environment["CAT_TEST_BED_CACHE"] == "1"
    #endif
    let panel = PetPanel(contentRect: NSRect(x: 0,y: 0,width: 290,height: 267), styleMask: [.borderless], backing: .buffered, defer: false)
    panel.contentView = art; art.frame = NSRect(x:0,y:0,width:290,height:267)
    let screen = NSScreen.screens.first!.visibleFrame
    panel.setFrameOrigin(NSPoint(x:screen.minX+60,y:screen.midY-100)); panel.level = .floating
    let coverRect = panel.convertToScreen(art.convert(NSRect(x:0,y:0,width:290,height:66), to:nil))
    let cover = NSWindow(contentRect: coverRect, styleMask: [.borderless], backing: .buffered, defer: false)
    cover.backgroundColor = .white; cover.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
    var acknowledgements: [String] = []
    var expectedCovered = false
    var coveredReceiptScenes: [ReceiptWindowScene] = []
    art.onTextRendered = {
        acknowledgements.append($0)
        if expectedCovered {
            let scene = ReceiptWindowScene("unexpected-covered-receipt", panel: panel, cover: cover)
            coveredReceiptScenes.append(scene); scene.emit()
        }
    }
    func checkCovered(_ expectedReceipts: Int) {
        // If a receipt already happened, use evidence captured INSIDE its
        // callback, before asynchronous probe removal can destroy the evidence.
        if acknowledgements.count != expectedReceipts {
            let scene = coveredReceiptScenes.last ?? ReceiptWindowScene("missing-receipt-evidence", panel: panel, cover: cover)
            scene.requireCover()
            receiptCheck(false, "covered bubble acknowledged despite validated cover")
        }
        ReceiptWindowScene("covered-pending", panel: panel, cover: cover).requireCover()
    }
    func pump(_ duration: Double) {
        let end = Date().addingTimeInterval(duration)
        while Date() < end {
            while let event = NSApp.nextEvent(matching: .any, until: Date(), inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
            NSApp.updateWindows()
            let currentText = art.text; art.text = currentText // production's same-text ticks
            art.needsDisplay = true; panel.displayIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }
    panel.orderFrontRegardless(); cover.isOpaque=false; cover.backgroundColor = .clear
    cover.orderFrontRegardless(); pump(0.3)
    receiptCheck(panel.isOnActiveSpace && panel.occlusionState.contains(.visible),
                 "INVALID_SCENE: visible desktop required; this test cannot be counted as passed or skipped", code: 2)
    art.text = "透明区域后面确实看得到。"; pump(0.5)
    if acknowledgements.isEmpty {
        print("transparent failure parent",panel.frame,panel.occlusionState,"children",panel.childWindows?.map {($0.frame,$0.occlusionState,$0.isVisible,$0.level.rawValue)} ?? [],"hidden",NSApp.isHidden)
        print("transparent cover content",cover.contentView.map {String(describing:type(of:$0))} ?? "nil",cover.contentView?.wantsLayer as Any,cover.contentView?.subviews.count as Any,cover.contentView?.layer as Any)
        ReceiptWindowScene("transparent-failure",panel:panel,cover:cover).emit()
        fflush(stdout)
    }
    precondition(acknowledgements == [art.text], "transparent window bounds must not veto a visible screen draw")
    precondition(panel.childWindows?.isEmpty ?? true, "receipt must remove the temporary probe")
    acknowledgements.removeAll()
    cover.isOpaque=true; cover.backgroundColor = .white; cover.display(); pump(0.3)
    precondition(panel.occlusionState.contains(.visible), "cat body remains visible during bubble-only occlusion")
    // Optional negative control demonstrates that missing/transparent covers
    // cannot silently pass as an occlusion regression test.
    if ProcessInfo.processInfo.environment["CAT_RECEIPT_NEGATIVE"] == "missing-cover" { cover.orderOut(nil) }
    if ProcessInfo.processInfo.environment["CAT_RECEIPT_NEGATIVE"] == "transparent-cover" { cover.isOpaque=false;cover.backgroundColor = .clear;cover.display() }
    expectedCovered = true
    art.text = "今天是陪伴你的第 2 天。"; pump(0.5)
    checkCovered(0)
    precondition(panel.childWindows?.count == 1, "pending ticks reuse exactly one probe")
    let probe = panel.childWindows!.first!
    precondition(probe.ignoresMouseEvents && !probe.isKeyWindow && probe.level == panel.level)
    expectedCovered = false; cover.orderOut(nil); pump(0.5)
    if acknowledgements.isEmpty {
        fputs("window=\(panel.windowNumber) visible=\(panel.isVisible) occlusion=\(panel.occlusionState)\n",stderr)
        let above = CGWindowListCopyWindowInfo([.optionOnScreenAboveWindow,.excludeDesktopElements],CGWindowID(panel.windowNumber)) as? [[String:Any]] ?? []
        for info in above where (info[kCGWindowLayer as String] as? Int ?? 99) <= NSWindow.Level.modalPanel.rawValue {
            fputs("above=\(info[kCGWindowNumber as String] ?? 0) layer=\(info[kCGWindowLayer as String] ?? 0) alpha=\(info[kCGWindowAlpha as String] ?? 0) bounds=\(info[kCGWindowBounds as String] ?? "missing")\n",stderr)
        }
    }
    precondition(acknowledgements == [art.text], "uncovered real screen draw must acknowledge once")
    pump(0.3)
    precondition(acknowledgements.count == 1, "redraw cannot repeat acknowledgement")
    precondition(panel.childWindows?.isEmpty ?? true, "no idle probe after receipt")
    // Cold creation under a same-level opaque window must not reorder the cat
    // above it. Also exercise parent movement and ordinary non-floating level.
    panel.level = .normal; cover.level = .normal
    panel.setFrameOrigin(NSPoint(x:screen.minX+80.25,y:screen.midY-90.5))
    cover.setFrame(panel.convertToScreen(art.convert(NSRect(x:0,y:0,width:290,height:66),to:nil)).integral,display:true)
    cover.order(.above,relativeTo:panel.windowNumber); pump(0.3)
    expectedCovered = true
    art.text = "同层遮住时先不算说过。"; pump(0.5)
    checkCovered(1)
    precondition(panel.childWindows?.count == 1 && panel.childWindows!.first!.level == .normal)
    expectedCovered = false; panel.orderOut(nil); pump(0.2)
    precondition(panel.childWindows?.isEmpty ?? true, "hidden pending probe must be cleaned up")
    precondition(acknowledgements.count == 1)
    cover.orderOut(nil); panel.orderFrontRegardless(); pump(0.5)
    precondition(acknowledgements == ["今天是陪伴你的第 2 天。",art.text], "visible resumption can acknowledge pending text once")
    precondition(panel.childWindows?.isEmpty ?? true)
    panel.orderOut(nil)
    art.text = "今天是陪伴你的第 3 天。"; pump(0.3)
    let bitmap = art.bitmapImageRepForCachingDisplay(in:art.bounds)!
    art.cacheDisplay(in:art.bounds,to:bitmap)
    precondition(acknowledgements.count == 2, "hidden and bitmap renders must not acknowledge")
    // Visibility means ANY pixels are exposed, not that the complete sentence
    // can be read. A half-width cover must also defer the receipt.
    acknowledgements.removeAll(); panel.orderFrontRegardless()
    cover.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
    let top = panel.convertToScreen(art.convert(NSRect(x:0,y:0,width:290,height:66),to:nil))
    cover.setFrame(NSRect(x:top.minX,y:top.minY,width:145,height:66),display:true)
    cover.orderFrontRegardless(); pump(0.3)
    art.text = "只有半句看得见，不能确认。"; pump(0.5)
    let partial = ReceiptWindowScene("partial-covered-pending", panel:panel, cover:cover); partial.emit()
    receiptCheck(panel.isOnActiveSpace && cover.isOnActiveSpace && partial.ownFrontToBack.first == cover.windowNumber,
                 "INVALID_SCENE: partial cover not on top",code:2)
    receiptCheck(acknowledgements.isEmpty, "partially covered text must not acknowledge")
    cover.orderOut(nil); pump(0.5)
    receiptCheck(acknowledgements == [art.text], "partial cover removal must permit exactly one receipt")
    if let helper=ProcessInfo.processInfo.environment["CAT_RECEIPT_COVER_HELPER"] {
        for width:CGFloat in [290,145] {
            acknowledgements.removeAll();art.text=""
            let child=Process();child.executableURL=URL(fileURLWithPath:helper)
            child.arguments=[String(Double(top.minX)),String(Double(top.minY)),String(Double(width)),"66"]
            try! child.run();pump(0.6)
            let rows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as! [[String:Any]]
            let ids=rows.compactMap {$0[kCGWindowNumber as String] as? Int}
            guard let row=rows.first(where:{($0[kCGWindowOwnerPID as String] as? Int32)==child.processIdentifier}),
                  let number=row[kCGWindowNumber as String] as? Int,
                  let index=ids.firstIndex(of:number),let parent=ids.firstIndex(of:panel.windowNumber),index<parent else {
                child.terminate();receiptCheck(false,"INVALID_SCENE: external cover not above cat",code:2);return
            }
            art.text="外部进程遮住时也不能确认。";pump(0.6)
            let count=acknowledgements.count
            child.terminate();child.waitUntilExit()
            receiptCheck(count==0,"external opaque / input-pass-through cover must defer receipt")
            pump(0.5);receiptCheck(acknowledgements == [art.text],"external cover removed: receipt exactly once")
            print("PASS external process cover width=\(width), ignoresMouseEvents=true, then removal")
        }
    }
    art.needsTextReceipt={_ in false};art.text="普通摸猫短句。";pump(0.3)
    receiptCheck(panel.childWindows?.isEmpty ?? true,"ordinary speech creates no receipt probe")
    panel.orderOut(nil)
    print("PASS native window: transparent cover allowed, cold opaque/same-level bubble cover rejected, screen receipt once, hide/resume, fractional movement, no focus/level change, probe cleanup, hidden/offscreen rejected (290pt)")
}
