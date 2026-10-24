import AppKit

@main struct LetterFontTests {
    static func main() throws {
        _=NSApplication.shared
        func check(_ ok:Bool,_ message:String) {if !ok {print("FAIL letter font: \(message)");exit(1)}}
        let names=["STKaitiSC-Regular","Kaiti SC","STKaiti","STFangsong","STSongti-SC-Regular","Songti SC","STSong"]
        let sentinel=NSFont.monospacedSystemFont(ofSize:18,weight:.regular)
        for (i,name) in names.enumerated() {
            var calls:[String]=[]
            let font=CatLetter.illustratedFont {candidate,size in
                check(size==18,"fallback never shrinks approved text")
                calls.append(candidate);return candidate==name ? sentinel:nil
            }
            check(font==sentinel,"a later installed font is used when earlier choices are missing: \(name)")
            check(calls==Array(names.prefix(i+1)),"priority and first-success short circuit")
        }
        check(CatLetter.illustratedFont(resolve:{_,_ in nil})==NSFont.systemFont(ofSize:18),"all missing remains readable")
        if let preferred=NSFont(name:"STKaitiSC-Regular",size:18) {
            check(CatLetter.illustratedFont()==preferred,"an installed approved first font stays unchanged")
        }
        let text=CatLetter.text(at:URL(fileURLWithPath:"src/letter.txt"))
        let paper=URL(fileURLWithPath:"src/assets/letter-stationery-v1.png")
        let prefs=UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?
        for excluded in [0,3,4,7] {
            let resolve:(String,CGFloat)->NSFont?={name,size in
                guard let index=names.firstIndex(of:name),index>=excluded else{return nil}
                return NSFont(name:name,size:size)
            }
            for body in [text,String(repeating:text,count:20)] {
                let reader=CatLetterController(text:body,stationeryURL:paper,fontResolver:resolve,reduceMotion:{true})
                let font=reader.textView.textStorage!.attribute(.font,at:0,effectiveRange:nil) as! NSFont
                check(font==CatLetter.illustratedFont(resolve:resolve),"reader uses selected local fallback")
                let paragraph=reader.textView.textStorage!.attribute(.paragraphStyle,at:0,effectiveRange:nil) as! NSParagraphStyle
                check(paragraph.lineSpacing==1 && paragraph.paragraphSpacing==0 && reader.textView.textContainerInset==NSSize(width:8,height:8),"approved reading layout unchanged")
                for size in [NSSize(width:540,height:580),NSSize(width:340,height:280)] {
                    reader.window!.setContentSize(size);reader.window!.contentView!.layoutSubtreeIfNeeded()
                    let layout=reader.textView.layoutManager!,container=reader.textView.textContainer!
                    layout.ensureLayout(for:container)
                    check(reader.textView.string==body,"whole letter preserved")
                    check(layout.usedRect(for:container).maxX<=container.containerSize.width+1,"no horizontal overflow")
                    reader.textView.scrollToEndOfDocument(nil)
                    check(layout.usedRect(for:container).maxY+8<=reader.scrollView.documentVisibleRect.maxY+1,"last line reachable in normal and narrow reader")
                    check(!reader.window!.isVisible,"font checks never show a window")
                }
            }
        }
        for (body,paperURL) in [("",Optional(paper)),(text,nil)] {
            _=CatLetterController(text:body,stationeryURL:paperURL,fontResolver:{_,_ in
                check(false,"empty/plain reader must not resolve illustrated fonts");return nil
            },reduceMotion:{true})
        }
        check(prefs==UserDefaults.standard.persistentDomain(forName:"local.catcompanion.opensource") as NSDictionary?,"no formal preference writes")
        print("PASS local font fallback order, whole-family absence, system fallback, normal/narrow/long layout, approved first-font and no writes")
    }
}
