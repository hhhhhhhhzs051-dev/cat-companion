import Foundation

@main struct WideReachTests {
    static func main() {
        func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        func pad(_ f:CatToyFrame)->CGPoint {
            let e=f.pawElbow,w=f.pawWrist
            let x=605+148*cos(e)+58*sin(e)+47*cos(e+w)+42*sin(e+w)
            let y=850+148*sin(e)-58*cos(e)+47*sin(e+w)-42*cos(e+w)
            // Independent geometry of two fixed chest attachments.
            return CGPoint(x:f.pawSide<0 ? x:1590.5-x,y:y)
        }
        // The user replaced the rejected wide/swaying reach with the original
        // fixed right paw plus its left-paw reflection; no expanded joint range.
        for x in [0.54,0.55,0.67,0.68] {
            var toy=CatToy();toy.start(0);toy.grab(1)
            toy.move(to:CGPoint(x:x,y:0.37),at:1)
            check(toy.dragZone == .pull,"Both flanks should retain the actual pull plan at x=\(x)")
            toy.release(1.1)
            let frames=(0...180).map{toy.frame(1.1+Double($0)/60)}
            check(toy.hits==1,"Each wider reachable release gets one response")
            check(abs(frames.last!.position.x-0.61)<0.001,"Wider pulls return the ball toward the chest")
            let first=frames.firstIndex{abs($0.position.x-x)>0.00001}!
            let contact=frames[first],tip=pad(contact)
            let ball=CGPoint(x:contact.position.x*1525-135,y:contact.position.y*1525+165)
            check(hypot(tip.x-ball.x,tip.y-ball.y)<70,"The original or mirrored paw physically reaches before rolling")
            check(contact.bodyRock==0 && contact.pawSide==(x<0.61 ? -1:1),"Use the same-side paw without rocking the cat")
            for (a,b) in zip(frames,frames.dropFirst()) {
                check(abs(b.bodyRock-a.bodyRock)<0.009,"No jump in the side lean at contact or settling")
                check(b.pawOffsetX==0,"Never slide the forearm independently of the chest")
            }
            check(frames.last!.bodyRock==0,"The cat fully returns to its original rest position")
            for t in [1.35,1.55,1.75,1.95,2.2] {
                for finish in [false,true] {
                    var interrupted=CatToy();interrupted.start(0);interrupted.grab(1)
                    interrupted.move(to:CGPoint(x:x,y:0.37),at:1);interrupted.release(1.1)
                    for n in 0...Int((t-1.1)*120) {_=interrupted.frame(1.1+Double(n)/120)}
                    let before=interrupted.frame(t)
                    if finish {interrupted.finish(t)}else{interrupted.grab(t)}
                    let after=interrupted.frame(t)
                    check(before.bodyRock==after.bodyRock,"Regrab and pet interruptions preserve the current lean")
                    if finish {interrupted.start(t)}
                    check(interrupted.frame(t).bodyRock==before.bodyRock,"Reopening during exit preserves the current lean")
                    check(interrupted.frame(t+0.6).bodyRock==0,"Cancelled lean settles without replaying")
                }
            }
            var quiet=CatToy();quiet.start(0);quiet.grab(1);quiet.move(to:CGPoint(x:x,y:0.37),at:1);quiet.release(1.1)
            for n in 0...240 {check(quiet.frame(1.1+Double(n)/60,reduced:true).bodyRock==0,"Reduced motion never rocks the cat")}
            check(quiet.hits==0,"No pending lean or strike in reduced motion")
        }
        var toy=CatToy();toy.start(0);toy.grab(1)
        toy.move(to:CGPoint(x:0.61,y:0.38),at:1)
        let pushing=toy.dragZone
        for (n,x) in [0.633,0.637,0.632,0.639].enumerated() {
            toy.move(to:CGPoint(x:x,y:0.38),at:1.1+Double(n)/60)
            check(toy.dragZone==pushing,"Tiny boundary crossings must not chatter between push and pull")
        }
        toy.move(to:CGPoint(x:0.65,y:0.38),at:1.3)
        let pulling=toy.dragZone
        check(pulling != pushing,"Deliberate crossing still changes zone")
        for (n,x) in [0.636,0.629,0.634].enumerated() {
            toy.move(to:CGPoint(x:x,y:0.38),at:1.4+Double(n)/60)
            check(toy.dragZone==pulling,"The pull side also has a buffer")
        }
        toy.release(1.5)
        let end=(0...150).map{toy.frame(1.5+Double($0)/60)}.last!
        check(end.position.x<0.634,"Release follows the buffered plan, not a different fresh classification")
        // The rejected long outer limb is gone. Keep the original physical
        // boundary and only the accepted small wrist refinement inside it.
        for (inside,jitter,outside) in [(0.55,[0.54,0.537,0.535],0.52),(0.67,[0.685,0.689,0.687],0.71)] {
            toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:inside,y:0.38),at:1)
            for (n,x) in jitter.enumerated() {
                toy.move(to:CGPoint(x:x,y:0.38),at:1.1+Double(n)/60)
                check(toy.dragZone==pulling,"Outer reach boundary retains a safe pull through small pointer jitter")
            }
            let releasedX=toy.frame(1.29).position.x
            toy.release(1.3)
            let frames=(0...160).map{toy.frame(1.3+Double($0)/60)}
            let first=frames.firstIndex{abs($0.position.x-releasedX)>0.00001}!
            let f=frames[first],tip=pad(f)
            check(hypot(tip.x-(f.position.x*1525-135),tip.y-(f.position.y*1525+165))<70,"Buffered outer pull still has real contact: side=\(inside), frame=\(f), pad=\(tip)")
            toy.grab(5);toy.move(to:CGPoint(x:outside,y:0.38),at:5)
            check(toy.dragZone == .watch,"Truly unreachable positions remain watch-only")
            toy.release(5.1)
            for n in 0...160 {
                let f=toy.frame(5.1+Double(n)/60)
                check(f.position.x==outside && f.bodyRock==0,"No remote ball motion or fake reach beyond the physical limit")
            }
        }
        print("PASS wider reach and bidirectional zone buffers")
    }
}
