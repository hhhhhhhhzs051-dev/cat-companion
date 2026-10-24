import AppKit

// Manual PetApp setup deliberately avoids formal preferences, copy and save loading.
// The unmodified build59 sources and candidate run this same visible-window harness.
func runMenuTests(_ app:PetApp) {
    setbuf(stdout,nil)
    let bench=CommandLine.arguments.contains("--bench"),scene=CommandLine.arguments.last!
    func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL closed-eye window: \(message)\n",stderr);exit(1)}}
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    check(app.isPlayPreview && app.growthStore == nil,"isolated settings and in-memory growth")
    check(!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,"benchmark needs ordinary motion; system setting not changed")
    let preferences=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:60,y:200,width:290,height:290*1085/1525+60),
        styleMask:.borderless,backing:.buffered,defer:false)
    app.panel.title="闭眼性能测量 · 未安装（290pt）"
    app.panel.isOpaque=false;app.panel.backgroundColor = .clear;app.panel.hasShadow=false
    if let screen=NSScreen.main {app.panel.setFrameOrigin(NSPoint(x:screen.visibleFrame.minX+60,y:screen.visibleFrame.midY-100))}
    let container=NSView(frame:NSRect(origin:.zero,size:app.panel.frame.size))
    app.panel.contentView=container
    app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch)
    app.setupControls(in:container)
    let growth=CatGrowthController(owner:app);app.growthController=growth
    growth.accessory.frame=container.bounds
    container.addSubview(growth.accessory,positioned:.above,relativeTo:app.art)
    app.active=true;app.petVisible=true
    func reset() {
        app.touch.cancelContact()
        app.motion=CatMotion(now:app.now,seed:42,refinedTouch:true,headPetLeans:false)
        app.tick()
    }
    func pump(_ seconds:Double) {
        let end=app.now+seconds
        while app.now<end {
            autoreleasepool {
                while let event=NSApp.nextEvent(matching:.any,until:Date(),inMode:.default,dequeue:true) {NSApp.sendEvent(event)}
                NSApp.updateWindows()
                RunLoop.current.run(until:Date().addingTimeInterval(0.002))
            }
        }
    }
    func residentBytes()->UInt64 {
        var info=mach_task_basic_info()
        var count=mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size/MemoryLayout<integer_t>.size)
        let result=withUnsafeMutablePointer(to:&info) {pointer in
            pointer.withMemoryRebound(to:integer_t.self,capacity:Int(count)) {
                task_info(mach_task_self_,task_flavor_t(MACH_TASK_BASIC_INFO),$0,&count)
            }
        }
        check(result==KERN_SUCCESS,"resident sample")
        return UInt64(info.resident_size)
    }
    func closedSource()->Bool {
        #if CAT_CLOSED_REFERENCE
        return false
        #else
        return app.art.hasHeldClosedSource
        #endif
    }
    func composites()->Int {
        #if CAT_CLOSED_REFERENCE
        return -1
        #else
        return app.art.fullClosureCompositions
        #endif
    }
    func press(_ region:CatTouchRegion) {
        app.touch.region=region
        if region == .back {app.touchBack()} else {app.pet()}
        app.stroke(region)
    }
    func release() {app.motion.endStroke(app.now);app.touch.cancelContact();app.tick()}
    app.panel.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);app.panel.displayIfNeeded()
    pump(0.3)
    check(app.panel.occlusionState.contains(.visible),"visible desktop required")
    // Identical initial window-update sequence. AppKit may coalesce these:
    // record actual rasters; the separate rest scene measures warmed steady idle.
    for i in 0...48 {autoreleasepool {
        app.art.update(CatPose(breath:Double(i)/48));app.panel.displayIfNeeded()
    }}
    reset()
    if !bench {
        #if !CAT_CLOSED_REFERENCE
        app.settingsReady=true
        for interrupted in ["pause","sleep","hidden"] {
            press(.back)
            let timer=Timer.scheduledTimer(withTimeInterval:1/30,repeats:true){_ in app.stroke(.back);app.tick()}
            pump(0.3);timer.invalidate();app.panel.displayIfNeeded()
            check(closedSource(),"closed endpoint present before \(interrupted)")
            // Exercise actual lifecycle handlers, not just their expected end state.
            switch interrupted {
            case "pause":app.togglePause()
            case "sleep":app.willSleep()
            default:app.suspendPet()
            }
            check(!closedSource(),"\(interrupted) releases source without requiring another draw")
            app.animationTimer?.invalidate();app.animationTimer=nil;app.stopPointerTracking()
            app.paused=false;app.active=true;app.sleeping=false;app.petVisible=true;reset()
        }
        app.settingsReady=false
        app.toy.start(app.now-2);app.toy.park(app.now-1,reduced:false);app.tick()
        press(.back)
        app.art.update(CatPose(eyes:1,breath:0.47));app.panel.displayIfNeeded()
        let setupBitmap=app.art.bitmapImageRepForCachingDisplay(in:app.art.bounds)!
        app.art.cacheDisplay(in:app.art.bounds,to:setupBitmap)
        // Park again in the past to reach the actual preserved resting-ball branch.
        app.toy.park(app.now-1,reduced:false);_=app.toy.frame(app.now,reduced:false,canBat:false)
        check(app.canKeepRestingToy && closedSource(),"closed endpoint with settled parked ball")
        let preservedPose=app.art.pose
        app.active=false;app.tick()
        check(!closedSource() && app.art.pose==preservedPose && app.toy.isOut,
              "occlusion early return drops only intermediate, preserving cat and parked ball")
        app.art.viewDidChangeBackingProperties()
        let bitmap=app.art.bitmapImageRepForCachingDisplay(in:app.art.bounds)!
        app.art.cacheDisplay(in:app.art.bounds,to:bitmap)
        check(!closedSource() && app.art.pose==preservedPose && app.toy.isOut,
              "inactive backing redraw must not resurrect the closed-eye source")
        app.active=true;app.toy.finish(app.now,immediate:true);reset()
        app.art.update(CatPose(eyes:1,breath:0.68))
        app.art.cacheDisplay(in:app.art.bounds,to:setupBitmap)
        check(closedSource(),"new active closed frame may reuse again")
        reset()
        press(.back);var p=app.motion.frame(app.now+0.3,reduced:false,paused:false)
        app.art.update(p);app.art.cacheDisplay(in:app.art.bounds,to:setupBitmap)
        check(closedSource(),"closed before reduced-motion frame")
        p=app.motion.frame(app.now+0.4,reduced:true,paused:false)
        app.art.update(p);check(!closedSource(),"reduced-motion endpoint clears without altering system preference")
        reset()
        check(!app.art.bedCacheEnabled,"no extra bed cache while settled")
        growth.accessory.selections=[.flower,.fish]
        growth.accessory.tap(.fish,at:app.now,reduced:false);app.tick()
        check(!app.art.bedCacheEnabled,"previous accessory-sway cache explicitly excluded")
        print("PASS closed-eye lifecycle: actual pause/sleep/hide handlers, reduced endpoint cleanup and original accessory bed policy")
        #endif
    } else {
        check(["idle","head","back","early","rest"].contains(scene),"known scene")
        if scene == "rest" {
            press(.back)
            let settle=Timer.scheduledTimer(withTimeInterval:1/30,repeats:true){_ in app.tick()}
            pump(1);release();pump(6);settle.invalidate();reset()
        }
        let start=app.now,cpu=clock(),rasterStart=app.art.catRasterizations,compositionStart=composites()
        let residentStart=residentBytes()
        var residentMaximum=residentStart,draws=0,visible=true,intervals:[Double]=[],lastDraw:Double?
        var heldTicks=0,cachedTicks=0,cycle = -1,released=false
        app.art.onDraw={
            draws += 1
            if let last=lastDraw {intervals.append((app.now-last)*1000)}
            lastDraw=app.now
        }
        let activeScene=["head","back","early"].contains(scene)
        let period=scene == "early" ? 3.0:6.0,duration=activeScene ? period*3:8.0
        let timer=Timer.scheduledTimer(withTimeInterval:1/30,repeats:true){_ in
            visible = visible && app.panel.isVisible && app.panel.occlusionState.contains(.visible) && !NSApp.isHidden
            let elapsed=app.now-start,index=Int(elapsed/period),age=elapsed.truncatingRemainder(dividingBy:period)
            if activeScene {
                let region:CatTouchRegion=scene == "head" ? .head:.back
                if index != cycle {press(region);cycle=index;released=false}
                let releaseAt=scene == "early" ? 2.0:5.5
                if age<releaseAt {app.stroke(region)}
                else if !released {release();released=true}
            }
            app.tick()
            if app.art.pose.eyes==1 {heldTicks += 1}
            if closedSource() {cachedTicks += 1}
            residentMaximum=max(residentMaximum,residentBytes())
        }
        timer.tolerance=(1/30)*0.15;pump(duration);timer.invalidate()
        let seconds=app.now-start,cpuPercent=Double(clock()-cpu)/Double(CLOCKS_PER_SEC)/seconds*100
        let rasters=app.art.catRasterizations-rasterStart,compositionCount=composites()-compositionStart
        app.art.onDraw=nil
        release()
        let settling=Timer.scheduledTimer(withTimeInterval:1/30,repeats:true){_ in app.tick()}
        pump(6);settling.invalidate()
        check(visible && app.panel.occlusionState.contains(.visible),"entire sample visible")
        check(!closedSource() && !app.art.bedCacheEnabled,"no retained interaction cache after settling")
        intervals.sort()
        #if CAT_CLOSED_REFERENCE
        let variant="build59"
        #else
        let variant="candidate"
        if activeScene {check(heldTicks>80 && cachedTicks>80,"measured actual complete closure")}
        #endif
        let row:[String:Any]=["variant":variant,"scene":scene,"cpu_pct":cpuPercent,"seconds":seconds,
            "draws":draws,"rasters":rasters,"full_closed_ticks":heldTicks,"cached_ticks":cachedTicks,
            "closed_compositions":compositionCount,"resident_start_bytes":residentStart,
            "resident_sample_max_bytes":residentMaximum,"resident_settled_bytes":residentBytes(),
            "p95_interval_ms":intervals.isEmpty ? 0:intervals[Int(Double(intervals.count-1)*0.95)],
            "visible":visible,"retained_closed_source":closedSource()]
        print("BENCH "+String(data:try! JSONSerialization.data(withJSONObject:row,options:.sortedKeys),encoding:.utf8)!)
    }
    check(preferences==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"formal preferences unchanged")
    app.panel.orderOut(nil)
}
