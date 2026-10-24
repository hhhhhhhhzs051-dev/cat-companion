import Foundation

@main struct ParkingTests {
 static func main() {
  func check(_ value:Bool,_ message:String) {if !value {fputs("FAIL: \(message)\n",stderr);exit(1)}}
  for x in [0.55,0.60,0.625,0.67] {
   for stop in [1.25,1.55,1.85,2.3] {
    var toy=CatToy();toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:x,y:CatToy.groundY(x)),at:1);toy.release(1.1)
    for n in 0...Int((stop-1.1)*120) {_=toy.frame(1.1+Double(n)/120)}
    let before=toy.frame(stop)
    var finish=toy;finish.finish(stop)
    toy.park(stop)
    check(toy.isOut && !toy.dragging,"Petting must keep the ball available")
    let initial=toy.frame(stop,canBat:false)
    check(initial.position==before.position && initial.rotation==before.rotation,"Parking cannot teleport or respin a supported rolling ball")
    let hits=toy.hits
    for n in 0...61 {
     let t=stop+Double(n)/120,a=toy.frame(t,canBat:false),b=finish.frame(t)
     check(abs(a.paw-b.paw)<1e-10 && abs(a.pawElbow-b.pawElbow)<1e-10 && abs(a.pawWrist-b.pawWrist)<1e-10,"Parking retains the accepted paw finish curve")
     check(a.position==initial.position && a.opacity==1,"The ball remains still and visible throughout petting")
    }
    _=toy.frame(stop+20)
    check(toy.isOut && !toy.isEngaged(stop+20) && toy.hits==hits,"A parked ball must not reserve active play or replay a bat")
    toy.grab(stop+21);toy.move(to:CGPoint(x:0.62,y:0.38),at:stop+21);toy.release(stop+21.1)
    for n in 0...180 {_=toy.frame(stop+21.1+Double(n)/60)}
    check(toy.hits==hits+1,"A new grab responds once without reopening the menu")
    toy.finish(stop+25,immediate:true)
    check(!toy.isPresent && toy.frame(stop+100).opacity==0,"Hide/rest leaves no delayed resurrection")
   }
  }
  var drop=CatToy();drop.start(0);drop.grab(1);drop.move(to:CGPoint(x:0.60,y:0.355),at:1);drop.release(1.1)
  _=drop.frame(1.14);var uninterrupted=drop;drop.park(1.14)
  for n in 0...16 {
   let t=1.14+Double(n)/120
   check(drop.frame(t,canBat:false).position==uninterrupted.frame(t,canBat:false).position,"Petting must not alter an in-flight 160ms drop")
  }
  for delay in [0.0,0.1,0.25,0.49] {
   var quick=CatToy();quick.start(0);quick.grab(1);quick.move(to:CGPoint(x:0.55,y:0.39),at:1);quick.release(1.1)
   for n in 0...60 {_=quick.frame(1.1+Double(n)/120)}
   quick.park(1.6);let before=quick.frame(1.6+delay,canBat:false)
   quick.grab(1.6+delay);let after=quick.frame(1.6+delay,canBat:false)
   check(before.position==after.position && before.rotation==after.rotation && before.paw==after.paw && before.pawElbow==after.pawElbow && before.pawWrist==after.pawWrist,"Fast regrab during parking preserves the visible paw and ball")
  }
  var toy=CatToy();toy.start(0)
  check(!toy.isEngaged(10) && toy.frame(15).opacity==1,"An untouched visible ball settles without disappearing")
  toy.grab(16);toy.move(to:CGPoint(x:0.55,y:0.36),at:16)
  check(toy.guide != nil && toy.guide!.contains(0.55) && !toy.guide!.contains(0.45),"Guide includes a reachable ball, excludes a distant position")
  toy.release(16.1);check(toy.guide == nil,"No guide persists after release")
  for n in 0...600 {_=toy.frame(16.1+Double(n)/60)}
  let idle=toy.frame(27)
  check(idle.paw==0 && idle.look==0 && idle.attention==0 && !toy.isEngaged(27),"Finite rest state permits exact idle cache reuse")
  toy.park(27,reduced:true)
  check(toy.frame(27,reduced:true).paw==0 && toy.frame(27,reduced:true).opacity==1,"Reduced motion parks without an animated paw")
  print("PASS parking: preserved finish, no teleport/replay, resume, finite idle, guide and cancellation")
 }
}
