import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoading = true
    @Published var error: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let db = Firestore.firestore()

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                await self?.handleAuthChange(firebaseUser)
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Sign In

    func signInWithGoogle() async {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else { return }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            await upsertUser(firebaseUser: authResult.user)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
    }

    // MARK: - Firestore User

    private func handleAuthChange(_ firebaseUser: FirebaseAuth.User?) async {
        guard let firebaseUser else {
            isLoading = false
            currentUser = nil
            return
        }
        do {
            let snap = try await db.collection("users").document(firebaseUser.uid).getDocument()
            if snap.exists {
                currentUser = try snap.data(as: AppUser.self)
            }
            isLoading = false
        } catch {
            isLoading = false
        }
    }

    private func upsertUser(firebaseUser: FirebaseAuth.User) async {
        let ref = db.collection("users").document(firebaseUser.uid)
        let email = firebaseUser.email ?? ""
        do {
            let snap = try await ref.getDocument()
            if !snap.exists {
                let role = await resolveRole(for: email)
                let newUser = AppUser(
                    uid: firebaseUser.uid,
                    email: email,
                    displayName: firebaseUser.displayName ?? email,
                    role: role,
                    enrolledCourses: []
                )
                try ref.setData(from: newUser)
                if role == .professor {
                    await migrateProfessorCourses(uid: firebaseUser.uid, email: email)
                }
            } else {
                try await ref.setData(["lastLoginAt": Timestamp()], merge: true)
                let existingSnap = try await ref.getDocument()
                if let existingUser = try? existingSnap.data(as: AppUser.self), existingUser.isProfessor {
                    await migrateProfessorCourses(uid: firebaseUser.uid, email: email)
                }
            }
            let updated = try await ref.getDocument()
            currentUser = try updated.data(as: AppUser.self)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func migrateProfessorCourses(uid: String, email: String) async {
        let snap = try? await db.collection("courses")
            .whereField("professorId", isEqualTo: email)
            .getDocuments()
        guard let docs = snap?.documents, !docs.isEmpty else { return }
        let batch = db.batch()
        for doc in docs {
            batch.updateData(["professorId": uid], forDocument: doc.reference)
        }
        try? await batch.commit()
    }

    private func resolveRole(for email: String) async -> UserRole {
        do {
            let snap = try await db.collection("settings").document("professors").getDocument()
            let emails = snap.get("emails") as? [String] ?? []
            return emails.contains(email.lowercased()) ? .professor : .student
        } catch {
            return .student
        }
    }
}
