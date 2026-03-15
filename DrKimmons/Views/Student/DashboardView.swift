import SwiftUI
import FirebaseFirestore

struct DashboardView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var firestore: FirestoreService
    @State private var upcomingAssignments: [Assignment] = []
    @State private var enrolledCourses: [Course] = []
    @State private var isLoading = true

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(greeting),")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text(auth.currentUser?.displayName.components(separatedBy: " ").first ?? "Student")
                            .font(.system(size: 32, weight: .black))
                    }
                    .padding(.horizontal)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        // Upcoming assignments
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Upcoming")
                                .font(.headline)
                                .padding(.horizontal)

                            if upcomingAssignments.isEmpty {
                                EmptyStateCard(
                                    icon: "checkmark.circle",
                                    title: "All caught up!",
                                    subtitle: "No upcoming assignments."
                                )
                                .padding(.horizontal)
                            } else {
                                ForEach(upcomingAssignments.prefix(5)) { assignment in
                                    NavigationLink(destination: AssignmentDetailView(assignment: assignment)) {
                                        AssignmentCard(assignment: assignment, courses: enrolledCourses)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }
                        }

                        // My courses
                        VStack(alignment: .leading, spacing: 12) {
                            Text("My Courses")
                                .font(.headline)
                                .padding(.horizontal)

                            if enrolledCourses.isEmpty {
                                EmptyStateCard(
                                    icon: "books.vertical",
                                    title: "No courses yet",
                                    subtitle: "Browse courses to enroll."
                                )
                                .padding(.horizontal)
                            } else {
                                ForEach(enrolledCourses) { course in
                                    NavigationLink(destination: StudentCourseDetailView(course: course)) {
                                        CourseCard(course: course)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Study Planner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        auth.signOut()
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .task { await loadData() }
        }
    }

    private func loadData() async {
        guard let uid = auth.currentUser?.uid else { return }
        do {
            async let courses = firestore.fetchEnrolledCourses(for: uid)
            let loaded = try await courses
            enrolledCourses = loaded
            let ids = loaded.compactMap { $0.id }
            upcomingAssignments = try await firestore.fetchUpcomingAssignments(for: ids)
        } catch {
            print("Dashboard load error:", error)
        }
        isLoading = false
    }
}

// MARK: - Assignment Card

struct AssignmentCard: View {
    let assignment: Assignment
    let courses: [Course]

    private var course: Course? {
        courses.first { $0.id == assignment.courseId }
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: course?.color ?? "4361ee"))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(course?.courseCode ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(assignment.dueDateFormatted)
                    .font(.caption)
                    .foregroundColor(assignment.daysUntilDue < 3 ? .red : .secondary)
                if assignment.daysUntilDue >= 0 {
                    Text("\(assignment.daysUntilDue)d")
                        .font(.caption2)
                        .foregroundColor(assignment.daysUntilDue < 3 ? .red : .secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Course Card

struct CourseCard: View {
    let course: Course

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
                Text(course.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Text(course.courseCode)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Empty state

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
