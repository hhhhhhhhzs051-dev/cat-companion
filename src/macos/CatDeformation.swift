import Foundation
import CoreGraphics

// CPU inverse is shared by hit testing and geometric safety tests; mirrors catMicro.
enum CatDeformation {
    static func smooth(_ a:Double,_ b:Double,_ x:Double)->Double {CatMotion.smooth((x-a)/(b-a))}
    static func rotateInverse(_ p:CGPoint,_ pivot:CGPoint,_ angle:Double)->CGPoint {
        let x=p.x-pivot.x,y=p.y-pivot.y
        return CGPoint(x:pivot.x+cos(angle)*x+sin(angle)*y,y:pivot.y-sin(angle)*x+cos(angle)*y)
    }
    static func sourcePoint(_ p:CGPoint,pose:CatPose)->CGPoint {
        var q=p
        let face=smooth(420,550,q.x)*(1-smooth(pose.groomingProfile ? 715:655,pose.groomingProfile ? 760:815,q.y))
        q.y -= pose.head*2.2*face
        q.x -= pose.lookX*18*face
        q=rotateInverse(q,CGPoint(x:790,y:670),(pose.head*0.0045+pose.lookX*0.018)*face)
        let chin=smooth(695,710,q.y)*(1-smooth(740,790,q.y))*(1-smooth(35,95,abs(q.x-798)))
        q.y -= 6*max(0,min(1,pose.mouth.opening))*chin
        let lw=(1-smooth(335,425,q.y))*(1-smooth(90,180,abs(q.x-520)))
        let rw=(1-smooth(325,418,q.y))*(1-smooth(80,160,abs(q.x-995)))
        q=rotateInverse(q,CGPoint(x:545,y:397),pose.leftEar*0.025*lw)
        q=rotateInverse(q,CGPoint(x:980,y:385),-pose.rightEar*0.022*rw)
        let body=(1-smooth(0,1,hypot((q.x-330)/330,(q.y-580)/330)))*(1-smooth(450,560,q.x))*(1-smooth(710,805,q.y))
        q.x -= pose.breath*body*(q.x-330)*0.004
        q.y -= pose.breath*body*(q.y-730)*0.011
        return q
    }
}
