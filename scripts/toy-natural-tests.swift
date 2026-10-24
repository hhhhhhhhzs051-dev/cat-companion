import Foundation

@main struct NaturalToyTests {
    static func main() {
        func check(_ c:Bool,_ message:String) {if !c {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        func sequence(_ point:CGPoint)->[CatToyFrame] {
            var toy=CatToy();toy.start(0);toy.grab(1);toy.move(to:point,at:1);toy.release(1.1)
            return stride(from:1.1,through:4,by:0.02).map{toy.frame($0)}
        }
        for far in [CGPoint(x:0.41,y:0.38),CGPoint(x:0.77,y:0.37)] {
            let frames=sequence(far)
            check(frames.allSatisfy{$0.position.x==frames[0].position.x},"Unreachable ball may land vertically but never rolls as if struck by a detached paw")
            check(frames.allSatisfy{$0.paw==0},"Far targets receive attention, not the same transplanted paw animation")
            check(frames.contains{$0.attention>0.4},"Far targets are acknowledged, not ignored")
        }
        let near=sequence(CGPoint(x:0.60,y:0.405)),reach=sequence(CGPoint(x:0.61,y:0.395))
        check(near.contains{$0.position.x != near[0].position.x},"Reachable near ball is actually batted")
        check(reach.contains{$0.position.x != reach[0].position.x},"Longer reachable target receives an actual reach")
        let nearContact=near.firstIndex{$0.position.x != near[0].position.x}!,reachContact=reach.firstIndex{$0.position.x != reach[0].position.x}!
        check(reachContact>nearContact+8,"Long reach includes observation and extension, not the same timing at every position")
        check(near.allSatisfy{abs($0.pawOffsetX)<0.001} && reach.allSatisfy{abs($0.pawOffsetX)<0.001},"Forearm attachment never slides across the chest to chase a drop")
        check(abs(near.last!.position.x-near[0].position.x)<abs(reach.last!.position.x-reach[0].position.x),"Short nudge and longer reach have different ball travel")
        let left=sequence(CGPoint(x:0.41,y:0.38)),right=sequence(CGPoint(x:0.77,y:0.37))
        check(left.contains{$0.look < -0.8} && right.contains{$0.look>0.8},"Attention follows the side of the ball, not one identical head response")
        for frames in [near,reach] {
            let contact=frames.first{$0.paw>0.999}!
            // Independent forward geometry, using the authored elbow, wrist and
            // paw-pad coordinates; do not use the planner's inverse solver.
            func rotated(_ x:Double,_ y:Double,_ a:Double)->CGPoint {CGPoint(x:cos(a)*x-sin(a)*y,y:sin(a)*x+cos(a)*y)}
            let upper=rotated(148,-58,contact.pawElbow),pad=rotated(47,-42,contact.pawElbow+contact.pawWrist)
            let x=605+upper.x+pad.x
            let tip=CGPoint(x:contact.pawSide<0 ? x:1590.5-x,y:850+upper.y+pad.y)
            let ball=CGPoint(x:contact.position.x*1525-135,y:contact.position.y*1525+165)
            check(hypot(tip.x-ball.x,tip.y-ball.y)<28,"Visible paw pad meets ball before the roll starts")
            check(tip.y>735,"Toy contact remains below the mouth instead of lifting into a grooming pose")
        }
        var held=CatToy();held.start(0);held.grab(1);_=held.frame(20)
        check(held.isOut,"A held ball is never automatically taken away during a long hold")
        var impulse=CatToy();impulse.start(0);impulse.grab(1);impulse.move(to:CGPoint(x:0.62,y:0.395),at:1);impulse.release(1.1);_=impulse.frame(1.6)
        let atContact=impulse.frame(2.38).position.x
        let first=impulse.frame(2.53).position.x-atContact
        let second=impulse.frame(2.68).position.x-atContact-first
        check(first>second,"Ball rolls fastest just after the nudge, then slows instead of accelerating on its own")
        for isGrab in [false,true] {
            var interrupted=CatToy();interrupted.start(0);interrupted.grab(1);interrupted.move(to:CGPoint(x:0.62,y:0.395),at:1);interrupted.release(1.1);_=interrupted.frame(1.6)
            let before=interrupted.frame(2.1)
            if isGrab {interrupted.grab(2.1)}else{interrupted.finish(2.1)}
            let after=interrupted.frame(2.1)
            check(abs(before.pawElbow-after.pawElbow)<0.00001 && abs(before.pawWrist-after.pawWrist)<0.00001,"Regrab and pet interruption preserve both joint angles at the transition")
            let rest=interrupted.frame(2.7)
            check(rest.paw==0 && rest.pawElbow==1.5 && rest.pawWrist==0,"Cancelled reach returns the entire attached limb behind the bed")
        }
        for point in [CGPoint(x:0.57,y:0.395),CGPoint(x:0.59,y:0.38),CGPoint(x:0.64,y:0.39),CGPoint(x:0.66,y:0.375)] {
            let frames=sequence(point)
            check(frames.contains{$0.position.x != frames[0].position.x},"Ball-width contact makes the chest-front region usable without pixel-perfect drops")
            check(frames.allSatisfy{$0.pawOffsetX==0},"Wider usable area must not slide the forearm attachment")
        }
        print("PASS natural toy: near/reach/far differ; unreachable ball stays; forearm remains attached")
    }
}
