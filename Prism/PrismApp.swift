import SwiftUI
import FirebaseCore
import GoogleSignIn
import UIKit
import Firebase

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        let handledByGoogle = GIDSignIn.sharedInstance.handle(url)
        return handledByGoogle
    }
}

@main
struct PrismApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var store: CheckInStore
    @StateObject private var goals: GoalStore
    @StateObject private var notifications: NotificationManager
    @StateObject private var navigation: AppNavigation
    @StateObject private var feedback: FeedbackManager
    @StateObject private var authSession: AuthSessionStore

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        let authSession = AuthSessionStore()
        let backupService = FirebaseBackupService()

        _store = StateObject(wrappedValue: CheckInStore(
            syncService: backupService,
            authSession: authSession
        ))

        _goals = StateObject(wrappedValue: GoalStore(
            syncService: backupService,
            authSession: authSession
        ))

        _notifications = StateObject(wrappedValue: NotificationManager())
        _navigation = StateObject(wrappedValue: AppNavigation())
        _feedback = StateObject(wrappedValue: FeedbackManager())
        _authSession = StateObject(wrappedValue: authSession)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
                .environmentObject(goals)
                .environmentObject(notifications)
                .environmentObject(navigation)
                .environmentObject(feedback)
                .environmentObject(authSession)
                .preferredColorScheme(.dark)
                .task {
                    authSession.start()
                    await notifications.refreshAuthorizationStatus()
                    await notifications.syncScheduledReminderIfNeeded()
                }
                .task(id: authSession.currentUser?.uid) {
                    guard authSession.currentUser != nil else { return }
                    await store.synchronizeWithCloud()
                    await goals.synchronizeWithCloud()
                }
        }
    }
}
