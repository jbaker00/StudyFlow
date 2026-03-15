import SwiftUI
import FirebaseFirestore

struct ProfessorStudentsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var firestore: FirestoreService
    @State private var students: [AppUser] = []
    @State private var isLoading = true
    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    SwiftUI.ProgressView()
                } else if students.isEmpty {
                    EmptyStateCard(
                        icon: "person.3",
                        title: "No students yet",
                        subtitle: "Students will appear here after they sign in."
                    )
                    .padding()
                } else {
                    List(students) { student in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(Color(hex: "4361ee").opacity(0.15))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(student.displayName.prefix(1))
                                        .fontWeight(.bold)
                                        .foregroundColor(Color(hex: "4361ee"))
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(student.displayName).font(.subheadline).fontWeight(.semibold)
                                Text(student.email).font(.caption).foregroundColor(.secondary)
                                Text("\(student.enrolledCourses.count) course(s) enrolled")
                                    .font(.caption2).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Students")
            .task { await loadStudents() }
        }
    }

    private func loadStudents() async {
        do {
            let snap = try await db.collection("users")
                .whereField("role", isEqualTo: "student")
                .getDocuments()
            students = try snap.documents.compactMap { try $0.data(as: AppUser.self) }
        } catch { print(error) }
        isLoading = false
    }
}
