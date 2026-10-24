import AppKit

func runMenuTests(_ app: PetApp) {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("cat-completion-" + UUID().uuidString)
    try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let store = CatGrowthStore(url: folder.appendingPathComponent("growth.json"))
    let date = Date(), key = CatGrowth.dayKey(date, calendar: .current)
    let legacy = "{\"version\":2,\"points\":4,\"companionDays\":2,\"completed\":[\"pet\",\"play\"],\"day\":\(key),\"ballSelected\":true,\"unlockedRewards\":[0]}"
    try! Data(legacy.utf8).write(to: store.url)
    let source = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("src")
    app.art = try! NativeCatView(resources: source); app.active = true
    app.panel = PetPanel(contentRect: NSRect(x: 40,y: 40,width: 290,height: 267), styleMask: [.borderless], backing: .buffered, defer: false)
    app.panel.contentView = app.art; app.art.frame = NSRect(x:0,y:0,width:290,height:267)
    app.touch = PetTouchView(frame: app.art.bounds); app.touch.owner = app
    app.motion = CatMotion(now: app.now, seed: 12)
    func controller() -> CatGrowthController { CatGrowthController(owner: app, store: store, currentDate: {date}) }
    var growth = controller(); app.growthController = growth
    precondition(growth.growth.points == 4 && growth.growth.companionDays == 2 && growth.ballSelected && growth.growth.completed.count == 2)
    precondition(growth.completionFeedback.text(at: app.now, available:true, blocked:false) == nil, "migration/restart does not automatically speak")
    growth.record(.pet)
    let line = growth.completionFeedback.text(at: app.now, available:true, blocked:false)!
    precondition(line.contains("第 2 天") && growth.growth.points == 4, "existing completed tasks can retry without rescoring")
    growth.completionFeedback.cancel()
    growth = controller(); app.growthController = growth
    precondition(growth.completionFeedback.text(at: app.now, available:true, blocked:false) == nil)
    growth.record(.play)
    let resumed = growth.completionFeedback.text(at: app.now, available:true, blocked:false)!
    // Offscreen snapshots are not delivery, even if the text is in the bitmap.
    var acknowledged = 0
    app.art.onTextRendered = { text in acknowledged += 1; app.growthController?.didRenderCompletion(text, at: app.now) }
    app.art.text = resumed
    let bitmap = app.art.bitmapImageRepForCachingDisplay(in: app.art.bounds)!
    app.art.cacheDisplay(in: app.art.bounds, to: bitmap)
    precondition(acknowledged == 0 && (try! store.load())!.completionShownDay == nil)
    // Model the acknowledgement supplied by the separately tested native draw.
    growth.didRenderCompletion(resumed, at: app.now); growth.flushCompletionReceipt()
    let saved = try! store.load()!
    precondition(saved.version == 4 && saved.completionShownDay == key && saved.points == 4 && saved.companionDays == 2 && saved.ballSelected && saved.completed.count == 2)
    growth = controller(); app.growthController = growth
    growth.record(.pet); growth.record(.play)
    precondition(growth.completionFeedback.text(at: app.now + 6, available:true, blocked:false) == nil, "acknowledged day stays silent after restart and deliberate input")
    var invalid = saved; invalid.completionShownDay = 99991231
    do { try invalid.validate(); preconditionFailure("future receipt accepted") } catch {}
    invalid = saved; invalid.completed = [.pet]
    do { try invalid.validate(); preconditionFailure("incomplete day receipt accepted") } catch {}
    invalid = saved; invalid.completionShownDay = 20260230
    do { try invalid.validate(); preconditionFailure("invalid receipt date accepted") } catch {}
    // Failed receipt persistence must not silently forget the dirty receipt,
    // repeat it in this process, or replace an unreadable on-disk file.
    try! Data(legacy.utf8).write(to: store.url)
    growth = controller(); app.growthController = growth; growth.record(.pet)
    let retryLine = growth.completionFeedback.text(at:app.now,available:true,blocked:false)!
    let goodData = try! Data(contentsOf:store.url), brokenData = Data("unreadable test fixture".utf8)
    try! brokenData.write(to:store.url)
    growth.didRenderCompletion(retryLine,at:app.now); growth.flushCompletionReceipt()
    precondition(growth.storageError != nil && growth.completionFeedback.shownDay == key)
    precondition((try! Data(contentsOf:store.url)) == brokenData)
    try! goodData.write(to:store.url)
    growth.record(.play)
    precondition(growth.storageError == nil && (try! store.load())!.completionShownDay == key && growth.growth.points == 4)
    // An ordinary commit arriving before the queued receipt flush must preserve
    // both the latest day's progress and yesterday's acknowledgement.
    try! Data(legacy.utf8).write(to:store.url)
    var movingDate = date
    growth = CatGrowthController(owner:app,store:store,currentDate:{movingDate}); app.growthController = growth
    growth.record(.pet)
    growth.didRenderCompletion(growth.completionFeedback.text(at:app.now,available:true,blocked:false)!,at:app.now)
    movingDate = Calendar.current.date(byAdding:.day,value:1,to:date)!
    growth.record(.pet)
    RunLoop.main.run(until:Date().addingTimeInterval(0.05))
    let latest = try! store.load()!
    precondition(latest.points == 5 && latest.companionDays == 3 && latest.completed == [.pet] && latest.completionShownDay == key && latest.ballSelected)
    print("PASS delivery persistence: v2 completed-day recovery, no reset, quiet restart, paint-only receipt, offscreen ignored, same-day dedupe, invalid state rejected")
    print("PASS receipt failure/retry and queued flush cannot overwrite newer progress")
}
