import Foundation
import CoreGraphics

@main struct GrowthTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let first = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 12))!
        func day(_ offset: Int) -> Date { calendar.date(byAdding: .day, value: offset, to: first)! }
        var growth = CatGrowth(date: first, calendar: calendar)
        precondition(growth.points == 0 && growth.completed.isEmpty)
        precondition(growth.record(.pet, at: first), "first real pet should count")
        for _ in 0..<100 { precondition(!growth.record(.pet, at: first)) }
        precondition(growth.points == 1 && growth.companionDays == 1)
        precondition(growth.record(.play, at: first))
        precondition(!growth.record(.play, at: first))
        precondition(growth.points == 2 && growth.unlocked(.sageBall) && !growth.unlocked(.flower))
        growth.refresh(at: day(1))
        precondition(growth.completed.isEmpty && growth.points == 2 && growth.companionDays == 1)
        // Turning the clock backward neither opens an old day nor awards new points.
        precondition(!growth.record(.pet, at: day(0)))
        precondition(growth.points == 2 && growth.completed.isEmpty)
        precondition(growth.record(.pet, at: day(1)))
        precondition(growth.record(.play, at: day(1)))
        growth.refresh(at: day(30))
        precondition(growth.points == 4 && growth.companionDays == 2, "absence is not punished")
        precondition(growth.record(.pet, at: day(30)))
        precondition(growth.record(.play, at: day(30)))
        precondition(!growth.unlocked(.flower) && !growth.unlocked(.fish))
        for offset in 31...33 {
            precondition(growth.record(.pet, at: day(offset)))
            precondition(growth.record(.play, at: day(offset)))
        }
        precondition(growth.points == 12 && growth.companionDays == 6 && growth.unlocked(.flower) && !growth.unlocked(.fish))
        for offset in 34...43 {
            precondition(growth.record(.pet, at: day(offset)))
            precondition(growth.record(.play, at: day(offset)))
        }
        precondition(growth.points == 32 && growth.companionDays == 16 && growth.unlocked(.fish))
        precondition(CatGrowth(date: first).points == 0, "preview sessions are isolated")
        var drag = CatGrowthDrag()
        precondition(!drag.release())
        drag.begin(.zero); precondition(!drag.release(), "taking out or tapping is not a play goal")
        drag.begin(.zero); drag.move(CGPoint(x: 0.01, y: 0)); precondition(!drag.release())
        drag.begin(.zero); drag.move(CGPoint(x: 0.04, y: 0)); drag.move(.zero)
        precondition(drag.release(), "a real moved-and-returned drag still counts")
        precondition(!drag.release(), "a gesture can only finish once")
        drag.begin(.zero); drag.move(CGPoint(x: 0.1, y: 0)); drag.cancel()
        precondition(!drag.release(), "hide, rest and cancellation must not count")
        print("PASS growth: daily cap, rollover, rollback, absence, all rewards, session isolation, real drag and cancellation")
    }
}
