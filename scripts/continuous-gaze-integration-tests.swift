import AppKit

func runMenuTests(_ app:PetApp) {
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    func check(_ ok:Bool,_ text:String) {if !ok {print("FAIL continuous integration: \(text)");exit(1)}}
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267))
    app.panel.contentView=container;app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch);app.setupControls(in:container)
    #if CAT_ACCESSORY_GAZE
    check(app.selfTest && !app.isPlayPreview,"release flags use explicit self-test isolation, not preview storage")
    let store=app.growthStore!
    var snapshot=CatGrowthSnapshot(unlockedRewards:[0,1,2],points:32,companionDays:16,completed:[.pet,.play],day:CatGrowth.dayKey(Date(),calendar:.current),ballSelected:true,decoration:nil)
    snapshot.decorations=[1,2]
    snapshot.completionShownDay=snapshot.day
    try! store.save(snapshot)
    let growth=CatGrowthController(owner:app,store:store);app.growthController=growth
    let fileBefore=try! Data(contentsOf:URL(fileURLWithPath:ProcessInfo.processInfo.environment["CAT_TEST_GROWTH_FILE"]!))
    func titles(_ menu:NSMenu)->[String] {menu.items.flatMap{[$0.title]+($0.submenu.map(titles) ?? [])}}
    check(!titles(app.makeMenu()).contains(where:{$0.contains("仅预览") || $0.contains("眼神幅度")}),"release has no amplitude comparison or preview menu")
    check(!app.responds(to:NSSelectorFromString("useOriginalEyeAmplitude")),"release cannot switch approved gain")
    #else
    let growth=CatGrowthController(owner:app);app.growthController=growth
    growth.prepareAccessoryDemo()
    #endif
    growth.accessory.frame=container.bounds;container.addSubview(growth.accessory)
    let saved=growth.growth.snapshot(ballSelected:growth.ballSelected,decorations:growth.decorations)
    let preferences=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    func advance(_ t:Double) {Thread.sleep(forTimeInterval:t);app.tick()}
    func reset() {
        app.active=true;app.petVisible=true;app.paused=false;app.sleeping=false
        app.touchBack();app.touch.cancelContact()
        app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
        app.toy.finish(app.now,immediate:true);app.art.toyFrame=CatToyFrame()
        growth.accessory.selections=[.flower,.fish];growth.accessory.cancelMotion()
        app.motion=CatMotion(now:app.now,seed:177,refinedTouch:true,headPetLeans:false)
        app.motion.nextBlink = .infinity;app.motion.nextGesture = .infinity;app.tick()
    }
    func click(_ reward:CatGrowthReward) {
        let r=growth.accessory.interactionRect(for:reward),p=NSPoint(x:r.midX,y:267-r.midY)
        func event(_ type:NSEvent.EventType)->NSEvent {NSEvent.mouseEvent(with:type,location:p,modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!}
        app.touch.mouseDown(with:event(.leftMouseDown));app.touch.mouseUp(with:event(.leftMouseUp))
    }
    #if CAT_ACCESSORY_GAZE
    let gains=[1.125]
    #else
    let gains=[1.0,1.125]
    #endif
    for gain in gains {
        reset()
        #if !CAT_ACCESSORY_GAZE
        if gain==1 {app.useOriginalEyeAmplitude()} else {app.useEnhancedEyeAmplitude()}
        #endif
        for reward in [CatGrowthReward.flower,.fish] {
            reset();click(reward);advance(0.50)
            check(app.art.eyeAim.x>0.99 && app.art.eyeAim.gain==gain,"real click renders selected amplitude")
            check(growth.accessory.sway(for:reward).isActive,"ornament sway unchanged")
            let first=app.art.eyeAim.x,head=app.art.pose.lookX
            click(reward)
            check(abs(app.art.eyeAim.x-first)<0.01 && abs(app.art.pose.lookX-head)<0.01,"repeat cannot reset eyes or head")
            advance(0.65)
            check(app.art.eyeAim.x>0 && app.accessoryGaze.isActive,"real own-glance pose must not reject continuing input")
            let returning=app.art.eyeAim.x
            click(reward == .flower ? .fish:.flower)
            check(abs(app.art.eyeAim.x-returning)<0.02,"cross-decoration return-phase input begins at current eye pose")
            advance(0.6);check(app.art.eyeAim.x>0.95,"return-phase click was admitted, not silently rejected")
            advance(1.0);check(app.art.eyeAim == .neutral && !app.accessoryGaze.isActive,"stopping input settles with no replay")
            click(reward);advance(0.05)
            check(app.art.eyeAim.x>0,"immediate post-return click responds without cooldown")
        }
    }
    for cancel in ["head","back","stroke","grab","letter","growth","pause","hide","sleep","menu","remove","mouth","menu-tail"] {
        reset();click(.flower);advance(cancel == "menu-tail" ? 1.18:0.5)
        check(app.art.eyeAim.x>0,"cancel case begins with active gaze")
        switch cancel {
        case "head":app.pet()
        case "back":app.touchBack()
        case "stroke":app.stroke(.back)
        case "grab":app.toy.start(app.now);app.beginToyContact()
        case "letter":app.showLetter()
        case "growth":app.showGrowth()
        case "pause":app.paused=true
        case "hide":app.petVisible=false
        case "sleep":app.sleeping=true
        case "menu","menu-tail":
            NotificationCenter.default.post(name:NSMenu.didBeginTrackingNotification,object:NSMenu())
            check(app.art.eyeAim == .neutral,"menu cancellation must not need a tick")
        case "remove":growth.accessory.selections=[.fish]
        default:app.motion.begin(.tongueTip,at:app.now-0.4)
        }
        app.tick();check(!app.accessoryGaze.isActive && app.art.eyeAim == .neutral,"priority cancellation: \(cancel)")
        if cancel == "letter" || cancel == "growth" {
            let window=cancel == "letter" ? app.letterController!.window! : growth.window!
            NSApp.activate(ignoringOtherApps:true);window.makeKeyAndOrderFront(nil)
            let deadline=Date(timeIntervalSinceNow:2)
            while !NSApp.isActive && Date()<deadline {
                while let event=NSApp.nextEvent(matching:.any,until:Date(),inMode:.default,dequeue:true) {NSApp.sendEvent(event)}
                NSApp.updateWindows();RunLoop.main.run(until:Date(timeIntervalSinceNow:0.01))
            }
            window.makeKeyAndOrderFront(nil)
            guard NSApp.isActive,window.isKeyWindow else {
                fputs("INVALID_SCENE: foreground panel fixture unavailable\n",stderr);exit(2)
            }
            app.lookAtAccessory(.flower);app.tick()
            check(app.art.eyeAim == .neutral,"foreground reader retains priority")
            // Direct NSView handler calls bypass AppKit's window activation.
            // Model that OS-owned handoff explicitly before the synthetic click.
            app.panel.makeKeyAndOrderFront(nil)
            check(!window.isKeyWindow && window.isVisible,"reader remains open behind the cat")
            click(.flower);app.tick()
            check(app.accessoryGaze.isActive,"deliberate click returns ownership to cat without closing panel")
        } else {click(.flower);app.tick()}
        if ["head","back","stroke","grab","pause","hide","sleep","remove","mouth"].contains(cancel) {
            check(app.art.eyeAim == .neutral,"removing cooldown must not bypass busy gates: \(cancel)")
        }
    }
    #if !CAT_ACCESSORY_GAZE
    reset();click(.fish);advance(0.5);app.useOriginalEyeAmplitude()
    check(app.art.eyeAim == .neutral && app.art.pose.lookX==0,"preset switch cancels to neutral before changing aperture")
    advance(1.5);check(app.art.eyeAim == .neutral,"preset switching cannot autoplay")
    check(app.animationTimer==nil && app.growthStore==nil,"no additional timer or real growth store")
    #else
    check(app.animationTimer==nil,"release gaze adds no timer")
    check(fileBefore == (try! Data(contentsOf:URL(fileURLWithPath:ProcessInfo.processInfo.environment["CAT_TEST_GROWTH_FILE"]!))),"gaze does not mutate persisted growth, earned rewards or decoration switches")
    let reloaded=CatGrowthController(owner:app,store:store)
    check(reloaded.ballSelected && reloaded.decorations == [.flower,.fish] && reloaded.growth.points==32,"production controller reload retains choices and growth")
    #endif
    check(preferences==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"formal preferences unchanged")
    check(saved==growth.growth.snapshot(ballSelected:growth.ballSelected,decorations:growth.decorations),"reward/score unchanged")
    app.panel.orderOut(nil)
    #if CAT_ACCESSORY_GAZE
    print("PASS release flower/fish repeat input, immediate replay, fixed approved gain, priority/menus, persisted choices and no real writes")
    #else
    print("PASS real repeated flower/fish input, return-phase switching, immediate replay, two amplitude presets, priority/menus, no timer or real writes")
    #endif
}
