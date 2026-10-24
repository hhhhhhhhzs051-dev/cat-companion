import Foundation

@main struct CompletionDeliveryTests {
    static func main() {
        let all: Set<CatGrowthGoal> = [.pet, .play]
        var feedback = CatCompletionFeedback()
        feedback.record(completed: all, day: 20261018, companionDays: 2, at: 0, sample: 0)
        for time in stride(from: 0.0, through: 60.0, by: 0.5) {
            precondition(feedback.text(at: time, available: true, blocked: true) == nil)
        }
        precondition(feedback.text(at: 61, available: true, blocked: false)?.contains("第 2 天") == true,
                     "busy play must not consume an unshown completion after 20 seconds")
        feedback.cancel()
        precondition(feedback.text(at: 62, available: true, blocked: false) == nil, "resuming alone must stay silent")
        feedback.record(completed: all, day: 20261018, companionDays: 2, at: 63, sample: 1)
        precondition(feedback.text(at: 64, available: true, blocked: false)?.contains("第 2 天") == true,
                     "next deliberate interaction may retry an unshown completion without rescoring")
        precondition(feedback.shownDay == 0, "returning a text value is not a visible delivery")
        precondition(feedback.didRender("其他短句", at: 65) == nil)
        let text = feedback.text(at: 70, available: true, blocked: false)!
        precondition(feedback.didRender(text, at: 70) == 20261018)
        precondition(feedback.text(at: 72.9, available: true, blocked: false) == text, "readable time starts at actual paint")
        precondition(feedback.text(at: 73.1, available: true, blocked: false) == nil)
        feedback.cancel()
        feedback.record(completed: all, day: 20261018, companionDays: 2, at: 80, sample: 5)
        precondition(feedback.text(at: 90, available: true, blocked: false) == nil, "painted day cannot repeat after hide or input")
        var restarted = CatCompletionFeedback(shownDay: 20261018)
        restarted.record(completed: all, day: 20261018, companionDays: 2, at: 0, sample: 3)
        precondition(restarted.text(at: 2, available: true, blocked: false) == nil, "restored receipt suppresses same-day repetition")
        restarted.record(completed: [.pet], day: 20261019, companionDays: 3, at: 3, sample: 3)
        precondition(restarted.text(at: 5, available: true, blocked: false) == nil)
        restarted.record(completed: all, day: 20261019, companionDays: 3, at: 6, sample: 3)
        precondition(restarted.text(at: 8, available: true, blocked: false)?.contains("第 3 天") == true)
        precondition(restarted.text(at: 9, available: false, blocked: false) == nil)
        precondition(restarted.text(at: 10, available: true, blocked: false) == nil)
        restarted.record(completed: [.pet], day: 20261020, companionDays: 4, at: 11, sample: 3)
        precondition(restarted.text(at: 12, available: true, blocked: false) == nil, "next day cannot replay yesterday's pending phrase")
        print("PASS retained completion: prolonged busy play, silent resume, deliberate-input retry")
    }
}
