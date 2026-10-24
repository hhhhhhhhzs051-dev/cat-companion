import Foundation

// User-input-only speech, separate from the toy's physics and idle scheduler.
// Kept by PetApp so putting away/reopening the ball cannot reset the cooldown.
struct CatPlayMood {
    enum Outcome {case watch,push,pull}
    private var considered=true
    private var pendingVariant:Int?
    private var lastResult:Double?
    private var line:String?
    private var until = -Double.infinity
    private var nextAllowed = -Double.infinity

    mutating func beginSession() {
        considered=false;pendingVariant=nil;lastResult=nil;line=nil;until = -.infinity
    }
    mutating func cancel() {
        line=nil;until = -.infinity;pendingVariant=nil
    }
    mutating func react(at now:Double,sample:Int,allowed:Bool) {
        guard !considered else{return}
        considered=true
        // Two of six outcomes speak. A skipped/busy session never retries later.
        guard allowed,now>=nextAllowed,(0...1).contains(sample) else{return}
        pendingVariant=sample
    }
    mutating func resolve(id:Double,outcome:Outcome,at now:Double,allowed:Bool) {
        guard lastResult != id else{return}
        lastResult=id
        guard let variant=pendingVariant else{return}
        pendingVariant=nil
        // A result hidden by another interaction is discarded, not queued.
        guard allowed,now>=nextAllowed else{return}
        let lines:[String]
        switch outcome {
        case .watch:lines=["我在这儿看着呢。","咦，跑到那边了。"]
        case .push:lines=["嘿，滚走啦。","这颗球真有意思。"]
        case .pull:lines=["回来啦。","又到爪边了。"]
        }
        line=lines[variant]
        until=now+1.8;nextAllowed=now+45
    }
    func text(at now:Double)->String? {now<until ? line:nil}
}

enum CatPetLines {
    static func candidates(base:[String],level:Int)->[String] {
        var lines=base
        if level>=3 {lines += ["这样摸很舒服。","再靠一会儿。"]}
        if level>=7 {lines += ["你一来，我就放松了。","待在你身边就很好。"]}
        return lines
    }
}
