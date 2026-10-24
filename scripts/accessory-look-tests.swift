import Foundation

@main struct Tests {
    static func main() {
        func check(_ ok:Bool,_ text:String) {if !ok {print("FAIL: \(text)");exit(1)}}
        var look=CatAccessoryLook()
        for i in 0..<3600 {check(look.sample(at:Double(i),allowed:true) == .init(),"idle never generates a response")}
        check(!look.tap(at:10,allowed:false) && !look.isActive,"busy input is discarded")
        check(look.tap(at:10,allowed:true),"explicit idle click starts once")
        check(look.sample(at:10,allowed:true) == .init(),"response starts at original pose")
        let peak=look.sample(at:10.25,allowed:true)
        check(peak.lookX==0.28 && peak.rightEar>0 && peak.rightEar<=0.18,"bounded local gaze and ear response")
        check(!look.tap(at:10.5,allowed:true),"repeated clicks cannot extend the response")
        check(look.sample(at:11.119,allowed:true).lookX<0.00001,"return is smooth near endpoint")
        check(look.sample(at:10+CatAccessoryLook.duration,allowed:true) == .init() && !look.isActive,"ends exactly without a loop")
        check(!look.tap(at:12.99,allowed:true) && look.tap(at:13,allowed:true),"cooldown is measured from accepted click")
        check(look.sample(at:13.1,allowed:false) == .init(),"higher priority action cancels")
        check(look.sample(at:13.3,allowed:true) == .init() && !look.tap(at:13.3,allowed:true),"cancelled input is not replayed and cooldown remains")
        check(look.tap(at:16,allowed:true),"new intentional click after cooldown is allowed")
        look.cancel()
        check(look.sample(at:20,allowed:true) == .init(),"hide or read cancellation remains silent on return")
        check(!look.tap(at:.infinity,allowed:true) && !look.tap(at:.nan,allowed:true),"invalid time never starts animation")
        for rate in [30.0,60] {
            var next=CatAccessoryLook();next.tap(at:100,allowed:true)
            for i in 0...Int(rate*2) {
                let v=next.sample(at:100+Double(i)/rate,allowed:true)
                check(v.lookX.isFinite && (0...0.28).contains(v.lookX) && (0...0.18).contains(v.rightEar),"all sampled responses remain bounded")
            }
            check(!next.isActive,"no timer or tail survives the finite response")
        }
        print("PASS accessory glance: finite envelope, quiet idle, no stacking, cooldown, cancellation without replay")
    }
}
