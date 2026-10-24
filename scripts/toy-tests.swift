import Foundation
import CoreGraphics

@main struct ToyTests {
    static func main() {
        func check(_ value:Bool,_ message:String) {
            if !value {fputs("FAIL: \(message)\n",stderr);exit(1)}
        }
        let pocket=CGPoint(x:0.62,y:0.395)
        // The whole lane acknowledges release, but unreachable balls stay put.
        for point in [CGPoint(x:0.41,y:0.375),CGPoint(x:0.41,y:0.435),CGPoint(x:0.46,y:0.415),CGPoint(x:0.77,y:0.375),CGPoint(x:0.77,y:0.435)] {
            var wide=CatToy();wide.start(0);wide.grab(1);wide.move(to:point,at:1)
            wide.release(1.1)
            let dropped=wide.frame(1.4).position
            _=wide.frame(1.6)
            check(wide.hits==0,"Distant positions are not telekinetically batted")
            for t in [1.8,2.0,2.3] {
                let f=wide.frame(t)
                check(f.position==dropped,"Ball waits in place during paw approach, never rolls before contact")
            }
            let reached=wide.frame(2.4)
            check(reached.attention>0,"Every position receives attention after movement")
            let end=wide.frame(3.3)
            check(end.position==dropped,"Distant ball stays in place without a real contact")
            check((0.41...0.77).contains(end.position.x) && (0.355...0.435).contains(end.position.y),"Either edge rolls inward without escaping the bed")
            for t in stride(from:4.0,through:10,by:0.1) {_=wide.frame(t)}
            check(wide.hits==0,"Distant attention never becomes autonomous play")
        }
        var toy=CatToy()
        toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:0.62,y:0.435),at:1);toy.release(1.1);_=toy.frame(1.6)
        let edgeRoll=toy.frame(3.3)
        check(edgeRoll.position.y<0.40,"Rolling toward the right edge follows the curved inner rim, not the outer wall")
        toy.start(0);toy.grab(1);toy.move(to:pocket,at:1);toy.release(1.1);_=toy.frame(1.6)
        let interrupted=toy.frame(2.05)
        toy.grab(2.05)
        check(abs(toy.frame(2.05).paw-interrupted.paw)<0.0001,"Regrabbing mid-lift starts a continuous retraction")
        check(toy.frame(2.5).paw==0,"Held ball cancels the old paw strike rather than batting empty space")
        toy.start(0);toy.grab(1);toy.move(to:pocket,at:1);toy.release(1.1);_=toy.frame(1.6)
        let spinning=toy.frame(2.8);toy.grab(2.8)
        let grabbed=toy.frame(2.8)
        check(grabbed.position==spinning.position && grabbed.rotation==spinning.rotation,"Regrabbing a rolling ball preserves its position and yarn orientation")
        let front=CGMutablePath();front.move(to:CGPoint(x:-98,y:625));front.addCurve(to:CGPoint(x:1348,y:625),control1:CGPoint(x:-98,y:872),control2:CGPoint(x:1348,y:872));front.addLine(to:CGPoint(x:1348,y:1274));front.addLine(to:CGPoint(x:-98,y:1274));front.closeSubpath()
        for drop in [CGPoint(x:0.41,y:0.435),CGPoint(x:0.62,y:0.435),CGPoint(x:0.77,y:0.435)] {
            toy.start(0);toy.grab(1);toy.move(to:drop,at:1);toy.release(1.1);_=toy.frame(1.6)
            for t in stride(from:1.6,through:3.3,by:0.02) {
                let p=toy.frame(t).position
                check(!front.contains(CGPoint(x:p.x*1525-135,y:p.y*1525+165+24)),"Entire roll stays on the inner side of the actual foreground rim")
            }
        }
        toy=CatToy()
        check(toy.frame(10000).opacity==0 && !toy.isOut,"Never appears without a manual start")
        toy.start(10001)
        check(toy.isOut && toy.frame(10001.3).opacity==1,"Manual start reveals the ball")
        toy.grab(10002);toy.move(to:CGPoint(x:-10,y:5),at:10002)
        let clamped=toy.frame(10002.1).position
        check(clamped.x>=0.4 && clamped.y<=0.44,"Dragging is bounded inside the bed")
        toy.move(to:pocket,at:10003)
        _=toy.frame(10003.5)
        check(toy.hits==0,"Never steals the ball while the pointer holds it")
        toy.release(10003.6)
        _=toy.frame(10003.65)
        check(toy.hits==0,"Release gets a brief debounce before responding")
        _=toy.frame(10003.7)
        let contact=toy.frame(10004.22)
        check(toy.hits==1 && contact.paw>0.9,"Reachable released ball gets one visible paw response")
        let roll=toy.frame(10005.8)
        check(roll.position.x>pocket.x+0.035,"Paw contact rolls the ball away a short distance")
        for t in stride(from:10005.0,through:10012.0,by:0.1) {_=toy.frame(t)}
        check(toy.hits==1,"No repeated batting without another user move")
        _=toy.frame(10020)
        check(toy.isOut && toy.frame(10021).opacity==1,"A short pause leaves the ball on the bed without another hit")
        _=toy.frame(10035)
        check(!toy.isPresent && toy.frame(10036).opacity==0,"Longer inactivity quietly puts the toy away")

        toy.start(20000);toy.grab(20000.1);toy.move(to:pocket,at:20000.1);toy.release(20000.2)
        _=toy.frame(20000.7)
        let before=toy.frame(20001.02)
        toy.finish(20001.02)
        let after=toy.frame(20001.02)
        check(abs(before.paw-after.paw)<0.0001 && abs(before.opacity-after.opacity)<0.0001,"Petting interruption begins without a paw/ball jump")
        check(toy.frame(20001.7).opacity==0 && !toy.isPresent,"Interrupted paw retracts and never replays")
        toy.start(30000);toy.grab(30000.1);toy.move(to:pocket,at:30000.1);toy.release(30000.2)
        for t in stride(from:30000.3,through:30002,by:0.1) {
            let f=toy.frame(t,reduced:true)
            check(f.paw==0 && f.position.x==pocket.x && abs(f.position.y-0.39249)<0.0001 && f.opacity==1,"Reduced motion places directly on the bed without animated landing or batting")
        }
        check(toy.hits==0,"Reduced motion does not trigger autonomous responses")
        toy.finish(30002,immediate:true)
        check(!toy.isPresent && toy.frame(30003).paw==0 && toy.frame(30003).opacity==0,"Hide/rest resets transient toy state, not saved settings")

        toy.start(40000);toy.grab(40000.1);toy.move(to:pocket,at:40000.1);toy.release(40000.2)
        _=toy.frame(40001,canBat:false)
        check(toy.hits==0,"Never overlaps a busy grooming/preview paw")
        toy.finish(40001,immediate:true)
        _=toy.frame(50000)
        check(toy.hits==0 && !toy.isOut,"No pending hit after cancellation or long resume")
        print("PASS toy: manual-only, bounds, release/dwell/contact, one hit per move, timeout, smooth exit, reduced motion and cancellation")
    }
}
