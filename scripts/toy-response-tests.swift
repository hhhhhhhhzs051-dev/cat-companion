import Foundation
@main struct ToyResponseTests {
 static func main() {
  func check(_ c:Bool,_ m:String) {if !c {fputs("FAIL: \(m)\n",stderr);exit(1)}}
  for x in [0.54,0.57,0.60,0.61,0.64,0.66] {
   var toy=CatToy();toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:x,y:0.355),at:1);toy.release(1.1)
   var firstPaw:Double?=nil,firstRoll:Double?=nil
   for n in 0...120 {
    let elapsed=Double(n)/120,f=toy.frame(1.1+elapsed)
    if firstPaw==nil && f.paw>0.1 {firstPaw=elapsed}
    if firstRoll==nil && abs(f.position.x-x)>0.0001 {firstRoll=elapsed}
   }
   check(firstPaw != nil && firstPaw!<0.32,"High release acknowledges with a paw within 320ms")
   check(firstRoll != nil && firstRoll!<0.75,"Reachable release starts rolling within 750ms")
   for i in 0..<8 {
    let start=2.2+Double(i)*0.9,x=i%2==0 ? 0.57:0.64
    toy.grab(start);toy.move(to:CGPoint(x:x,y:0.355),at:start+0.01);toy.release(start+0.02)
    var responded=false
    for n in 0...106 {
     let f=toy.frame(start+0.02+Double(n)/120)
     if abs(f.position.x-x)>0.0001 {responded=true}
    }
    check(responded,"Repeated releases respond within 890ms, including continuous 350ms paw retraction")
   }
  }
  var tap=CatToy();tap.start(0);tap.grab(1);tap.release(1.1)
  for n in 0...120 {_=tap.frame(1.1+Double(n)/120)}
  check(tap.hits==1,"Grabbing and releasing the visible ball counts even without pixel-perfect movement")
  for n in 0...240 {_=tap.frame(2.2+Double(n)/60)}
  check(tap.hits==1,"One gesture never produces autonomous repeated hits")
  // Early approach and the exact retract/restart boundary moved ahead of the
  // older interruption fixtures when response latency was shortened.
  for elapsed in [0.12,0.24,0.4,0.6,0.8] {
   var toy=CatToy();toy.start(0);toy.grab(1);toy.move(to:CGPoint(x:0.64,y:0.355),at:1);toy.release(1.1)
   let grab=1.1+elapsed
   for n in 0...Int(elapsed*120) {_=toy.frame(1.1+Double(n)/120)}
   let before=toy.frame(grab);toy.grab(grab)
   let grabbed=toy.frame(grab)
   check(before.position==grabbed.position && before.pawElbow==grabbed.pawElbow && before.pawWrist==grabbed.pawWrist,"Early regrab preserves visible ball and both joints exactly")
   toy.move(to:CGPoint(x:0.57,y:0.355),at:grab+0.01);toy.release(grab+0.02)
   var prior=toy.frame(grab+0.02)
   for n in 1...240 {
    let next=toy.frame(grab+0.02+Double(n)/120)
    check(abs(next.pawElbow-prior.pawElbow)<0.12 && abs(next.pawWrist-prior.pawWrist)<0.12,"Rapid reversal is continuous through the old 350ms retraction/new reach handoff")
    prior=next
   }
   check(abs(prior.position.x-0.61)<0.0001,"The newest release, not the cancelled target, receives the response")
  }
  var hint=CatToy();hint.start(0)
  check(hint.guide==nil,"Reach guidance never appears without active user dragging")
  hint.grab(1);hint.move(to:CGPoint(x:0.60,y:0.355),at:1)
  let push=hint.dragZone
  hint.move(to:CGPoint(x:0.64,y:0.355),at:1.1);let pull=hint.dragZone
  hint.move(to:CGPoint(x:0.77,y:0.355),at:1.2);let watch=hint.dragZone
  check(push == .push && pull == .pull && watch == .watch && hint.guide != nil,"Actual response zones remain distinct behind the nonverbal reach guide")
  hint.release(1.3);check(hint.guide==nil,"Release removes guidance without notifications")
  print("PASS response budget: initial/high/repeated releases and stationary click; single response")
 }
}
