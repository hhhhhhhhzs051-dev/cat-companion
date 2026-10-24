import AppKit

// Exercises the actual accessory release -> PetApp tick -> NativeCatView path.
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
    let saved=growth.growth.snapshot(ballSelected:growth.ballSelected,decorations:growth.decorations)
    let preferences=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    func event(_ type:NSEvent.EventType,_ point:CGPoint)->NSEvent {
        NSEvent.mouseEvent(with:type,location:NSPoint(x:point.x,y:267-point.y),modifierFlags:[],timestamp:app.now,windowNumber:app.panel.windowNumber,context:nil,eventNumber:0,clickCount:1,pressure:1)!
    }
    func click(_ reward:CatGrowthReward) {
        let r=growth.accessory.interactionRect(for:reward),p=CGPoint(x:r.midX,y:r.midY)
        app.touch.mouseDown(with:event(.leftMouseDown,p));app.touch.mouseUp(with:event(.leftMouseUp,p))
    }
    func reset() {
        app.active=true;app.petVisible=true;app.paused=false;app.sleeping=false
        app.touchBack() // Real priority cancellation, not a test-only eye reset.
        app.touch.cancelContact();app.accessoryLook=CatAccessoryLook()
        app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
        app.toy.finish(app.now,immediate:true);app.art.toyFrame=CatToyFrame()
        growth.accessory.selections=[.flower,.fish];growth.accessory.cancelMotion()
        app.motion=CatMotion(now:app.now,seed:177,refinedTouch:true,headPetLeans:false)
        app.motion.nextBlink = .infinity;app.motion.nextGesture = .infinity
        app.tick()
    }
    func advance(_ seconds:Double) {Thread.sleep(forTimeInterval:seconds);app.tick()}
    for reward in [CatGrowthReward.flower,.fish] {
        reset();click(reward);advance(0.50)
        check(app.art.eyeAim.x>0.99 && app.art.eyeAim.x<=1 && app.art.eyeAim.fixedApertureX==1,
              "real ornament release uses the accepted small rightward gaze and fixed aperture")
        check(growth.accessory.sway(for:reward).isActive,"original ornament sway remains active")
        check(app.art.pose.lean==0 && app.art.pose.head==0,"gaze adds no body lean or vertical head movement")
        check(app.art.touchRegion(CGPoint(x:170,y:112)) == .head && app.art.touchRegion(CGPoint(x:105,y:154)) == .back,
              "eye texture movement does not change central head/back hits")
        click(reward);advance(0.69)
        check(app.art.pose.lookX==0 && app.art.pose.rightEar==0,"old head/ear response ends on its original schedule")
        check(app.art.eyeAim.x>0 && app.art.eyeAim.x<0.8,"accepted eye return continues independently after head settles")
        advance(0.25)
        check(app.art.eyeAim == .neutral && !app.accessoryLook.isActive,"finite gaze returns exactly to original eyes")
        click(reward);advance(0.10)
        check(app.art.eyeAim == .neutral,"cooldown click neither restarts nor queues eyes")
    }
    for cancel in ["head","back","stroke","grab","letter","growth","pause","hide","sleep","menu","remove","mouth","menu-tail"] {
        reset();click(.flower);advance(cancel == "menu-tail" ? 1.18:0.5)
        check(app.art.eyeAim.x>0,"cancellation begins with visible eye movement: \(cancel)")
        let tracked=app.makeMenu()
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
            NotificationCenter.default.post(name:NSMenu.didBeginTrackingNotification,object:tracked)
            check(app.art.eyeAim == .neutral,"menu clears eyes even without an animation tick: \(cancel)")
        case "remove":growth.accessory.selections=[.fish]
        default:app.motion.begin(.tongueTip,at:app.now-0.4)
        }
        app.tick()
        check(app.art.eyeAim == .neutral,"higher-priority interaction clears eye gaze: \(cancel)")
        app.letterController?.window?.orderOut(nil);growth.window?.orderOut(nil)
        app.active=true;app.paused=false;app.petVisible=true;app.sleeping=false
        app.toy.finish(app.now,immediate:true);app.touch.cancelContact()
        growth.accessory.selections=[.flower,.fish];app.tick()
        check(app.art.eyeAim == .neutral,"unblocking never replays eye gaze: \(cancel)")
    }
    for blocked in ["pet","ball","letter","growth","pause","hidden","gesture"] {
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
            app.lookAtAccessory(.fish)
        } else {click(.fish)}
        advance(0.1)
        check(app.art.eyeAim == .neutral,"busy input cannot arm eye movement: \(blocked)")
    }
    reset();advance(1.5)
    check(app.art.eyeAim == .neutral && app.animationTimer==nil,"idle starts no autonomous gaze or extra timer")
    check(app.growthStore==nil && growth.growth.snapshot(ballSelected:growth.ballSelected,decorations:growth.decorations)==saved,
          "mock rewards remain in memory, progress and rewards unchanged")
    check(preferences==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"formal preferences untouched")
    app.panel.orderOut(nil)
    print("PASS real flower/fish gaze routing, original timing, cancellation including eye-only tail, idle silence, storage isolation")
}
