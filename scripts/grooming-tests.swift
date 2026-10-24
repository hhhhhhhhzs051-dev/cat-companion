import Foundation

@main struct GroomingTests {
    static func main() {
        func check(_ c:Bool,_ message:String) {if !c {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        // Keep the coordinated head approach, without the rejected sustained squint.
        let preparation=CatGrooming.pose(elapsed:0.2)
        check(preparation.cat.head>0,"Head prepares before the paw lifts")
        check(preparation.paw.raise==0 && preparation.cat.mouth.extensionAmount==0,"No premature floating paw or tongue")
        for t in [-1.0,0,4,100,Double.nan,Double.infinity] {
            check(CatGrooming.pose(elapsed:t)==GroomingPose(),"All layers return to original rest")
        }
        var previous=GroomingPose(),licks=0,wasLicking=false
        for i in 0...480 {
            let p=CatGrooming.pose(elapsed:Double(i)/120)
            check(p.cat.eyes==0,"Grooming preserves V1 eyes instead of forcing a sustained squint")
            check((0...1).contains(p.paw.raise) && (0...1).contains(p.cat.eyes),"Bounded paw and eyelids")
            check((0...4).contains(p.cat.head),"Head remains a small original-pose variation")
            check(abs(p.paw.raise-previous.paw.raise)<0.025 && abs(p.cat.head-previous.cat.head)<0.09,"No paw or head snap")
            if p.cat.mouth.extensionAmount>0 {
                check(p.paw.raise>0.98 && p.cat.head>2,"Licking requires the head and paw approach pose")
                if !wasLicking {licks+=1}
            }
            wasLicking=p.cat.mouth.extensionAmount>0;previous=p
        }
        check(licks==2,"Only two separated grooming strokes")
        let early=CatGrooming.pose(elapsed:1.52),late=CatGrooming.pose(elapsed:1.66),retract=CatGrooming.pose(elapsed:1.80)
        check(early.cat.mouth.grooming && late.cat.mouth.sweep>early.cat.mouth.sweep+0.5,"Tongue sweeps across the paw rather than touching one fixed point")
        check(retract.cat.mouth.fold>0.5 && retract.cat.mouth.extensionAmount<late.cat.mouth.extensionAmount,"Tongue folds while retracting")
        check(early.paw.offsetX < -5,"Paw approaches slightly beside the mouth, not centered under the nose")
        let bedPoint=CGPoint(x:1000,y:800)
        let bedSample=CatDeformation.sourcePoint(bedPoint,pose:late.cat)
        check(hypot(bedSample.x-bedPoint.x,bedSample.y-bedPoint.y)<0.001,"Head influence must end before the foreground bed")
        let eye=CGPoint(x:685,y:551),nose=CGPoint(x:798,y:670)
        let a=CatDeformation.sourcePoint(eye,pose:late.cat),b=CatDeformation.sourcePoint(nose,pose:late.cat)
        check(abs(hypot(a.x-b.x,a.y-b.y)-hypot(eye.x-nose.x,eye.y-nose.y))<0.001,"Eye-to-nose proportions remain rigid, not just eye spacing")
        let closing=CatGrooming.pose(elapsed:3.3)
        check(closing.paw.raise<0.6 && closing.cat.head>1,"Paw lowers before attention returns")
        print("PASS grooming preparation, coordinated contact, continuity, two strokes and exact rest")
    }
}
