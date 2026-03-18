import SwiftUI
import SwiftData

// MARK: - Color hex extension (shared across all views)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - Dashboard

struct DashboardView: View {
    @Query(sort: \LocalAssignment.dueDate) private var allAssignments: [LocalAssignment]
    @Query(sort: \LocalCourse.createdAt)   private var courses: [LocalCourse]

    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:      return "Good evening"
        }
    }

    private var upcoming: [LocalAssignment] {
        allAssignments
            .filter { $0.dueDate >= Date() && !$0.isCompleted }
            .prefix(5)
            .map { $0 }
    }

    private var userName: String {
        UserDefaults.standard.string(forKey: "user_display_name") ?? "Student"
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
                        Text(userName.components(separatedBy: " ").first ?? userName)
                            .font(.system(size: 32, weight: .black))
                    }
                    .padding(.horizontal)

                    // Upcoming assignments
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Upcoming")
                            .font(.headline)
                            .padding(.horizontal)

                        if upcoming.isEmpty {
                            EmptyStateCard(icon: "checkmark.circle",
                                           title: "All caught up!",
                                           subtitle: "No upcoming assignments.")
                                .padding(.horizontal)
                        } else {
                            ForEach(upcoming) { assignment in
                                NavigationLink(destination: AssignmentDetailView(assignment: assignment)) {
                                    AssignmentCard(assignment: assignment)
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

                        if courses.isEmpty {
                            EmptyStateCard(icon: "books.vertical",
                                           title: "No courses yet",
                                           subtitle: "Import a syllabus from the Courses tab.")
                                .padding(.horizontal)
                        } else {
                            ForEach(courses) { course in
                                NavigationLink(destination: CourseDetailView(course: course)) {
                                    CourseCard(course: course)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Study Planner")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Shared Cards

struct AssignmentCard: View {
    let assignment: LocalAssignment

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: assignment.course?.color ?? "4361ee"))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(assignment.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(assignment.course?.courseCode ?? "")
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

struct CourseCard: View {
    let course: LocalCourse

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
            Text(subtitle).font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
