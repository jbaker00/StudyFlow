import SwiftUI

struct ProgressView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var firestore: FirestoreService
    @State private var courses: [Course] = []
    @State private var assignmentsByCourse: [String: [Assignment]] = [:]
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    SwiftUI.ProgressView()
                } else if courses.isEmpty {
                    EmptyStateCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No courses enrolled",
                        subtitle: "Enroll in courses to track progress."
                    )
                    .padding()
                } else {
                    List(courses) { course in
                        let assignments = assignmentsByCourse[course.id ?? ""] ?? []
                        CourseProgressRow(course: course, assignments: assignments)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Progress")
            .task { await loadData() }
        }
    }

    private func loadData() async {
        guard let uid = auth.currentUser?.uid else { return }
        do {
            let enrolled = try await firestore.fetchEnrolledCourses(for: uid)
            courses = enrolled
            for course in enrolled {
                if let cid = course.id {
                    assignmentsByCourse[cid] = try await firestore.fetchAssignments(for: cid)
                }
            }
        } catch { print(error) }
        isLoading = false
    }
}

struct CourseProgressRow: View {
    let course: Course
    let assignments: [Assignment]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: course.color))
                    .frame(width: 10, height: 10)
                Text(course.courseCode).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(assignments.count) assignments").font(.caption).foregroundColor(.secondary)
            }
            Text(course.title).font(.caption).foregroundColor(.secondary).lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
