import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var navigation: AppNavigation
    @EnvironmentObject private var feedback: FeedbackManager

    var body: some View {
        ZStack {
            PrismAmbientBackground()

            TabView(selection: $navigation.selectedTab) {
                DashboardView()
                    .tag(AppTab.today)
                    .tabItem {
                        Label("Prism", systemImage: "triangle")
                            .symbolVariant(.none)
                    }

                ProgressScreen()
                    .tag(AppTab.progress)
                    .tabItem {
                        Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
                    }

                GoalsView()
                    .tag(AppTab.goals)
                    .tabItem {
                        Label("Goals", systemImage: "target")
                    }

                SettingsView()
                    .tag(AppTab.settings)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape.fill")
                    }
            }
        }
        .environment(\.orbitMotionEnabled, feedback.motionEffectsEnabled)
        .onChange(of: navigation.selectedTab) { _ in
            feedback.perform(.tab)
        }
    }
}

struct RootTabView_Previews: PreviewProvider {
    static var previews: some View {
        RootTabView()
            .environmentObject(CheckInStore.preview)
            .environmentObject(GoalStore())
            .environmentObject(NotificationManager())
            .environmentObject(AppNavigation())
            .environmentObject(FeedbackManager())
    }
}
