import AppKit

@main struct LetterContentTests {
    static func main() throws {
        _=NSApplication.shared
        func check(_ value:Bool,_ message:String) {
            if !value {fputs("FAIL: \(message)\n",stderr);exit(1)}
        }
        let url=URL(fileURLWithPath:"src/letter.txt")
        let bytes=try Data(contentsOf:url)
        let text=CatLetter.text(at:url)
        let expected="""
        你好呀！
        
        这是一封随开源项目提供的示例信。你可以在编译前修改 src/letter.txt，写下自己的问候，也可以保留这份示例，看看信纸、换行和滚动的效果。
        
        小猫会在桌面陪你待一会儿。试试轻点猫头、持续抚摸，或者拿出小球，观察它如何回应。成长目标和奖励只保存在你自己的电脑上。
        
        希望这只小猫能给平常的一天添一点轻松。休息好了，再慢慢做下一件事吧。
        """+"\n"
        check(text==expected,"Public example wording, punctuation and paragraph breaks stay exact")
        let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
        let reader=CatLetterController(text:text,stationeryURL:URL(fileURLWithPath:"src/assets/letter-stationery-v1.png"),reduceMotion:{true})
        let window=reader.window!
        for size in [NSSize(width:540,height:580),NSSize(width:340,height:280)] {
            window.setContentSize(size)
            window.contentView!.layoutSubtreeIfNeeded()
            let layout=reader.textView.layoutManager!,container=reader.textView.textContainer!
            layout.ensureLayout(for:container)
            let used=layout.usedRect(for:container)
            check(reader.textView.string==expected,"Layout preserves the whole public example letter")
            check(reader.textView.frame.width<=reader.scrollView.contentSize.width+1,"No horizontal scrolling needed")
            check(used.maxX<=container.containerSize.width+1,"All glyphs wrap within the text container")
            if size.width==540 {
                let reading=reader.paperView.convert(reader.scrollView.bounds,from:reader.scrollView)
                check(reading.minX>=94 && reading.maxX<=476 && reading.minY>=104 && reading.maxY<=476,
                      "Scrolled text stays inside the illustrated paper's central safe area: \(reading)")
            }
            print("LAYOUT \(size): used=\(used), document=\(reader.textView.frame.size), viewport=\(reader.scrollView.contentSize)")
            if CommandLine.arguments.count>1 {
                let view=window.contentView!
                let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds)!
                view.cacheDisplay(in:view.bounds,to:bitmap)
                let output=URL(fileURLWithPath:CommandLine.arguments[1]).appendingPathComponent("letter-\(Int(size.width)).png")
                try bitmap.representation(using:.png,properties:[:])!.write(to:output)
            }
            reader.present()
            reader.textView.scrollToEndOfDocument(nil)
            if size.width==340 {
                check(reader.scrollView.contentView.bounds.minY>0,"Narrow window really scrolls to the last paragraph")
            }
            check(used.maxY+reader.textView.textContainerInset.height<=reader.scrollView.documentVisibleRect.maxY+1,"Final line is reachable without clipping")
            window.contentView!.subviews.compactMap{$0 as? NSButton}.first!.performClick(nil)
            check(!window.isVisible,"Close button hides the actual reader")
            reader.present()
            check(reader.scrollView.contentView.bounds.origin.y==0,"Rereading starts at the beginning: \(reader.scrollView.contentView.bounds.origin)")
            check(reader.textView.string==expected,"Reopening keeps all approved content")
            window.cancelOperation(nil)
            check(!window.isVisible,"Escape closes the populated reader")
        }
        check(try Data(contentsOf:url)==bytes,"Reading never writes the letter source")
        check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"No formal preferences or reading state written")
        print("PASS public example letter: exact text, normal/narrow layout, final-line reachability, scroll, close/reopen and no writes")
    }
}
