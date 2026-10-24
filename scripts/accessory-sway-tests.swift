import Foundation

@main struct AccessorySwayTests {
    static func check(_ ok:Bool,_ message:String) {if !ok {print("FAIL: \(message)");exit(1)}}
    static func main() {
        for flower in [false,true] {
            var m=CatAccessorySway()
            for i in 0..<3600 {m.advance(to:Double(i));check(m.angle==0 && !m.isActive,"idle has no autonomous motion")}
            m.tap(at:4000,flower:flower,reduced:false)
            m.advance(to:4000.08)
            check(m.angle>0.02 && m.isActive,"deliberate tap produces a visible, bounded response")
            var maxAngle=0.0
            for i in 9...240 {m.advance(to:4000+Double(i)/120);maxAngle=max(maxAngle,abs(m.angle))}
            check(maxAngle<0.20 && m.angle==0 && !m.isActive,"one tap settles exactly and stops within two seconds")
            for i in 0...1200 {
                let t=5000+Double(i)/120
                m.advance(to:t);let before=m.angle
                m.tap(at:t,flower:flower,reduced:false)
                check(m.angle==before,"repeated taps never snap position")
                check(abs(m.angle)<0.25,"rapid tapping remains bounded")
            }
            m.advance(to:5013);check(m.angle==0 && !m.isActive,"no queued replay after repeated taps")
            m.tap(at:6000,flower:flower,reduced:true);m.advance(to:6000.1)
            check(m.angle==0 && !m.isActive,"reduced motion is static")
            m.tap(at:7000,flower:flower,reduced:false);m.advance(to:7000.1);m.cancel();m.advance(to:8000)
            check(m.angle==0 && !m.isActive,"cancel/hide/rest never replays")
        }
        var slow=CatAccessorySway(),fast=CatAccessorySway()
        slow.tap(at:1,flower:false,reduced:false);fast.tap(at:1,flower:false,reduced:false)
        for i in 1...15 {slow.advance(to:1+Double(i)/30)}
        for i in 1...60 {fast.advance(to:1+Double(i)/120)}
        check(abs(slow.angle-fast.angle)<1e-12,"motion uses time, not frame count")
        print("PASS accessory impulse: explicit-only, bounded repeat continuity, finite settle, reduced/cancel, frame-rate independence")
    }
}
