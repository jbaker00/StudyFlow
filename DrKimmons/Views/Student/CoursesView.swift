import SwiftUI
import SwiftData
import PDFKit
import UniformTypeIdentifiers

struct CoursesView: View {
    @Query(sort: \LocalCourse.createdAt) private var courses: [LocalCourse]
    @Environment(\.modelContext) private var context
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            Group {
                if courses.isEmpty {
                    EmptyStateCard(
                        icon: "arrow.down.doc",
                        title: "No courses yet",
                        subtitle: "Tap + to import a syllabus and create your first course."
                    )
                    .padding()
                } else {
                    List {
                        ForEach(courses) { course in
                            NavigationLink(destination: CourseDetailView(course: course)) {
                                CourseRow(course: course)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    context.delete(course)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Courses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showImport = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showImport) {
                SyllabusImportView()
            }
        }
    }
}

// MARK: - Course Row

struct CourseRow: View {
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
                Text(course.title).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                Text("\(course.courseCode) · \(course.term)").font(.caption).foregroundColor(.secondary)
                if let times = course.meetingTimes {
                    Text(times).font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Course Detail

struct CourseDetailView: View {
    let course: LocalCourse
    @Environment(\.modelContext) private var context
    @State private var showAddAssignment = false

    private var upcoming: [LocalAssignment] {
        course.assignments
            .filter { $0.dueDate >= Date() }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var past: [LocalAssignment] {
        course.assignments
            .filter { $0.dueDate < Date() }
            .sorted { $0.dueDate > $1.dueDate }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Term",      value: course.term)
                LabeledContent("Professor", value: course.professorName)
                if let times = course.meetingTimes { LabeledContent("Schedule", value: times) }
                if let loc   = course.location      { LabeledContent("Location", value: loc)   }
                if !course.courseDescription.isEmpty {
                    Text(course.courseDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !upcoming.isEmpty {
                Section("Upcoming (\(upcoming.count))") {
                    ForEach(upcoming) { a in
                        NavigationLink(destination: AssignmentDetailView(assignment: a)) {
                            AssignmentListRow(assignment: a, courseColor: course.color)
                        }
                    }
                }
            }

            if !past.isEmpty {
                Section("Past (\(past.count))") {
                    ForEach(past) { a in
                        NavigationLink(destination: AssignmentDetailView(assignment: a)) {
                            AssignmentListRow(assignment: a, courseColor: course.color)
                        }
                    }
                }
            }

            if course.assignments.isEmpty {
                Section { Text("No assignments yet.").foregroundColor(.secondary) }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(course.courseCode)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddAssignment = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddAssignment) {
            AddAssignmentView(course: course)
        }
    }
}

// MARK: - Assignment List Row

struct AssignmentListRow: View {
    let assignment: LocalAssignment
    let courseColor: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: courseColor))
                .frame(width: 3, height: 38)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(assignment.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                        .strikethrough(assignment.isCompleted)
                    if assignment.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                HStack(spacing: 6) {
                    Text(assignment.type.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color(hex: courseColor).opacity(0.15))
                        .foregroundColor(Color(hex: courseColor))
                        .cornerRadius(4)
                    Text(assignment.dueDateFormatted)
                        .font(.caption)
                        .foregroundColor(
                            assignment.daysUntilDue < 3 && assignment.daysUntilDue >= 0
                                ? .red : .secondary
                        )
                }
            }

            Spacer()
            Text("\(assignment.totalPoints)pt")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Assignment (manual entry)

struct AddAssignmentView: View {
    let course: LocalCourse
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var selectedType = "homework"
    @State private var dueDate = Date().addingTimeInterval(7 * 86400)
    @State private var totalPoints = "10"

    private let types = ["homework","reading","essay","quiz","exam",
                         "project","presentation","response","custom"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignment Info") {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Details") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(types, id: \.self) { Text($0.capitalized) }
                    }
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    TextField("Points", text: $totalPoints).keyboardType(.numberPad)
                }
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }.disabled(title.isEmpty)
                }
            }
        }
    }

    private func save() {
        let a = LocalAssignment(
            title: title,
            description: description,
            dueDate: dueDate,
            type: selectedType,
            totalPoints: Int(totalPoints) ?? 10,
            course: course
        )
        context.insert(a)
        dismiss()
    }
}
