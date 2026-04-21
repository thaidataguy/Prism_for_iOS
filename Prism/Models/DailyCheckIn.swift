import Foundation

struct DailyCheckIn: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    var updatedAt: Date
    var career: Int
    var health: Int
    var social: Int
    var careerNote: String
    var healthNote: String
    var socialNote: String

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case updatedAt
        case career
        case health
        case social
        case careerNote
        case healthNote
        case socialNote
        case note
    }

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        updatedAt: Date = Date(),
        career: Int,
        health: Int,
        social: Int,
        careerNote: String = "",
        healthNote: String = "",
        socialNote: String = ""
    ) {
        self.id = id
        self.date = date < Date(timeIntervalSince1970: 0) ? Date() : date
        self.updatedAt = Date()
        self.career = career
        self.health = health
        self.social = social
        self.careerNote = careerNote
        self.healthNote = healthNote
        self.socialNote = socialNote
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacyNote = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        let decodedDate = try container.decode(Date.self, forKey: .date)

        id = try container.decode(UUID.self, forKey: .id)
        date = Calendar.current.startOfDay(for: decodedDate)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? decodedDate
        career = try container.decode(Int.self, forKey: .career)
        health = try container.decode(Int.self, forKey: .health)
        social = try container.decode(Int.self, forKey: .social)
        careerNote = try container.decodeIfPresent(String.self, forKey: .careerNote) ?? legacyNote
        healthNote = try container.decodeIfPresent(String.self, forKey: .healthNote) ?? legacyNote
        socialNote = try container.decodeIfPresent(String.self, forKey: .socialNote) ?? legacyNote
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(career, forKey: .career)
        try container.encode(health, forKey: .health)
        try container.encode(social, forKey: .social)
        try container.encode(careerNote, forKey: .careerNote)
        try container.encode(healthNote, forKey: .healthNote)
        try container.encode(socialNote, forKey: .socialNote)
    }

    var averageScore: Double {
        Double(career + health + social) / 3.0
    }

    var weakestDomain: Domain {
        let pairs: [(Domain, Int)] = [(.career, career), (.health, health), (.social, social)]
        return pairs.min(by: { $0.1 < $1.1 })?.0 ?? .career
    }

    var strongestDomain: Domain {
        let pairs: [(Domain, Int)] = [(.career, career), (.health, health), (.social, social)]
        return pairs.max(by: { $0.1 < $1.1 })?.0 ?? .career
    }

    func score(for domain: Domain) -> Int {
        switch domain {
        case .career:
            return career
        case .health:
            return health
        case .social:
            return social
        }
    }
}
