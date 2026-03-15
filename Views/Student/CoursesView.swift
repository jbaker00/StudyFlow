import SwiftUI

struct CoursesView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var firestore: FirestoreService
    @State private var allCourses: [Course] = []
    @State private var enrolledIds: Set<String> = []
    @State private var isLoading = true
    @State private var selectedCourse: Course?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if allCourses.isEmpty {
                    EmptyStateCard(
                        icon: "books.vertical",
                        title: "No courses available",
                        subtitle: "Check back later."
                    )
                    .padding()
                } else {
                    List(allCourses) { course in
                        CourseEnrollRow(
                            course: course,
                            isEnrolled: enrolledIds.contains(course.id ?? "")
                        ) {
                            Task { await toggleEnroll(course) }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Courses")
            .task { await loadData() }
        }
    }

    private func loadData() async {
        guard let uid = auth.currentUser?.uid else { return }
        do {
            async let all = firestore.fetchAllCourses()
            async let enrolled = firestore.fetchEnrolledCourses(for: uid)
            let (a, e) = try await (all, enrolled)
            allCourses = a
            enrolledIds = Set(e.compactMap { $0.id })
        } catch { print(error) }
        isLoading = false
    }

    private func toggleEnroll(_ course: Course) async {
        guard let uid = auth.currentUser?.uid, let cid = course.id else { return }
        do {
            if enrolledIds.contains(cid) {
                try await firestore.unenrollFromCourse(userId: uid, courseId: cid)
                enrolledIds.remove(cid)
            } else {
                try await firestore.enrollInCourse(userId: uid, courseId: cid)
                enrolledIds.insert(cid)
            }
        } catch { print(error) }
    }
}

struct CourseEnrollRow: View {
    let course: Course
    let isEnrolled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: course.color))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(course.courseCode.prefix(3))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(course.title).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                Text("\(course.courseCode) · \(course.term)").font(.caption).foregroundColor(.secondary)
                if let times = course.meetingTimes {
                    Text(times).font(.caption2).foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(isEnrolled ? "Drop" : "Enroll") {
                onToggle()
            }
            .font(.caption).fontWeight(.semibold)
            .foregroundColor(isEnrolled ? .red : Color(hex: "4361ee"))
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
