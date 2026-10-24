import AppKit

// Preview-only controls around the production reader; suppress its own opening.
final class LetterDriftPreviewController:NSObject {
    let reader:CatLetterController
    let drift=LetterDriftView(frame:.zero)
    private(set) var replayButton:NSButton!
    private(set) var reducedButton:NSButton!
    private let systemReduced:()->Bool
    private var observers:[NSObjectProtocol]=[]
    private var workspaceObserver:NSObjectProtocol?
    private var visibilityObserver:NSKeyValueObservation?
    private(set) var previewReduced=false
    init(stationeryURL:URL,systemReduced:@escaping ()->Bool={
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }) {
        reader=CatLetterController(text:"",stationeryURL:stationeryURL,reduceMotion:{true})
        self.systemReduced=systemReduced
        super.init()
        let window=reader.window!,content=window.contentView!
        visibilityObserver=window.observe(\.isVisible,options:[.new]){[weak self] window,_ in
            if !window.isVisible {self?.drift.stop()}
        }
        window.title="小猫信纸 · 飘落预览 · 未安装"
        window.contentMinSize=NSSize(width:540,height:580)
        drift.translatesAutoresizingMaskIntoConstraints=false
        content.addSubview(drift)
        NSLayoutConstraint.activate([
            drift.leadingAnchor.constraint(equalTo:reader.paperView.leadingAnchor),
            drift.trailingAnchor.constraint(equalTo:reader.paperView.trailingAnchor),
            drift.topAnchor.constraint(equalTo:reader.paperView.topAnchor),
            drift.bottomAnchor.constraint(equalTo:reader.paperView.bottomAnchor)
        ])
        // Preview-only controls; the production reader and its size policy
        // remain untouched. Keep all three controls reachable at minimum size.
        replayButton=NSButton(title:"重播开场",target:self,action:#selector(replay))
        replayButton.frame=NSRect(x:20,y:12,width:94,height:28);replayButton.bezelStyle = .rounded
        replayButton.setAccessibilityLabel("重播一次花瓣与叶子飘落")
        content.addSubview(replayButton)
        reducedButton=NSButton(checkboxWithTitle:"减少动态（预览）",target:self,action:#selector(toggleReduced(_:)))
        reducedButton.frame=NSRect(x:128,y:12,width:172,height:28)
        reducedButton.setAccessibilityHelp("仅用于这个预览，不更改系统或正式猫咪的设置")
        content.addSubview(reducedButton)
        for name in [NSWindow.willCloseNotification,NSWindow.didMiniaturizeNotification,
                     NSWindow.willStartLiveResizeNotification,NSWindow.didResizeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:window,queue:.main){[weak self] _ in self?.drift.stop()})
        }
        observers.append(NotificationCenter.default.addObserver(forName:NSWindow.didChangeOcclusionStateNotification,object:window,queue:.main){[weak self] _ in
            if self?.reader.window?.occlusionState.contains(.visible) != true {self?.drift.stop()}
        })
        for name in [NSApplication.didHideNotification,NSApplication.didResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:NSApp,queue:.main){[weak self] _ in self?.drift.stop()})
        }
        workspaceObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main){[weak self] _ in
            guard let self else{return}
            if self.systemReduced() {self.drift.stop()}
        }
    }
    deinit {
        for observer in observers {NotificationCenter.default.removeObserver(observer)}
        if let workspaceObserver {NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)}
    }
    func present() {
        let opening=reader.window?.isVisible != true
        reader.present()
        if opening {replay()}
    }
    @objc func replay() {
        reader.window?.contentView?.layoutSubtreeIfNeeded()
        guard let image=reader.paperView.image else {drift.stop();return}
        drift.play(imageSize:image.size,textRight:drift.bounds.width-reader.textView.textContainerInset.width,
                   reduced:previewReduced || systemReduced())
    }
    func setPreviewReduced(_ value:Bool) {
        previewReduced=value
        reducedButton.state=value ? .on:.off
        if value {drift.stop()}
        // Turning reduction off is not an opening and must never replay.
    }
    @objc private func toggleReduced(_ sender:NSButton) {setPreviewReduced(sender.state == .on)}
}
