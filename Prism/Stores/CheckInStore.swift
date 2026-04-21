import Combine
import Foundation

@MainActor
final class CheckInStore: ObservableObject {
    @Published private(set) var checkIns: [DailyCheckIn] = [] {
        didSet {
            guard automaticallyPersists else { return }
            save()
        }
    }
    @Published private(set) var firstUseDate: Date

    private let saveKey: String
    private let firstUseDateKey: String
    private let legacySaveKeys: [String]
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let automaticallyPersists: Bool
    private let syncService: FirebaseBackupService?
    private let authSession: AuthSessionStore?

    init(
        userDefaults: UserDefaults = .standard,
        saveKey: String = "orbit.checkins.v2",
        firstUseDateKey: String = "orbit.first-use-date.v1",
        legacySaveKeys: [String] = ["orbit.checkins.v1"],
        calendar: Calendar = .current,
        automaticallyPersists: Bool = true,
        syncService: FirebaseBackupService? = nil,
        authSession: AuthSessionStore? = nil
    ) {
        self.userDefaults = userDefaults
        self.saveKey = saveKey
        self.firstUseDateKey = firstUseDateKey
        self.legacySaveKeys = legacySaveKeys
        self.calendar = calendar
        self.automaticallyPersists = automaticallyPersists
        self.syncService = syncService
        self.authSession = authSession
        self.firstUseDate = calendar.startOfDay(for: .now)
        load()
        resolveFirstUseDate()
    }

    func upsertToday(
        career: Int,
        health: Int,
        social: Int,
        careerNote: String,
        healthNote: String,
        socialNote: String
    ) {
        upsert(
            for: calendar.startOfDay(for: .now),
            career: career,
            health: health,
            social: social,
            careerNote: careerNote,
            healthNote: healthNote,
            socialNote: socialNote
        )
    }

    func upsert(
        date: Date,
        career: Int,
        health: Int,
        social: Int,
        careerNote: String,
        healthNote: String,
        socialNote: String
    ) {
        upsert(
            for: date,
            career: career,
            health: health,
            social: social,
            careerNote: careerNote,
            healthNote: healthNote,
            socialNote: socialNote
        )
    }

    func todayCheckIn() -> DailyCheckIn? {
        checkIns.first(where: { calendar.isDateInToday($0.date) })
    }

    func checkIn(on date: Date) -> DailyCheckIn? {
        let day = calendar.startOfDay(for: date)
        return checkIns.first(where: { calendar.isDate($0.date, inSameDayAs: day) })
    }

    func average(for domain: Domain, last days: Int) -> Double {
        let items = recentCheckIns(days: days)
        guard !items.isEmpty else { return 0 }

        let total = items.reduce(0) { partial, item in
            partial + item.score(for: domain)
        }

        return Double(total) / Double(items.count)
    }

    func overallAverage(last days: Int) -> Double {
        let items = recentCheckIns(days: days)
        guard !items.isEmpty else { return 0 }

        let total = items.reduce(0.0) { partial, item in
            partial + item.averageScore
        }

        return total / Double(items.count)
    }

    func recentCheckIns(days: Int) -> [DailyCheckIn] {
        guard
            let start = calendar.date(
                byAdding: .day,
                value: -(days - 1),
                to: calendar.startOfDay(for: .now)
            )
        else {
            return checkIns
        }

        return checkIns
            .filter { $0.date >= start }
            .sorted { $0.date < $1.date }
    }

    func chartPoints(days: Int) -> [DomainPoint] {
        recentCheckIns(days: days).map { item in
            DomainPoint(date: item.date, score: item.averageScore)
        }
    }

    func streakCount() -> Int {
        let days = Set(checkIns.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var cursor = calendar.startOfDay(for: .now)

        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }

    func insightText() -> String {
        let recent = recentCheckIns(days: 7)
        guard let latest = recent.last else {
            return "Start your first daily check-in to get Prism moving."
        }

        if recent.count >= 3 {
            let lastThree = Array(recent.suffix(3))
            let averages = Dictionary(uniqueKeysWithValues: Domain.allCases.map { domain in
                let total = lastThree.reduce(0) { $0 + $1.score(for: domain) }
                return (domain, total / lastThree.count)
            })

            if averages[.health, default: 0] <= 4 {
                return "Health has been low for a few days. Protect sleep, movement, and recovery before pushing harder elsewhere."
            }

            if averages[.social, default: 0] <= 4 {
                return "Social energy looks thin. One small reach-out today could shift the whole week."
            }

            if averages[.career, default: 0] >= 8 &&
                (averages[.health, default: 0] <= 5 || averages[.social, default: 0] <= 5) {
                return "Career is strong, but Prism sees imbalance building. Hold the win without letting the rest of life drift."
            }
        }

        return "Today’s weakest area is \(latest.weakestDomain.rawValue.lowercased()). A tiny improvement there will likely give you the best return tomorrow."
    }

    private func upsert(
        for date: Date,
        career: Int,
        health: Int,
        social: Int,
        careerNote: String,
        healthNote: String,
        socialNote: String
    ) {
        let day = calendar.startOfDay(for: date)
        updateFirstUseDateIfNeeded(with: day)

        if let index = checkIns.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            checkIns[index].career = career
            checkIns[index].health = health
            checkIns[index].social = social
            checkIns[index].careerNote = careerNote
            checkIns[index].healthNote = healthNote
            checkIns[index].socialNote = socialNote
            checkIns[index].updatedAt = .now
        } else {
            checkIns.append(
                DailyCheckIn(
                    date: day,
                    updatedAt: .now,
                    career: career,
                    health: health,
                    social: social,
                    careerNote: careerNote,
                    healthNote: healthNote,
                    socialNote: socialNote
                )
            )
        }

        checkIns.sort { $0.date < $1.date }
    }

    func synchronizeWithCloud() async {
        guard
            let syncService,
            let userID = authSession?.currentUser?.uid
        else {
            return
        }

        do {
            let merged = try await syncService.synchronizeCheckIns(checkIns, userID: userID)
            if merged != checkIns {
                checkIns = merged
                resolveFirstUseDate()
            }
        } catch {
            print("Error:", error)
        }
    }

    func flushCloudSyncNow() async {
        guard
            let syncService,
            let userID = authSession?.currentUser?.uid
        else {
            return
        }

        do {
            try await syncService.pushCheckIns(checkIns, userID: userID)
        } catch {
            print("Error:", error)
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(checkIns)
            userDefaults.set(data, forKey: saveKey)
        } catch {
            assertionFailure("Failed saving check-ins: \(error)")
        }
    }

    private func load() {
        if let data = userDefaults.data(forKey: saveKey) {
            decodeCheckIns(from: data)
            return
        }

        for legacyKey in legacySaveKeys {
            guard let data = userDefaults.data(forKey: legacyKey) else { continue }
            decodeCheckIns(from: data)
            if !checkIns.isEmpty {
                save()
            }
            return
        }
    }

    private func decodeCheckIns(from data: Data) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            checkIns = try decoder.decode([DailyCheckIn].self, from: data).sorted { $0.date < $1.date }
        } catch {
            assertionFailure("Failed loading check-ins: \(error)")
            checkIns = []
        }
    }

    private func resolveFirstUseDate() {
        let inferredFirstUseDate = checkIns.map(\.date).min() ?? calendar.startOfDay(for: .now)

        if let savedFirstUseDate = userDefaults.object(forKey: firstUseDateKey) as? Date {
            let normalizedSavedDate = calendar.startOfDay(for: savedFirstUseDate)
            let resolvedDate = min(normalizedSavedDate, inferredFirstUseDate)
            firstUseDate = resolvedDate
            userDefaults.set(resolvedDate, forKey: firstUseDateKey)
            return
        }

        firstUseDate = inferredFirstUseDate
        userDefaults.set(inferredFirstUseDate, forKey: firstUseDateKey)
    }

    private func updateFirstUseDateIfNeeded(with date: Date) {
        let normalizedDate = calendar.startOfDay(for: date)
        guard normalizedDate < firstUseDate else { return }
        firstUseDate = normalizedDate
        userDefaults.set(normalizedDate, forKey: firstUseDateKey)
    }
}
