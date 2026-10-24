import AppKit

// Plain local text only: no links, remote content, read receipts or saved position.
enum CatLetter {
    static func text(at url:URL?) -> String {
        guard let url,let file=try? FileHandle(forReadingFrom:url) else {
            return "信还没有放进来。"
        }
        defer {try? file.close()}
        guard let data=try? (file.read(upToCount:256*1024+1) ?? Data()),data.count<=256*1024,
              let text=String(data:data,encoding:.utf8) else {
            return "信还没有放进来。"
        }
        return text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty ? "":text
    }
}

final class CatLetterWindow:NSWindow {
    override func cancelOperation(_ sender:Any?) {performClose(sender)}
    override func performKeyEquivalent(with event:NSEvent)->Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers=="w" {
            performClose(nil);return true
        }
        return super.performKeyEquivalent(with:event)
    }
}

private final class CatStationeryView:NSImageView {
    // The illustration's pixel size must never resize the recipient's window.
    override var intrinsicContentSize:NSSize {
        NSSize(width:NSView.noIntrinsicMetric,height:NSView.noIntrinsicMetric)
    }
}

final class CatLetterController:NSWindowController {
    let textView=NSTextView()
    let scrollView=NSScrollView()
    let paperView:NSImageView=CatStationeryView()
    let openingDrift=LetterDriftView(frame:.zero)
    private let reduceMotion:()->Bool
    private var observers:[NSObjectProtocol]=[]
    private var workspaceObserver:NSObjectProtocol?
    private var visibilityObserver:NSKeyValueObservation?

    init(text:String,stationeryURL:URL?=nil,reduceMotion:@escaping ()->Bool={
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }) {
        self.reduceMotion=reduceMotion
        let window=CatLetterWindow(contentRect:NSRect(x:0,y:0,width:540,height:580),
            styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init(window:window)
        window.title="给你的一封信"
        window.isReleasedWhenClosed=false
        window.isRestorable=false
        window.contentMinSize=NSSize(width:340,height:280)
        window.collectionBehavior=[.fullScreenNone]
        window.animationBehavior = .none
        let stationery=stationeryURL.flatMap{NSImage(contentsOf:$0)}
        window.backgroundColor = stationery == nil ? .textBackgroundColor:
            NSColor(srgbRed:0.137,green:0.161,blue:0.173,alpha:1)
        if stationery != nil {window.appearance=NSAppearance(named:.darkAqua)}
        let content=window.contentView!
        // The approved static paper remains behind the existing reader.
        // Opening decoration has no timer, reading state or pet clock changes.
        paperView.translatesAutoresizingMaskIntoConstraints=false
        paperView.image=stationery
        // Nonempty/error text may extend beyond the aspect-fit image on resize.
        // Keep those margins readable; the accepted blank paper is unchanged.
        if stationery != nil && !text.isEmpty {
            paperView.wantsLayer=true
            paperView.layer?.backgroundColor=NSColor(srgbRed:0.98,green:0.955,blue:0.90,alpha:1).cgColor
        }
        paperView.imageScaling = .scaleProportionallyDown
        paperView.imageAlignment = .alignCenter
        paperView.setAccessibilityElement(false)
        content.addSubview(paperView)
        scrollView.translatesAutoresizingMaskIntoConstraints=false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller=true
        scrollView.hasHorizontalScroller=false
        scrollView.autohidesScrollers=true
        scrollView.drawsBackground=stationery == nil
        scrollView.contentView.drawsBackground=stationery == nil
        scrollView.backgroundColor = .textBackgroundColor
        content.addSubview(scrollView)

        textView.isEditable=false
        textView.isSelectable=true
        textView.isRichText=false
        textView.isAutomaticLinkDetectionEnabled=false
        textView.isAutomaticDataDetectionEnabled=false
        textView.isAutomaticTextReplacementEnabled=false
        textView.isAutomaticSpellingCorrectionEnabled=false
        textView.isContinuousSpellCheckingEnabled=false
        textView.usesFindBar=true
        textView.drawsBackground=stationery == nil
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset=NSSize(width:28,height:28)
        textView.minSize=NSSize(width:0,height:0)
        textView.maxSize=NSSize(width:CGFloat.greatestFiniteMagnitude,height:CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable=true
        textView.isHorizontallyResizable=false
        textView.autoresizingMask=[.width]
        textView.textContainer?.widthTracksTextView=true
        textView.textContainer?.containerSize=NSSize(width:484,height:CGFloat.greatestFiniteMagnitude)
        let paragraph=NSMutableParagraphStyle()
        paragraph.lineSpacing=6
        paragraph.paragraphSpacing=12
        textView.textStorage?.setAttributedString(NSAttributedString(string:text,attributes:[
            .font:NSFont.systemFont(ofSize:17),
            .foregroundColor:stationery == nil ? NSColor.textColor:NSColor(srgbRed:0.35,green:0.30,blue:0.24,alpha:1),
            .paragraphStyle:paragraph
        ]))
        textView.setAccessibilityLabel("信的正文")
        scrollView.documentView=textView

        let close=NSButton(title:"关闭",target:self,action:#selector(closeLetter))
        close.bezelStyle = .rounded
        close.translatesAutoresizingMaskIntoConstraints=false
        close.keyEquivalent="\u{1b}"
        content.addSubview(close)
        NSLayoutConstraint.activate([
            paperView.leadingAnchor.constraint(equalTo:scrollView.leadingAnchor),
            paperView.trailingAnchor.constraint(equalTo:scrollView.trailingAnchor),
            paperView.topAnchor.constraint(equalTo:scrollView.topAnchor),
            paperView.bottomAnchor.constraint(equalTo:scrollView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo:content.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo:content.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo:content.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo:close.topAnchor,constant:-12),
            close.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-24),
            close.bottomAnchor.constraint(equalTo:content.bottomAnchor,constant:-12),
            close.widthAnchor.constraint(greaterThanOrEqualToConstant:72),
            close.heightAnchor.constraint(greaterThanOrEqualToConstant:28)
        ])
        window.initialFirstResponder=textView
        window.center()
        openingDrift.translatesAutoresizingMaskIntoConstraints=false
        content.addSubview(openingDrift)
        NSLayoutConstraint.activate([
            openingDrift.leadingAnchor.constraint(equalTo:paperView.leadingAnchor),
            openingDrift.trailingAnchor.constraint(equalTo:paperView.trailingAnchor),
            openingDrift.topAnchor.constraint(equalTo:paperView.topAnchor),
            openingDrift.bottomAnchor.constraint(equalTo:paperView.bottomAnchor)
        ])
        visibilityObserver=window.observe(\.isVisible,options:[.new]){[weak self] window,_ in
            if !window.isVisible {self?.openingDrift.stop()}
        }
        for name in [NSWindow.willCloseNotification,NSWindow.didMiniaturizeNotification,
                     NSWindow.willStartLiveResizeNotification,NSWindow.didResizeNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:window,queue:.main){[weak self] _ in self?.openingDrift.stop()})
        }
        observers.append(NotificationCenter.default.addObserver(forName:NSWindow.didChangeOcclusionStateNotification,object:window,queue:.main){[weak self] _ in
            if self?.window?.occlusionState.contains(.visible) != true {self?.openingDrift.stop()}
        })
        for name in [NSApplication.didHideNotification,NSApplication.didResignActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName:name,object:NSApp,queue:.main){[weak self] _ in self?.openingDrift.stop()})
        }
        workspaceObserver=NSWorkspace.shared.notificationCenter.addObserver(forName:NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,object:nil,queue:.main){[weak self] _ in
            if self?.reduceMotion() == true {self?.openingDrift.stop()}
        }
    }
    deinit {
        for observer in observers {NotificationCenter.default.removeObserver(observer)}
        if let workspaceObserver {NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)}
    }
    required init?(coder:NSCoder) {fatalError("init(coder:) has not been implemented")}

    func present() {
        guard let window else{return}
        let opening = !window.isVisible
        window.contentView?.layoutSubtreeIfNeeded()
        if let container=textView.textContainer {textView.layoutManager?.ensureLayout(for:container)}
        if !window.isVisible {
            textView.setSelectedRange(NSRange(location:0,length:0))
            textView.scrollToBeginningOfDocument(nil)
        }
        NSApp.activate(ignoringOtherApps:true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)
        if opening,let image=paperView.image {
            openingDrift.play(imageSize:image.size,textRight:openingDrift.bounds.width-textView.textContainerInset.width,
                              reduced:reduceMotion())
        }
    }
    @objc private func closeLetter() {window?.performClose(nil)}
}
