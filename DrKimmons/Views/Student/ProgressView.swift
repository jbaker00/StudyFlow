import SwiftUI
import SwiftData

struct StudentProgressView: View {
    @Query(sort: \LocalCourse.createdAt) private var courses: [LocalCourse]

    var body: some View {
        NavigationStack {
            Group {
                if courses.isEmpty {
                    EmptyStateCard(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "No courses yet",
                        subtitle: "Import a syllabus to start tracking progress."
                    )
                    .padding()
                } else {
                    List(courses) { course in
                        CourseProgressRow(course: course)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Progress")
        }
    }
}

struct CourseProgressRow: View {
    let course: LocalCourse

    private var total: Int     { course.assignments.count }
    private var completed: Int { course.assignments.filter(\.isCompleted).count }
    private var ratio: Double  { total > 0 ? Double(completed) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(hex: course.color))
                    .frame(width: 10, height: 10)
                Text(course.courseCode).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("\(completed)/\(total)").font(.caption).foregroundColor(.secondary)
            }
            Text(course.title).font(.caption).foregroundColor(.secondary).lineLimit(1)
            ProgressBar(value: ratio)
        }
        .padding(.vertical, 4)
    }
}

struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray5))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "4361ee"))
                    .frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 8)
    }
}
