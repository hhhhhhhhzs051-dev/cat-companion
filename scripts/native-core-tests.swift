import AppKit

@main struct NativeCoreTests {
    static func main() {
        _ = NSApplication.shared
        var cat=CatMotion(now:0,seed:42);cat.nextBlink=3
        precondition(cat.frame(3.07,reduced:false,paused:false).eyes == 1)
        precondition(cat.frame(3.191,reduced:false,paused:false).eyes == 0)
        cat.pet(10)
        precondition(cat.frame(10.12,reduced:false,paused:false).eyes>0.9)
        precondition(cat.frame(10.71,reduced:false,paused:false).eyes == 0)
        precondition(cat.frame(10.8,reduced:false,paused:false).lean>0)
        for time in stride(from:10.8,through:11.3,by:0.1) {cat.pet(time)}
        precondition(cat.frame(15,reduced:false,paused:false).lean == 0)
        cat.pet(20)
        let reduced=cat.frame(20.1,reduced:true,paused:false)
        precondition(reduced.eyes==1 && reduced.breath==0 && reduced.lean==0)
        let paused=cat.frame(20.1,reduced:false,paused:true)
        precondition(paused.eyes==0 && paused.breath==0 && paused.lean==0)
        cat.reset(100)
        precondition(cat.frame(100,reduced:false,paused:false).eyes==0 && cat.petEnd<100)
        cat.nextGesture=101
        _ = cat.frame(101,reduced:false,paused:false)
        precondition(!cat.gestureStart.isFinite,"Reserve the quiet gap for the upcoming first mouth action")
        _ = cat.frame(114,reduced:false,paused:false)
        precondition(cat.gestureStart==114 && cat.nextGesture>=138 && cat.nextGesture<=166)
        cat.reset(100)
        cat.begin(.leftEar,at:101)
        precondition(cat.frame(101.3,reduced:false,paused:false).leftEar>0.99)
        precondition(cat.frame(102.6,reduced:false,paused:false).leftEar==0)
        cat.pet(103)
        precondition(cat.nextGesture>=cat.petEnd+10)
        let still=cat.frame(103.1,reduced:true,paused:false)
        precondition(still.leftEar==0 && still.rightEar==0 && still.head==0 && still.breath==0 && still.eyes==1)
        cat.reset(300)
        precondition(cat.frame(300,reduced:false,paused:false)==CatPose())
        // Rigid facial core must preserve eye spacing while the neck absorbs the small tilt.
        let eyeA=CGPoint(x:685,y:550),eyeB=CGPoint(x:881,y:550)
        for h in [-1.0,0,1] {
            let a=CatDeformation.sourcePoint(eyeA,pose:CatPose(head:h))
            let b=CatDeformation.sourcePoint(eyeB,pose:CatPose(head:h))
            precondition(abs(hypot(a.x-b.x,a.y-b.y)-196)<0.00001)
        }
        precondition(CatDeformation.sourcePoint(eyeA,pose:CatPose(breath:1,leftEar:1,rightEar:1))==eyeA)
        for look in [-1.0,1] {
            let a=CatDeformation.sourcePoint(eyeA,pose:CatPose(lookX:look))
            let b=CatDeformation.sourcePoint(eyeB,pose:CatPose(lookX:look))
            precondition(abs(a.x-eyeA.x)>14,"Far-toy attention visibly follows horizontally at normal size")
            precondition(abs(hypot(a.x-b.x,a.y-b.y)-196)<0.00001,"Looking keeps eye spacing rigid and the original face proportions")
            let root=CGPoint(x:605,y:850)
            precondition(CatDeformation.sourcePoint(root,pose:CatPose(lookX:look))==root,"Head attention never moves the attached forearm")
        }
        precondition(CatDeformation.sourcePoint(CGPoint(x:400,y:805),pose:CatPose(breath:1))==CGPoint(x:400,y:805))
        var simulation=CatMotion(now:0,seed:7)
        var lastStart = -Double.infinity,previous:CatGesture?,events=0,activeFrames=0
        for index in 0..<18000 {
            let t=Double(index)/30
            let p=simulation.frame(t,reduced:false,paused:false)
            precondition([p.eyes,p.breath,p.leftEar,p.rightEar].allSatisfy{$0.isFinite && $0>=0 && $0<=1})
            precondition(abs(p.head)<=1)
            if abs(p.head)+p.leftEar+p.rightEar>0 {activeFrames+=1}
            if simulation.gestureStart != lastStart {
                precondition(simulation.gestureStart-lastStart>=24)
                precondition(previous != simulation.gesture)
                previous=simulation.gesture;lastStart=simulation.gestureStart;events+=1
            }
        }
        precondition(events>8 && events<26 && Double(activeFrames)/18000<0.12)
        simulation.begin(.slowBlink,at:700)
        let half=simulation.frame(700.32,reduced:false,paused:false)
        precondition(abs(half.eyes-0.55)<0.001)
        simulation.pet(700.32)
        let entry=simulation.frame(700.32,reduced:false,paused:false)
        precondition(abs(entry.eyes-half.eyes)<0.001)
        precondition(simulation.frame(701.021,reduced:false,paused:false).eyes==0)
        print("PASS rigid eye spacing, face/breath isolation, bed anchor, 10-minute bounded scheduling, quiet occupancy, slow blink and continuous pet entry")
        var touch=CatMotion(now:0,seed:9)
        touch.touchBack(1)
        let back=touch.frame(1.2,reduced:false,paused:false)
        precondition(back.leftEar>0.8 && back.eyes==1 && back.head<0,"Body contact fully closes eyes while retaining ear/head response")
        touch.stroke(.back,at:1.3)
        let before=touch.frame(1.31,reduced:false,paused:false)
        touch.endStroke(1.31)
        let release=touch.frame(1.31,reduced:false,paused:false)
        precondition(abs(before.leftEar-release.leftEar)<0.001,"Release must not snap")
        let relaxing=touch.frame(1.8,reduced:false,paused:false)
        precondition(relaxing.leftEar>0 && relaxing.leftEar<release.leftEar)
        var repeated=touch
        repeated.stroke(.back,at:1.8)
        precondition(abs(repeated.frame(1.8,reduced:false,paused:false).leftEar-relaxing.leftEar)<0.001,"A new stroke during settling cannot snap to full strength")
        let rested=touch.frame(2.4,reduced:false,paused:false)
        precondition(rested.leftEar==0 && rested.head==0 && rested.eyes==0)
        touch.pet(3);_ = touch.frame(3.2,reduced:false,paused:false);touch.stroke(.head,at:3.2)
        precondition(touch.frame(3.3,reduced:false,paused:false).eyes>0.9)
        precondition(touch.frame(3.71,reduced:false,paused:false).eyes==1,"Head stroking holds complete closure beyond the click response")
        touch.endStroke(3.71)
        precondition(touch.frame(3.96,reduced:false,paused:false).eyes==0,"Head stroke release reopens eyes")
        var held=CatMotion(now:0,seed:2);held.pet(1)
        let easingLean=held.frame(2.8,reduced:false,paused:false).lean
        held.stroke(.head,at:2.8)
        precondition(abs(held.frame(2.8,reduced:false,paused:false).lean-easingLean)<0.001,"Resuming a held stroke must not restart the body lean")
        var switching=CatMotion(now:0,seed:2);switching.touchBack(1)
        let backBefore=switching.frame(1.2,reduced:false,paused:false)
        switching.pet(1.2)
        let headAfter=switching.frame(1.2,reduced:false,paused:false)
        precondition(abs(headAfter.leftEar-backBefore.leftEar)<0.001 && abs(headAfter.head-backBefore.head)<0.001,"Head click must ease out the previous back response")
        _ = switching.frame(1.4,reduced:false,paused:false)
        let leanBefore=switching.frame(1.5,reduced:false,paused:false).lean
        switching.touchBack(1.5)
        precondition(abs(switching.frame(1.5,reduced:false,paused:false).lean-leanBefore)<0.001,"Back touch must ease out the previous head lean")
        touch.resume(4)
        precondition(touch.frame(4,reduced:false,paused:false)==CatPose(),"Resume discards pending contact")
        touch.touchBack(5);touch.stroke(.back,at:5.2)
        precondition(touch.frame(5.3,reduced:true,paused:false)==CatPose(),"Reduced motion omits back deformation")
        touch.touchBack(6)
        precondition(touch.frame(6.2,reduced:false,paused:true)==CatPose(),"Pause cancels contact")
        print("PASS differentiated touch, continuous release, settling, 700ms head eyes, reduced motion and interruption")
        let view=try! NativeCatView(resources:URL(fileURLWithPath:"src"))
        view.frame=NSRect(x:0,y:0,width:290,height:267)
        for side in [-1,1] {
            for p in [CGPoint(x:390,y:670),CGPoint(x:760,y:420),CGPoint(x:930,y:580)] {
                view.toyFrame=CatToyFrame()
                let original=view.touchRegion(CGPoint(x:(p.x+135)*290/1525,y:60+(p.y-165)*290/1525))
                precondition(original == .head || original == .back,"Fixture must lie on visible cat artwork")
                view.toyFrame=CatToyFrame(paw:1,pawElbow:-1,pawWrist:-1,pawSide:side)
                precondition(view.touchRegion(CGPoint(x:(p.x+135)*290/1525,y:60+(p.y-165)*290/1525))==original,"Either paw leaves head/body touch coordinates stable")
            }
        }
        print("PASS head/body touch stays fixed for either toy paw")
        do {_ = try NativeCatView(resources:URL(fileURLWithPath:"/nonexistent-cat-test-resources"));fatalError("Missing assets must fail") }catch{}
        print("PASS native motion: natural blink, 700ms eyes, independent body response, repeated input, reduced motion, pause/resume; missing assets fail safely")
    }
}
