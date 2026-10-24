import Foundation
@main struct ToyAccessoryPriorityTests {
    static func main(){
        func check(_ ok:Bool,_ text:String){if !ok {print("FAIL toy/accessory priority: \(text)");exit(1)}}
        var toy=CatToy(rollInEnabled:true);toy.start(0)
        check(toy.isEngaged(0.1) && !toy.blocksAccessoryLook(at:0.1),"stationary attention tail may yield")
        toy.grab(0.2)
        check(toy.blocksAccessoryLook(at:0.2),"drag cannot yield")
        toy.move(to:CGPoint(x:0.61,y:0.355),at:0.3);toy.release(0.4)
        check(toy.blocksAccessoryLook(at:0.4),"fall and pending strike cannot yield")
        var control=toy,sawPaw=false,sawSettled=false
        for index in 0...180 {
            let t=0.4+Double(index)/30
            let blocked=toy.blocksAccessoryLook(at:t)
            let a=toy.frame(t),b=control.frame(t)
            check(a==b,"gate must not advance original physics \(index)")
            if a.paw>0 {sawPaw=true;check(blocked,"active paw cannot yield")}
            if t>4 && !blocked {sawSettled=true}
        }
        check(sawPaw && sawSettled,"exercise both strike and settled states")
        toy.start(10);toy.grab(10.1);toy.move(to:CGPoint(x:0.50,y:CatToy.groundY(0.50)),at:10.2);toy.release(10.3)
        check(toy.blocksAccessoryLook(at:10.35),"surface roll/pending strike cannot yield")
        check(toy.blocksAccessoryLook(at:.nan),"nonfinite input fails safe")
        print("PASS read-only physical activity gate: drag, fall, roll, pending strike, paw and stationary tail; physics unchanged")
    }
}
