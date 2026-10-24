import Foundation

@main struct TwoPawTests {
    static func main() {
        func check(_ c:Bool,_ m:String) {if !c {fputs("FAIL: \(m)\n",stderr);exit(1)}}
        for x in [0.55,0.57,0.60,0.62,0.66,0.67] {
            var toy=CatToy();toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:x,y:0.37),at:1);toy.release(1.1)
            let frames=(0...240).map{toy.frame(1.1+Double($0)/120)}
            check(frames.allSatisfy{$0.bodyRock==0},"Reaching for either side must never rock the body")
            check(toy.hits==1,"Each reachable release gets one response")
            let active=frames.filter{$0.paw>0}
            check(!active.isEmpty && active.allSatisfy{$0.pawSide==(x<0.61 ? -1:1)},"Use the ball-side paw for the whole strike")
        }
        for side in [-1,1] {
            let transform=CatToyFrame.pawTransform(side)
            let root=CGPoint(x:605,y:850).applying(transform)
            check(root==CGPoint(x:side<0 ? 605:985.5,y:850),"Original and mirrored paws have fixed anatomical attachments")
            let end=CGPoint(x:800,y:750).applying(transform)
            check(abs(hypot(end.x-root.x,end.y-root.y)-hypot(195,100))<0.000001,"Neither paw changes length")
        }
        // An interrupted left paw must not jump to the right attachment. The
        // replacement paw emerges only after the old one has disappeared.
        var toy=CatToy();toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:0.55,y:0.38),at:1);toy.release(1.1)
        for n in 0...65 {_=toy.frame(1.1+Double(n)/120)}
        let before=toy.frame(1.65);toy.grab(1.65)
        toy.move(to:CGPoint(x:0.67,y:0.38),at:1.66);toy.release(1.67)
        let after=toy.frame(1.67)
        check(before.pawSide == -1 && after.pawSide == -1,"Regrab preserves the currently visible side")
        var prior=after,switched=false
        for n in 1...240 {
            let f=toy.frame(1.67+Double(n)/120)
            if f.pawSide != prior.pawSide {
                check(prior.paw<0.01 && f.paw<0.01,"Switch attachments only while fully withdrawn")
                switched=true
            }
            prior=f
        }
        check(switched && prior.pawSide==1 && toy.hits==2,"The newer right-side release responds exactly once")
        for initial in [0.59,0.63] {
            toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:initial,y:0.38),at:1)
            for (n,x) in [0.607,0.613,0.606,0.614].enumerated() {toy.move(to:CGPoint(x:x,y:0.38),at:1.1+Double(n)/60)}
            toy.release(1.2)
            let active=(0...240).map{toy.frame(1.2+Double($0)/120)}.filter{$0.paw>0}
            check(active.allSatisfy{$0.pawSide==(initial<0.61 ? -1:1)},"Central buffer prevents tiny crossings from swapping paws")
        }
        for origin in [0.55,0.67,0.76] {
            for near in [0.595,0.625] {
                toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:origin,y:0.37),at:1);toy.release(1.1)
                for n in 0...240 {_=toy.frame(1.1+Double(n)/120)}
                toy.grab(4);toy.move(to:CGPoint(x:near,y:0.37),at:4);toy.release(4.1)
                let end=(0...240).map{toy.frame(4.1+Double($0)/120)}.last!
                check(abs(end.position.x-0.61)>abs(near-0.61)+0.04,"Near preview presets push even after far/pull history")
                check(end.pawSide==(near<0.61 ? -1:1),"Near presets use their labeled screen side")
            }
        }
        print("PASS two-paw stable-body preview")
    }
}
