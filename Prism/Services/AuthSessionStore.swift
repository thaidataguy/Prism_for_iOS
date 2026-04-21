import AuthenticationServices
import Combine
import CryptoKit
import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
import SwiftUI
import UIKit

@MainActor
final class AuthSessionStore: ObservableObject {
    struct UserProfile: Equatable {
        let uid: String
        let email: String?
        let displayName: String?
        let providerIDs: [String]
    }

    @Published private(set) var currentUser: UserProfile?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
    }

    func start() {
        guard authStateHandle == nil else { return }

        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user.map(Self.makeUserProfile)
            }
        }
    }

    func signInWithGoogle() async {
        guard let presentingViewController = Self.presentingViewController() else {
            errorMessage = "Unable to present Google sign-in from the current screen."
            return
        }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase Google client ID is missing."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthFlowError.missingCredential
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        isBusy = true
        defer { isBusy = false }

        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithEmail(email: String, password: String) async {
        isBusy = true
        defer { isBusy = false }

        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithApple(idToken: String, nonce: String, fullName: PersonNameComponents?) async {
        isBusy = true
        defer { isBusy = false }

        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: nonce,
                fullName: fullName
            )
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }

    static func makeNonce() -> String {
        UUID().uuidString + UUID().uuidString
    }

    static func hashNonce(_ nonce: String) -> String {
        let input = Data(nonce.utf8)
        let hashed = SHA256.hash(data: input)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }

    private static func presentingViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController?
            .topMostViewController()
    }

    private static func makeUserProfile(from user: User) -> UserProfile {
        UserProfile(
            uid: user.uid,
            email: user.email,
            displayName: user.displayName,
            providerIDs: user.providerData.map(\.providerID)
        )
    }
}

private enum AuthFlowError: LocalizedError {
    case cancelled
    case missingCredential

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "The sign-in flow was cancelled."
        case .missingCredential:
            return "The sign-in provider did not return a usable credential."
        }
    }
}

private extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presentedViewController {
            return presentedViewController.topMostViewController()
        }

        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.topMostViewController() ?? navigationController
        }

        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.topMostViewController() ?? tabBarController
        }

        return self
    }
}
