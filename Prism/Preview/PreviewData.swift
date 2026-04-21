import Foundation

extension CheckInStore {
    static var preview: CheckInStore {
        let defaults = UserDefaults(suiteName: "PrismPreview-\(UUID().uuidString)")!

        let store = CheckInStore(
            userDefaults: defaults,
            saveKey: "orbit.preview.checkins",
            automaticallyPersists: false
        )

//        store.loadPreviewData(
//            [
//                DailyCheckIn(
//                    date: daysAgo(6),
//                    career: 6,
//                    health: 7,
//                    social: 5,
//                    careerNote: "Made steady progress on a hard task.",
//                    healthNote: "Meals and sleep were pretty solid.",
//                    socialNote: "Quiet evening, not much connection today."
//                ),
//                DailyCheckIn(date: daysAgo(5), career: 7, health: 6, social: 5),
//                DailyCheckIn(
//                    date: daysAgo(4),
//                    career: 8,
//                    health: 5,
//                    social: 4,
//                    careerNote: "Strong momentum and good focus at work.",
//                    healthNote: "Felt stretched and skipped recovery.",
//                    socialNote: "Did not have much energy left for anyone."
//                ),
//                DailyCheckIn(date: daysAgo(3), career: 7, health: 6, social: 6),
//                DailyCheckIn(date: daysAgo(2), career: 6, health: 8, social: 6),
//                DailyCheckIn(date: daysAgo(1), career: 7, health: 7, social: 5),
//                DailyCheckIn(
//                    date: .now,
//                    career: 8,
//                    health: 6,
//                    social: 4,
//                    careerNote: "Wrapped up a meaningful win today.",
//                    healthNote: "Need a little more recovery tomorrow.",
//                    socialNote: "Mostly heads-down and a bit isolated."
//                )
//           ]
//        )

        return store
    }

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
    }
}
