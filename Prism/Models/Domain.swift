import SwiftUI

enum Domain: String, CaseIterable, Codable, Identifiable {
    case career = "Career"
    case health = "Health"
    case social = "Social"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .career:
            return "briefcase.fill"
        case .health:
            return "heart.fill"
        case .social:
            return "person.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .career:
            return PrismColors.career
        case .health:
            return PrismColors.health
        case .social:
            return PrismColors.social
        }
    }

    var backgroundColor: Color {
        switch self {
        case .career:
            return PrismColors.careerBackground
        case .health:
            return PrismColors.healthBackground
        case .social:
            return PrismColors.socialBackground
        }
    }
}
