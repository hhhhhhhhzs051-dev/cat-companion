import AppKit
import UniformTypeIdentifiers

#if CAT_ACCESSORY_PREVIEW && !CAT_PLAY_PREVIEW
#error("Accessory preview requires isolated storage and settings")
#endif

#if CAT_ROLL_IN_PREVIEW && !CAT_PLAY_PREVIEW
#error("Roll-in preview must use isolated play-preview storage and settings")
#endif
#if CAT_PERF_PREVIEW && !CAT_PLAY_PREVIEW
#error("Performance preview requires isolated preview storage and settings")
#endif
#if CAT_TOUCH_PREVIEW && !CAT_PLAY_PREVIEW
#error("Touch preview requires isolated preview storage and settings")
#endif
#if CAT_STEADY_HEAD_PREVIEW && (!CAT_PLAY_PREVIEW || !CAT_TOUCH_PREVIEW)
#error("Steady-head preview requires the isolated refined-touch preview")
#endif

final class PetPanel: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
final class PetControlButton: NSButton {
    override func acceptsFirstMouse(for event:NSEvent?) -> Bool { true }
}
final class PetTouchView: NSView {
    weak var owner: PetApp?
    var allowsContextMenu=true
    var startMouse = NSPoint.zero
    var startOrigin = NSPoint.zero
    var dragging = false
    var region=CatTouchRegion.none
    var stroking=false
    var playing=false
    private var lastStrokePoint=NSPoint.zero
    var accessoryContact:CatGrowthReward?
    var hasContact:Bool {region != .none || playing || accessoryContact != nil}
    func cancelContact() {
        accessoryContact=nil

        owner?.growthController?.cancelDrag()
        // A stationary press also owns an eye hold, even without a drag event.
        if region == .back || region == .head,let owner {owner.motion.releaseContactEyes(owner.now)}
        region = .none;dragging=false;stroking=false;playing=false
    }
    private func screenPoint(_ event:NSEvent)->NSPoint {window?.convertPoint(toScreen:event.locationInWindow) ?? .zero}
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        startMouse = screenPoint(event);lastStrokePoint=startMouse
        startOrigin = window?.frame.origin ?? .zero
        dragging = false;stroking=false
        guard let owner else {cancelContact();return}
        let local=owner.art.convert(event.locationInWindow,from:nil)
        playing=owner.toy.isOut && owner.art.containsToy(local)
        if playing {region = .none;owner.beginToyContact();return}
        accessoryContact=owner.growthController?.accessory.reward(at:local)
        if accessoryContact != nil {region = .none;return}

        region=owner.art.touchRegion(local)
        if region == .head {owner.pet()}
        else if region == .back {owner.touchBack()}
    }
    override func mouseDragged(with event: NSEvent) {
        if playing,let owner {
            owner.moveToy(owner.art.convert(event.locationInWindow,from:nil));return
        }
        let mouse = screenPoint(event)
        let dx = mouse.x-startMouse.x, dy = mouse.y-startMouse.y
        if accessoryContact != nil {
            if hypot(dx,dy)>4 {dragging=true}
            if dragging {window?.setFrameOrigin(NSPoint(x:startOrigin.x+dx,y:startOrigin.y+dy))}
            return
        }

        if region == .bed {
            if hypot(dx,dy)>4 { dragging = true }
            if dragging { window?.setFrameOrigin(NSPoint(x:startOrigin.x+dx,y:startOrigin.y+dy)) }
        } else if region == .head || region == .back {
            guard let owner else {cancelContact();return}
            let current=owner.art.touchRegion(owner.art.convert(event.locationInWindow,from:nil))
            if current == .head || current == .back {
                // Re-entering the cat resumes contact even below the stroke distance threshold.
                if region == .back || stroking {owner.motion.continueContactEyes(owner.now)}
                if hypot(mouse.x-lastStrokePoint.x,mouse.y-lastStrokePoint.y)>=3 {
                    stroking=true;lastStrokePoint=mouse
                    owner.stroke(region)
                }
            } else {
                // Crossing the artwork boundary is not a mouse release. Let the
                // ear/head response settle, but keep this gesture's eye hold.
                owner.motion.endStroke(owner.now,releaseEyes:false)
            }
        }
    }
    override func mouseUp(with event: NSEvent) {
        if let accessoryContact,!dragging,let owner,owner.active,!owner.paused,owner.petVisible,
           let accessory=owner.growthController?.accessory,
           accessory.reward(at:owner.art.convert(event.locationInWindow,from:nil)) == accessoryContact {
            accessory.tap(accessoryContact,at:owner.now,reduced:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
            owner.tick()
        }

        if playing, let owner, owner.active, !owner.paused, owner.toy.isOut, owner.toy.dragging {
            owner.growthController?.releaseDrag()
        }
        if playing,let owner {owner.toy.release(owner.now);owner.tick()}
        if dragging { owner?.keepOnScreen() }
        if stroking,let owner {owner.motion.endStroke(owner.now)}
        cancelContact()
    }
    override func rightMouseDown(with event: NSEvent) {
        guard allowsContextMenu else{return}
        if let menu = owner?.makeMenu() { NSMenu.popUpContextMenu(menu, with:event, for:self) }
    }
}
final class PetApp: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    var panel: PetPanel!
    var letterController:CatLetterController?
    var growthController: CatGrowthController?
    @objc func showGrowth() { growthController?.present() }
    var growthStore: CatGrowthStore? {
        if selfTest {
            guard let path = ProcessInfo.processInfo.environment["CAT_TEST_GROWTH_FILE"] else { return nil }
            return CatGrowthStore(url: URL(fileURLWithPath: path))
        }
        guard !isPlayPreview else { return nil }
        return CatGrowthStore(url: copyURL.deletingLastPathComponent().appendingPathComponent("成长记录.json"))
    }
    #if CAT_PLAY_PREVIEW
    let isPlayPreview=true
    #else
    let isPlayPreview=false
    #endif
    var art: NativeCatView!
    #if CAT_STEADY_HEAD_PREVIEW
    var motion=CatMotion(refinedTouch:true,headPetLeans:false)
    #elseif CAT_TOUCH_PREVIEW
    var motion=CatMotion(refinedTouch:true)
    #else
    // Same configuration as the user-accepted 290pt steady-head preview.
    var motion=CatMotion(refinedTouch:true,headPetLeans:false)
    #endif
    // The accepted short surface roll uses the same model in preview and release.
    var toy=CatToy(rollInEnabled:true)
    var playMood=CatPlayMood()
    var animationTimer:Timer?
    #if CAT_PERF_PREVIEW
    var performancePreview:CatPerformancePreview?
    #endif
    private var menuTrackingTimer:Timer?
    private weak var trackingMenu:NSMenu?
    var previewVisibilityUntil:Double=0
    var sleeping=false
    var active=false
    var phraseUntil=0.0, nextPhrase=Double.infinity
    var phrase="",petPhrase=""
    private var petPhraseUntil = -Double.infinity
    var lastPhrase = -1, lastPet = -1
    var touch: PetTouchView!
    var status: NSStatusItem!
    var controls: NSView!
    var pinButton: NSButton!
    var controlsShown = false
    var lastHover = Date.distantPast
    var pointerMonitors:[Any]=[]
    var hoverFade:DispatchWorkItem?
    // Automatic speech and grooming were removed from the desktop experience.
    // Do not restore legacy enabled preferences on launch.
    let voiceEnabled = false
    var paused = false
    var floating = false
    #if CAT_PAW_EXPERIMENT
    let autoGrooming=false
    #endif
    var petVisible = true
    var copy: [String:Any] = [:]
    var settingsReady = false
    let preferences = UserDefaults.standard
    func saveSettings() {
        guard !selfTest,!isPlayPreview, settingsReady, panel != nil else { return }
        preferences.set(voiceEnabled,forKey:"voice")
        preferences.set(paused,forKey:"paused")
        preferences.set(floating,forKey:"floating")
        #if CAT_PAW_EXPERIMENT
        preferences.set(autoGrooming,forKey:"autoGrooming")
        #endif
        preferences.set(NSStringFromRect(panel.frame),forKey:"frame")
    }
    @objc func screenChanged() { keepOnScreen(); saveSettings(); syncActivity() }
    func windowDidMove(_ notification:Notification) { saveSettings() }
    func windowDidResize(_ notification:Notification) { layoutControls();art?.needsDisplay=true;saveSettings() }
    func windowDidChangeOcclusionState(_ notification:Notification) {syncActivity()}
    func applicationDidHide(_ notification:Notification) {syncActivity(force:true)}
    func applicationDidUnhide(_ notification:Notification) {syncActivity()}
    @objc func willSleep() {sleeping=true;syncActivity(force:true)}
    @objc func didWake() {sleeping=false;keepOnScreen();syncActivity()}
    @objc func accessibilityChanged() {layoutControls();syncActivity(force:true);status?.menu=makeMenu()}
    var now:Double {ProcessInfo.processInfo.systemUptime}
    func schedulePhrase() {
        let interval=copy["intervalSeconds"] as? [Double] ?? [120,180]
        let low=max(30,min(3600,interval.first ?? 120)),high=max(low,min(3600,interval.count>1 ? interval[1]:180))
        nextPhrase=now+Double.random(in:low...high)
    }
    func syncActivity(force:Bool=false) {
        guard settingsReady,art != nil else{return}
        let visible=petVisible && !panel.isMiniaturized && !NSApp.isHidden && !sleeping && (selfTest || (panel.isVisible && (toy.isEngaged(now) || now<previewVisibilityUntil || panel.occlusionState.contains(.visible))))
        guard force || visible != active else{return}
        active=visible;animationTimer?.invalidate();animationTimer=nil
        #if CAT_PERF_PREVIEW
        performancePreview?.activityChanged()
        #endif
        growthController?.completionFeedback.cancel()
        playMood.cancel()
        touch?.cancelContact()
        if !force && canKeepRestingToy {
            // Ordinary occlusion is not an explicit hide/rest. Preserve the
            // original inactivity deadline, but never replay an expired fade.
            _=toy.frame(now,reduced:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,canBat:false)
            if !toy.isOut {toy.finish(now,immediate:true)}
        } else {toy.finish(now,immediate:true)}
        if trackingMenu == nil {status?.menu=makeMenu()}
        stopPointerTracking()
        motion.resume(now);phrase="";phraseUntil=0;nextPhrase = .infinity
        dismissPetSpeech()
        if visible {
            schedulePhrase();startPointerTimer()
            let interval=paused || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.05:1.0/30
            if !paused {
                animationTimer=Timer.scheduledTimer(withTimeInterval:interval,repeats:true){[weak self] _ in self?.tick()}
                animationTimer?.tolerance=interval*0.15
            }
        }else{revealControls(false,animated:false)}
        tick()
    }
    func tick() {
        guard art != nil else{return}
        growthController?.accessory.advance(to:now,enabled:active && !paused && petVisible && !sleeping && !NSApp.isHidden && letterController?.window?.isVisible != true,reduced:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)

        if !active && art.bedCacheEnabled {art.bedCacheEnabled=false}
        if !active && canKeepRestingToy {return}
        if previewVisibilityUntil>0 && now>=previewVisibilityUntil {
            previewVisibilityUntil=0;syncActivity()
        }
        if active && !paused && voiceEnabled && now>=nextPhrase {
            let lines=copy["study"] as? [String] ?? ["嗯，我还在这里。"]
            let options=lines.indices.filter{lines.count==1 || $0 != lastPhrase}
            lastPhrase=options.randomElement()!;phrase=lines[lastPhrase]
            phraseUntil=now+max(2,min(30,copy["displaySeconds"] as? Double ?? 9));schedulePhrase();nextPhrase += max(0,phraseUntil-now)
        }
        let time=now,reduced=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let wasOut=toy.isOut,wasPresent=toy.isPresent
        if paused || !active {toy.finish(time,immediate:true)}
        var value=motion.frame(time,reduced:reduced,paused:paused || !active,engaged:toy.isEngaged(time))
        let canBat=motion.canPlayWithToy(time) && !art.useV1Rendering
        art.toyFrame=toy.frame(time,reduced:reduced,canBat:canBat)
        art.toyGuide=toy.guide
        if !toy.isOut || !canBat || reduced {playMood.cancel()}
        if let result=toy.completedResponse(at:time) {
            let outcome:CatPlayMood.Outcome=result.zone == .watch ? .watch:(result.zone == .pull ? .pull:.push)
            playMood.resolve(id:result.id,outcome:outcome,at:time,
                allowed:active && !paused && !reduced && canBat && petVisible && !sleeping && !NSApp.isHidden && !panel.isMiniaturized &&
                    !touch.hasContact && trackingMenu == nil && letterController?.window?.isVisible != true &&
                    time>=petPhraseUntil && motion.demoLabel(time) == nil && growthController?.completionFeedback.isPresenting(at:time) != true)
        }
        #if !CAT_PERF_PREVIEW
        let cacheBed=active && !paused && !reduced && (toy.isEngaged(time) || touch.playing || touch.region == .head || touch.region == .back || time<motion.petEnd)
        if art.bedCacheEnabled != cacheBed {art.bedCacheEnabled=cacheBed}
        #endif
        if canBat && !reduced {
            let look=art.toyFrame.look
            let side=max(-1,min(1,look*3))
            value.leftEar=max(value.leftEar,art.toyFrame.attention*(0.675-0.425*side))
            value.rightEar=max(value.rightEar,art.toyFrame.attention*(0.675+0.425*side))
            value.lookX=look
        }
        #if CAT_PAW_EXPERIMENT
        if art.toyFrame.paw>0 {
            value.paw=PawPose(raise:art.toyFrame.paw,toyElbow:art.toyFrame.pawElbow,toyWrist:art.toyFrame.pawWrist,toySide:art.toyFrame.pawSide)
        }
        #endif
        if trackingMenu == nil && (wasOut != toy.isOut || wasPresent != toy.isPresent) {status?.menu=makeMenu()}
        if wasPresent && !toy.isEngaged(time) {syncActivity();if !active {return}}
        if art.useV1Rendering && active && !paused && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            value.breath=(1-cos(now/4.4 * .pi*2))/2
        }
        art.update(value)
        let petText=active && time<petPhraseUntil && !petPhrase.isEmpty ? petPhrase:nil
        let baseText=motion.demoLabel(now) ?? (paused ? (copy["paused"] as? String ?? "我先歇一会儿。") : petText ?? playMood.text(at:time) ?? (voiceEnabled && now<phraseUntil ? phrase:""))
        art.text=completionText(baseText,at:time)
        #if CAT_PERF_PREVIEW
        performancePreview?.didTick(at:time)
        #endif
    }
    func completionText(_ baseText: String, at time: Double) -> String {
        guard let growthController else { return baseText }
        let available = active && !paused && petVisible && !sleeping && !NSApp.isHidden && !panel.isMiniaturized && letterController?.window?.isVisible != true
        // Completion owns the bubble after release, not the animation clock.
        // The toy's attention tail can continue underneath. Ordinary speech
        // cannot delay this once-per-day feedback or queue behind it.
        let blocked = touch.hasContact || trackingMenu != nil
        if let completion=growthController.completionFeedback.text(at:time,available:available,blocked:blocked) {
            dismissPetSpeech() // No ordinary-speech backlog beneath the daily line.
            playMood.cancel()
            return completion
        }
        return baseText
    }
    private func dismissPetSpeech() {petPhraseUntil = -.infinity}
    let selfTest = CommandLine.arguments.contains("--self-test")
    private var testedGroomingPreview=false
    var resources: URL {
        if selfTest,let path=ProcessInfo.processInfo.environment["CAT_TEST_RESOURCES"] {return URL(fileURLWithPath:path)}
        return Bundle.main.resourceURL!
    }
    var copyURL: URL {
        if selfTest {
            return URL(fileURLWithPath:ProcessInfo.processInfo.environment["CAT_TEST_COPY_FILE"] ?? "/tmp/cat-unused-selftest.json")
        }
        return FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("local.catcompanion.opensource/猫咪文案.json")
    }
    func ensureCopy() throws {
        guard !selfTest,!isPlayPreview,!FileManager.default.fileExists(atPath:copyURL.path) else{return}
        let adjacent=Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("猫咪文案.json")
        let origin=FileManager.default.fileExists(atPath:adjacent.path) ? adjacent:resources.appendingPathComponent("cat-copy.json")
        let data=try validatedCopy(origin).data
        try FileManager.default.createDirectory(at:copyURL.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:copyURL,options:.atomic)
    }
    func validatedCopy(_ url:URL)throws->(data:Data,value:[String:Any]) {
        let handle=try FileHandle(forReadingFrom:url);defer {try? handle.close()}
        let data=try handle.read(upToCount:256_000) ?? Data()
        guard data.count<256_000,let value=try JSONSerialization.jsonObject(with:data) as? [String:Any] else{throw NSError(domain:"CatCopy",code:1)}
        for key in ["study","pet"] {
            guard let lines=value[key] as? [String],!lines.isEmpty,lines.count<=1000,
                  lines.allSatisfy({!$0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && $0.count<=24 && !$0.contains("\n") && !$0.contains("\r")}) else{throw NSError(domain:"CatCopy",code:2)}
        }
        for key in ["paused","idle"] {if let v=value[key], !(v is String) || (v as? String ?? "").count>24 || (v as? String ?? "").contains("\n") || (v as? String ?? "").contains("\r") {throw NSError(domain:"CatCopy",code:3)}}
        if let v=value["intervalSeconds"] {guard let range=v as? [Double],range.count==2,range.allSatisfy({$0.isFinite}),range[0]>=30,range[1]>=range[0],range[1]<=3600 else{throw NSError(domain:"CatCopy",code:4)}}
        if let v=value["displaySeconds"] {guard let seconds=v as? Double,seconds.isFinite,seconds>=2,seconds<=30 else{throw NSError(domain:"CatCopy",code:5)}}
        return (data,value)
    }
    func showError(_ message:String) {
        guard !selfTest else{return}
        let alert=NSAlert();alert.messageText=message;alert.informativeText="原文件不会被覆盖，小猫将暂用内置文案。";alert.runModal()
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !selfTest, let identifier=Bundle.main.bundleIdentifier,
           let existing=NSRunningApplication.runningApplications(withBundleIdentifier:identifier).first(where:{$0.processIdentifier != ProcessInfo.processInfo.processIdentifier}) {
            existing.activate(options:[.activateAllWindows])
            NSApp.terminate(nil);return
        }
        NSApp.setActivationPolicy(.regular)
        // Use the system-resolved icon (including macOS mask/padding), not the raw ICNS bitmap.
        NSApp.applicationIconImage=NSWorkspace.shared.icon(forFile:Bundle.main.bundlePath)
        let menu=NSMenu(), appMenu=NSMenu();let root=NSMenuItem();root.submenu=appMenu;menu.addItem(root)
        appMenu.addItem(item("显示猫咪",#selector(showPet)))
        appMenu.addItem(item("成长小窝",#selector(showGrowth)))
        let quitItem=item("退出猫咪陪伴",#selector(quit));quitItem.keyEquivalent="q";appMenu.addItem(quitItem);NSApp.mainMenu=menu
        do {try ensureCopy()}catch{showError("文案初始化失败，将暂用内置文案")}
        _ = readCopy(report:true)
        do {art=try NativeCatView(resources:resources)}catch{
            let alert=NSAlert();alert.messageText="小猫素材缺失或损坏";alert.informativeText="请重新获取完整安装包。";if !selfTest {alert.runModal()};NSApp.terminate(nil);return
        }
        art.onPet={ [weak self] in self?.pet() }
        art.onToyKey={ [weak self] code in self?.toyKey(code) ?? false }
        art.needsTextReceipt={ [weak self] text in self?.growthController?.completionFeedback.awaitsRender(text) ?? false }
        art.onTextRendered={ [weak self] text in
            guard let self else { return }
            self.growthController?.didRenderCompletion(text, at: self.now)
        }
        panel = PetPanel(contentRect:NSRect(x:120,y:100,width:300,height:274),styleMask:[.borderless,.miniaturizable],backing:.buffered,defer:false)
        panel.title = "猫咪陪伴"
        panel.delegate = self
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .normal; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.fullScreenNone]
        panel.isReleasedWhenClosed = false
        let container = NSView(frame:NSRect(x:0,y:0,width:300,height:274))
        art.frame = container.bounds; art.autoresizingMask = [.width,.height];container.addSubview(art)
        touch = PetTouchView(frame:container.bounds);touch.owner=self;touch.autoresizingMask=[.width,.height];container.addSubview(touch)
        panel.contentView=container
        setupControls(in:container)
        let growth = CatGrowthController(owner: self, store: growthStore); growthController = growth
        growth.accessory.frame = container.bounds; growth.accessory.autoresizingMask = [.width, .height]
        container.addSubview(growth.accessory, positioned: .above, relativeTo: art)
        #if CAT_ACCESSORY_PREVIEW
        growth.prepareAccessoryDemo()
        #endif
        status=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        status.button?.title="猫"
        status.menu=makeMenu()
        if let screen=NSScreen.main {panel.setFrameOrigin(NSPoint(x:screen.visibleFrame.maxX-330,y:screen.visibleFrame.minY+25))}
        if !selfTest && !isPlayPreview {
            paused=preferences.bool(forKey:"paused")
            floating=preferences.bool(forKey:"floating")
            #if CAT_PAW_EXPERIMENT
            motion.setAutomaticGrooming(autoGrooming,at:now)
            #endif
            if let value=preferences.string(forKey:"frame") {
                let saved=NSRectFromString(value)
                if saved.width.isFinite && saved.width>=200 && saved.width<=440 && saved.origin.x.isFinite && saved.origin.y.isFinite { panel.setFrame(NSRect(origin:saved.origin,size:NSSize(width:saved.width,height:saved.width*1085/1525+60)),display:false) }
            }
            panel.level=floating ? .floating : .normal;updatePin();keepOnScreen();refreshMenu()
        }
        settingsReady=true
        if isPlayPreview {
            panel.title="原版爪形玩球预览 · 未安装（290pt）"
            panel.setContentSize(NSSize(width:290,height:290*1085/1525+60));panel.center()
            status.button?.title="猫·预览"
        }
        #if CAT_PERF_PREVIEW
        performancePreview=CatPerformancePreview(owner:self)
        panel.title="流畅度对照预览 · 未安装（290pt）"
        status.button?.title="猫·流畅度预览"
        if let screen=NSScreen.screens.first {panel.setFrameOrigin(NSPoint(x:screen.visibleFrame.minX+60,y:screen.visibleFrame.midY-100))}
        #endif
        #if CAT_TOUCH_PREVIEW
        panel.title="抚摸回应预览 · 未安装（290pt）"
        status.button?.title="猫·抚摸预览"
        if let screen=NSScreen.screens.first {panel.setFrameOrigin(NSPoint(x:screen.visibleFrame.minX+60,y:screen.visibleFrame.midY-100))}
        #endif
        #if CAT_STEADY_HEAD_PREVIEW
        panel.title="摸头稳身预览 · 未安装（290pt）"
        status.button?.title="猫·稳身预览"
        #endif
        #if CAT_ACCESSORY_PREVIEW
        panel.title="花鱼同摆预览 · 未安装（290pt）"
        status.button?.title="猫·小物预览"
        panel.setContentSize(NSSize(width:290,height:290*1085/1525+60))
        if let screen=NSScreen.screens.first {panel.setFrameOrigin(NSPoint(x:screen.visibleFrame.minX+60,y:screen.visibleFrame.midY-100))}
        #endif
        NotificationCenter.default.addObserver(self,selector:#selector(screenChanged),name:NSApplication.didChangeScreenParametersNotification,object:nil)
        let workspace=NSWorkspace.shared.notificationCenter
        workspace.addObserver(self,selector:#selector(willSleep),name:NSWorkspace.willSleepNotification,object:nil)
        workspace.addObserver(self,selector:#selector(didWake),name:NSWorkspace.didWakeNotification,object:nil)
        workspace.addObserver(self,selector:#selector(accessibilityChanged),name:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil)
        panel.orderFrontRegardless();syncActivity(force:true)
        #if CAT_GROWTH_PREVIEW
        panel.title = "小猫成长预览 · 未安装（290pt）"
        status.button?.title = "猫·成长预览"
        // Present once for this explicitly requested demo; never on interaction or unlock.
        #if !CAT_LEVEL_PREVIEW
        if !selfTest { growthController?.present() }
        #endif
        #endif
        #if CAT_LEVEL_PREVIEW
        panel.title = "等级与完成短句预览 · 未安装（290pt）"
        status.button?.title = "猫·等级预览"
        #endif
        #if CAT_COMPLETION_PREVIEW
        panel.title = "摸猫短句预览 · 未安装（290pt）"
        status.button?.title = "猫·短句预览"
        if let screen = NSScreen.screens.first {
            panel.setFrameOrigin(NSPoint(x:screen.visibleFrame.minX+60,y:screen.visibleFrame.midY-100))
        }
        #endif
        #if CAT_ROLL_IN_PREVIEW
        panel.title="小球滚近预览 · 未安装（290pt）"
        status.button?.title="猫·滚近预览"
        if let screen=NSScreen.screens.first {
            panel.setFrameOrigin(NSPoint(x:screen.visibleFrame.minX+60,y:screen.visibleFrame.midY-100))
        }
        #endif
        if selfTest {
            if ProcessInfo.processInfo.environment["CAT_TEST_INTERACTIVE"] == "1" {
                panel.title="猫咪陪伴 · 交互验收（不保存设置）"
                panel.setContentSize(NSSize(width:290,height:290*1085/1525+60));panel.center()
                NSApp.activate(ignoringOtherApps:true);panel.makeKeyAndOrderFront(nil)
                DispatchQueue.main.asyncAfter(deadline:.now()+180){NSApp.terminate(nil)}
            } else {DispatchQueue.main.asyncAfter(deadline:.now()+0.3){self.runSelfTest()}}
        }
    }
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {
        showPet();return true
    }
    func applicationDidBecomeActive(_ notification:Notification) {
        if growthController?.window?.isVisible == true { return }
        if letterController?.window?.isVisible == true {return}
        guard panel != nil,petVisible,!panel.isMiniaturized else{return}
        panel.makeKeyAndOrderFront(nil)
    }
    @objc func showPet() {
        NSApp.activate(ignoringOtherApps:true)
        if panel.isMiniaturized { panel.deminiaturize(nil) }
        else { resumePet() }
        DispatchQueue.main.async { [weak self] in
            guard let self,!self.panel.isMiniaturized,self.petVisible else{return}
            self.panel.makeKeyAndOrderFront(nil)
        }
    }
    func suspendPet() {
        petVisible=false
        syncActivity(force:true)
        stopPointerTracking();touch.dragging=false
        revealControls(false,animated:false);refreshMenu()
    }
    func resumePet() {
        petVisible=true
        syncActivity(force:true)
        keepOnScreen();refreshMenu()
    }
    func windowWillMiniaturize(_ notification:Notification) { suspendPet() }
    func windowDidDeminiaturize(_ notification:Notification) { resumePet();panel.makeKeyAndOrderFront(nil) }
    func setupControls(in container:NSView) {
        controls=NSView(frame:.zero)
        controls.autoresizingMask=[]
        controls.wantsLayer=true;controls.layer?.cornerRadius=16
        controls.layer?.backgroundColor=NSColor(calibratedWhite:0.96,alpha:0.50).cgColor
        controls.alphaValue=0;container.addSubview(controls)
        for (index,symbol) in ["xmark","minus","pin","envelope"].enumerated() {
            let button=PetControlButton(frame:.zero)
            button.title="";button.isBordered=false;button.target=self
            button.image=NSImage(systemSymbolName:symbol,accessibilityDescription:nil)
            button.imagePosition = .imageOnly;button.imageScaling = .scaleProportionallyDown
            if index==0 { button.action=#selector(quit);button.contentTintColor=NSColor.darkGray;button.toolTip="退出猫咪陪伴" }
            else if index==1 {button.action=#selector(toggleVisible);button.contentTintColor=NSColor.darkGray;button.toolTip="收起猫咪（点 Dock 图标可找回）"}
            else if index==2 {button.action=#selector(toggleFloat);pinButton=button}
            else {
                button.action=#selector(toggleLetter)
                button.contentTintColor=NSColor.darkGray;button.toolTip="给你的一封信"
            }
            button.setAccessibilityLabel(button.toolTip ?? "置顶当前桌面")
            controls.addSubview(button)
        }
        layoutControls()
        updatePin()
        lastHover=Date().addingTimeInterval(2)
    }
    func layoutControls() {
        guard let controls,let container=controls.superview else {return}
        let scale=container.bounds.width/300
        controls.frame=NSRect(x:0,y:container.bounds.height-60-12*scale,width:116*scale,height:28*scale)
        controls.layer?.cornerRadius=14*scale
        let accessible=NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        controls.layer?.backgroundColor=NSColor(calibratedWhite:0.96,alpha:accessible ? 1:0.50).cgColor
        if controlsShown {controls.alphaValue=accessible ? 1:0.72}
        for (index,view) in controls.subviews.enumerated() {
            guard let button=view as? NSButton else {continue}
            // Keep the existing hit area, but optically balance the wide envelope
            // against the narrow pin instead of assigning every glyph 18 points.
            button.frame=NSRect(x:(4+CGFloat(index)*28)*scale,y:2*scale,width:24*scale,height:24*scale)
            button.symbolConfiguration=NSImage.SymbolConfiguration(pointSize:(index==2 ? 16:14)*scale,weight:.regular)
        }
    }
    func updatePin() {
        guard pinButton != nil else{return}
        pinButton.image=NSImage(systemSymbolName:floating ? "pin.fill" : "pin",accessibilityDescription:nil)
        pinButton.contentTintColor=NSColor.darkGray
        pinButton.toolTip=floating ? "取消置顶" : "置顶当前桌面（不跨桌面）"
        pinButton.setAccessibilityLabel(pinButton.toolTip!)
    }
    func revealControls(_ visible:Bool,animated:Bool=true) {
        guard controlsShown != visible else{return}
        controlsShown=visible
        NSAnimationContext.runAnimationGroup { context in
            context.duration=animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.18 : 0
            controls.animator().alphaValue=visible ? (NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 1:0.72) : 0
        }
    }
    func stopPointerTracking() {
        pointerMonitors.forEach { NSEvent.removeMonitor($0) };pointerMonitors=[]
        hoverFade?.cancel();hoverFade=nil
    }
    func startPointerTimer() {
        stopPointerTracking();panel.acceptsMouseMovedEvents=true
        let events:NSEvent.EventTypeMask=[.mouseMoved,.leftMouseDragged,.rightMouseDragged]
        if let monitor=NSEvent.addLocalMonitorForEvents(matching:events,handler:{[weak self] event in self?.updateHitRegion();return event}) {pointerMonitors.append(monitor)}
        if let monitor=NSEvent.addGlobalMonitorForEvents(matching:events,handler:{[weak self] _ in self?.updateHitRegion()}) {pointerMonitors.append(monitor)}
        updateHitRegion()
    }
    @objc func toggleVisible() {
        if petVisible && !panel.isMiniaturized {
            NSApp.activate(ignoringOtherApps:true)
            panel.makeKeyAndOrderFront(nil)
            panel.miniaturize(nil)
        }
        else { showPet() }
    }
    func readCopy(report:Bool)->Bool {
        do {
            let url=FileManager.default.fileExists(atPath:copyURL.path) ? copyURL:resources.appendingPathComponent("cat-copy.json")
            copy=try validatedCopy(url).value;return true
        }catch{
            if copy.isEmpty {copy=(try? validatedCopy(resources.appendingPathComponent("cat-copy.json")).value) ?? ["study":["嗯，我还在这里。"],"pet":["嗯，再摸一下。"]]}
            if report {showError("文案格式有误：每句限24字，间隔30—3600秒")};return false
        }
    }
    func updateHitRegion() {
        if touch.hasContact && NSEvent.pressedMouseButtons != 0 {return}
        let point=NSEvent.mouseLocation
        let local=NSPoint(x:point.x-panel.frame.minX,y:point.y-panel.frame.minY)
        let toolbar = controls.frame.insetBy(dx:-2,dy:-3).contains(local)
        let artPoint=art.convert(local,from:nil)
        let opaque=art.containsCat(artPoint) || (toy.isOut && art.containsToy(artPoint))
        let nearPet = opaque || toolbar || growthController?.accessory.containsInteraction(artPoint) == true
        hoverFade?.cancel();hoverFade=nil
        if nearPet { lastHover=Date();revealControls(true) }
        else {
            let item=DispatchWorkItem { [weak self] in self?.revealControls(false) }
            hoverFade=item;DispatchQueue.main.asyncAfter(deadline:.now()+0.65,execute:item)
        }
        panel.ignoresMouseEvents = !nearPet
    }

    func keepOnScreen() {
        guard let screen=NSScreen.screens.max(by:{a,b in a.visibleFrame.intersection(panel.frame).width*a.visibleFrame.intersection(panel.frame).height < b.visibleFrame.intersection(panel.frame).width*b.visibleFrame.intersection(panel.frame).height}) else{return}
        let bounds=screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x:min(max(panel.frame.minX,bounds.minX),max(bounds.minX,bounds.maxX-panel.frame.width)),y:min(max(panel.frame.minY,bounds.minY),max(bounds.minY,bounds.maxY-panel.frame.height))))
    }
    func item(_ title:String,_ selector:Selector,_ state:Bool?=nil)->NSMenuItem {
        let item=NSMenuItem(title:title,action:selector,keyEquivalent:"");item.target=self;if let state {item.state=state ? .on : .off};return item
    }
    func makeMenu()->NSMenu {
        let menu=NSMenu();menu.autoenablesItems=false;menu.delegate=self
        func group(_ title:String,_ children:[NSMenuItem])->NSMenuItem {
            let submenu=NSMenu(title:title);submenu.autoenablesItems=false
            children.forEach{submenu.addItem($0)}
            let parent=NSMenuItem(title:title,action:nil,keyEquivalent:"");parent.submenu=submenu
            return parent
        }
        let canPreview=petVisible && !paused && !toy.isPresent && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        menu.addItem(item(paused ? "继续陪伴" : "休息一下",#selector(togglePause)))
        let play=item(toy.isOut ? "收起小绒球":"拿出小绒球",#selector(toggleToy))
        play.isEnabled=petVisible && !paused && !(art?.useV1Rendering ?? false) && (toy.isOut || motion.canTakeOutToy(now))
        menu.addItem(play)
        menu.addItem(item("成长小窝",#selector(showGrowth)))
        menu.addItem(item("窗口置顶",#selector(toggleFloat),floating))
        menu.addItem(.separator())
        let settings=[item("小一点",#selector(smaller)),item("大一点",#selector(larger)),item("回到屏幕角落",#selector(resetPosition))]
        var previews=[item("连续演示（12 秒）",#selector(previewNewMoves)),item("露舌尖",#selector(previewTongue)),item("舔鼻子",#selector(previewNoseLick))]
        previews.forEach{$0.isEnabled=canPreview}
        #if CAT_PAW_EXPERIMENT
        let groom=item("舔爪子",#selector(previewPawLick))
        groom.isEnabled=art?.pawArt != nil && canPreview;previews.append(groom)
        #endif
        // Keep legacy rendering available to regression tests, not recipient menus.
        menu.addItem(group("设置",settings));menu.addItem(group("动作预览",previews))
        menu.addItem(item("给你的一封信",#selector(showLetter)))
        #if CAT_PERF_PREVIEW
        if let performancePreview {menu.addItem(performancePreview.menuItem())}
        #endif
        menu.addItem(.separator())
        menu.addItem(item(petVisible ? "收起桌面猫" : "显示桌面猫",#selector(toggleVisible)))
        menu.addItem(item("退出猫咪陪伴",#selector(quit)))
        return menu
    }
    func menuNeedsUpdate(_ menu:NSMenu) {
        updateMenuState(menu)
    }
    private func updateMenuState(_ menu:NSMenu) {
        // Preserve the live menu's item identity, highlight and submenu stack.
        let fresh=makeMenu()
        func copyState(_ target:NSMenu,_ source:NSMenu) {
            for (item,state) in zip(target.items,source.items) {
                if item.title != state.title {item.title=state.title}
                if item.isEnabled != state.isEnabled {item.isEnabled=state.isEnabled}
                if item.state != state.state {item.state=state.state}
                if let a=item.submenu,let b=state.submenu {copyState(a,b)}
            }
        }
        copyState(menu,fresh)
    }
    func menuWillOpen(_ menu:NSMenu) {
        menuTrackingTimer?.invalidate();trackingMenu=menu
        // The normal animation timer runs in default mode. While AppKit tracks
        // this menu, advance the same animation at the same cadence, not a new one.
        let interval=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.05:1.0/30
        let timer=Timer(timeInterval:interval,repeats:true){[weak self,weak menu] _ in
            guard let self,let menu else{return}
            if self.active && !self.paused {self.tick()}
            self.updateMenuState(menu)
        }
        menuTrackingTimer=timer
        RunLoop.main.add(timer,forMode:.eventTracking)
    }
    func menuDidClose(_ menu:NSMenu) {
        guard trackingMenu === menu else{return}
        menuTrackingTimer?.invalidate();menuTrackingTimer=nil;trackingMenu=nil
        status?.menu=makeMenu()
    }
    func refreshMenu(){status?.menu=makeMenu();saveSettings()}
    @objc func showLetter() {
        growthController?.completionFeedback.cancel()
        playMood.cancel()
        dismissPetSpeech()
        if letterController == nil {
            letterController=CatLetterController(text:CatLetter.text(at:resources.appendingPathComponent("letter.txt")),
                stationeryURL:resources.appendingPathComponent("assets/letter-stationery-v1.png"))
        }
        letterController?.present()
    }
    @objc func toggleLetter() {
        if let window=letterController?.window,window.isVisible {window.performClose(nil)}
        else {showLetter()}
    }
    @objc func pet(){
        guard active,!paused else{return}
        growthController?.record(.pet)
        parkToy()
        let time=now
        if growthController?.completionFeedback.isPresenting(at:time) != true {
            // Speech has its own fixed lifetime: neither body contact nor motion
            // renewal can clear, extend, or block the next head response.
            if time>=petPhraseUntil || petPhrase.isEmpty {
                let base=copy["pet"] as? [String] ?? ["嗯，再摸一下。"]
                let level=CatLevelProgress(points:growthController?.growth.points ?? 0).level
                let lines=CatPetLines.candidates(base:base,level:level)
                lastPet=lines.indices.filter{lines.count==1 || $0 != lastPet}.randomElement()!;petPhrase=lines[lastPet]
                petPhraseUntil=time+1.9
            }
        }
        motion.pet(now);tick()
    }
    func touchBack() {
        guard active,!paused else{return}
        growthController?.record(.pet)
        parkToy()
        // Body contact is nonverbal, but does not cut off a recent head line.
        motion.touchBack(now);tick()
    }
    func stroke(_ region:CatTouchRegion) {
        guard active,!paused else{return}
        parkToy()
        motion.stroke(region,at:now);tick()
    }
    @objc func togglePause(){paused.toggle();syncActivity(force:true);refreshMenu()}
    @objc func toggleToy() {
        guard petVisible,!paused,art != nil,!art.useV1Rendering else{return}
        if toy.isOut {finishToy();tick();return}
        guard motion.canTakeOutToy(now) else{return}
        // No delayed start: hide/rest cannot leave a callback that resurrects play.
        NSApp.activate(ignoringOtherApps:true);panel.makeKeyAndOrderFront(nil)
        previewVisibilityUntil=now+0.5;syncActivity()
        guard active else{return}
        toy.start(now)
        playMood.beginSession()
        if now>=petPhraseUntil {dismissPetSpeech()}
        panel.makeFirstResponder(art);tick();status?.menu=makeMenu()
    }
    func finishToy() {
        playMood.cancel()
        guard toy.isOut else{return}
        toy.finish(now,immediate:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        if touch?.playing == true {touch.cancelContact()}
        status?.menu=makeMenu()
    }
    func parkToy() {
        playMood.cancel()
        toy.park(now,reduced:NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        if touch?.playing == true {touch.cancelContact()}
    }
    var canKeepRestingToy:Bool {
        panel != nil && petVisible && !panel.isMiniaturized && !NSApp.isHidden && !sleeping && !paused && toy.isOut && !toy.isEngaged(now)
    }
    func beginToyContact() {
        guard active,!paused,toy.isOut else{return}
        toy.grab(now)
        growthController?.beginDrag(art.toyFrame.position)
        playMood.react(at:now,sample:Int.random(in:0..<6),
                       allowed:motion.canPlayWithToy(now) && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion &&
                           letterController?.window?.isVisible != true && growthController?.completionFeedback.isPresenting(at:now) != true)
    }
    func moveToy(_ point:CGPoint) {
        guard active,!paused,art.bounds.width>0 else{return}
        let time=now,reduced=NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        toy.move(to:CGPoint(x:point.x/art.bounds.width,y:(point.y-60)/art.bounds.width),at:time)
        // Pointer input moves the ball immediately. Cat pose/render invalidation
        // stays on its existing 30Hz clock instead of repeating per mouse event.
        art.toyFrame=toy.frame(time,reduced:reduced,canBat:motion.canPlayWithToy(time) && !art.useV1Rendering)
        art.toyGuide=toy.guide
        growthController?.moveDrag(art.toyFrame.position)
    }
    func toyKey(_ code:UInt16)->Bool {
        guard toy.isOut else{return false}
        if code==53 {finishToy();tick();return true}
        guard [123,124,125,126,49,36].contains(code) else{return false}
        var p=art.toyFrame.position
        if code==123 {p.x -= 0.025};if code==124 {p.x += 0.025}
        if code==125 {p.y += 0.01};if code==126 {p.y -= 0.01}
        if code==49 || code==36 {p=CGPoint(x:0.62,y:0.395)}
        beginToyContact();toy.move(to:p,at:now);toy.release(now);tick()
        if active, !paused {
            // Each existing keyboard play command is intentional input, including
            // the small vertical nudge. Pointer drags still require actual travel.
            growthController?.cancelDrag()
            growthController?.record(.play)
        }
        return true
    }
    @objc func toggleV1(){
        toy.finish(now,immediate:true);touch?.cancelContact()
        art.useV1Rendering.toggle()
        #if CAT_PAW_EXPERIMENT
        motion.setAutomaticGrooming(autoGrooming && !art.useV1Rendering,at:now);motion.resume(now)
        #endif
        tick();refreshMenu()
    }
    #if CAT_PAW_EXPERIMENT
    @objc func previewPawLick(){
        guard art.pawArt != nil else{return}
        runMouthPreview { $0.motion.begin(.pawLick,at:$0.now) }
    }
    #endif
    func previewMouth(_ kind:CatGesture) {
        runMouthPreview { $0.motion.begin(kind,at:$0.now) }
    }
    @objc func previewTongue(){previewMouth(.tongueTip)}
    @objc func previewNoseLick(){previewMouth(.noseLick)}
    @objc func previewNewMoves(){
        runMouthPreview { $0.motion.startDemo($0.now) }
    }
    func runMouthPreview(_ start:@escaping (PetApp)->Void) {
        guard petVisible,!paused,!toy.isPresent,!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else{return}
        NSApp.activate(ignoringOtherApps:true)
        panel.makeKeyAndOrderFront(nil)
        // A context menu can occlude the entire small pet window. Wait for it to
        // close before checking visibility, otherwise an explicit preview is dropped.
        DispatchQueue.main.asyncAfter(deadline:.now()+0.2) { [weak self] in
            guard let self,!self.paused,!self.toy.isPresent,!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else{return}
            // Bound explicit playback independently of transient menu occlusion.
            // Hidden/minimized/sleeping states still suspend the pet normally.
            self.previewVisibilityUntil=self.now+13
            self.syncActivity()
            guard self.active else{return}
            self.art.useV1Rendering=false
            #if CAT_PAW_EXPERIMENT
            self.motion.setAutomaticGrooming(self.autoGrooming,at:self.now)
            #endif
            start(self);self.tick();self.refreshMenu()
        }
    }
    @objc func toggleFloat(){floating.toggle();panel.level=floating ? .floating : .normal;updatePin();refreshMenu()}
    func resize(_ delta:CGFloat){let width=min(440,max(200,panel.frame.width+delta));panel.setContentSize(NSSize(width:width,height:width*1085/1525+60));keepOnScreen()}
    @objc func smaller(){resize(-30)}
    @objc func larger(){resize(30)}
    @objc func resetPosition(){if let s=NSScreen.main{panel.setFrameOrigin(NSPoint(x:s.visibleFrame.maxX-panel.frame.width-24,y:s.visibleFrame.minY+24))};if petVisible {panel.orderFrontRegardless()}}
    @objc func reloadCopy(){if readCopy(report:true){lastPhrase = -1;lastPet = -1;syncActivity(force:true)}}
    @objc func importCopy(){
        let picker=NSOpenPanel();picker.allowedContentTypes=[.json];picker.allowsMultipleSelection=false
        guard picker.runModal() == .OK,let url=picker.url else{return}
        do {let result=try validatedCopy(url)
            if let data=try? Data(contentsOf:copyURL){try data.write(to:copyURL.appendingPathExtension("backup"),options:.atomic)}
            try result.data.write(to:copyURL,options:.atomic);copy=result.value;lastPhrase = -1;lastPet = -1;syncActivity(force:true)
        }catch{showError("无法导入文案，请检查内容格式")}
    }
    @objc func exportCopy(){
        let picker=NSSavePanel();picker.allowedContentTypes=[.json];picker.nameFieldStringValue="猫咪文案.json"
        guard picker.runModal() == .OK,let url=picker.url else{return}
        do {try JSONSerialization.data(withJSONObject:copy,options:[.prettyPrinted,.sortedKeys]).write(to:url,options:.atomic)}catch{showError("无法导出文案")}
    }
    @objc func quit(){growthController?.flushCompletionReceipt();NSApp.terminate(nil)}
    func applicationWillTerminate(_ notification:Notification){growthController?.flushCompletionReceipt();stopPointerTracking();animationTimer?.invalidate();saveSettings()}
    func waitFor(_ condition:@escaping()->Bool, label:String, attempts:Int=100, then:@escaping()->Void) {
        if condition(){then();return}
        guard attempts>0 else{
            fputs("FAIL native transition \(label): hidden=\(NSApp.isHidden) appActive=\(NSApp.isActive) active=\(active) mini=\(panel.isMiniaturized) key=\(panel.isKeyWindow) visible=\(panel.isVisible)\n",stderr)
            exit(1)
        }
        DispatchQueue.main.asyncAfter(deadline:.now()+0.05){self.waitFor(condition,label:label,attempts:attempts-1,then:then)}
    }
    func runSelfTest(){
        #if CAT_PAW_EXPERIMENT
        if ProcessInfo.processInfo.environment["CAT_TEST_GROOMING_LIVE"] == "1" && !testedGroomingPreview {
            testedGroomingPreview=true
            // Verify the real menu callback and timer pipeline, not a directly injected pose.
            status.menu=nil;accessibilityChanged()
            func groomingItem(in menu:NSMenu?)->NSMenuItem? {
                for item in menu?.items ?? [] {
                    if item.action == #selector(previewPawLick) {return item}
                    if let found=groomingItem(in:item.submenu) {return found}
                }
                return nil
            }
            guard let groom=groomingItem(in:status.menu),groom.isEnabled,
                  NSApp.sendAction(groom.action!,to:groom.target,from:groom) else {
                fputs("FAIL accessibility change must refresh grooming menu\n",stderr);exit(1)
            }
            waitFor({self.art.pose.paw.raise>0.98 && self.art.pose.mouth.extensionAmount>0.9},label:"live grooming menu callback") {
                guard self.art.pose.eyes==0 else{exit(1)}
                if let path=ProcessInfo.processInfo.environment["CAT_LIVE_GROOM_SNAPSHOT"],let bitmap=self.art.bitmapImageRepForCachingDisplay(in:self.art.bounds) {
                    self.art.cacheDisplay(in:self.art.bounds,to:bitmap)
                    try? bitmap.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:path))
                }
                print("PASS live menu callback -> timer -> visible paw and tongue, original eyes")
                self.pet()
                self.waitFor({self.art.pose.eyes>0.9},label:"live pet priority") {
                    self.waitFor({self.now>self.motion.petEnd-1.2 && self.art.pose.paw.raise==0 && self.art.pose.eyes==0},label:"live grooming retraction") {
                        print("PASS live pet feedback and paw retraction")
                        self.runSelfTest()
                    }
                }
            }
            return
        }
        #endif
        let originalSize=panel.frame.size
        for width:CGFloat in [200,300,440] {
            panel.setContentSize(NSSize(width:width,height:width*1085/1525+60))
            guard abs(controls.frame.width-116*width/300)<0.1,
                  art.containsCat(CGPoint(x:width/2,y:60+width*0.4)),
                  !art.containsCat(CGPoint(x:0,y:61)) else{fputs("FAIL layout/hit testing\n",stderr);exit(1)}
        }
        panel.setContentSize(originalSize)
        var test=CatMotion();test.pet(100)
        guard test.frame(100.120,reduced:false,paused:false).eyes>0.9,test.frame(100.700,reduced:false,paused:false).eyes<0.001 else{exit(1)}
        let scratch=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".json")
        defer {try? FileManager.default.removeItem(at:scratch)}
        do {
            try Data("{\"study\":[\"正常\"],\"pet\":[\"正常\"]}".utf8).write(to:scratch)
            _ = try validatedCopy(scratch)
            try Data(repeating:32,count:256_001).write(to:scratch)
            do {_ = try validatedCopy(scratch);exit(1)}catch{}
            try JSONSerialization.data(withJSONObject:["study":[String(repeating:"猫",count:25)],"pet":["好"]]).write(to:scratch)
            do {_ = try validatedCopy(scratch);exit(1)}catch{}
        }catch{exit(1)}
        print("PASS bounded copy loading rejects oversized files and overlong text")
        toy.start(now);tick()
        willSleep()
        guard !active,animationTimer == nil,pointerMonitors.isEmpty,!toy.isPresent else {exit(1)}
        didWake()
        guard active,animationTimer != nil,!toy.isPresent else {exit(1)}
        toy.start(now);tick();accessibilityChanged()
        guard !toy.isPresent,art.toyFrame.opacity==0 else{exit(1)}
        toy.start(now);tick();togglePause()
        guard paused,!toy.isPresent,art.toyFrame.opacity==0 else{exit(1)}
        togglePause()
        guard !paused,!toy.isPresent else{exit(1)}
        print("PASS toy lifecycle: sleep/wake, accessibility changes and rest/resume never replay play")
        let oldOrigin=panel.frame.origin
        panel.setFrameOrigin(NSPoint(x:-99999,y:-99999));keepOnScreen()
        guard NSScreen.screens.contains(where:{$0.visibleFrame.intersects(panel.frame)}) else {exit(1)}
        panel.setFrameOrigin(oldOrigin)
        print("PASS sleep/wake lifecycle and off-screen recovery")
        pet();tick()
        if ProcessInfo.processInfo.environment["CAT_TEST_CLOSED"] == "1" {art.update((eyes:1,breath:0,lean:0))}
        #if CAT_PAW_EXPERIMENT
        guard art.pawArt != nil else{fputs("FAIL packaged paw asset missing\n",stderr);exit(1)}
        if ProcessInfo.processInfo.environment["CAT_TEST_GROOMING"] == "1" {
            var grooming=CatMotion(now:0,seed:1);grooming.begin(.pawLick,at:1)
            let p=grooming.frame(2.66,reduced:false,paused:false)
            guard p.paw.raise>0.98,p.eyes==0 else{exit(1)}
            art.update(p)
        }
        #endif
        if let bitmap=art.bitmapImageRepForCachingDisplay(in:art.bounds) {
            art.cacheDisplay(in:art.bounds,to:bitmap)
            guard (bitmap.colorAt(x:0,y:0)?.alphaComponent ?? 1)<0.01 else{fputs("FAIL transparent native view\n",stderr);exit(1)}
            if let data=bitmap.representation(using:.png,properties:[:]){try? data.write(to:URL(fileURLWithPath:ProcessInfo.processInfo.environment["CAT_SNAPSHOT"] ?? "/tmp/cat-native.png"))}
        }else{exit(1)}
        pinButton.performClick(nil);guard panel.level == .floating else{exit(1)};pinButton.performClick(nil)
        NSApp.hide(nil)
        waitFor({NSApp.isHidden && !self.active && self.animationTimer == nil && self.pointerMonitors.isEmpty},label:"hide") {
            NSApp.unhide(nil);self.syncActivity(force:true)
            self.waitFor({!NSApp.isHidden && self.active},label:"unhide") {
                print("PASS native rendering, shared silhouette hits, 200/300/440 layout, 700ms eyes, transparency, pin, hide and unhide")
                guard NSApp.isActive else {
                    print("SKIP native minimize in background self-test; verify through the foreground UI")
                    NSApp.terminate(nil)
                    return
                }
                self.toggleVisible()
                self.waitFor({self.panel.isMiniaturized},label:"miniaturize") {
                    guard !self.active,self.animationTimer == nil,self.pointerMonitors.isEmpty else{fputs("FAIL suspension\n",stderr);exit(1)}
                    self.showPet()
                    self.waitFor({!self.panel.isMiniaturized && self.panel.isKeyWindow},label:"restore") {
                        guard self.active,self.panel.level == .normal else{exit(1)}
                        print("PASS native minimize and restoration")
                        NSApp.terminate(nil)
                    }
                }
            }
        }
    }
}
let app=NSApplication.shared
let delegate=PetApp()
#if CAT_MENU_TEST
runMenuTests(delegate)
#else
app.delegate=delegate
app.run()
#endif
