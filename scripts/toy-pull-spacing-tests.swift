import Foundation

@main struct PullSpacingTests {
 static func main() {
  func check(_ ok:Bool,_ message:String) {if !ok {fputs("FAIL: \(message)\n",stderr);exit(1)}}
  func pad(_ e:Double,_ w:Double,_ side:Int)->CGPoint {
   let x=605+148*cos(e)+58*sin(e)+47*cos(e+w)+42*sin(e+w)
   return CGPoint(x:side<0 ? x:1590.5-x,y:850+148*sin(e)-58*cos(e)+47*sin(e+w)-42*cos(e+w))
  }
  for x in [0.55,0.57,0.58,0.64,0.65,0.67] {
   let point=CGPoint(x:x,y:CatToy.groundY(x)),p=CatToyReach(point),b=PreviousToyReach(point)
   check(p.contacts && b.contacts && p.stroke == .pull,"Representative left/right pulls still trigger")
   let a=pad(p.elbow,p.wrist,p.pawSide),old=pad(b.elbow,b.wrist,b.pawSide)
   let outward=(a.x-old.x)*(x<0.61 ? -1.0:1.0)*290/1525
   check(outward>=1 && outward<=3.5,"Pull paw moves only a small visible amount toward the ball's outer side at x=\(x): \(outward)pt")
   check(abs(a.y-old.y)*290/1525<2,"Outward correction must not become another high lift or dive")
   check(p.elbow==b.elbow && p.followElbow==b.followElbow && p.followWrist==b.followWrist,"Keep the forearm attachment and existing inward follow-through")
   check(p.contactTime==b.contactTime && p.travel==b.travel,"No added waiting or changed ball travel")
  }
  // Consumer-visible complete push gesture, including central paw hysteresis,
  // must be identical to the currently reviewed two-paw preview.
  for x in [0.59,0.595,0.60,0.605,0.61,0.615,0.625,0.63] {
   var new=CatToy(),old=PreviousToy();new.start(0);old.start(0);new.grab(1);old.grab(1)
   let point=CGPoint(x:x,y:0.37)
   new.move(to:point,at:1);old.move(to:point,at:1);new.release(1.1);old.release(1.1)
   for n in 0...360 {
    let t=1.1+Double(n)/120,a=new.frame(t),b=old.frame(t)
    check(a.position==b.position && a.paw==b.paw && a.pawElbow==b.pawElbow && a.pawWrist==b.pawWrist && a.pawSide==b.pawSide && a.rotation==b.rotation,"Push animation is frame-identical at x=\(x)")
    check(a.bodyRock==0,"Body never rocks")
   }
  }
  print("PASS modest outward pull adjustment; unchanged push frames and inward follow-through")
 }
}
