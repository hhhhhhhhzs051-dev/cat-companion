import AppKit

func runMenuTests(_ app:PetApp) {
    setbuf(stdout,nil)
    func check(_ condition:Bool,_ message:String) {if !condition {fputs("FAIL \(message)\n",stderr);exit(1)}}
    // Additional display samples may interpolate but must not commit an early
    // strike, alter any later accepted sample, or reset a cooldown/regrab.
    for x in [0.41,0.50,0.55,0.61,0.67,0.72,0.77] {
        var reference=CatToy(rollInEnabled:true)
        reference.start(0);reference.grab(0.1);reference.move(to:CGPoint(x:x,y:0.355),at:0.2);reference.release(0.3)
        var sampled=reference
        for i in 0..<240 {
            let t=0.3+Double(i)/30
            let committed=sampled.frame(t)
            check(committed==reference.frame(t),"60 Hz presentation changes a committed build-56 toy frame")
            let beforeHits=sampled.hits
            let half=sampled.presentationFrame(t+1/60,canBat:true)
            var next=sampled;let following=next.frame(t+1/30)
            check(half.position.x.isFinite && half.position.y.isFinite && half.paw.isFinite,"Intermediate frames are finite")
            for (a,b,c) in [(committed.position.x,half.position.x,following.position.x),(committed.position.y,half.position.y,following.position.y)] {
                check(b>=min(a,c)-0.001 && b<=max(a,c)+0.001,"Extra ball frame cannot overshoot then move backward")
            }
            check(abs(half.paw-committed.paw)<0.3 && abs(half.paw-following.paw)<0.3,"Intermediate paw transitions cannot jump")
            check(sampled.hits==beforeHits,"Display-only sampling cannot score a hit")
            if i==15 {sampled.grab(t+0.02);reference.grab(t+0.02);sampled.release(t+0.025);reference.release(t+0.025)}
        }
    }
    print("PASS display-only samples preserve all 30 Hz committed toy frames and regrab timing")
    let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
    NSApp.setActivationPolicy(.regular);NSApp.finishLaunching()
    app.art=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
    app.panel=PetPanel(contentRect:NSRect(x:70,y:250,width:290,height:267),styleMask:[.borderless],backing:.buffered,defer:false)
    app.panel.title="流畅度计时验证 · 隔离数据"
    app.panel.isOpaque=false;app.panel.backgroundColor = .clear
    let container=NSView(frame:NSRect(origin:.zero,size:app.panel.frame.size));app.panel.contentView=container
    app.art.frame=container.bounds;container.addSubview(app.art)
    app.touch=PetTouchView(frame:container.bounds);app.touch.owner=app;container.addSubview(app.touch)
    app.setupControls(in:container)
    app.copy=["pet":["嗯，再摸一下。"]];app.growthController=CatGrowthController(owner:app)
    app.status=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
    app.settingsReady=true;app.performancePreview=CatPerformancePreview(owner:app)
    app.panel.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    app.syncActivity(force:true)
    check(app.isPlayPreview && app.growthStore==nil,"Performance preview has no real store")
    func run(_ seconds:Double) {let end=app.now+seconds;while app.now<end {
        while let event=NSApp.nextEvent(matching:.any,until:Date(),inMode:.default,dequeue:true) {NSApp.sendEvent(event)}
        NSApp.updateWindows()
        RunLoop.main.run(until:Date().addingTimeInterval(0.002))
    }}
    run(0.3)
    let controller=app.performancePreview!
    let idleBench=CommandLine.arguments.contains("--bench-idle")
    if CommandLine.arguments.contains("--bench") || idleBench {
        check(app.panel.occlusionState.contains(.visible),"Visible-window benchmark requires an unlocked ordinary desktop")
        // Same real window and deterministic input stream; each mode is warmed
        // separately and paired in forward/reverse order. No formal input/store.
        let orders:[[CatPerformancePreview.Mode]]=idleBench ? [[.baseline,.smooth],[.smooth,.baseline]]:[[.baseline,.bed,.look,.smooth],[.smooth,.look,.bed,.baseline]]
        for order in orders {
            for mode in order {for scene in (idleBench ? ["idle"]:["idle","drag","release"]) {
                controller.choose(mode)
                app.toy.finish(app.now,immediate:true);app.motion=CatMotion(now:app.now,seed:42)
                run(5)
                check(app.panel.occlusionState.contains(.visible),"Benchmark window became occluded during warmup")
                if scene != "idle" {app.toggleToy();app.beginToyContact()}
                let start=app.now,cpu=clock(),model=controller.modelTicks,extra=controller.presentationFrames
                var poses:[Double]=[],lastPose:CatPose?,lastCycle = -1,released=false,visibleThroughout=true
                app.art.onDraw={
                    visibleThroughout = visibleThroughout && app.panel.occlusionState.contains(.visible)
                    if app.art.pose != lastPose {poses.append(app.now);lastPose=app.art.pose}
                }
                let input=Timer.scheduledTimer(withTimeInterval:1/120,repeats:true){_ in
                    let t=app.now-start
                    if scene == "drag" {app.moveToy(CGPoint(x:(0.61+sin(t*3)*0.10)*290,y:60+0.32*290))}
                    if scene == "release" {
                        let cycle=Int(t/1.5),phase=t.truncatingRemainder(dividingBy:1.5)
                        if cycle != lastCycle {app.beginToyContact();lastCycle=cycle;released=false}
                        if phase<0.25 {app.moveToy(CGPoint(x:(cycle%2==0 ? 0.50:0.71)*290,y:60+0.30*290))}
                        else if !released {app.toy.release(app.now);app.tick();released=true}
                    }
                }
                if scene == "idle" {input.invalidate()}
                run(6);input.invalidate();app.art.onDraw=nil
                let elapsed=app.now-start
                let intervals=zip(poses.dropFirst(),poses).map{($0-$1)*1000}.sorted()
                visibleThroughout = visibleThroughout && app.panel.occlusionState.contains(.visible)
                let row:[String:Any] = ["mode":String(describing:mode),"scene":scene,"cpu_pct":Double(clock()-cpu)/Double(CLOCKS_PER_SEC)/elapsed*100,"cat_pose_hz":Double(poses.count)/elapsed,"model_hz":Double(controller.modelTicks-model)/elapsed,"extra_hz":Double(controller.presentationFrames-extra)/elapsed,"p95_pose_ms":intervals.isEmpty ? 0:intervals[Int(Double(intervals.count-1)*0.95)],"bed_bytes":app.art.bedCacheBytes,"visible":visibleThroughout]
                print("WINDOW "+String(data:try! JSONSerialization.data(withJSONObject:row,options:.sortedKeys),encoding:.utf8)!)
                check(visibleThroughout,"Visible benchmark cannot include an occluded sample")
                if scene == "idle" {check(app.art.bedCacheBytes==0 && controller.presentationFrames==extra,"Idle retains no added bed memory or presentation callbacks")}
                else if mode == .bed || mode == .smooth {check(app.art.bedCacheBytes>0,"Active real-window bed cache must actually be populated")}
            }}
        }
        app.animationTimer?.invalidate();app.stopPointerTracking();app.settingsReady=false;app.panel.orderOut(nil)
        return
    }
    let negative=CommandLine.arguments.contains("--expect60-on-baseline")
    for mode in [CatPerformancePreview.Mode.baseline,.bed,.smooth] {
        controller.choose(mode)
        app.toy.finish(app.now,immediate:true);app.motion=CatMotion(now:app.now,seed:42)
        run(0.2)
        let before=controller.presentationFrames
        run(0.5)
        check(controller.presentationFrames==before,"Idle cannot create additional display callbacks")
        check(app.art.bedCacheBytes==0,"Idle releases bed-cache memory")
        app.toggleToy();app.beginToyContact()
        let start=app.now,cpu=clock(),model=controller.modelTicks,extra=controller.presentationFrames
        var draws:[Double]=[];app.art.onDraw={
            if draws.isEmpty,let ctx=NSGraphicsContext.current?.cgContext {print("SCREEN",ctx.ctm,"color",ctx.colorSpace?.name as Any,"windowColor",app.panel.colorSpace as Any,"cacheEnabled",app.art.bedCacheEnabled)}
            draws.append(app.now)
        }
        let drag=Timer.scheduledTimer(withTimeInterval:1/120,repeats:true){_ in
            app.moveToy(CGPoint(x:(0.61+sin((app.now-start)*3)*0.10)*290,y:60+0.36*290))
        }
        run(2);drag.invalidate()
        let elapsed=app.now-start
        app.art.onDraw=nil
        let intervals=zip(draws.dropFirst(),draws).map{($0-$1)*1000}.sorted()
        let extras=controller.presentationFrames-extra,models=controller.modelTicks-model
        print("LIVE mode=\(mode) cpu_pct=\(Double(clock()-cpu)/Double(CLOCKS_PER_SEC)/elapsed*100) model_hz=\(Double(models)/elapsed) extra_hz=\(Double(extras)/elapsed) draws_hz=\(Double(draws.count)/elapsed) p95_interval_ms=\(intervals.isEmpty ? 0:intervals[Int(Double(intervals.count-1)*0.95)])")
        if mode == .smooth || negative {check(extras>=40,"Active 60 Hz must provide additional presentation samples")}
        else {check(extras==0,"Baseline/individual render experiments cannot add frames")}
        check((45...70).contains(models),"60 Hz rendering must not advance the accepted 30 Hz model clock")
        if mode == .bed || mode == .smooth {check(app.art.bedCacheBytes>0,"Active real-window bed cache must actually be populated")}
        app.toy.release(app.now);app.tick();run(0.3)
    }
    controller.choose(.smooth);app.pet()
    let petEnd=app.motion.petEnd
    run(0.3);check(app.motion.petEnd==petEnd,"Extra presentation cannot extend pet timing")
    let menu=app.makeMenu();app.menuWillOpen(menu)
    let models=controller.modelTicks
    let end=app.now+0.5
    while app.now<end {RunLoop.main.run(mode:.eventTracking,before:Date().addingTimeInterval(0.002))}
    check((10...20).contains(controller.modelTicks-models),"Menu tracking must not run two model clocks")
    app.menuDidClose(menu)
    controller.reducedForTest=true;app.tick()
    let reduced=controller.presentationFrames;run(0.2)
    check(controller.presentationFrames==reduced && app.art.bedCacheBytes==0,"Reduced-motion policy disables added callbacks and bed memory")
    controller.reducedForTest=false
    app.togglePause();let stopped=controller.presentationFrames;run(0.2)
    check(controller.presentationFrames==stopped,"Rest cancels intermediate frames")
    check(app.art.bedCacheBytes==0,"Rest releases bed layers")
    app.togglePause();app.pet();run(0.05)
    app.petVisible=false;app.syncActivity(force:true)
    let hidden=controller.presentationFrames;run(0.2)
    check(controller.presentationFrames==hidden && app.art.bedCacheBytes==0,"Hide stops added rendering and releases bed layers")
    app.saveSettings()
    check(prefs == UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"No formal preference writes")
    app.animationTimer?.invalidate();app.stopPointerTracking();app.settingsReady=false;app.panel.orderOut(nil)
    print("PASS active-only presentation, original model cadence, pet endpoint, menu tracking, pause and storage isolation")
}
