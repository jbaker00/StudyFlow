import SwiftUI
import FirebaseFirestore

struct ProfessorStudentsView: View {
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
                        NavigationLink(destination: StudentDetailView(student: student)) {
                            StudentRow(student: student)
                        }
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

// MARK: - Student Row

struct StudentRow: View {
    let student: AppUser

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: "4361ee").opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(student.displayName.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "4361ee"))
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(student.displayName)
                    .font(.subheadline).fontWeight(.semibold)
                Text(student.email)
                    .font(.caption).foregroundColor(.secondary)
                Text("\(student.enrolledCourses.count) course\(student.enrolledCourses.count == 1 ? "" : "s") enrolled")
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Student Detail View

struct StudentDetailView: View {
    let student: AppUser
    @EnvironmentObject var firestore: FirestoreService
    @State private var courses: [Course] = []
    @State private var assignmentsByCourse: [String: [Assignment]] = [:]
    @State private var completedTaskIds: Set<String> = []
    @State private var isLoading = true
    private let db = Firestore.firestore()

    var totalAssignments: Int { assignmentsByCourse.values.reduce(0) { $0 + $1.count } }
    var upcomingAssignments: Int {
        assignmentsByCourse.values.flatMap { $0 }.filter { $0.daysUntilDue >= 0 }.count
    }
    var pastDueAssignments: Int {
        assignmentsByCourse.values.flatMap { $0 }.filter { $0.daysUntilDue < 0 }.count
    }

    var body: some View {
        List {
            // Student info header
            Section {
                HStack(spacing: 16) {
                    Circle()
                        .fill(Color(hex: "4361ee").opacity(0.12))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(student.displayName.prefix(1).uppercased())
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(hex: "4361ee"))
                        )
                    VStack(alignment: .leading, spacing: 4) {
                        Text(student.displayName)
                            .font(.title3).fontWeight(.bold)
                        Text(student.email)
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Stats row
            if !isLoading {
                Section {
                    HStack(spacing: 0) {
                        StatBox(value: "\(courses.count)", label: "Courses")
                        Divider()
                        StatBox(value: "\(upcomingAssignments)", label: "Upcoming")
                        Divider()
                        StatBox(value: "\(pastDueAssignments)", label: "Past Due")
                    }
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Per-course breakdown
            if isLoading {
                Section { SwiftUI.ProgressView() }
            } else if courses.isEmpty {
                Section {
                    Text("Not enrolled in any courses yet.")
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(courses) { course in
                    let assignments = assignmentsByCourse[course.id ?? ""] ?? []
                    Section {
                        // Course header row
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(hex: course.color))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Text(course.courseCode.prefix(3))
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(course.title)
                                    .font(.subheadline).fontWeight(.semibold)
                                Text("\(course.courseCode) · \(course.term)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(assignments.count) assignments")
                                .font(.caption2).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)

                        // Assignment rows
                        ForEach(assignments) { assignment in
                            AssignmentProgressRow(assignment: assignment)
                        }
                    } header: {
                        Text(course.courseCode)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(student.displayName.components(separatedBy: " ").first ?? "Student")
        .navigationBarTitleDisplayMode(.large)
        .task { await loadData() }
    }

    private func loadData() async {
        guard !student.enrolledCourses.isEmpty else {
            isLoading = false
            return
        }
        do {
            // Fetch enrolled courses
            let snap = try await db.collection("courses")
                .whereField(FieldPath.documentID(), in: student.enrolledCourses)
                .getDocuments()
            courses = try snap.documents.compactMap { try $0.data(as: Course.self) }

            // Fetch assignments per course
            for course in courses {
                if let cid = course.id {
                    assignmentsByCourse[cid] = try await firestore.fetchAssignments(for: cid)
                }
            }

            // Fetch this student's task progress
            let progressSnap = try await db.collection("userProgress")
                .document(student.uid)
                .collection("taskProgress")
                .whereField("completed", isEqualTo: true)
                .getDocuments()
            completedTaskIds = Set(progressSnap.documents.map { $0.documentID })
        } catch { print(error) }
        isLoading = false
    }
}

// MARK: - Supporting views

struct StatBox: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

struct AssignmentProgressRow: View {
    let assignment: Assignment

    var urgencyColor: Color {
        if assignment.daysUntilDue < 0 { return .secondary }
        if assignment.daysUntilDue < 3 { return .red }
        if assignment.daysUntilDue < 7 { return .orange }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: typeIcon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(assignment.title)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Text(assignment.daysUntilDue < 0 ? "Past due" :
                 assignment.daysUntilDue == 0 ? "Due today" :
                 "Due \(assignment.dueDateFormatted)")
                .font(.caption2)
                .foregroundColor(urgencyColor)
        }
        .padding(.vertical, 2)
    }

    private var typeIcon: String {
        switch assignment.type {
        case .reading: return "book"
        case .essay: return "doc.text"
        case .quiz, .exam: return "pencil.and.list.clipboard"
        case .project: return "folder"
        case .presentation: return "person.wave.2"
        default: return "checkmark.circle"
        }
    }
}
