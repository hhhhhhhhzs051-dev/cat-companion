import AppKit

func runMenuTests(_ app:PetApp) {
    // Match a launched app before creating or presenting any reader windows.
    // Finishing launch after those interactions can reselect the older pet key window.
    NSApp.setActivationPolicy(.regular)
    NSApp.finishLaunching()
    func check(_ condition:Bool,_ message:String) {
        if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)}
    }
    func leaves(_ menu:NSMenu)->[NSMenuItem] {
        menu.items.flatMap { item in
            if let submenu=item.submenu {return leaves(submenu)}
            return item.isSeparatorItem ? []:[item]
        }
    }
    let menu=app.makeMenu()
    let letterAction=NSSelectorFromString("showLetter")
    check(menu.items.contains{$0.action==letterAction && $0.title=="给你的一封信" && $0.isEnabled},"A letter is reachable by explicit menu choice")
    check(app.letterController == nil,"Creating or refreshing menus never creates a letter window")
    check(menu.items.filter{!$0.isSeparatorItem}.count<=9,"Daily menu does not add an unnecessary play-help destination")
    let actions=leaves(menu)
    check(!actions.contains{$0.action == #selector(PetApp.toggleV1)},"Recipient menus never expose the V1 developer comparison")
    let expected=["toggleVisible","togglePause","previewNewMoves","previewTongue","previewNoseLick","previewPawLick","toggleFloat","smaller","larger","resetPosition","quit","toggleToy","showLetter","showGrowth"]
    check(Set(actions.compactMap{$0.action.map(NSStringFromSelector)})==Set(expected),"Only retained daily and manual-preview commands remain reachable")
    check(actions.count==expected.count && actions.allSatisfy{($0.target as? PetApp) === app},"Menu commands retain their targets without duplicates")
    check(!menu.items.contains{$0.action == #selector(PetApp.previewTongue)},"Previews remain in their submenu")
    let settings=menu.items.first{$0.title=="设置"}?.submenu
    check(settings?.items.map{$0.title} == ["小一点","大一点","回到屏幕角落"],"Settings contain only size and position controls")
    check(!app.voiceEnabled && !app.autoGrooming,"Unrequested automatic speech and grooming stay disabled")
    check(menu.items.last?.action == #selector(PetApp.quit),"Quit stays last, separate from daily actions")
    check(actions.first{$0.action == #selector(PetApp.toggleVisible)}?.title=="收起桌面猫","Hide must not be labeled close/quit")
    app.paused=true;app.petVisible=false;app.floating=true
    let changed=leaves(app.makeMenu())
    check(changed.first{$0.action == #selector(PetApp.toggleVisible)}?.title=="显示桌面猫","Hidden pet remains recoverable")
    check(changed.first{$0.action == #selector(PetApp.togglePause)}?.title=="继续陪伴","Pause label reflects state")
    check(!changed.contains{$0.action == #selector(PetApp.pet)},"Petting is a direct cat interaction, not a menu command")
    for selector in [#selector(PetApp.previewNewMoves),#selector(PetApp.previewTongue),#selector(PetApp.previewNoseLick),#selector(PetApp.previewPawLick)] {
        check(changed.first{$0.action==selector}?.isEnabled==false,"Paused/hidden previews must be disabled in submenus")
    }
    check(changed.first{$0.action == #selector(PetApp.toggleToy)}?.isEnabled==false,"Resting/hidden cat cannot start a toy session")
    check(changed.first{$0.action == #selector(PetApp.toggleFloat)}?.state == .on,"Pin checkmark reflects preference")
    print("PASS compact native menu, all command targets, nested state, disabled previews, hide/quit distinction")
    let preferencesBefore=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    let letter=changed.first{$0.action==letterAction}!
    check(letter.isEnabled,"Letter remains readable while cat is hidden or resting")
    check(NSApp.sendAction(letter.action!,to:letter.target,from:letter),"Letter menu invokes its real handler")
    let controller=app.letterController!
    check(controller.window?.isVisible == true,"Explicit choice opens a nonmodal reading window")
    let bundledLetter=CatLetter.text(at:app.resources.appendingPathComponent("letter.txt"))
    check(controller.paperView.image != nil && controller.textView.string==bundledLetter && !bundledLetter.isEmpty,"Real menu loads the approved stationery and exact bundled letter")
    app.showLetter()
    check(app.letterController === controller,"Repeated menu clicks reuse one window")
    controller.window?.performClose(nil)
    check(controller.window?.isVisible == false,"Close dismisses the letter without terminating the app")
    app.showLetter()
    check(controller.window?.isVisible == true && app.letterController === controller,"Letter can be reread after closing")
    controller.window?.cancelOperation(nil)
    check(controller.window?.isVisible == false,"Escape cancellation closes the reader")
    check(app.paused && !app.petVisible && app.floating,"Reading never changes cat rest/visibility/pin preferences")
    let preferencesAfter=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    check(preferencesBefore == preferencesAfter,"Opening/closing/rereading never persists a read receipt or other cat preference")
    print("PASS letter menu: explicit-only, single window, close/reopen, no cat state or preference writes")
    runTouchTests(app)
    runEnvelopeTests(app)
    check(app.panel.contentView!.subviews.compactMap{$0 as? NSButton}.isEmpty,"No permanent play button covers the bed artwork")
    app.panel.contentView!.setFrameSize(NSSize(width:290,height:290*1085/1525+60));app.layoutControls()
    app.active=true;app.petVisible=true;app.paused=false;app.motion=CatMotion(now:app.now,seed:1)
    app.toy.finish(app.now,immediate:true)
    let play=leaves(app.makeMenu()).first{$0.action == #selector(PetApp.toggleToy)}!
    check(NSApp.sendAction(play.action!,to:play.target,from:play) && app.toy.isOut,"Existing menu still takes out the ball")
    check(app.art.text.isEmpty,"Taking out the ball does not show a tutorial or action forecast")
    app.pet()
    check(app.toy.isOut,"A direct head pet keeps the ball ready")
    app.motion=CatMotion(now:app.now,seed:1);app.petPhrase=""
    app.playMood=CatPlayMood();app.playMood.beginSession()
    app.playMood.react(at:app.now,sample:0,allowed:true)
    app.playMood.resolve(id:app.now,outcome:.pull,at:app.now,allowed:true)
    let mood=app.playMood.text(at:app.now)!
    app.toy.grab(app.now)
    for x in [0.60,0.64,0.77,0.55] {
        app.toy.move(to:CGPoint(x:x,y:0.355),at:app.now);app.tick()
        check(app.art.text==mood && app.art.toyGuide != nil,"Crossing response zones preserves one emotional line and the nonverbal guide")
    }
    app.toy.release(app.now);app.tick()
    check(app.art.toyGuide==nil,"Releasing hides the guide without adding action forecasts")
    app.touchBack()
    check(app.playMood.text(at:app.now)==nil && app.toy.isOut,"Petting clears toy speech while retaining the ball")
    NSApp.sendAction(play.action!,to:play.target,from:play)
    check(!app.toy.isOut,"The same entry can manually put away the ball")
    check(preferencesBefore == UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"Play does not change formal preferences")
    app.previewVisibilityUntil=0
    app.toy.start(app.now-10)
    app.settingsReady=true;app.active=true;app.panel.orderOut(nil);app.syncActivity()
    check(!app.active && app.animationTimer==nil && app.toy.isOut,"Ordinary occlusion suspends drawing without discarding a resting ball (active=\(app.active), out=\(app.toy.isOut), engaged=\(app.toy.isEngaged(app.now)), visible=\(app.panel.occlusionState.contains(.visible)))")
    app.tick();check(app.toy.isOut,"Suspended ticks cannot discard an unexpired resting ball")
    app.willSleep()
    check(!app.toy.isPresent,"Actual sleep callback clears a retained ball even when already inactive")
    app.sleeping=false
    app.toy.start(app.now-10);app.active=true;app.syncActivity()
    check(!app.active && app.toy.isOut,"Recreate an inactive retained ball")
    app.applicationDidHide(Notification(name:NSApplication.didHideNotification))
    check(!app.toy.isPresent,"Actual app-hide callback clears a retained ball even when already inactive")
    app.toy.start(app.now-31);app.active=true;app.syncActivity()
    check(!app.toy.isPresent,"An expired hidden ball is discarded without replaying its fade")
    app.toy.start(app.now-10);app.active=true;app.petVisible=false;app.syncActivity(force:true)
    check(!app.toy.isPresent,"Explicit hiding still clears all toy state")
    app.settingsReady=false;app.petVisible=true
    print("PASS quiet play entry, unobstructed bed, park continuity and manual close")
    app.panel.makeKeyAndOrderFront(nil)
    // A command-line AppKit harness has no normal app.run() launch loop.
    // Establish foreground activation before measuring the reader's focus
    // handoff; otherwise a cold asynchronous process activation is measured
    // against the unrelated 300ms reader assertion. Keep that assertion intact.
    NSApp.activate(ignoringOtherApps:true)
    let activationDeadline=Date(timeIntervalSinceNow:2)
    var nextActivationAttempt=Date(timeIntervalSinceNow:0.25)
    while !NSApp.isActive && Date()<activationDeadline {
        while let event=NSApp.nextEvent(matching:.any,until:Date(),inMode:.default,dequeue:true) {NSApp.sendEvent(event)}
        NSApp.updateWindows()
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.01))
        if !NSApp.isActive && Date()>=nextActivationAttempt {
            if ProcessInfo.processInfo.environment["CAT_FOCUS_DIAGNOSTICS"] == "1" {
                print("ACTIVATION_RETRY hidden=\(NSApp.isHidden) policy=\(NSApp.activationPolicy().rawValue) frontPID=\(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1) ownPID=\(ProcessInfo.processInfo.processIdentifier)")
            }
            NSApp.activate(ignoringOtherApps:true)
            nextActivationAttempt=Date(timeIntervalSinceNow:0.25)
        }
    }
    guard NSApp.isActive,app.panel.isOnActiveSpace else {
        fputs("INVALID_SCENE: foreground activation unavailable before letter focus test\n",stderr);exit(2)
    }
    app.showLetter()
    let focusDeadline=Date(timeIntervalSinceNow:0.3)
    var focusDiagnostic=""
    while Date()<focusDeadline {
        while let event=NSApp.nextEvent(matching:.any,until:Date(),inMode:.default,dequeue:true) {NSApp.sendEvent(event)}
        NSApp.updateWindows()
        RunLoop.main.run(until:Date(timeIntervalSinceNow:0.01))
        if ProcessInfo.processInfo.environment["CAT_FOCUS_DIAGNOSTICS"] == "1" {
            let state="active=\(NSApp.isActive) key=\(NSApp.keyWindow?.windowNumber ?? -1) reader=\(controller.window!.windowNumber) readerSpace=\(controller.window!.isOnActiveSpace) readerVisible=\(controller.window!.isVisible) front=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "none")"
            if state != focusDiagnostic {print("FOCUS remaining=\(focusDeadline.timeIntervalSinceNow) \(state)");focusDiagnostic=state}
        }
    }
    check(NSApp.keyWindow === controller.window,"Opening letter gives the reader keyboard focus with the pet present")
    app.applicationDidBecomeActive(Notification(name:NSApplication.didBecomeActiveNotification))
    check(NSApp.keyWindow === controller.window,"App reactivation cannot steal focus from a visible letter")
    controller.window?.performClose(nil)
    app.showLetter()
    check(NSApp.keyWindow === controller.window,"Rereading restores reader focus")
    controller.window?.performClose(nil);app.panel.orderOut(nil)
    print("PASS letter and pet coexist: reader key focus survives activation and reopening")
}

func runEnvelopeTests(_ app:PetApp) {
    func check(_ condition:Bool,_ message:String) {
        if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)}
    }
    let preferences=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    let catFrame=app.panel.frame
    let petEnd=app.motion.petEnd
    app.setupControls(in:app.panel.contentView!)
    let buttons=app.controls.subviews.compactMap{$0 as? NSButton}
    check(buttons.count==4 && buttons.allSatisfy{$0.image != nil && $0.title.isEmpty && !($0.accessibilityLabel() ?? "").isEmpty},"All four controls have visible symbols and accessible names, without mixed text glyphs")
    let envelope=buttons.first{$0.action==NSSelectorFromString("toggleLetter")}
    check(envelope != nil,"Hover controls expose a letter toggle next to pin")
    let button=envelope!
    check(button.image != nil && button.toolTip=="给你的一封信","Envelope has an icon and readable label")
    check(button.frame.minX>app.pinButton.frame.maxX,"Envelope sits to the right of pin without overlap")
    for width:CGFloat in [200,290,440] {
        app.panel.contentView!.setFrameSize(NSSize(width:width,height:width*1085/1525+60))
        app.layoutControls()
        check(app.controls.bounds.contains(button.frame),"Full envelope hit area remains inside toolbar at supported sizes")
        check(app.controls.frame.maxX<=width,"Toolbar stays inside cat window")
        for (index,control) in buttons.enumerated() {
            check(control.frame.width>=24*width/300-0.01 && control.frame.height>=24*width/300-0.01,"Optical resizing never shrinks the accepted click target")
            check(app.controls.bounds.contains(control.frame),"Every control stays inside the hover region")
            if index>0 {check(control.frame.minX>buttons[index-1].frame.maxX,"Adjacent control hit areas never overlap")}
            app.controls.alphaValue=0.72
            for point in [NSPoint(x:1,y:1),NSPoint(x:control.bounds.maxX-1,y:control.bounds.maxY-1),NSPoint(x:control.bounds.midX,y:control.bounds.midY)] {
                check(app.panel.contentView!.hitTest(control.convert(point,to:app.panel.contentView!)) === control,"Full control hit target stays above the cat touch layer")
            }
        }
        let center=button.convert(NSPoint(x:button.bounds.midX,y:button.bounds.midY),to:app.panel.contentView!)
        app.controls.alphaValue=0.72
        check(app.panel.contentView!.hitTest(center) === button,"Envelope hit routes to its button, not the cat touch layer")
    }
    app.panel.contentView!.setFrameSize(catFrame.size);app.layoutControls()
    app.revealControls(true,animated:false)
    check(app.controlsShown && button.alphaValue==app.pinButton.alphaValue,"Envelope shares the existing hover group")
    if let path=ProcessInfo.processInfo.environment["CAT_CONTROLS_SNAPSHOT"],
       let bitmap=app.controls.bitmapImageRepForCachingDisplay(in:app.controls.bounds) {
        app.controls.cacheDisplay(in:app.controls.bounds,to:bitmap)
        try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
        let floating=app.floating
        app.floating=false;app.updatePin()
        app.controls.cacheDisplay(in:app.controls.bounds,to:bitmap)
        try! bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path+"-unpinned.png"))
        app.floating=floating;app.updatePin()
    }
    button.performClick(nil)
    check(app.letterController?.window?.isVisible==true,"Envelope opens the letter")
    button.performClick(nil)
    check(app.letterController?.window?.isVisible==false,"Second envelope click closes the letter")
    app.showLetter();button.performClick(nil)
    check(app.letterController?.window?.isVisible==false,"Envelope closes a letter opened from the context menu")
    button.performClick(nil);app.letterController?.window?.performClose(nil);button.performClick(nil)
    check(app.letterController?.window?.isVisible==true,"Envelope reopens after window close, without stale state")
    app.letterController?.window?.performClose(nil)
    app.revealControls(false,animated:false)
    check(!app.controlsShown,"Envelope has no separate always-visible reminder")
    check(app.panel.frame==catFrame && app.motion.petEnd==petEnd,"Letter controls do not move or pet the cat")
    check(preferences == UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"Envelope never writes read state or cat preferences")
    print("PASS envelope: pin-adjacent layout, shared hover, open/close/menu interop and no cat or preference mutation")
}

func runTouchTests(_ app:PetApp) {
    func check(_ value:Bool,_ message:String) {
        if !value {fputs("FAIL: \(message)\n",stderr);exit(1)}
    }
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("src"))
    app.panel=PetPanel(contentRect:NSRect(x:120,y:100,width:290,height:290*1085/1525+60),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(origin:.zero,size:app.panel.frame.size))
    app.panel.contentView=container
    app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch)
    app.paused=false;app.active=true;app.petVisible=true
    for width:CGFloat in [200,290,440] {
        app.art.frame.size=NSSize(width:width,height:width*1085/1525+60)
        func point(_ x:CGFloat,_ y:CGFloat)->CGPoint {CGPoint(x:x*width/290,y:60+(y-60)*width/290)}
        check(app.art.touchRegion(point(170,112)) == .head,"Head region follows resized artwork")
        check(app.art.touchRegion(point(80,140)) == .back,"Back region follows resized artwork")
        check(app.art.touchRegion(point(145,222)) == .bed,"Foreground rim masks hidden fur")
        check(app.art.touchRegion(CGPoint(x:0,y:61)) == .none,"Transparent pixels remain click-through")
    }
    app.art.frame=container.bounds
    // Hand-picked visible pixels, measured in the 290pt normal-size artwork.
    func event(_ type:NSEvent.EventType,_ x:CGFloat,_ y:CGFloat)->NSEvent {
        NSEvent.mouseEvent(with:type,location:NSPoint(x:x,y:container.bounds.height-y),modifierFlags:[],timestamp:0,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    }
    func click(_ x:CGFloat,_ y:CGFloat) {
        app.touch.mouseDown(with:event(.leftMouseDown,x,y));app.touch.mouseUp(with:event(.leftMouseUp,x,y))
    }
    app.motion=CatMotion(now:app.now,seed:1)
    click(145,222)
    check(app.motion.petEnd<app.now,"Clicking the visible bed must not pet the cat")
    click(170,112)
    check(app.motion.frame(app.now+0.12,reduced:false,paused:false).eyes>0.9,"Head click keeps the immediate eye response")
    check(app.motion.frame(app.now+0.71,reduced:false,paused:false).eyes==0,"Head click preserves 700ms eyes")
    app.motion=CatMotion(now:app.now,seed:1)
    let headOrigin=app.panel.frame.origin
    app.touch.mouseDown(with:event(.leftMouseDown,170,112))
    app.touch.mouseDragged(with:event(.leftMouseDragged,180,115))
    RunLoop.current.run(until:Date(timeIntervalSinceNow:0.8))
    check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Head drag holds complete closure beyond the click response")
    app.touch.mouseDragged(with:event(.leftMouseDragged,5,5))
    RunLoop.current.run(until:Date(timeIntervalSinceNow:0.26))
    check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Leaving the silhouette must not end held head petting")
    app.touch.mouseDragged(with:event(.leftMouseDragged,180,115))
    RunLoop.current.run(until:Date(timeIntervalSinceNow:0.18))
    check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Same-point head re-entry resumes full closure")
    app.touch.mouseDragged(with:event(.leftMouseDragged,80,140))
    check(app.touch.region == .head && app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Head-start stroke stays held when crossing onto the body")
    app.touch.mouseUp(with:event(.leftMouseUp,80,140))
    check(app.motion.frame(app.now+0.25,reduced:false,paused:false).eyes==0,"Head stroke mouseUp reopens eyes")
    check(app.panel.frame.origin==headOrigin,"Head stroking and cross-zone contact never move the window")
    app.motion=CatMotion(now:app.now,seed:1)
    click(80,140)
    let back=app.motion.frame(app.now+0.3,reduced:false,paused:false)
    check(back.eyes==0 && back.leftEar>0 && back.head<0,"A released body click reopens with its original ear/head response")
    app.touch.mouseDown(with:event(.leftMouseDown,80,140))
    RunLoop.current.run(until:Date(timeIntervalSinceNow:0.18))
    check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Stationary body press fully closes eyes")
    app.touch.mouseDragged(with:event(.leftMouseDragged,5,5))
    RunLoop.current.run(until:Date(timeIntervalSinceNow:0.26))
    check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Leaving the silhouette must not end held body petting")
    app.touch.mouseDragged(with:event(.leftMouseDragged,80,140))
    RunLoop.current.run(until:Date(timeIntervalSinceNow:0.18))
    check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Re-entry at the same point reacquires hold without a 3pt stroke")
    app.touch.mouseUp(with:event(.leftMouseUp,80,140))
    check(app.motion.frame(app.now+0.25,reduced:false,paused:false).eyes==0,"Mouse up without a drag releases held eyes")
    // One held gesture owns its eyes across repeated boundary crossings and an outside release.
    for head in [false,true] {
        app.motion=CatMotion(now:app.now,seed:42)
        let x:CGFloat=head ? 170:80, y:CGFloat=head ? 112:140
        app.touch.mouseDown(with:event(.leftMouseDown,x,y))
        app.touch.mouseDragged(with:event(.leftMouseDragged,x+8,y))
        RunLoop.current.run(until:Date(timeIntervalSinceNow:0.18))
        for _ in 0..<4 {
            app.touch.mouseDragged(with:event(.leftMouseDragged,-20,-20))
            RunLoop.current.run(until:Date(timeIntervalSinceNow:0.26))
            check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Repeated outside motion must keep fully closed eyes")
            app.touch.mouseDragged(with:event(.leftMouseDragged,x+8,y))
            check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Re-entry must not replay closure")
        }
        app.touch.mouseDragged(with:event(.leftMouseDragged,-20,-20))
        app.touch.mouseUp(with:event(.leftMouseUp,-20,-20))
        check(app.motion.frame(app.now+0.25,reduced:false,paused:false).eyes==0,"MouseUp outside the window still releases eyes")
        check(!app.touch.hasContact && app.panel.frame.origin==headOrigin,"Boundary crossing cannot move the window or leave input latched")
        app.touch.mouseDown(with:event(.leftMouseDown,x,y))
        app.touch.mouseDragged(with:event(.leftMouseDragged,x+8,y))
        RunLoop.current.run(until:Date(timeIntervalSinceNow:0.18))
        app.touch.mouseDragged(with:event(.leftMouseDragged,-20,-20))
        app.touch.cancelContact()
        RunLoop.current.run(until:Date(timeIntervalSinceNow:0.26))
        app.touch.mouseDragged(with:event(.leftMouseDragged,x+8,y))
        check(app.motion.frame(app.now,reduced:false,paused:false).eyes==0,"Cancelling an outside hold releases it and ignores stale re-entry")
    }
    // Exercise the real input owner: expiry is not a new press, including re-entry.
    for head in [false,true] {
        app.motion=CatMotion(now:app.now,seed:42)
        let x:CGFloat=head ? 170:80, y:CGFloat=head ? 112:140
        app.touch.mouseDown(with:event(.leftMouseDown,x,y))
        app.touch.mouseDragged(with:event(.leftMouseDragged,x+8,y))
        RunLoop.current.run(until:Date(timeIntervalSinceNow:4.6))
        app.touch.mouseDragged(with:event(.leftMouseDragged,-20,-20))
        app.touch.mouseDragged(with:event(.leftMouseDragged,x+8,y))
        check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"Pre-limit re-entry retains full closure")
        RunLoop.current.run(until:Date(timeIntervalSinceNow:0.7))
        check(app.motion.frame(app.now,reduced:false,paused:false).eyes==0,"Real held input opens after five seconds without mouseUp")
        for _ in 0..<4 {
            app.touch.mouseDragged(with:event(.leftMouseDragged,-20,-20))
            app.touch.mouseDragged(with:event(.leftMouseDragged,x+8,y))
            check(app.motion.frame(app.now,reduced:false,paused:false).eyes==0,"Expired input cannot reclose on boundary re-entry")
        }
        check(app.touch.hasContact && app.panel.frame.origin==headOrigin,"Timed eyes do not cancel gesture ownership or move the window")
        app.touch.mouseUp(with:event(.leftMouseUp,-20,-20))
        app.touch.mouseDown(with:event(.leftMouseDown,x,y))
        app.touch.mouseDragged(with:event(.leftMouseDragged,x+8,y))
        RunLoop.current.run(until:Date(timeIntervalSinceNow:0.18))
        check(app.motion.frame(app.now,reduced:false,paused:false).eyes==1,"MouseUp then a new press renews the eye response")
        app.touch.mouseUp(with:event(.leftMouseUp,x+8,y))
        check(app.motion.frame(app.now+0.25,reduced:false,paused:false).eyes==0,"New gesture can still release early")
    }
    app.motion=CatMotion(now:app.now,seed:42)
    app.touch.mouseDown(with:event(.leftMouseDown,170,112))
    app.touch.mouseDragged(with:event(.leftMouseDragged,-20,-20))
    check(app.motion.frame(app.now+0.71,reduced:false,paused:false).eyes==0,"Head press that never starts stroking retains its 700ms response outside")
    app.touch.mouseUp(with:event(.leftMouseUp,-20,-20))
    let origin=app.panel.frame.origin
    app.touch.mouseDown(with:event(.leftMouseDown,80,140))
    app.touch.mouseDragged(with:event(.leftMouseDragged,120,145))
    check(app.panel.frame.origin==origin,"Stroking the cat must never move its window")
    app.touch.mouseUp(with:event(.leftMouseUp,120,145))
    app.motion=CatMotion(now:app.now,seed:1)
    app.touch.mouseDown(with:event(.leftMouseDown,145,222))
    app.touch.mouseDragged(with:event(.leftMouseDragged,165,212))
    app.touch.mouseUp(with:event(.leftMouseUp,165,212))
    check(app.panel.frame.origin==NSPoint(x:origin.x+20,y:origin.y+10),"Bed drag moves the window by the pointer delta")
    check(app.motion.petEnd<app.now,"Bed drag must not also trigger petting")
    app.touch.mouseDown(with:event(.leftMouseDown,80,140))
    app.touch.cancelContact()
    let cancelledOrigin=app.panel.frame.origin
    app.touch.mouseDragged(with:event(.leftMouseDragged,160,222))
    app.touch.mouseUp(with:event(.leftMouseUp,160,222))
    check(app.panel.frame.origin==cancelledOrigin,"Cancelled contact cannot turn into a bed drag")
    app.paused=true;app.motion=CatMotion(now:app.now,seed:1)
    click(170,112);click(80,140)
    check(app.motion.petEnd<app.now,"Resting cat ignores both touch zones")
    app.paused=false;app.motion=CatMotion(now:app.now,seed:1)
    app.toy.start(app.now-1);app.tick()
    let ball=app.art.toyCenter,toyOrigin=app.panel.frame.origin
    app.touch.mouseDown(with:event(.leftMouseDown,ball.x,ball.y))
    let dragPose=app.art.pose
    app.touch.mouseDragged(with:event(.leftMouseDragged,290*0.63,60+290*0.395))
    check(app.art.pose==dragPose,"Pointer events do not advance or re-render the cat's pose between animation ticks")
    check(abs(app.art.toyCenter.x-290*0.63)<0.01,"Ball tracks the pointer immediately without waiting for a cat animation tick")
    check(app.art.containsToy(CGPoint(x:app.art.toyCenter.x+15,y:app.art.toyCenter.y)),"Normal-size ball has a forgiving 16pt grab radius without enlarging its artwork")
    check(app.panel.frame.origin==toyOrigin && app.toy.dragging,"Ball captures drag without moving the window")
    check(app.art.toyGuide != nil,"Dragging the ball shows its grounded reach guide")
    app.touch.mouseUp(with:event(.leftMouseUp,290*0.63,60+290*0.395))
    check(!app.toy.dragging && !app.touch.hasContact && app.motion.petEnd<app.now,"Toy release is not a head click or stroke")
    check(app.art.toyGuide == nil,"Releasing the ball removes the reach guide")
    click(80,140)
    check(app.toy.isOut && !app.toy.dragging,"Touching the cat parks the ball for the next manual interaction")
    app.toy.start(app.now-1);app.tick()
    app.touch.mouseDown(with:event(.leftMouseDown,145,222))
    let bedOrigin=app.panel.frame.origin
    app.touch.mouseDragged(with:event(.leftMouseDragged,165,212))
    app.touch.mouseUp(with:event(.leftMouseUp,165,212))
    check(app.panel.frame.origin==NSPoint(x:bedOrigin.x+20,y:bedOrigin.y+10) && app.toy.isOut,"Bed drag remains available while the ball is out")
    check(app.toyKey(53) && !app.toy.isOut,"Escape puts the toy away")
    app.toy.start(app.now-1);app.tick()
    check(app.toyKey(49) && app.art.toyFrame.position.x==0.62 && abs(app.art.toyFrame.position.y-0.39249)<0.0001,"Keyboard can offer the ball on the bed surface without dragging")
    app.toy.finish(app.now,immediate:true)
    var quiet=CatMotion(now:0,seed:1)
    for t in stride(from:1.0,through:80,by:0.1) {
        let pose=quiet.frame(t,reduced:false,paused:false,engaged:true)
        check(pose.mouth.extensionAmount==0 && pose.paw.raise==0,"Manual play never starts automatic mouth or paw actions")
    }
    check(quiet.nextGesture>=91,"Manual play reserves a quiet gap without resetting earlier cooldowns")
    check(quiet.frame(80.1,reduced:false,paused:false).mouth.extensionAmount==0,"Finishing play does not flush overdue gestures")
    // Exercise lifecycle cancellation with the cached status menu, not a fresh makeMenu().
    // syncActivity does not write preferences; disable settingsReady before returning.
    app.status=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    app.toy.start(app.now);app.status.menu=app.makeMenu()
    app.settingsReady=true;app.sleeping=true;app.syncActivity(force:true)
    check(!app.toy.isPresent,"Sleep cancels the toy session")
    check(app.status.menu?.items.first{$0.action == #selector(PetApp.toggleToy)}?.title=="拿出小绒球","Lifecycle cancellation updates the cached menu label")
    app.motion.pet(app.now)
    app.status.menu=app.makeMenu()
    check(app.status.menu?.items.first{$0.action == #selector(PetApp.toggleToy)}?.isEnabled==true,"Petting must not disable taking out a toy")
    app.motion=CatMotion(now:app.now,seed:1)
    let cached=app.status.menu!
    cached.delegate?.menuNeedsUpdate?(cached)
    check(cached.items.first{$0.action == #selector(PetApp.toggleToy)}?.isEnabled==true,"Opening the cached menu re-enables toy after busy motion ends")
    app.settingsReady=false;app.sleeping=false
    app.active=true;app.paused=false;app.motion=CatMotion(now:app.now,seed:1)
    app.toy.start(app.now-1);app.pet()
    let open=app.makeMenu()
    app.status.menu=open
    let button=open.items.first{$0.action == #selector(PetApp.toggleToy)}!
    check(button.isEnabled,"Taking out the ball is immediately available during petting and toy exit")
    open.delegate?.menuWillOpen?(open)
    let until=Date().addingTimeInterval(2.2)
    while Date()<until {RunLoop.main.run(mode:.eventTracking,before:Date().addingTimeInterval(0.03))}
    check(button.isEnabled,"The same open menu item becomes enabled after petting ends without closing/reopening")
    check(open.items.first{$0.action == #selector(PetApp.toggleToy)} === button,"Tracking refresh preserves item identity and selection")
    check(app.status.menu === open,"Toy cleanup cannot replace a menu while it is being tracked")
    check(app.toy.isOut && app.art.toyFrame.paw==0,"Parked ball remains without an old paw or replay while the menu tracks")
    app.paused=true
    RunLoop.main.run(mode:.eventTracking,before:Date().addingTimeInterval(0.08))
    check(!button.isEnabled,"Open-menu refresh never enables play while paused")
    app.paused=false
    open.delegate?.menuDidClose?(open)
    app.toy.start(app.now);app.toy.finish(app.now)
    let closedUntil=Date().addingTimeInterval(0.6)
    while Date()<closedUntil {RunLoop.main.run(mode:.eventTracking,before:Date().addingTimeInterval(0.03))}
    check(app.toy.isPresent,"Closing the menu removes its tracking timer, leaving no hidden animation driver")
    app.toy.finish(app.now,immediate:true)
    app.motion=CatMotion(now:app.now,seed:1);app.toy.start(app.now);app.pet()
    let originalEnd=app.motion.petEnd
    var referenceMotion=app.motion
    // Already parked after petting: no need to take it out again. Preserve the
    // old take-out-during-petting contract separately.
    check(app.toy.isOut,"Petting leaves the ball ready for the next gesture")
    app.toy.finish(app.now,immediate:true);app.toggleToy()
    check(app.toy.isOut && !app.motion.canPlayWithToy(app.now),"Click immediately shows the ball while the cat remains busy with petting")
    check(app.motion.petEnd==originalEnd,"Taking out the ball never cuts short the accepted pet response")
    app.toy.grab(app.now);app.toy.move(to:CGPoint(x:0.62,y:0.395),at:app.now);app.toy.release(app.now)
    for offset in [0.15,0.72,1.5] {
        let t=originalEnd-1.9+offset
        let actual=app.motion.frame(t,reduced:false,paused:false,engaged:true)
        let expected=referenceMotion.frame(t,reduced:false,paused:false)
        check(actual.eyes==expected.eyes && actual.lean==expected.lean && actual.head==expected.head,"Visible pet motion remains identical while the toy is offered")
        let ball=app.toy.frame(t,canBat:app.motion.canPlayWithToy(t))
        check(app.toy.hits==0 && ball.look==0 && ball.paw==0,"Moving the offered ball cannot interrupt the current pet response")
    }
    _=app.motion.frame(originalEnd+0.01,reduced:false,paused:false,engaged:true)
    _=app.toy.frame(originalEnd+0.01,canBat:app.motion.canPlayWithToy(originalEnd+0.01))
    check(app.toy.hits==1,"The user's released ball receives its response once the original pet action has finished")
    app.toy.finish(app.now,immediate:true);app.panel.orderOut(nil)
    NSStatusBar.system.removeStatusItem(app.status);app.status=nil
    print("PASS actual native mouse events: head/back/bed separation and drag ownership at 290pt")
    print("PASS toy event routing: ball drag, bed drag, touch interruption, Escape/keyboard and quiet scheduler")
}
