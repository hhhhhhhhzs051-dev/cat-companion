import AppKit

// A disposable second process, deliberately ignoring mouse events. This checks
// visual occlusion, not just which window would receive a click. No data access.
@main struct ExternalReceiptCover {
    static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let a=CommandLine.arguments.dropFirst().compactMap(Double.init)
        precondition(a.count==4)
        let window=NSWindow(contentRect:NSRect(x:a[0],y:a[1],width:a[2],height:a[3]),
                            styleMask:.borderless,backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.isOpaque=true;window.backgroundColor = .white
        window.ignoresMouseEvents=true;window.level=NSWindow.Level(rawValue:1)
        window.collectionBehavior=[.fullScreenNone];window.orderFrontRegardless()
        // Safety exit if the owning test fails before its normal cleanup.
        DispatchQueue.main.asyncAfter(deadline:.now()+8) { NSApp.terminate(nil) }
        NSApp.run()
    }
}
