import AppKit

// An isolated, manually operated preview. No PetApp, copy store or migration.
@main final class LetterDriftPreviewApp:NSObject,NSApplicationDelegate {
    var controller:LetterDriftPreviewController!
    static func main() {
        let app=NSApplication.shared
        let delegate=LetterDriftPreviewApp()
        app.setActivationPolicy(.regular);app.delegate=delegate
        withExtendedLifetime(delegate){app.run()}
    }
    func applicationDidFinishLaunching(_ notification:Notification) {
        guard let image=Bundle.main.url(forResource:"stationery",withExtension:"png") else {
            fputs("Missing approved stationery image\n",stderr);NSApp.terminate(nil);return
        }
        controller=LetterDriftPreviewController(stationeryURL:image)
        let menu=NSMenu(),item=NSMenuItem(),appMenu=NSMenu()
        menu.addItem(item);item.submenu=appMenu
        appMenu.addItem(withTitle:"重新打开信纸",action:#selector(reopen),keyEquivalent:"o").target=self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle:"退出预览",action:#selector(NSApplication.terminate(_:)),keyEquivalent:"q")
        NSApp.mainMenu=menu
        controller.present()
    }
    @objc func reopen() {controller.present()}
    func applicationShouldHandleReopen(_ sender:NSApplication,hasVisibleWindows flag:Bool)->Bool {
        controller.present();return true
    }
    func applicationWillTerminate(_ notification:Notification) {controller?.drift.stop()}
}
