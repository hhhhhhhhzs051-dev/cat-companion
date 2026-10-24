import Foundation

@main struct CompletionStableTests {
    static func main() {
        func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        let all:Set<CatGrowthGoal>=[.pet,.play]
        var f=CatCompletionFeedback()
        f.record(completed:all,day:20261018,companionDays:2,at:0,sample:4)
        check(f.text(at:0,available:true,blocked:true)==nil,"initial held input waits for release")
        let line=f.text(at:0.2,available:true,blocked:false)!
        check(f.text(at:0.3,available:true,blocked:true)==line,"a started completion must not yield its bubble to the next pet")
        _=f.didRender(line,at:0.4)
        for t in stride(from:0.5,through:3.3,by:0.1) {
            f.record(completed:all,day:20261018,companionDays:2,at:t,sample:1)
            check(f.text(at:t,available:true,blocked:true)==line,"continued petting keeps one line without resetting its deadline")
        }
        check(f.text(at:3.41,available:true,blocked:true)==nil,"three seconds expires even while input remains held")
        check(f.text(at:3.5,available:true,blocked:false)==nil,"release cannot resurrect an acknowledged line")
        f.cancel();f.record(completed:all,day:20261018,companionDays:2,at:5,sample:0)
        check(f.text(at:6,available:true,blocked:false)==nil,"shown day never repeats after rest or input")
        var pending=CatCompletionFeedback()
        pending.record(completed:all,day:20261018,companionDays:2,at:0,sample:4)
        _=pending.text(at:0.2,available:true,blocked:false)
        check(pending.text(at:0.3,available:false,blocked:false)==nil,"hide/rest cancels an unacknowledged display")
        check(pending.text(at:10,available:true,blocked:false)==nil,"resume alone stays quiet")
        pending.record(completed:all,day:20261018,companionDays:2,at:11,sample:0)
        check(pending.text(at:11,available:true,blocked:true)==nil,"retry still waits for the new gesture release")
        check(pending.text(at:11.2,available:true,blocked:false)==line,"next deliberate released input retries the same unshown line")
        print("PASS stable completion: initial release, sustained input, unchanged three-second deadline, same-day dedupe, quiet resume and active retry")
    }
}
