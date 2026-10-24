import Foundation

@main struct MouthTests {
    static func main() {
        func check(_ condition:Bool,_ message:String) {
            if !condition {fputs("FAIL: \(message)\n",stderr);exit(1)}
        }
        // Catches a missing extension as well as a stuck tongue after the action ends.
        let prepare=CatMouth.pose(.noseLick,elapsed:0.06)
        check(prepare.opening>0.1 && prepare.extensionAmount==0,"Nose lick must open the mouth before the tongue emerges")
        let settle=CatMouth.pose(.noseLick,elapsed:0.92)
        check(settle.opening>0 && settle.extensionAmount==0,"Nose lick closes only after the tongue retracts")
        check(CatMouth.pose(.tongueTip,elapsed:0.4).opening==0,"Do not change the accepted tongue-tip action")
        check(CatMouth.pose(.tongueTip,elapsed:0.85).extensionAmount>0.9,"Tongue must remain visible long enough to notice")
        check(CatMouth.pose(.tongueTip,elapsed:0.4).extensionAmount>0.9,"Tongue tip must extend during its brief hold")
        for gesture in [MouthGesture.tongueTip,.noseLick] {
            check(CatMouth.pose(gesture,elapsed:-1)==MouthPose(),"No tongue before the action")
            check(CatMouth.pose(gesture,elapsed:0)==MouthPose(),"Action begins at unchanged V1")
            check(CatMouth.pose(gesture,elapsed:2)==MouthPose(),"Action restores unchanged V1")
            var previous=MouthPose()
            for frame in 0...120 {
                let p=CatMouth.pose(gesture,elapsed:Double(frame)/60)
                check(p.extensionAmount>=0 && p.extensionAmount<=1 && p.curl>=0 && p.curl<=1,"Bounded finite mouth motion")
                check(abs(p.extensionAmount-previous.extensionAmount)<0.15,"Continuous tongue extension")
                check(p.opening.isFinite && (0...1).contains(p.opening) && abs(p.opening-previous.opening)<0.2,"Smooth bounded mouth opening")
                previous=p
            }
        }
        check(CatMouth.pose(.noseLick,elapsed:0.32).curl>0.8,"Lick tip curls toward the nose")
        var motion=CatMotion(now:0,seed:24)
        motion.begin(.tongueTip,at:10)
        check(motion.frame(10.4,reduced:false,paused:false).mouth.extensionAmount>0.9,"Native motion must deliver mouth pose")
        motion.pet(10.4)
        check(motion.frame(10.41,reduced:false,paused:false).mouth.extensionAmount>0.9,"Petting does not abruptly erase a visible tongue")
        check(motion.frame(11.101,reduced:false,paused:false).eyes==0,"Mouth gesture must preserve 700ms pet eye response")
        check(motion.frame(11.2,reduced:false,paused:false).mouth==MouthPose(),"No stuck tongue after petting")
        motion.begin(.noseLick,at:20)
        check(motion.frame(20.3,reduced:true,paused:false).mouth==MouthPose(),"Reduced motion suppresses mouth gestures")
        check(motion.frame(20.3,reduced:false,paused:true).mouth==MouthPose(),"Pause suppresses mouth gestures")
        var idle=CatMotion(now:0,seed:9)
        var previousStart = -Double.infinity,lastMouth = -Double.infinity,count=0
        for second in 0...3600 {
            _ = idle.frame(Double(second),reduced:false,paused:false)
            if idle.gestureStart != previousStart {
                if idle.gesture == .tongueTip || idle.gesture == .noseLick {
                    check(second>=8 && Double(second)-lastMouth>=35,"Mouth events respect initial quiet period and cooldown")
                    check(count==0 ? second<=15 : Double(second)-lastMouth<=60,"Automatic mouth actions must be noticeable without menu input")
                    lastMouth=Double(second);count+=1
                }
                previousStart=idle.gestureStart
            }
        }
        check(count>0,"Idle schedule must eventually select mouth gestures")
        var demo=CatMotion(now:0,seed:9)
        demo.startDemo(10)
        check(demo.demoLabel(10.8) != nil && demo.frame(10.8,reduced:false,paused:false).mouth.extensionAmount>0.9,"Demo starts with a clearly visible tongue")
        check(demo.frame(13.3,reduced:false,paused:false).mouth.curl>0.9,"Demo includes nose lick")
        check(demo.frame(16.8,reduced:false,paused:false).mouth.extensionAmount>0.9,"Demo repeats without requiring another click")
        check(demo.demoLabel(23)==nil,"Demo stops automatically")
        demo.startDemo(30)
        demo.pet(30.5)
        check(demo.demoLabel(30.5)==nil,"Petting cancels later demo repetitions")
        check(demo.frame(30.51,reduced:false,paused:false).mouth.extensionAmount>0.9,"Petting preserves the current demo action")
        demo.startDemo(40)
        check(demo.frame(40.5,reduced:true,paused:false).mouth==MouthPose() && demo.demoLabel(40.5)==nil,"Reduced motion cancels demo")
        demo.startDemo(50)
        check(demo.frame(50.5,reduced:false,paused:true).mouth==MouthPose() && demo.demoLabel(50.5)==nil,"Pause cancels demo")
        var resumed=CatMotion(now:0,seed:1)
        var firstMouth:Double?
        for i in 0...1800 {
            let t=Double(i)/30
            if i>0 && i%240==0 {resumed.resume(t)}
            let p=resumed.frame(t,reduced:false,paused:false)
            if p.mouth.extensionAmount>0 {firstMouth=t;break}
        }
        check(firstMouth != nil && firstMouth!<35,"Repeated visibility changes must not starve the first mouth action")
        print("PASS tongue visibility, V1 endpoints, bounded continuous movement and nose curl")
    }
}
