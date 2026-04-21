import Combine
import SwiftUI

enum AppTab: Hashable {
    case today
    case progress
    case goals
    case settings
}

@MainActor
final class AppNavigation: ObservableObject {
    @Published var selectedTab: AppTab = .today
}
