import AppKit

func runMenuTests(_ app:PetApp) {
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    func check(_ ok:Bool,_ message:String) {if !ok {print("FAIL: \(message)");exit(1)}}
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    let container=NSView(frame:NSRect(x:0,y:0,width:290,height:267))
    app.panel.contentView=container;app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch)
    app.setupControls(in:container)
    let growth=CatGrowthController(owner:app);app.growthController=growth
    growth.prepareAccessoryDemo();growth.accessory.frame=container.bounds
    container.addSubview(growth.accessory,positioned:.above,relativeTo:app.art)
    app.active=true;app.petVisible=true;app.paused=false
    let preferences=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    let saved=growth.growth.snapshot(ballSelected:growth.ballSelected,decorations:growth.decorations)
    app.motion=CatMotion(now:app.now,seed:177,refinedTouch:true,headPetLeans:false)
    app.motion.nextBlink = .infinity;app.motion.nextGesture = .infinity
    app.tick()
    func event(_ type:NSEvent.EventType,_ p:CGPoint)->NSEvent {
        NSEvent.mouseEvent(with:type,location:NSPoint(x:p.x,y:267-p.y),modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    }
    let p=CGPoint(x:270,y:232)
    app.touch.mouseDown(with:event(.leftMouseDown,p))
    check(app.art.pose.lookX==0,"press alone does not glance")
    app.touch.mouseUp(with:event(.leftMouseUp,p))
    Thread.sleep(forTimeInterval:0.25);app.tick()
    check(app.art.pose.lookX>0.1 && app.art.pose.rightEar>0,"a real flower release makes the idle cat glance toward the accessory")
    check(app.art.pose.lean==0 && app.art.pose.head==0,"glance never moves the whole body or changes head nod")
    #if CAT_ACCESSORY_LOOK_PREVIEW
    check(!app.art.bedCacheEnabled,"this preview does not enable the unaccepted accessory bed cache")
    func click(_ reward:CatGrowthReward) {
        let rect=growth.accessory.interactionRect(for:reward),point=CGPoint(x:rect.midX,y:rect.midY)
        app.touch.mouseDown(with:event(.leftMouseDown,point))
        app.touch.mouseUp(with:event(.leftMouseUp,point))
    }
    func reset() {
        app.accessoryLook=CatAccessoryLook();app.touch.cancelContact()
        app.active=true;app.petVisible=true;app.paused=false;app.sleeping=false
        app.toy.finish(app.now,immediate:true);app.art.toyFrame=CatToyFrame()
        growth.accessory.selections=[.flower,.fish];growth.accessory.cancelMotion()
        app.motion=CatMotion(now:app.now,seed:177,refinedTouch:true,headPetLeans:false)
        app.motion.nextBlink = .infinity;app.motion.nextGesture = .infinity
        app.tick()
    }
    for reward in [CatGrowthReward.flower,.fish] {
        reset()
        let petEnd=app.motion.petEnd,gestureStart=app.motion.gestureStart
        click(reward)
        check(app.accessoryLook.isActive,"both ornaments start the same finite glance")
        check(app.motion.petEnd==petEnd && app.motion.gestureStart==gestureStart &&
              app.motion.nextBlink == .infinity && app.motion.nextGesture == .infinity,"click does not reschedule original motion or blink clocks")
        check(growth.accessory.sway(for:reward).isActive,"original ornament sway still starts")
        Thread.sleep(forTimeInterval:0.25);app.tick()
        let peak=app.art.pose
        check(peak.lookX>0.1 && peak.rightEar>0,"rendered pose carries gaze for drawing and inverse hit testing")
        check(app.art.touchRegion(CGPoint(x:170,y:112)) == .head &&
              app.art.touchRegion(CGPoint(x:105,y:154)) == .back,"accepted central touch regions remain reachable during glance")
        click(reward)
        Thread.sleep(forTimeInterval:0.90);app.tick()
        check(!app.accessoryLook.isActive && app.art.pose.lookX==0 && app.art.pose.rightEar==0,"repeated click does not extend finite return")
        check(app.art.pose==CatPose(breath:app.art.pose.breath),"settled pose is exactly the accepted idle pose")
        click(reward)
        check(!app.accessoryLook.isActive,"cooldown ignores new clicks instead of replaying or queueing")
    }
    for cancel in ["head","back","stroke","grab","letter","growth","pause","hide","sleep","menu","remove","mouth"] {
        reset();click(.flower)
        let trackedMenu=app.makeMenu()
        check(app.accessoryLook.isActive,"cancellation case begins with a glance: \(cancel)")
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
        case "menu":
            app.menuWillOpen(trackedMenu)
            check(!app.accessoryLook.isActive,"menu opening cancels synchronously before its first tracking tick")
        case "remove":growth.accessory.selections=[.fish]
        default:app.motion.begin(.tongueTip,at:app.now-0.4)
        }
        app.tick()
        check(!app.accessoryLook.isActive,"higher priority action cancels with no queue: \(cancel)")
        app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
        app.menuDidClose(trackedMenu)
        app.active=true;app.paused=false;app.petVisible=true;app.sleeping=false
        app.toy.finish(app.now,immediate:true);app.touch.cancelContact()
        growth.accessory.selections=[.flower,.fish]
        app.tick()
        check(!app.accessoryLook.isActive,"unblocking never replays ignored input: \(cancel)")
    }
    reset();click(.fish)
    Thread.sleep(forTimeInterval:0.25);app.tick()
    check(app.art.pose.lookX>0,"application menu test begins with a visible glance")
    let menuBreath=app.art.pose.breath
    // A resting ball at its timeout must not advance, or mutate the menu being
    // opened, merely because the glance is cancelled during menu tracking.
    app.toy.start(app.now-31)
    let applicationMenu=NSMenu()
    NotificationCenter.default.post(name:NSMenu.didBeginTrackingNotification,object:applicationMenu)
    check(!app.accessoryLook.isActive && app.art.pose.lookX==0,"application-menu tracking notification cancels and redraws without a timer tick")
    check(app.toy.isOut && app.art.pose.breath==menuBreath,"menu-start cancellation must not run the simulation or expire a resting ball")
    for blocked in ["pet","ball","letter","growth","pause","hidden","head-gesture"] {
        reset()
        switch blocked {
        case "pet":app.touchBack()
        case "ball":app.toy.start(app.now)
        case "letter":app.showLetter()
        case "growth":app.showGrowth()
        case "pause":app.paused=true
        case "hidden":app.petVisible=false
        default:app.motion.begin(.headDown,at:app.now-0.5);app.tick()
        }
        if blocked == "letter" || blocked == "growth" {
            let window=blocked == "letter" ? app.letterController!.window! : growth.window!
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
            // A real cat click now deliberately transfers focus. Probe only
            // the foreground gate here; background clicks have their own suite.
            app.lookAtAccessory(.fish)
        } else {click(.fish)}
        check(!app.accessoryLook.isActive,"busy foreground input does not arm a later response: \(blocked)")
        app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
    }
    reset()
    // Press one/release the other and decoration drag retain release ownership.
    let fishPoint=CGPoint(x:256,y:184)
    app.touch.mouseDown(with:event(.leftMouseDown,p));app.touch.mouseUp(with:event(.leftMouseUp,fishPoint))
    check(!app.accessoryLook.isActive,"cross-decoration release triggers no glance")
    app.touch.mouseDown(with:event(.leftMouseDown,p))
    app.touch.mouseDragged(with:event(.leftMouseDragged,CGPoint(x:p.x-12,y:p.y)))
    app.touch.mouseUp(with:event(.leftMouseUp,CGPoint(x:p.x-12,y:p.y)))
    check(!app.accessoryLook.isActive,"moving the bed from an ornament is not a click")
    check(growth.growth.snapshot(ballSelected:growth.ballSelected,decorations:growth.decorations)==saved,"decorations and interference tests do not alter already completed demo progress or rewards")
    check(preferences==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"isolated preview never writes formal preferences")
    check(app.animationTimer==nil && app.growthStore==nil,"response owns no additional timer or persistent growth store")
    app.panel.orderOut(nil)
    print("PASS both ornaments, unchanged clocks/idle pose/hit regions, cancellation and busy ignore, no stacking, no queue or real-save writes")
    #endif
    print("PASS accessory look through the real release and tick path")
}
