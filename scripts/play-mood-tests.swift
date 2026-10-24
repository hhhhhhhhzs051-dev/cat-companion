import Foundation

@main struct PlayMoodTests {
    static func main() {
        func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        var mood=CatPlayMood()
        check(mood.text(at:0)==nil && mood.text(at:1000)==nil,"Idle time never creates a phrase")
        mood.beginSession()
        check(mood.text(at:1)==nil,"Taking out the ball stays quiet until direct contact")
        mood.react(at:1,sample:0,allowed:true)
        check(mood.text(at:1)==nil,"A grab only reserves the session chance; it cannot predict a result")
        mood.resolve(id:1,outcome:.pull,at:1,allowed:true)
        let first=mood.text(at:1)
        check(first != nil,"An eligible user contact can produce one short emotional response")
        for t in [1.1,1.4,2.0] {
            mood.react(at:t,sample:1,allowed:true)
            mood.resolve(id:t,outcome:.push,at:t,allowed:true)
            check(mood.text(at:t)==first,"Repeated grabs cannot replace or restart the same phrase")
        }
        check(mood.text(at:3)==nil,"Phrase expires without a new timer or user action")
        mood.react(at:50,sample:1,allowed:true)
        mood.resolve(id:50,outcome:.watch,at:50,allowed:true)
        check(mood.text(at:50)==nil,"Even a long same-session play cannot retrigger speech")
        mood.beginSession();mood.react(at:51,sample:1,allowed:true)
        mood.resolve(id:51,outcome:.watch,at:51,allowed:true)
        check(mood.text(at:51) != nil && mood.text(at:51) != first,"A later session can use another neutral response")
        mood.cancel();check(mood.text(at:51.1)==nil,"Pet/hide/rest immediately removes toy speech")
        mood.beginSession();mood.react(at:52,sample:0,allowed:true)
        mood.resolve(id:52,outcome:.push,at:52,allowed:true)
        check(mood.text(at:52)==nil,"Reopening the ball cannot reset the speech cooldown")
        mood.react(at:100,sample:0,allowed:true)
        mood.resolve(id:100,outcome:.push,at:100,allowed:true)
        check(mood.text(at:100)==nil,"A skipped session does not deliver a delayed phrase")
        for sample in 2...5 {
            mood.beginSession();mood.react(at:200,sample:sample,allowed:true)
            mood.resolve(id:200,outcome:.pull,at:200,allowed:true)
            check(mood.text(at:200)==nil,"Most sampled sessions are entirely quiet")
            mood.react(at:201,sample:0,allowed:true)
            mood.resolve(id:201,outcome:.pull,at:201,allowed:true)
            check(mood.text(at:201)==nil,"Repeated input cannot reroll a quiet session")
        }
        mood.beginSession();mood.react(at:300,sample:0,allowed:false)
        mood.react(at:301,sample:0,allowed:true)
        mood.resolve(id:301,outcome:.push,at:301,allowed:true)
        check(mood.text(at:301)==nil,"Reduced motion or an ongoing pet response cannot queue later speech")
        mood.beginSession();mood.react(at:400,sample:0,allowed:true);mood.cancel()
        check(mood.text(at:400.2)==nil,"Resuming visibility does not revive a cancelled phrase")
        mood.resolve(id:400,outcome:.push,at:401,allowed:true)
        check(mood.text(at:401)==nil,"A cancelled result opportunity must not survive hide/rest/pet/letter")
        mood.beginSession();mood.react(at:500,sample:0,allowed:true)
        mood.resolve(id:500,outcome:.pull,at:501,allowed:false)
        mood.resolve(id:500,outcome:.pull,at:502,allowed:true)
        mood.resolve(id:501,outcome:.pull,at:503,allowed:true)
        check(mood.text(at:503)==nil,"A busy result is dropped, not replayed or retried on the next hit")
        let base=["私人文案甲。","私人文案乙。"]
        check(CatPetLines.candidates(base:base,level:2)==base,"Before Lv.3 only existing private lines are used")
        let lv3=CatPetLines.candidates(base:base,level:3),lv6=CatPetLines.candidates(base:base,level:6),lv7=CatPetLines.candidates(base:base,level:7)
        check(lv3.count==4 && lv3==lv6 && lv7.count==6,"Two small pools unlock only at Lv.3 and Lv.7")
        check(Array(lv3.prefix(2))==base && Array(lv7.prefix(4))==lv3,"Private lines and earlier rewards remain available, in original order")
        check(lv7.allSatisfy{$0.count<=24 && !$0.contains("\n")},"All new lines fit the accepted single-line bubble")
        print("PASS play mood: input-only, mostly quiet, one short phrase, cooldown, no reroll/replay")
    }
}
