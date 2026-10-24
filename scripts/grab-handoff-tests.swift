import Foundation
@main struct GrabHandoffTests {
    static func main() {
        func check(_ ok:Bool,_ message:String) {if !ok {print("FAIL grab remainder: \(message)");exit(1)}}
        var handoff=CatGrabHandoff()
        handoff.begin(lookX:0,rightEar:0,eye:0,at:0)
        check(!handoff.isActive,"neutral capture is an exact no-op")
        handoff.begin(lookX:0.28,rightEar:0.18,eye:1,at:1)
        check(handoff.sample(at:1) == .init(lookX:0.28,rightEar:0.18,eye:1),"first sample preserves all displayed channels")
        let half=handoff.sample(at:1.12)
        check(abs(half.lookX-0.14)<1e-12 && abs(half.rightEar-0.09)<1e-12 && abs(half.eye-0.5)<1e-12,"bounded halfway release")
        handoff.begin(lookX:0.28,rightEar:0.18,eye:1,at:1.12)
        check(handoff.sample(at:1.24) == .init() && !handoff.isActive,"regrab cannot renew deadline")
        handoff.begin(lookX:0.14,rightEar:0.08,eye:0.3,at:2)
        var previous=handoff.sample(at:2)
        for i in 1...240 {
            let next=handoff.sample(at:2+Double(i)/1000)
            check(next.eye<=previous.eye && next.lookX<=previous.lookX && next.rightEar<=previous.rightEar,"no overshoot during release")
            check(previous.eye-next.eye<0.003,"fine steps remain continuous")
            previous=next
        }
        check(!handoff.isActive,"finite cleanup")
        handoff.begin(lookX:0.28,rightEar:0.18,eye:1,at:3);handoff.cancel()
        check(handoff.sample(at:3.1) == .init(),"cancellation cannot replay")
        handoff.begin(lookX:Double.nan,rightEar:0.18,eye:1,at:4)
        check(!handoff.isActive,"invalid input is ignored")
        print("PASS visual remainder endpoints, finite deadline, no regrab renewal, monotonic bounds and cancellation")
    }
}
