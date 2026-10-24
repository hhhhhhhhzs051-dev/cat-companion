import Foundation

@main struct SinglePawBaselineTests {
    static func main() {
        func check(_ condition:Bool,_ message:String) {if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        // The authored paw is the cat's RIGHT paw on screen LEFT. Its root and
        // handedness must survive unchanged, not be moved/mirrored to that side.
        let originalRoot=CGPoint(x:605,y:850),originalPad=CGPoint(x:800,y:750)
        check(originalRoot.applying(CatToyFrame.pawTransform(-1))==originalRoot,"Screen-left must retain the original cat-right root")
        check(originalPad.applying(CatToyFrame.pawTransform(-1))==originalPad,"Screen-left must retain original paw handedness")
        let mirroredRoot=originalRoot.applying(CatToyFrame.pawTransform(1))
        let mirroredPad=originalPad.applying(CatToyFrame.pawTransform(1))
        check(mirroredRoot==CGPoint(x:985.5,y:850) && mirroredPad==CGPoint(x:790.5,y:750),"Screen-right must mirror the original cat-right paw into a cat-left paw")
        // Ground coordinates are real-world coordinates, including the bed's
        // slight asymmetry. Only the paw space is reflected, not the cat or bed.
        for x in [0.55,0.57,0.59,0.60,0.605,0.615,0.625,0.65,0.67] {
            let y=CatToy.groundY(x),localX=x<0.61 ? x:1.22-x
            let baseline=LegacySinglePawReach(CGPoint(x:localX,y:y))
            let plan=CatToyReach(CGPoint(x:x,y:y))
            check(plan.contacts==baseline.contacts,"Reachability comes from the original limb")
            if !plan.contacts {continue}
            check(plan.pawSide==(x<0.61 ? -1:1),"Screen side selects the corresponding anatomical paw")
            check(plan.contactTime==baseline.contactTime && plan.travel==baseline.travel,"Preserve single-paw timing and stroke distance")
            let values=[plan.elbow,plan.wrist,plan.approachElbow,plan.approachWrist,plan.followElbow,plan.followWrist]
            let expected=[baseline.elbow,baseline.wrist,baseline.approachElbow,baseline.approachWrist,baseline.followElbow,baseline.followWrist]
            if plan.stroke == .push {
                check(zip(values,expected).allSatisfy{abs($0-$1)<1e-10},"Preserve original single-paw push joint poses; only reflect their placement")
            } else {
                // Pull-only contact spacing is now explicitly authorized; its
                // forearm, inward follow-through and original timing stay fixed.
                check(plan.elbow==baseline.elbow && plan.followElbow==baseline.followElbow && plan.followWrist==baseline.followWrist,"Pull spacing cannot change the original forearm or follow-through")
            }
        }
        // At unchanged left-side targets the full live gesture must preserve
        // the old extension/contact/retraction timeline, not just endpoints.
        for x in [0.60,0.605] {
            var new=CatToy(),old=LegacySinglePawToy();new.start(0);old.start(0)
            new.grab(1);old.grab(1)
            // Establish the left paw before entering the intentionally sticky
            // center buffer; a fresh center grab otherwise starts on the right.
            new.move(to:CGPoint(x:0.59,y:0.37),at:1);old.move(to:CGPoint(x:0.59,y:0.37),at:1)
            let point=CGPoint(x:x,y:0.37)
            new.move(to:point,at:1);old.move(to:point,at:1);new.release(1.1);old.release(1.1)
            for n in 0...360 {
                let time=1.1+Double(n)/120,a=new.frame(time),b=old.frame(time)
                check(a.position==b.position && a.paw==b.paw && a.pawElbow==b.pawElbow && a.pawWrist==b.pawWrist,"Left-paw gesture remains frame-identical to build 46 at x=\(x)")
                check(a.bodyRock==0,"No body sway added to either paw")
            }
        }
        print("PASS anatomical handedness and frozen single-paw action baseline")
    }
}
