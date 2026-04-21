import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var authSession: AuthSessionStore
    @EnvironmentObject private var store: CheckInStore
    @EnvironmentObject private var goals: GoalStore
    @EnvironmentObject private var notifications: NotificationManager
    @EnvironmentObject private var feedback: FeedbackManager
    @State private var isAuthenticationSheetPresented = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.largeTitle.bold())
                    .foregroundStyle(PrismColors.heading)
                    .padding(.horizontal)
                    .padding(.top)

                Form {
                    Section("Feedback") {
                        Toggle("Sound effects", isOn: soundEffectsBinding)
                        Toggle("Animations", isOn: motionEffectsBinding)
                    }

                    Section("Daily reminder") {
                        if notifications.isAuthorized {
                            DatePicker(
                                "Reminder time",
                                selection: reminderTimeBinding,
                                displayedComponents: .hourAndMinute
                            )
                        } else {
                            Button("Enable notifications") {
                                feedback.perform(.tap)
                                Task {
                                    await notifications.requestPermission()
                                }
                            }
                            .buttonStyle(PrismPressableButtonStyle())
                        }
                    }

                    Section("Backup") {
                        if authSession.currentUser == nil {
                            Button("Sign In to Backup Data") {
                                feedback.perform(.tap)
                                isAuthenticationSheetPresented = true
                            }
                            .buttonStyle(PrismPressableButtonStyle())
                        } else {
                            Button("Sign Out") {
                                feedback.perform(.tap)
                                authSession.signOut()
                            }
                            .buttonStyle(PrismPressableButtonStyle())
                        }
                    }

                    Section("About Prism") {
                        Text("Prism helps you track your life through three daily signals: career, health, and social.")
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAuthenticationSheetPresented) {
                AuthenticationSheet()
                    .environmentObject(authSession)
                    .environmentObject(feedback)
            }
        }
    }

    private var soundEffectsBinding: Binding<Bool> {
        Binding(
            get: {
                feedback.soundEffectsEnabled
            },
            set: { isEnabled in
                feedback.setSoundEffectsEnabled(isEnabled)
                if isEnabled {
                    feedback.perform(.selection)
                }
            }
        )
    }

    private var motionEffectsBinding: Binding<Bool> {
        Binding(
            get: {
                feedback.motionEffectsEnabled
            },
            set: { isEnabled in
                feedback.setMotionEffectsEnabled(isEnabled)
                feedback.perform(.selection)
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(
                        hour: notifications.reminderHour,
                        minute: notifications.reminderMinute
                    )
                ) ?? .now
            },
            set: { newValue in
                feedback.perform(.selection)
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                notifications.scheduleDailyReminder(
                    hour: components.hour ?? 20,
                    minute: components.minute ?? 0
                )
            }
        )
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AuthSessionStore())
            .environmentObject(CheckInStore())
            .environmentObject(GoalStore())
            .environmentObject(NotificationManager())
            .environmentObject(FeedbackManager())
    }
}
