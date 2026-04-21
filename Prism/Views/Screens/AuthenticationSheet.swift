import AuthenticationServices
import SwiftUI

struct AuthenticationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authSession: AuthSessionStore
    @EnvironmentObject private var feedback: FeedbackManager

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var currentNonce = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Back Up Your Data")
                        .font(.largeTitle.bold())
                        .foregroundStyle(PrismColors.heading)

                    Text("Create an account or sign in so Prism can sync your check-ins and goals across devices.")
                        .foregroundStyle(.secondary)

                    providerButtons
                    emailCard

                    if let errorMessage = authSession.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        PrismColors.heading.opacity(0.10),
                        Color(.systemBackground),
                        PrismColors.social.opacity(0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onChange(of: authSession.currentUser?.uid) { newValue in
                guard newValue != nil else { return }
                dismiss()
            }
            .onDisappear {
                authSession.clearError()
            }
        }
    }

    private var providerButtons: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                currentNonce = AuthSessionStore.makeNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = AuthSessionStore.hashNonce(currentNonce)
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                feedback.perform(.tap)
                Task {
                    await authSession.signInWithGoogle()
                }
            } label: {
                HStack(spacing: 12) {
                    googleMark
                        .frame(width: 20, height: 20)

                    Text("Sign in with Google")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.88))
                        .frame(maxWidth: .infinity)

                    Color.clear
                        .frame(width: 20, height: 20)
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PrismPressableButtonStyle())
        }
    }

    private var emailCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Auth Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)

            Button(mode.buttonTitle) {
                feedback.perform(.tap)
                Task {
                    if mode == .signIn {
                        await authSession.signInWithEmail(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password
                        )
                    } else {
                        await authSession.signUpWithEmail(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password
                        )
                    }
                }
            }
            .buttonStyle(PrismPressableButtonStyle())
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || authSession.isBusy)
            .opacity((email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || authSession.isBusy) ? 0.6 : 1)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var googleMark: some View {
        ZStack {
            Circle()
                .trim(from: 0.00, to: 0.24)
                .stroke(
                    Color(red: 0.26, green: 0.52, blue: 0.96),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
                .rotationEffect(.degrees(5))

            Circle()
                .trim(from: 0.24, to: 0.44)
                .stroke(
                    Color(red: 0.91, green: 0.30, blue: 0.24),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
                .rotationEffect(.degrees(5))

            Circle()
                .trim(from: 0.44, to: 0.69)
                .stroke(
                    Color(red: 0.98, green: 0.74, blue: 0.18),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
                .rotationEffect(.degrees(5))

            Circle()
                .trim(from: 0.69, to: 0.95)
                .stroke(
                    Color(red: 0.20, green: 0.66, blue: 0.33),
                    style: StrokeStyle(lineWidth: 3.2, lineCap: .round)
                )
                .rotationEffect(.degrees(5))

            Rectangle()
                .fill(Color.white)
                .frame(width: 7.5, height: 10)
                .offset(x: 4.5)

            Rectangle()
                .fill(Color(red: 0.26, green: 0.52, blue: 0.96))
                .frame(width: 8, height: 3.2)
                .offset(x: 4, y: 0.5)
        }
        .frame(width: 20, height: 20)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                authSession.errorMessage = "Apple did not return a usable credential."
                return
            }

            guard
                let identityToken = credential.identityToken,
                let idToken = String(data: identityToken, encoding: .utf8)
            else {
                authSession.errorMessage = "Apple did not return an ID token."
                return
            }

            Task {
                await authSession.signInWithApple(
                    idToken: idToken,
                    nonce: currentNonce,
                    fullName: credential.fullName
                )
            }
        case .failure(let error):
            authSession.errorMessage = error.localizedDescription
        }
    }
}

private extension AuthenticationSheet {
    enum Mode: CaseIterable {
        case signIn
        case signUp

        var title: String {
            switch self {
            case .signIn:
                return "Sign In"
            case .signUp:
                return "Sign Up"
            }
        }

        var buttonTitle: String {
            switch self {
            case .signIn:
                return "Sign In with Email"
            case .signUp:
                return "Create Account"
            }
        }
    }
}
