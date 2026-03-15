import SwiftUI
import FirebaseFirestore

struct ProfessorAdminView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var firestore: FirestoreService
    @State private var courses: [Course] = []
    @State private var isLoading = true
    @State private var showCreateCourse = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    SwiftUI.ProgressView()
                } else if courses.isEmpty {
                    EmptyStateCard(
                        icon: "books.vertical",
                        title: "No courses yet",
                        subtitle: "Tap + to create your first course."
                    )
                    .padding()
                } else {
                    List(courses) { course in
                        NavigationLink(destination: ProfessorCourseDetailView(course: course)) {
                            CourseCard(course: course)
                                .listRowInsets(EdgeInsets())
                                .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("My Courses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showCreateCourse = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateCourse, onDismiss: { Task { await loadCourses() } }) {
                CreateCourseView()
            }
            .task { await loadCourses() }
        }
    }

    private func loadCourses() async {
        do {
            courses = try await firestore.fetchAllCourses()
        } catch { print(error) }
        isLoading = false
    }
}

// MARK: - Professor Course Detail

struct ProfessorCourseDetailView: View {
    let course: Course
    @EnvironmentObject var firestore: FirestoreService
    @State private var assignments: [Assignment] = []
    @State private var isLoading = true
    @State private var showAddAssignment = false

    var body: some View {
        List {
            Section {
                LabeledContent("Term", value: course.term)
                if let times = course.meetingTimes {
                    LabeledContent("Schedule", value: times)
                }
                if let loc = course.location {
                    LabeledContent("Location", value: loc)
                }
                LabeledContent("Enrollment", value: course.enrollmentOpen ? "Open" : "Closed")
            }

            Section("Assignments (\(assignments.count))") {
                if isLoading {
                    SwiftUI.ProgressView()
                } else if assignments.isEmpty {
                    Text("No assignments yet.").foregroundColor(.secondary)
                } else {
                    ForEach(assignments) { a in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(a.title)
                                    .font(.subheadline).fontWeight(.semibold)
                                Spacer()
                                Text("\(a.totalPoints) pts")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            HStack {
                                Text(a.type.rawValue.capitalized)
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color(hex: course.color).opacity(0.15))
                                    .foregroundColor(Color(hex: course.color))
                                    .cornerRadius(4)
                                Text("Due \(a.dueDateFormatted)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(course.courseCode)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddAssignment = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddAssignment, onDismiss: { Task { await reload() } }) {
            AddAssignmentView(course: course)
        }
        .task { await reload() }
    }

    private func reload() async {
        guard let cid = course.id else { return }
        assignments = (try? await firestore.fetchAssignments(for: cid)) ?? []
        isLoading = false
    }
}

// MARK: - Create Course

struct CreateCourseView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var firestore: FirestoreService
    @Environment(\.dismiss) var dismiss

    @State private var courseCode = ""
    @State private var title = ""
    @State private var description = ""
    @State private var term = "Spring 2026"
    @State private var meetingTimes = ""
    @State private var isSaving = false

    let terms = ["Spring 2026", "Fall 2026", "Spring 2027"]
    let colors = ["4361ee", "f72585", "7209b7", "3a0ca3", "4cc9f0", "06d6a0", "ff6b6b"]

    @State private var selectedColor = "4361ee"

    var body: some View {
        NavigationStack {
            Form {
                Section("Course Info") {
                    TextField("Course Code (e.g. ENG 101)", text: $courseCode)
                    TextField("Course Title", text: $title)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section("Schedule") {
                    Picker("Term", selection: $term) {
                        ForEach(terms, id: \.self) { Text($0) }
                    }
                    TextField("Meeting Times (e.g. MWF 10-11am)", text: $meetingTimes)
                }
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 7), spacing: 8) {
                        ForEach(colors, id: \.self) { c in
                            Circle()
                                .fill(Color(hex: c))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    selectedColor == c
                                    ? Image(systemName: "checkmark").foregroundColor(.white).font(.caption)
                                    : nil
                                )
                                .onTapGesture { selectedColor = c }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(courseCode.isEmpty || title.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let user = auth.currentUser else { return }
        isSaving = true
        let course = Course(
            courseCode: courseCode.uppercased(),
            title: title,
            description: description,
            professorId: user.uid,
            professorName: user.displayName,
            term: term,
            enrollmentOpen: true,
            color: selectedColor,
            meetingTimes: meetingTimes.isEmpty ? nil : meetingTimes
        )
        do {
            try await firestore.createCourse(course)
            dismiss()
        } catch { print(error) }
        isSaving = false
    }
}

// MARK: - Add Assignment

struct AddAssignmentView: View {
    let course: Course
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var firestore: FirestoreService
    @Environment(\.dismiss) var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var selectedType: AssignmentType = .homework
    @State private var dueDate = Date().addingTimeInterval(7 * 86400)
    @State private var totalPoints = "10"
    @State private var isSaving = false

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
                        Text("Homework").tag(AssignmentType.homework)
                        Text("Reading").tag(AssignmentType.reading)
                        Text("Essay").tag(AssignmentType.essay)
                        Text("Quiz").tag(AssignmentType.quiz)
                        Text("Exam").tag(AssignmentType.exam)
                        Text("Project").tag(AssignmentType.project)
                        Text("Presentation").tag(AssignmentType.presentation)
                        Text("Response").tag(AssignmentType.response)
                        Text("Custom").tag(AssignmentType.custom)
                    }
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
                    TextField("Points", text: $totalPoints)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("New Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { Task { await save() } }
                        .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() async {
        guard let uid = auth.currentUser?.uid, let cid = course.id else { return }
        isSaving = true
        let assignment = Assignment(
            courseId: cid,
            title: title,
            description: description,
            dueDate: Timestamp(date: dueDate),
            type: selectedType,
            totalPoints: Int(totalPoints) ?? 10,
            createdBy: uid,
            isCustom: false
        )
        do {
            try await firestore.addAssignment(assignment)
            dismiss()
        } catch { print(error) }
        isSaving = false
    }
}

