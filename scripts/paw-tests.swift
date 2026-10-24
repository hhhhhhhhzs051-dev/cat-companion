import Foundation

@main struct PawTests {
    static func main() {
        func check(_ c:Bool,_ message:String) {if !c {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        check(CatPaw.pose(elapsed:1.2).raise==1,"Paw must reach mouth before grooming")
        for t in [-1.0,0,4,100] {check(CatPaw.pose(elapsed:t)==PawPose(),"Paw returns completely behind bed")}
        var prev=PawPose(),licks=0,wasLicking=false
        for i in 0...240 {
            let p=CatPaw.pose(elapsed:Double(i)/60)
            check((0...1).contains(p.raise) && (0...1).contains(p.lick),"Bounded limb and tongue")
            check(abs(p.raise-prev.raise)<0.04,"Paw movement has no snap")
            if p.lick>0 {check(p.raise==1,"Tongue only reaches a stationary raised paw")}
            if p.lick>0 && !wasLicking {licks+=1}
            wasLicking=p.lick>0;prev=p
        }
        check(licks==2,"Two brief licks, not an endless grooming loop")
        let middle=CatPawRig(raise:0.5)
        check(abs(middle.wristAngle)>0.3,"Wrist bends separately rather than translating a rigid cutout")
        let anchor=CGPoint(x:605,y:850)
        check(hypot(middle.sourcePoint(anchor).x-anchor.x,middle.sourcePoint(anchor).y-anchor.y)<0.001,"Hidden forearm anchor stays fixed")
        let contact=CGPoint(x:798,y:715)
        let sampled=CatPawRig(raise:1).sourcePoint(contact)
        check(hypot(sampled.x-contact.x,sampled.y-contact.y)<0.001,"Contact pose preserves the sampled paw geometry")
        let hidden=CatPawRig(raise:0)
        let toyLift=CatPawRig(raise:1,lift:1)
        check(hypot(toyLift.sourcePoint(anchor).x-anchor.x,toyLift.sourcePoint(anchor).y-anchor.y)<0.001,"Toy lift keeps the elbow anchor attached behind the bed")
        check(abs(toyLift.elbowAngle)>0.3,"Toy anticipation lifts beyond the grooming contact angle")
        check(hidden.elbowAngle>1,"Rest folds the paw behind the bed instead of teleporting it")
        for (e,w) in [(0.2,-0.3),(0.39,-1.0),(0.7,-0.5)] {
            let rig=CatPawRig(raise:1,elbow:e,wrist:w)
            let fixed=rig.sourcePoint(anchor)
            check(hypot(fixed.x-anchor.x,fixed.y-anchor.y)<0.001,"Explicit toy joints keep the authored forearm attachment fixed")
            let dx=148*cos(e)+58*sin(e)+47*cos(e+w)+42*sin(e+w)
            let dy=148*sin(e)-58*cos(e)+47*sin(e+w)-42*cos(e+w)
            let sample=rig.sourcePoint(CGPoint(x:605+dx,y:850+dy))
            check(hypot(sample.x-800,sample.y-750)<0.001,"Actual inverse warp maps a reached pad back to the original texture, not a disconnected proxy")
        }
        print("PASS paw entry/return, continuous lift, stationary contact and two licks")
    }
}
