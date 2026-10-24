// Standalone UI check only. No cat instance, bundle ID, settings or private letter.
import AppKit

@main struct LetterPreview {
    static func main() {
        let app=NSApplication.shared
        app.setActivationPolicy(.regular)
        let text=CommandLine.arguments.contains("--long")
            ? "长文排版测试\n\n以下只是测试内容，不是将要送出的信。\n\n"+String(repeating:"这是一段用于检查中文换行、段落间距和窗口滚动的测试文字。可以随时关闭窗口，再重新打开阅读。\n\n",count:45)+"测试结束。"
            : CatLetter.text(at:nil)
        let controller=CatLetterController(text:text)
        let menu=NSMenu(),root=NSMenuItem(),items=NSMenu()
        root.submenu=items;menu.addItem(root)
        let reopen=NSMenuItem(title:"给你的一封信",action:nil,keyEquivalent:"")
        final class Handler:NSObject {
            let controller:CatLetterController
            init(_ controller:CatLetterController){self.controller=controller}
            @objc func show(){controller.present()}
        }
        let handler=Handler(controller)
        reopen.target=handler;reopen.action=#selector(Handler.show)
        items.addItem(reopen);app.mainMenu=menu
        controller.present()
        DispatchQueue.main.asyncAfter(deadline:.now()+180){app.terminate(nil)}
        withExtendedLifetime(handler){app.run()}
    }
}
