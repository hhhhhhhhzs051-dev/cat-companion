import AppKit

private let growthInk = NSColor(calibratedRed: 0.26, green: 0.31, blue: 0.29, alpha: 1)
private let growthMuted = NSColor(calibratedRed: 0.43, green: 0.47, blue: 0.43, alpha: 1)
let growthSage = NSColor(calibratedRed: 0.49, green: 0.65, blue: 0.56, alpha: 1)

// Accessory artwork only; cat pixels and toy geometry are never changed here.
enum CatGrowthArt {
    static func draw(_ reward: CatGrowthReward, in rect: NSRect, sway:Double=0) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState(); defer { ctx.restoreGState() }
        ctx.translateBy(x: rect.minX, y: rect.minY)
        ctx.scaleBy(x: rect.width / 40, y: rect.height / 40)
        let outline = NSColor(calibratedRed: 0.40, green: 0.47, blue: 0.41, alpha: 0.85)
        func ellipse(_ rect: NSRect, _ color: NSColor) {
            color.setFill(); let path = NSBezierPath(ovalIn: rect); path.fill()
        }
        switch reward {
        case .sageBall:
            ellipse(NSRect(x: 7, y: 8, width: 26, height: 26), growthSage)
            NSColor(calibratedRed: 0.90, green: 0.91, blue: 0.76, alpha: 1).setStroke()
            for offset in [-7.0, 0, 7] {
                let p = NSBezierPath(); p.lineWidth = 1.4
                p.move(to: NSPoint(x: 10, y: 16 + offset))
                p.curve(to: NSPoint(x: 30, y: 25 + offset), controlPoint1: NSPoint(x: 8, y: 26 + offset), controlPoint2: NSPoint(x: 28, y: 13 + offset)); p.stroke()
            }
        case .flower:
            ctx.saveGState()
            if sway != 0 {ctx.translateBy(x:20,y:28);ctx.rotate(by:sway);ctx.translateBy(x:-20,y:-28)}
            outline.setStroke()
            let stem = NSBezierPath(); stem.lineWidth = 1.5; stem.move(to: NSPoint(x: 20, y: 29)); stem.curve(to: NSPoint(x: 21, y: 13), controlPoint1: NSPoint(x: 18, y: 22), controlPoint2: NSPoint(x: 23, y: 20)); stem.stroke()
            ellipse(NSRect(x: 12, y: 20, width: 9, height: 4), growthSage)
            ellipse(NSRect(x: 21, y: 18, width: 8, height: 4), growthSage)
            let petal = NSColor(calibratedRed: 1.00, green: 0.63, blue: 0.77, alpha: 1)
            let flowerCenter = NSColor(calibratedRed: 0.99, green: 0.84, blue: 0.31, alpha: 1)
            for i in 0..<5 {
                let a = Double(i) * .pi * 2 / 5
                ellipse(NSRect(x: 17 + cos(a) * 5, y: 9 + sin(a) * 5, width: 7, height: 7), petal)
            }
            ellipse(NSRect(x: 18, y: 10, width: 5, height: 5), flowerCenter)
            ctx.restoreGState() // The pot and its shadow remain planted.
            let pot = NSBezierPath(); pot.move(to: NSPoint(x: 12, y: 27)); pot.line(to: NSPoint(x: 28, y: 27)); pot.line(to: NSPoint(x: 26, y: 37)); pot.line(to: NSPoint(x: 14, y: 37)); pot.close()
            NSColor(calibratedRed: 0.72, green: 0.55, blue: 0.43, alpha: 1).setFill(); pot.fill()
            outline.setStroke(); pot.lineWidth = 0.8; pot.stroke()
        case .fish:
            if sway != 0 {ctx.translateBy(x:20,y:2);ctx.rotate(by:sway);ctx.translateBy(x:-20,y:-2)}
            let fishInk = NSColor(calibratedRed:0.60,green:0.29,blue:0.25,alpha:1)
            let red = NSColor(calibratedRed:0.91,green:0.43,blue:0.36,alpha:1)
            let finRed = NSColor(calibratedRed:0.98,green:0.58,blue:0.44,alpha:1)
            // Keep the accepted cord and hinge; the ornament alone is a goldfish.
            NSColor(calibratedRed:0.52,green:0.31,blue:0.25,alpha:1).setStroke()
            let cord=NSBezierPath();cord.move(to:NSPoint(x:20,y:2));cord.line(to:NSPoint(x:20,y:15));cord.lineWidth=1;cord.stroke()
            func fin(_ path:NSBezierPath) {finRed.setFill();path.fill();fishInk.setStroke();path.lineWidth=0.65;path.stroke()}
            let tail=NSBezierPath();tail.move(to:NSPoint(x:16,y:23))
            tail.curve(to:NSPoint(x:4,y:13),controlPoint1:NSPoint(x:11,y:16),controlPoint2:NSPoint(x:7,y:13))
            tail.curve(to:NSPoint(x:7,y:24),controlPoint1:NSPoint(x:3,y:18),controlPoint2:NSPoint(x:5,y:22))
            tail.curve(to:NSPoint(x:4,y:34),controlPoint1:NSPoint(x:5,y:27),controlPoint2:NSPoint(x:3,y:31))
            tail.curve(to:NSPoint(x:16,y:25),controlPoint1:NSPoint(x:8,y:34),controlPoint2:NSPoint(x:12,y:30));tail.close();fin(tail)
            let dorsal=NSBezierPath();dorsal.move(to:NSPoint(x:18,y:17))
            dorsal.curve(to:NSPoint(x:18,y:11),controlPoint1:NSPoint(x:16,y:15),controlPoint2:NSPoint(x:17,y:12))
            dorsal.curve(to:NSPoint(x:27,y:16),controlPoint1:NSPoint(x:22,y:11),controlPoint2:NSPoint(x:26,y:13));dorsal.close();fin(dorsal)
            let lower=NSBezierPath();lower.move(to:NSPoint(x:21,y:29))
            lower.curve(to:NSPoint(x:18,y:34),controlPoint1:NSPoint(x:22,y:32),controlPoint2:NSPoint(x:20,y:34))
            lower.curve(to:NSPoint(x:28,y:29),controlPoint1:NSPoint(x:23,y:34),controlPoint2:NSPoint(x:27,y:32));lower.close();fin(lower)
            let body=NSBezierPath(ovalIn:NSRect(x:13.5,y:15,width:20.5,height:16.5));red.setFill();body.fill();fishInk.setStroke();body.lineWidth=0.8;body.stroke()
            let gill=NSBezierPath();gill.move(to:NSPoint(x:24,y:18.5));gill.curve(to:NSPoint(x:24,y:28.5),controlPoint1:NSPoint(x:21,y:21),controlPoint2:NSPoint(x:21.5,y:26));gill.lineWidth=0.7;gill.stroke()
            let rays=NSBezierPath();rays.move(to:NSPoint(x:13,y:22));rays.line(to:NSPoint(x:6,y:17));rays.move(to:NSPoint(x:13,y:26));rays.line(to:NSPoint(x:6,y:30));rays.lineWidth=0.5;rays.stroke()
            NSColor(calibratedRed:1,green:0.66,blue:0.48,alpha:0.8).setStroke()
            let glint=NSBezierPath();glint.move(to:NSPoint(x:17,y:20));glint.curve(to:NSPoint(x:24,y:18),controlPoint1:NSPoint(x:19,y:18),controlPoint2:NSPoint(x:21,y:17.5));glint.lineWidth=0.9;glint.stroke()
            ellipse(NSRect(x:28.5,y:20.5,width:2,height:2),NSColor(calibratedRed:0.35,green:0.15,blue:0.13,alpha:1))
        }
    }
}

final class CatGrowthAccessoryView: NSView {
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    var selections:Set<CatGrowthReward> = [] {didSet {
        guard oldValue != selections else{return}
        if !selections.contains(.flower) {flowerSway.cancel()}
        if !selections.contains(.fish) {fishSway.cancel()}
        needsDisplay=true
    }}
    private var flowerSway=CatAccessorySway(),fishSway=CatAccessorySway()
    func sway(for reward:CatGrowthReward)->CatAccessorySway {reward == .flower ? flowerSway:fishSway}
    func drawingRect(for reward:CatGrowthReward)->NSRect {
        let s=bounds.width/290
        // 34 * 1.25. Keep the original pot base at y=60+187.45*s;
        // shift inward so the larger flower and its sway stay inside the window.
        if reward == .flower {return NSRect(x:246.5*s,y:60+148.1375*s,width:42.5*s,height:42.5*s)}
        if reward == .fish {return NSRect(x:241*s,y:60+109*s,width:31*s,height:31*s)}
        return .zero
    }
    func interactionRect(for reward:CatGrowthReward)->NSRect {
        guard selections.contains(reward),reward != .sageBall else{return .zero}
        let padding=3*bounds.width/290
        return drawingRect(for:reward).insetBy(dx:-padding,dy:-padding).intersection(bounds)
    }
    func reward(at point:NSPoint)->CatGrowthReward? {
        [.flower,.fish].first {let r=interactionRect(for:$0);return !r.isEmpty && r.contains(point)}
    }
    func containsInteraction(_ point:NSPoint)->Bool {reward(at:point) != nil}
    func tap(_ reward:CatGrowthReward,at time:Double,reduced:Bool) {
        guard selections.contains(reward) else{return}
        if reward == .flower {flowerSway.tap(at:time,flower:true,reduced:reduced)}
        else if reward == .fish {fishSway.tap(at:time,flower:false,reduced:reduced)}
    }
    func cancelMotion() {
        let changed=flowerSway.angle != 0 || fishSway.angle != 0
        flowerSway.cancel();fishSway.cancel();if changed {needsDisplay=true}
    }
    func advance(to time:Double,enabled:Bool,reduced:Bool) {
        guard enabled,!reduced else {cancelMotion();return}
        guard flowerSway.isActive || fishSway.isActive else{return}
        let flowerBefore=flowerSway.angle,fishBefore=fishSway.angle
        flowerSway.advance(to:time);fishSway.advance(to:time)
        if flowerSway.angle != flowerBefore || fishSway.angle != fishBefore {needsDisplay=true}
    }

    override func draw(_ dirtyRect: NSRect) {
        let scale = bounds.width / 290
        for reward in [CatGrowthReward.fish,.flower] where selections.contains(reward) {
            if reward == .flower {
                NSColor(calibratedWhite:0.25,alpha:0.14).setFill()
                NSBezierPath(ovalIn:NSRect(x:255.25*scale,y:60+187*scale,width:25*scale,height:4*scale)).fill()
            }
            CatGrowthArt.draw(reward,in:drawingRect(for:reward),sway:sway(for:reward).angle)
        }
    }
}

private final class GrowthSurface: NSView {
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.93, alpha: 1).setFill(); bounds.fill()
    }
}
private final class GrowthWindow: NSWindow {
    override func cancelOperation(_ sender: Any?) { performClose(sender) }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "w" { performClose(nil); return true }
        return super.performKeyEquivalent(with: event)
    }
}
private final class GrowthRewardSwatch: NSView {
    let reward: CatGrowthReward
    init(_ reward: CatGrowthReward, frame: NSRect) { self.reward = reward; super.init(frame: frame) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { CatGrowthArt.draw(reward, in: bounds) }
}

final class CatGrowthController: NSObject {
    private(set) var growth = CatGrowth(date: Date())
    private(set) var drag = CatGrowthDrag()
    private(set) var dayOffset = 0
    private(set) var ballSelected = false
    private(set) var decorations = Set<CatGrowthReward>()
    weak var owner: PetApp?
    let accessory = CatGrowthAccessoryView()
    private(set) var window: NSWindow?
    private var levelLabel: NSTextField!
    private var pointsLabel: NSTextField!
    private var daysLabel: NSTextField!
    private var familiarityLabels: [NSTextField] = []
    private var milestoneLabel: NSTextField!
    private var nextMilestoneLabel: NSTextField!
    private var goalLabels: [NSTextField] = []
    private var goalDetails: [NSTextField] = []
    private var rewardButtons: [NSButton] = []
    private var rewardDetails: [NSTextField] = []
    private var dayLabel: NSTextField!
    private var saveLabel: NSTextField!
    private var bar: NSProgressIndicator!
    private var observers: [NSObjectProtocol] = []
    private let currentDate: () -> Date
    private let store: CatGrowthStore?
    private var loadFailed = false
    private(set) var storageError: String?
    var completionFeedback = CatCompletionFeedback()
    private var receiptNeedsSave = false
    func isUnlocked(_ reward: CatGrowthReward) -> Bool {
        return growth.unlocked(reward)
    }
    private var isPreview: Bool { owner?.isPlayPreview ?? false }
    var date: Date { Calendar.current.date(byAdding: .day, value: dayOffset, to: currentDate())! }
    init(owner: PetApp, store: CatGrowthStore? = nil, currentDate: @escaping () -> Date = { Date() }) {
        self.owner = owner; self.store = store; self.currentDate = currentDate
        #if CAT_ACCESSORY_PREVIEW
        precondition(owner.isPlayPreview && store == nil,"Accessory preview cannot open formal growth storage")
        #endif
        #if CAT_COMPANION_PREVIEW
        precondition(owner.isPlayPreview && store == nil,"Companion preview cannot open formal growth storage")
        #endif
        growth = CatGrowth(date: currentDate()); super.init()
        do {
            if let saved = try store?.load() {
                growth = CatGrowth(snapshot: saved); ballSelected = saved.ballSelected
                decorations = Set(saved.selectedDecorations.compactMap(CatGrowthReward.init(rawValue:)))
                completionFeedback = CatCompletionFeedback(shownDay: saved.completionShownDay ?? 0)
                applyRewards()
                // Preserve all v1 earned rewards, not only the selected accessory.
                // A migration does not record a goal or enqueue a completion line.
                if saved.version < 4 {
                    var migrated = growth.snapshot(ballSelected: ballSelected, decorations: decorations)
                    migrated.completionShownDay = saved.completionShownDay
                    try store?.save(migrated)
                }
            }
        } catch {
            loadFailed = true; storageError = "记录暂时无法读取，已保留原文件；本次未记录。"
        }
        // Event-driven date refresh, not a new polling/animation timer.
        for name in [Notification.Name.NSCalendarDayChanged, NSApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                self.refreshDay()
            })
        }
    }
    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }
    func refreshDay() {
        if CatGrowth.dayKey(date, calendar: .current) < growth.day { completionFeedback.cancel() }
        var next = growth; next.refresh(at: date)
        if next.day != growth.day {
            completionFeedback.cancel()
            _ = commit(next, ball: ballSelected, decorations: decorations)
        }
        refresh()
    }
    func record(_ goal: CatGrowthGoal) {
        guard !loadFailed else { return }
        guard CatGrowth.dayKey(date, calendar: .current) >= growth.day else { completionFeedback.cancel(); return }
        var next = growth
        let changed = next.record(goal, at: date)
        if changed || next.day != growth.day {
            guard commit(next, ball: ballSelected, decorations: decorations) else { return }
        } else {
            flushCompletionReceipt()
        }
        // Already completed goals are eligible input too, but never score twice.
        if CatGrowth.dayKey(date, calendar: .current) == growth.day, let owner {
            completionFeedback.record(completed: growth.completed, day: growth.day, companionDays: growth.companionDays,
                                      at: owner.now, sample: Int.random(in: 0..<6))
        }
        if window?.isVisible == true { refresh() }
    }
    private func commit(_ next: CatGrowth, ball: Bool, decorations nextDecorations: Set<CatGrowthReward>) -> Bool {
        guard !loadFailed else { return false }
        do {
            var snapshot = next.snapshot(ballSelected: ball, decorations: nextDecorations)
            snapshot.completionShownDay = completionFeedback.shownDay == 0 ? nil : completionFeedback.shownDay
            try store?.save(snapshot)
            growth = next; ballSelected = ball; decorations = nextDecorations
            receiptNeedsSave = false; storageError = nil; return true
        } catch {
            storageError = "暂时无法保存，原有进度已保留；稍后再试。"
            return false
        }
    }
    func didRenderCompletion(_ text: String, at time: Double) {
        guard let owner, owner.active, !owner.paused, owner.petVisible, !owner.sleeping,
              !NSApp.isHidden, owner.letterController?.window?.isVisible != true,
              CatGrowth.dayKey(date, calendar: .current) == growth.day,
              completionFeedback.didRender(text, at: time) != nil else { return }
        receiptNeedsSave = true
        // Keep disk I/O out of draw. Quit and the next deliberate input also flush.
        DispatchQueue.main.async { [weak self] in self?.flushCompletionReceipt() }
    }
    func flushCompletionReceipt() {
        guard receiptNeedsSave else { return }
        _ = commit(growth, ball: ballSelected, decorations: decorations)
    }
    private func applyRewards() {
        owner?.art.growthBallTint = ballSelected ? growthSage : nil
        accessory.selections=decorations
    }
    #if CAT_ACCESSORY_PREVIEW
    func prepareAccessoryDemo() {
        precondition(isPreview && store==nil)
        growth=CatGrowth(snapshot:CatGrowthSnapshot(unlockedRewards:[0,1,2],points:32,companionDays:16,completed:[.pet,.play],day:CatGrowth.dayKey(date,calendar:.current),ballSelected:false,decoration:nil))
        // Simulated rewards only; never emit a completion line for demo setup.
        completionFeedback=CatCompletionFeedback(shownDay:growth.day)
        ballSelected=false;decorations=[.flower,.fish];applyRewards()
    }
    #endif
    func beginDrag(_ point: CGPoint) { drag.begin(point) }
    #if CAT_RECEIPT_PREVIEW
    func prepareReceiptDemo() {
        precondition(isPreview && store == nil)
        // In-memory rewards for testing accepted flower/fish interactions, but
        // today's two goals are fresh. Restarting this preview resets only it.
        growth=CatGrowth(snapshot:CatGrowthSnapshot(unlockedRewards:[0,1,2],points:32,companionDays:16,
            completed:[],day:CatGrowth.dayKey(date,calendar:.current),ballSelected:false,decoration:nil))
        completionFeedback=CatCompletionFeedback();receiptNeedsSave=false
        ballSelected=false;decorations=[.flower,.fish];applyRewards()
    }
    #endif
    func moveDrag(_ point: CGPoint) { drag.move(point) }
    func cancelDrag() { drag.cancel() }
    func releaseDrag() { if drag.release() { record(.play) } }
    @objc func present() {
        if window == nil { buildWindow() }
        refreshDay()
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
    #if CAT_COMPANION_PREVIEW
    // Explicit demo controls only; never compiled into the formal app.
    @objc func selectCompanionPreview(_ sender: NSPopUpButton) {
        guard isPreview, store == nil, let points = sender.selectedItem?.tag else { return }
        let day = CatGrowth.dayKey(date, calendar: .current)
        let earned = Set(CatGrowthReward.allCases.filter { points >= $0.threshold })
        ballSelected = ballSelected && earned.contains(.sageBall)
        decorations.formIntersection(earned)
        growth = CatGrowth(snapshot: CatGrowthSnapshot(unlockedRewards: Set(earned.map(\.rawValue)),
            points: points, companionDays: (points + 1) / 2,
            completed: points == 0 ? [] : [.pet, .play], day: day,
            ballSelected: ballSelected, decoration: nil, decorations: Set(decorations.map(\.rawValue))))
        completionFeedback = CatCompletionFeedback(shownDay: points == 0 ? 0 : day)
        receiptNeedsSave = false; drag.cancel(); applyRewards(); refresh()
    }
    #endif
    #if CAT_GROWTH_PREVIEW
    @objc func nextDay() {
        completionFeedback.cancel()
        dayOffset += 1; growth.refresh(at: date); drag.cancel(); refresh()
    }
    #endif
    @objc func chooseReward(_ sender: NSButton) {
        guard let reward = CatGrowthReward(rawValue: sender.tag), isUnlocked(reward) else { return }

        let ball = reward == .sageBall ? !ballSelected : ballSelected
        var selected = decorations
        if reward != .sageBall {
            if selected.contains(reward) { selected.remove(reward) } else { selected.insert(reward) }
        }
        if commit(growth, ball: ball, decorations: selected) { applyRewards() }
        refresh()
    }
    private func refresh() {
        guard window != nil else { return }
        let progress = CatLevelProgress(points: growth.points)
        let companion = CatCompanionProgress(points: growth.points)
        levelLabel.stringValue = "Lv.\(progress.level)"
        pointsLabel.stringValue = "经验 \(progress.earnedInLevel) / \(progress.requiredInLevel)"
        bar.maxValue = Double(progress.requiredInLevel); bar.doubleValue = Double(progress.earnedInLevel)
        daysLabel.stringValue = "已经一起玩过 \(growth.companionDays) 天，不必连续。"
        let familiar = companion.familiarity
        familiarityLabels[0].stringValue = familiar.first ?? "慢慢熟悉中，原来的摸猫回应一直都在。"
        familiarityLabels[1].stringValue = familiar.count > 1 ? familiar[1] : ""
        milestoneLabel.stringValue = companion.milestoneText
        nextMilestoneLabel.stringValue = companion.nextMilestone.map { "下一个陪伴纪念：Lv.\($0)" } ?? "这些相处的日子，会一直留在这里。"
        for (i, goal) in CatGrowthGoal.allCases.enumerated() {
            let done = growth.completed.contains(goal)
            goalLabels[i].stringValue = (done ? "✓  " : "○  ") + ["摸摸猫", "陪它玩一次球"][i]
            goalDetails[i].stringValue = done ? "今天已完成" : "+1 经验"
            goalDetails[i].textColor = done ? growthMuted : growthInk
        }
        for reward in CatGrowthReward.allCases {
            let i = reward.rawValue, enabled = isUnlocked(reward)
            let selected = reward == .sageBall ? ballSelected : decorations.contains(reward)
            rewardButtons[i].isEnabled = enabled
            rewardButtons[i].title = !enabled ? "未解锁" : selected ? (i == 0 ? "还原" : "收起") : (i == 0 ? "换上" : "摆上")
            rewardDetails[i].stringValue = enabled ? (selected ? "正在使用" : "已解锁，随时可用") : "Lv.\(CatLevelProgress.requiredLevel(reward)) 解锁"
        }
        dayLabel?.stringValue = dayOffset == 0 ? "当前：今天" : "当前：模拟第 \(dayOffset + 1) 天"
        saveLabel?.stringValue = storageError ?? (isPreview ? "仅预览 · 关闭面板不丢进度，退出预览后重置" : "成长和小物保存在这台 Mac，退出也不会丢失。")
    }
    private func buildWindow() {
        var contentHeight: CGFloat = 752, previewStrip: CGFloat = 0
        #if CAT_GROWTH_PREVIEW
        contentHeight += 36
        #endif
        #if CAT_COMPANION_PREVIEW
        previewStrip = 40
        #endif
        let surface = GrowthSurface(frame: NSRect(x: 0, y: 0, width: 400, height: contentHeight))
        let screenHeight = (owner?.panel.screen ?? NSScreen.main)?.visibleFrame.height ?? 900
        let height = min(contentHeight + previewStrip, max(360, screenHeight - 60))
        let root = GrowthSurface(frame: NSRect(x: 0, y: 0, width: 400, height: height))
        let w = GrowthWindow(contentRect: root.bounds, styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        w.title = isPreview ? "成长小窝 · 独立预览" : "成长小窝"; w.isReleasedWhenClosed = false
        #if CAT_LEVEL_PREVIEW
        w.title = "等级与完成短句 · 未安装"
        #endif
        #if CAT_COMPLETION_PREVIEW
        w.title = "短句恢复 · 独立预览"
        #endif
        #if CAT_COMPANION_PREVIEW
        w.title = "长期成长 · 独立预览（未安装）"
        #endif
        w.contentView = root; w.appearance = NSAppearance(named: .aqua)
        w.collectionBehavior = [.fullScreenNone]
        let scroll = NSScrollView(frame: NSRect(x: 0, y: previewStrip, width: 400, height: height - previewStrip))
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.drawsBackground = false; scroll.borderType = .noBorder
        scroll.documentView = surface; root.addSubview(scroll)
        func label(_ text: String, _ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ size: CGFloat = 13, _ bold: Bool = false, _ muted: Bool = false) -> NSTextField {
            let l = NSTextField(labelWithString: text); l.frame = NSRect(x: x, y: y, width: width, height: size + 8)
            l.font = bold ? .systemFont(ofSize: size, weight: .semibold) : .systemFont(ofSize: size)
            l.textColor = muted ? growthMuted : growthInk; surface.addSubview(l); return l
        }
        func divider(_ y: CGFloat) {
            let line = NSBox(frame: NSRect(x: 24, y: y, width: 352, height: 1)); line.boxType = .separator; surface.addSubview(line)
        }
        _ = label("一起慢慢长大", 24, 21, 352, 23, true)
        _ = label("今天陪一会儿，就很好。", 25, 57, 350, 13, false, true)
        levelLabel = label("", 24, 99, 160, 16, true)
        levelLabel.setAccessibilityIdentifier("growth-level")
        pointsLabel = label("", 182, 101, 194); pointsLabel.alignment = .right
        bar = NSProgressIndicator(frame: NSRect(x: 25, y: 131, width: 350, height: 8)); bar.style = .bar; bar.isIndeterminate = false; surface.addSubview(bar)
        daysLabel = label("", 24, 150, 352, 12, false, true)
        divider(183)
        _ = label("今天的小目标", 24, 200, 352, 15, true)
        for i in 0..<2 {
            let y = CGFloat(233 + i * 30)
            goalLabels.append(label("", 24, y, 226, 14))
            let detail = label("", 244, y + 1, 132, 12, false, true); detail.alignment = .right; goalDetails.append(detail)
        }
        divider(300)
        _ = label("慢慢攒下的小物", 24, 317, 352, 15, true)
        for reward in CatGrowthReward.allCases {
            let i = reward.rawValue, y = CGFloat(349 + i * 57)
            surface.addSubview(GrowthRewardSwatch(reward, frame: NSRect(x: 22, y: y, width: 40, height: 40)))
            _ = label(["鼠尾草绿小球", "窝边小花", "窝沿金鱼挂饰"][i], 75, y + 1, 210, 14)
            rewardDetails.append(label("", 75, y + 23, 210, 12, false, true))
            let b = NSButton(title: "未解锁", target: self, action: #selector(chooseReward(_:)))
            b.frame = NSRect(x: 294, y: y + 7, width: 82, height: 30); b.bezelStyle = .rounded; b.tag = i
            b.setAccessibilityLabel(["使用绿色小球", "摆上或收起小花", "摆上或收起小鱼"][i]); surface.addSubview(b); rewardButtons.append(b)
        }
        _ = label("小花和小鱼可以一起摆，也可以分别收起。", 24, 520, 352, 12, false, true)
        divider(548)
        _ = label("已经有的默契", 24, 561, 352, 14, true)
        familiarityLabels = [label("", 24, 587, 352, 12, false, true),
                             label("", 24, 608, 352, 12, false, true)]
        divider(638)
        _ = label("陪伴纪念", 24, 651, 150, 14, true)
        let quietNote = label("不用领取，也不必赶进度", 184, 653, 192, 11, false, true)
        quietNote.alignment = .right
        milestoneLabel = label("", 24, 677, 352, 12)
        nextMilestoneLabel = label("", 24, 698, 352, 12, false, true)
        milestoneLabel.setAccessibilityIdentifier("growth-milestone")
        nextMilestoneLabel.setAccessibilityIdentifier("growth-next-milestone")
        #if CAT_GROWTH_PREVIEW
        dayLabel = label("", 24, 727, 210, 12, false, true)
        let next = NSButton(title: "模拟下一天", target: self, action: #selector(nextDay))
        next.frame = NSRect(x: 266, y: 721, width: 111, height: 31); next.bezelStyle = .rounded; surface.addSubview(next)
        #endif
        saveLabel = label("", 24, contentHeight - 25, 352, 11, false, true)
        #if CAT_COMPANION_PREVIEW
        let hint = NSTextField(labelWithString: "仅预览等级")
        hint.frame = NSRect(x: 24, y: 12, width: 100, height: 19)
        hint.font = .systemFont(ofSize: 12); hint.textColor = growthMuted; root.addSubview(hint)
        let picker = NSPopUpButton(frame: NSRect(x: 132, y: 6, width: 244, height: 28), pullsDown: false)
        for (level, points) in [(0,0),(3,6),(10,32),(30,195),(37,284),(50,492),(100,1817),(110,2182)] {
            picker.addItem(withTitle: "Lv.\(level)"); picker.lastItem?.tag = points
        }
        picker.target = self; picker.action = #selector(selectCompanionPreview(_:))
        picker.setAccessibilityLabel("切换模拟等级，不改变真实存档")
        root.addSubview(picker)
        #endif
        window = w
        if let screen = owner?.panel.screen ?? NSScreen.main {
            let available = screen.visibleFrame
            w.setFrameOrigin(NSPoint(x: max(available.minX + 20, available.midX - 380), y: max(available.minY + 20, available.midY - w.frame.height / 2)))
            if isPreview { owner?.panel.setFrameOrigin(NSPoint(x: min(available.maxX - 310, w.frame.maxX + 30), y: w.frame.midY - 134)) }
        }
    }
}
