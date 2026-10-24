import Foundation

@main struct ApprovedPreviewTests {
    static func check(_ ok:Bool,_ message:String) {
        if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}
    }
    static func match(_ a:CatToyFrame,_ b:PreOuterFrame)->Bool {
        let values=[a.position.x-b.position.x,a.position.y-b.position.y,a.opacity-b.opacity,
                    a.rotation-b.rotation,a.paw-b.paw,a.pawElbow-b.pawElbow,a.pawWrist-b.pawWrist,
                    a.pawLift-b.pawLift,a.pawOffsetX-b.pawOffsetX]
        return values.allSatisfy{abs($0)<1e-9} && a.pawSide==b.pawSide && a.bodyRock==0
    }
    static func main() {
        for demo in PawDemo.allCases {
            var live=CatToy(),approved=OriginalPawPlayback()
            live.start(0);live.grab(0.1)
            let inside=demo.x<0.61 ? 0.55:0.67
            live.move(to:CGPoint(x:inside,y:CatToy.groundY(inside)),at:0.2)
            live.move(to:CGPoint(x:demo.x,y:CatToy.groundY(demo.x)),at:0.3)
            live.release(1);_=live.frame(1.08)
            _=approved.play(demo,at:0)
            for n in 0...156 {
                let age=Double(n)/120;approved.tick(age)
                check(match(live.frame(1.08+age),approved.frame),"Real drag/release differs from the accepted 290pt preview: \(demo), age \(age)")
            }
        }
        for x in [0.535,0.685] {
            var live=CatToy();live.start(0);live.grab(0.1)
            live.move(to:CGPoint(x:x,y:CatToy.groundY(x)),at:0.2)
            check(live.dragZone == .pull,"Accepted outer target must trigger on a fresh drag, without a secret priming gesture")
            live.release(1);_=live.frame(1.08)
            check(live.hits==1,"Accepted target responds exactly once")
            for age in [0.2,0.52,0.64,0.82] {
                let time=1.08+age,before=live.frame(time)
                for action in 0..<3 {
                    var interrupted=live
                    if action==0 {interrupted.grab(time)}
                    else if action==1 {interrupted.park(time)}
                    else {interrupted.finish(time)}
                    let after=interrupted.frame(time)
                    check(before.paw==after.paw && before.pawElbow==after.pawElbow && before.pawWrist==after.pawWrist && before.pawSide==after.pawSide,"Interruptions preserve the refined pose without snapping")
                    check(interrupted.frame(time+0.6).paw==0,"Interrupted paw settles fully")
                }
            }
        }
        for x in [0.41,0.50,0.52,0.71,0.73,0.77] {
            check(!CatToyReach(CGPoint(x:x,y:CatToy.groundY(x))).contacts,"Rejected long outer reach must not return")
        }
        for zone in [CatToyReach.Zone.watch,.push,.pull] {
            let span=CatToyReach.guideSpan(for:zone)
            for n in 0...100 {
                let x=span.lowerBound+(span.upperBound-span.lowerBound)*Double(n)/100
                check(CatToyReach(CGPoint(x:x,y:CatToy.groundY(x)),previous:zone).contacts,"Faint guide cannot promise unreachable contact")
            }
        }
        print("PASS actual drag/release matches six approved clips (942 frames), fresh reach, interruption continuity and bounded guide")
    }
}
