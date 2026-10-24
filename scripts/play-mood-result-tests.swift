import Foundation

@main struct PlayMoodResultTests {
    static func main() {
        var mood=CatPlayMood()
        mood.beginSession();mood.react(at:1,sample:0,allowed:true)
        guard mood.text(at:1)==nil else {
            fputs("FAIL: grabbing must not announce a result before the cat responds\n",stderr);exit(1)
        }
        print("PASS grabbing stays quiet until an actual play result")
        func check(_ value:Bool,_ message:String) {if !value {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        for (x,expected) in [(0.61,CatToyReach.Zone.push),(0.55,.pull),(0.41,.watch),(0.50,.pull)] {
            var toy=CatToy(rollInEnabled:true)
            toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:x,y:0.355),at:1.01);toy.release(1.02)
            check(toy.completedResponse(at:1.02)==nil,"release is not a completed result")
            var result:(id:Double,zone:CatToyReach.Zone)?
            var first=0.0
            for step in 0...120 {
                let t=1.02+Double(step)/30
                let frame=toy.frame(t)
                if let found=toy.completedResponse(at:t) {
                    if result == nil {
                        first=t;result=found
                        if expected == .pull {check(abs(frame.position.x-0.61)<0.0001,"pull phrase waits until the ball is actually back")}
                        if expected == .push {check(abs(frame.position.x-x)>0.0001,"push phrase waits for actual ball travel")}
                    } else {check(found.id==result!.id,"one result ID per release")}
                }
            }
            check(result?.zone==expected,"real near/far/assisted outcome classification at \(x)")
            if expected == .watch {check(first>=1.02+0.16+0.30-0.04,"watch response waits for landing and attention")}
            toy.grab(6)
            check(toy.completedResponse(at:6)==nil,"regrab cancels old result even before a frame tick")
            toy.move(to:CGPoint(x:0.55,y:0.355),at:6.01);toy.release(6.02)
            _=toy.frame(6.3)
            toy.park(6.31)
            check(toy.completedResponse(at:8)==nil,"petting cannot deliver an interrupted result")
            toy.grab(9);toy.release(9.01);_=toy.frame(10,reduced:true)
            check(toy.completedResponse(at:10)==nil,"reduced motion cancels results without a delayed retry")
        }
        print("PASS actual result timing: no prediction, landed watch, completed pull/roll-in, push contact, stable identity and cancellation")
    }
}
