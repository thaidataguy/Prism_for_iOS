import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var authSession: AuthSessionStore
    @EnvironmentObject private var goals: GoalStore
    @EnvironmentObject private var feedback: FeedbackManager
    @State private var isAuthenticationSheetPresented = false
    @State private var isSavingGoals = false
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    pageHeader
                        .orbitEntrance(delay: 0.02)

                    GoalCard(
                        title: Domain.career.rawValue,
                        subtitle: "What active career outcome are you pushing forward right now?",
                        systemImage: Domain.career.systemImage,
                        tint: Domain.career.color,
                        backgroundTint: Domain.career.backgroundColor,
                        text: $goals.careerGoal,
                        placeholder: "Ship the portfolio update, land three interviews, or define the next milestone.",
                        isEditorFocused: $isEditorFocused
                    )
                    .orbitEntrance(delay: 0.08)

                    GoalCard(
                        title: Domain.health.rawValue,
                        subtitle: "What active health goal are you protecting this season?",
                        systemImage: Domain.health.systemImage,
                        tint: Domain.health.color,
                        backgroundTint: Domain.health.backgroundColor,
                        text: $goals.healthGoal,
                        placeholder: "Train three times a week, hit a sleep target, or keep a daily walk streak.",
                        isEditorFocused: $isEditorFocused
                    )
                    .orbitEntrance(delay: 0.14)

                    GoalCard(
                        title: Domain.social.rawValue,
                        subtitle: "What active social goal deserves attention?",
                        systemImage: Domain.social.systemImage,
                        tint: Domain.social.color,
                        backgroundTint: Domain.social.backgroundColor,
                        text: $goals.socialGoal,
                        placeholder: "Reconnect with close friends, plan one dinner a week, or follow up with family.",
                        isEditorFocused: $isEditorFocused
                    )
                    .orbitEntrance(delay: 0.2)

                    saveGoalsButton
                        .orbitEntrance(delay: 0.26)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        PrismColors.heading.opacity(0.10),
                        Color(.systemBackground),
                        PrismColors.health.opacity(0.06)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $isAuthenticationSheetPresented) {
                AuthenticationSheet()
                    .environmentObject(authSession)
                    .environmentObject(feedback)
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goals")
                .font(.largeTitle.bold())
                .foregroundStyle(PrismColors.heading)

            Text("Keep one active goal in view for each pillar so your daily check-ins stay tied to something real.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var saveGoalsButton: some View {
        Button(action: saveGoals) {
            Text(isSavingGoals ? "Saving Goals..." : "Save Goals")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [PrismColors.heading, PrismColors.health],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .disabled(isSavingGoals)
        .opacity(isSavingGoals ? 0.72 : 1)
        .buttonStyle(PrismPressableButtonStyle())
    }

    private func saveGoals() {
        guard !isSavingGoals else { return }

        if authSession.currentUser == nil {
            feedback.perform(.tap)
            isAuthenticationSheetPresented = true
            return
        }

        isEditorFocused = false
        isSavingGoals = true
        feedback.perform(.success)

        Task {
            await goals.flushCloudSyncNow()
            await MainActor.run {
                isSavingGoals = false
            }
        }
    }
}

private struct GoalCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let backgroundTint: Color
    @Binding var text: String
    let placeholder: String
    let isEditorFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.72))

                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(height: 132)
                    .focused(isEditorFocused)

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 17)
                        .allowsHitTesting(false)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(tint.opacity(0.18), lineWidth: 1)
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundTint.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.14), radius: 18, x: 0, y: 10)
    }
}

struct GoalsView_Previews: PreviewProvider {
    static var previews: some View {
        GoalsView()
            .environmentObject(AuthSessionStore())
            .environmentObject(GoalStore())
            .environmentObject(FeedbackManager())
    }
}
