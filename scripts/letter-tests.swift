import AppKit

@main struct LetterTests {
    static func main() throws {
        _=NSApplication.shared
        func check(_ condition:Bool,_ message:String) {
            if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)}
        }
        let scratch=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:scratch,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:scratch)}
        let file=scratch.appendingPathComponent("letter.txt")
        check(CatLetter.text(at:file)=="信还没有放进来。","Missing content has an honest empty state")
        try " \n\t".write(to:file,atomically:true,encoding:.utf8)
        check(CatLetter.text(at:file).isEmpty,"An intentional blank draft stays blank on the approved stationery")
        try Data().write(to:file)
        check(CatLetter.text(at:file).isEmpty,"A zero-byte draft also stays blank")
        let text="  第一段，中文与标点。\n\n第二段 <b>原样</b> https://example.invalid\n"+String(repeating:"这只是长文排版测试，不是信的正文。\n",count:160)
        try text.write(to:file,atomically:true,encoding:.utf8)
        check(CatLetter.text(at:file)==text,"UTF-8 paragraphs and literal markup are preserved")
        let controller=CatLetterController(text:CatLetter.text(at:file))
        let window=controller.window!
        check(!window.isVisible,"Constructing reader does not show it")
        for width:CGFloat in [340,540,760] {
            window.setContentSize(NSSize(width:width,height:400))
            window.contentView?.layoutSubtreeIfNeeded()
            controller.textView.layoutManager?.ensureLayout(for:controller.textView.textContainer!)
            check(controller.textView.string==text,"Layout never truncates stored long text")
            check(controller.textView.frame.width <= controller.scrollView.contentSize.width+1,"Narrow reader wraps without horizontal overflow")
            check(controller.textView.frame.height>controller.scrollView.contentSize.height,"Long letter extends into a scrollable document")
        }
        check(!controller.textView.isEditable && controller.textView.isSelectable,"Recipient can read/select but not accidentally edit")
        check(!controller.textView.isAutomaticLinkDetectionEnabled,"Plain text cannot turn into active remote links")
        controller.present()
        controller.textView.scrollToEndOfDocument(nil)
        check(controller.scrollView.contentView.bounds.origin.y>0,"Long letter can scroll to its end")
        window.performClose(nil)
        controller.present()
        check(controller.scrollView.contentView.bounds.origin.y==0,"Reopening starts at the beginning, without saved reading progress")
        let event=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:.command,timestamp:0,windowNumber:window.windowNumber,context:nil,characters:"w",charactersIgnoringModifiers:"w",isARepeat:false,keyCode:13)!
        check(window.performKeyEquivalent(with:event) && !window.isVisible,"Command-W closes only the letter")
        check(try Data(contentsOf:file)==Data(text.utf8),"Reading and scrolling do not write the source letter")
        try Data([0xff,0xfe]).write(to:file)
        check(CatLetter.text(at:file)=="信还没有放进来。","Malformed UTF-8 fails safely")
        try Data(repeating:65,count:256*1024+1).write(to:file)
        check(CatLetter.text(at:file)=="信还没有放进来。","Oversized content is bounded")
        print("PASS letter: literal UTF-8, bounded loading, empty/error state, long/narrow layout, scrolling, close/reopen, no content writes")
    }
}
