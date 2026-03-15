import SwiftUI
import FirebaseFirestore

struct ProfessorTabView: View {
    @State private var previewAsStudent = false

    var body: some View {
        if previewAsStudent {
            StudentTabView()
                .overlay(alignment: .bottom) {
                    Button {
                        previewAsStudent = false
                    } label: {
                        Label("Back to Professor View", systemImage: "graduationcap.fill")
                            .font(.caption).fontWeight(.semibold)
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .shadow(radius: 4)
                    }
                    .padding(.bottom, 90)
                }
        } else {
            TabView {
                ProfessorAdminView()
                    .tabItem {
                        Label("Courses", systemImage: "books.vertical.fill")
                    }
                ProfessorStudentsView()
                    .tabItem {
                        Label("Students", systemImage: "person.3.fill")
                    }
                ProfessorPreviewTab(previewAsStudent: $previewAsStudent)
                    .tabItem {
                        Label("Preview", systemImage: "eye.fill")
                    }
            }
            .tint(Color(hex: "4361ee"))
        }
    }
}

struct ProfessorPreviewTab: View {
    @Binding var previewAsStudent: Bool
    @EnvironmentObject var auth: AuthService
    @State private var students: [AppUser] = []
    @State private var isLoadingStudents = true
    private let db = Firestore.firestore()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isLoadingStudents {
                        SwiftUI.ProgressView()
                    } else if students.isEmpty {
                        Text("No students have signed in yet.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(students) { student in
                            NavigationLink(destination: StudentPreviewView(student: student)) {
                                StudentRow(student: student)
                            }
                        }
                    }
                } header: {
                    Text("Preview as Student")
                } footer: {
                    Text("Select a student to see exactly what they see in the app.")
                }

                Section {
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
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
        isLoadingStudents = false
    }
}

// MARK: - Student Preview (read-only student view for a specific user)

struct StudentPreviewView: View {
    let student: AppUser
    @EnvironmentObject var firestore: FirestoreService
    @State private var enrolledCourses: [Course] = []
    @State private var upcomingAssignments: [Assignment] = []
    @State private var isLoading = true
    private let db = Firestore.firestore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header — mirrors DashboardView
                VStack(alignment: .leading, spacing: 4) {
                    Text("Good morning,")
                        .font(.title2).foregroundColor(.secondary)
                    Text(student.displayName.components(separatedBy: " ").first ?? "Student")
                        .font(.system(size: 32, weight: .black))
                }
                .padding(.horizontal)

                if isLoading {
                    SwiftUI.ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    // Upcoming assignments
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming").font(.headline).padding(.horizontal)
                        if upcomingAssignments.isEmpty {
                            EmptyStateCard(icon: "checkmark.circle", title: "All caught up!", subtitle: "No upcoming assignments.")
                                .padding(.horizontal)
                        } else {
                            ForEach(upcomingAssignments.prefix(5)) { a in
                                AssignmentCard(assignment: a, courses: enrolledCourses)
                                    .padding(.horizontal)
                            }
                        }
                    }

                    // Enrolled courses
                    VStack(alignment: .leading, spacing: 12) {
                        Text("My Courses").font(.headline).padding(.horizontal)
                        if enrolledCourses.isEmpty {
                            EmptyStateCard(icon: "books.vertical", title: "No courses", subtitle: "Student hasn't enrolled yet.")
                                .padding(.horizontal)
                        } else {
                            ForEach(enrolledCourses) { course in
                                CourseCard(course: course).padding(.horizontal)
                            }
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("\(student.displayName.components(separatedBy: " ").first ?? "Student")'s View")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    private func loadData() async {
        guard !student.enrolledCourses.isEmpty else { isLoading = false; return }
        do {
            let snap = try await db.collection("courses")
                .whereField(FieldPath.documentID(), in: student.enrolledCourses)
                .getDocuments()
            enrolledCourses = try snap.documents.compactMap { try $0.data(as: Course.self) }
            let ids = enrolledCourses.compactMap { $0.id }
            upcomingAssignments = try await firestore.fetchUpcomingAssignments(for: ids)
        } catch { print(error) }
        isLoading = false
    }
}
