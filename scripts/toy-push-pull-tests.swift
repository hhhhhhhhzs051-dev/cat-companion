import Foundation

@main struct PushPullToyTests {
    static func main() {
        func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        // Independent forward geometry of the authored texture: the elbow root
        // is fixed; ball movement must be backed by a nearby, moving paw pad.
        func pad(_ f:CatToyFrame)->CGPoint {
            let e=f.pawElbow,w=f.pawWrist
            let x=605+148*cos(e)+58*sin(e)+47*cos(e+w)+42*sin(e+w)
            return CGPoint(x:f.pawSide<0 ? x:1590.5-x,
                           y:850+148*sin(e)-58*cos(e)+47*sin(e+w)-42*cos(e+w))
        }
        func sequence(_ x:Double)->[CatToyFrame] {
            var toy=CatToy();toy.start(0);toy.grab(1)
            toy.move(to:CGPoint(x:x,y:0.395),at:1);toy.release(1.1)
            let frames=(0...210).map{toy.frame(1.1+Double($0)/60)}
            check(toy.hits==1,"Reachable release receives exactly one response")
            for n in 1...420 {_=toy.frame(4.6+Double(n)/60)}
            check(toy.hits==1,"The returned ball cannot autonomously trigger another push")
            let first=frames.firstIndex{abs($0.position.x-x)>0.00001}!
            let before=frames[first-1],contact=frames[first]
            let tip=pad(contact),ball=CGPoint(x:contact.position.x*1525-135,y:contact.position.y*1525+165)
            check(contact.paw>0.98 && hypot(tip.x-ball.x,tip.y-ball.y)<70,"Ball starts moving only at visible low-paw contact")
            check(tip.y>735,"Push and pull remain below the mouth")
            let direction=frames.last!.position.x-x
            check((pad(frames[first+3]).x-pad(before).x)*direction>0,"Paw follow-through moves with the ball, not against it")
            for (prior,next) in zip(frames,frames.dropFirst()) {
                check(abs(next.pawElbow-prior.pawElbow)<0.2 && abs(next.pawWrist-prior.pawWrist)<0.2,"Joint paths continuous at x=\(x): elbow \(prior.pawElbow)→\(next.pawElbow), wrist \(prior.pawWrist)→\(next.pawWrist)")
                check((next.position.x-prior.position.x)*direction >= -0.00001,"Crossing the near/far boundary never reverses an active stroke")
                check(abs(next.position.y-CatToy.groundY(next.position.x))<0.00001,"The whole roll remains on the bed surface")
                check(next.pawOffsetX==0,"The forearm root cannot slide to chase the ball")
            }
            let end=frames.last!
            check(end.paw==0 && end.pawElbow==1.5 && end.pawWrist==0,"Both responses settle fully behind the bed")
            return frames
        }
        for x in [0.57,0.64,0.66] {
            let frames=sequence(x)
            check(abs(frames.last!.position.x-0.61)<abs(x-0.61)-0.015,"Reachable far ball is drawn toward the chest pocket, not sent farther away")
        }
        for x in [0.605,0.62] {
            let frames=sequence(x)
            check(abs(frames.last!.position.x-0.61)>abs(x-0.61)+0.04,"Near ball is pushed away from the chest pocket")
        }
        // For pulls, the preparation path must not just reuse the push's one
        // straight joint blend with a flipped ball velocity.
        for x in [0.57,0.64,0.66] {
            let pull=sequence(x)
            let first=pull.firstIndex{abs($0.position.x-x)>0.00001}!
            let contact=pull[first-1],preparation=pull[first-10]
            check(hypot(pad(preparation).x-pad(contact).x,pad(preparation).y-pad(contact).y)>14,"Both left and right pulls curl visibly before contact instead of dwelling at the same joint limits")
        }
        for x in [0.57,0.605,0.62,0.64,0.66] {
            for when in [1.85,2.1,2.4,2.7] {
                for finish in [false,true] {
                    var toy=CatToy();toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:x,y:0.395),at:1);toy.release(1.1)
                    for n in 0...Int((when-1.1)*60) {_=toy.frame(1.1+Double(n)/60)}
                    let before=toy.frame(when)
                    if finish {toy.finish(when)}else{toy.grab(when)}
                    let after=toy.frame(when)
                    check(before.position==after.position && before.rotation==after.rotation,"Regrab or pet interruption preserves the actual ball position and rotation")
                    check(abs(before.pawElbow-after.pawElbow)<0.00001 && abs(before.pawWrist-after.pawWrist)<0.00001,"Interruption keeps both current joint angles in every stroke phase")
                    let rest=toy.frame(when+0.6)
                    check(rest.paw==0 && rest.pawElbow==1.5 && rest.pawWrist==0,"Cancelled push/pull retracts without completing the old strike")
                }
            }
        }
        print("PASS push/pull: directions, distinct hook, contact and follow-through, continuous joints, supported roll, single response and all-phase interruption")
    }
}
