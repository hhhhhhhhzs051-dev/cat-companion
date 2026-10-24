import Foundation

@main struct GroomingIntegrationTests {
    static func main() {
        func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
        var m=CatMotion(now:0,seed:12)
        check(!m.automaticGrooming,"Grooming is opt-in")
        m.begin(.pawLick,at:1)
        let contact=m.frame(2.55,reduced:false,paused:false)
        check(contact.paw.raise>0.98 && contact.mouth.grooming && contact.groomingProfile,"Native scheduler delivers the complete grooming pose")
        check(contact.eyes==0,"Grooming does not reintroduce squinting")
        m.begin(.pawLick,at:2.6)
        check(m.gestureStart==1,"Repeated preview does not restart a raised paw")
        m.pet(2.6)
        let touched=m.frame(2.61,reduced:false,paused:false)
        check(touched.paw.raise>0.9,"Petting retracts rather than teleporting the paw")
        check(m.frame(2.72,reduced:false,paused:false).eyes>0.9,"Pet response takes priority immediately")
        let settled=m.frame(3.31,reduced:false,paused:false)
        check(settled.paw==PawPose() && settled.mouth==MouthPose() && settled.eyes==0,"Paw settles and 700ms eye response is preserved")
        for reduced in [false,true] {
            var p=CatMotion(now:0,seed:4);p.begin(.pawLick,at:1)
            _ = p.frame(2.4,reduced:false,paused:false)
            let hidden=p.frame(2.5,reduced:reduced,paused:!reduced)
            check(hidden.paw==PawPose() && hidden.mouth==MouthPose(),"Pause/reduced motion suppress grooming")
            check(p.frame(2.6,reduced:false,paused:false).paw==PawPose(),"Cancelled grooming cannot reappear after resume")
        }
        var idle=CatMotion(now:0,seed:8);idle.setAutomaticGrooming(true,at:0)
        var lastStart = -Double.infinity,lastGroom = -Double.infinity,grooms=0
        for i in 0...36000 {
            let now=Double(i)/10,p=idle.frame(now,reduced:false,paused:false)
            if idle.gestureStart != lastStart {
                check(idle.gestureStart-lastStart>=24,"All automatic gestures share a quiet gap")
                if idle.gesture == .pawLick {
                    check(now-lastGroom>=90,"Automatic grooming respects its longer cooldown")
                    lastGroom=now;grooms+=1
                }
                lastStart=idle.gestureStart
            }
            if p.paw.raise>0 {check(p.eyes==0 && p.leftEar==0 && p.rightEar==0,"No competing idle expression during grooming")}
        }
        check(grooms>=10 && grooms<=40,"Opt-in idle schedule actually plays occasional grooming")
        var late=CatMotion(now:0,seed:2);late.setAutomaticGrooming(true,at:0);late.begin(.pawLick,at:1)
        _ = late.frame(1000,reduced:false,paused:false)
        check(late.gestureStart==1000,"A late frame safely starts one due event even if the last gesture was grooming")
        idle.setAutomaticGrooming(false,at:3600)
        for i in 3610...3900 {check(idle.frame(Double(i),reduced:false,paused:false).paw==PawPose(),"Disabling auto grooming prevents later triggers")}
        print("PASS native grooming delivery, repeated input, smooth pet cancellation, pause/reduced motion, opt-in scheduling and shared cooldown")
    }
}
