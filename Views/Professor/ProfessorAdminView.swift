import SwiftUI

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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out") { auth.signOut() }
                        .foregroundColor(.red)
                }
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
        guard let uid = auth.currentUser?.uid else { return }
        do {
            let all = try await firestore.fetchAllCourses()
            courses = all.filter { $0.professorId == uid }
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

    var body: some View {
        List {
            if isLoading {
                SwiftUI.ProgressView()
            } else if assignments.isEmpty {
                Text("No assignments yet.").foregroundColor(.secondary)
            } else {
                ForEach(assignments) { a in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(a.title).font(.subheadline).fontWeight(.semibold)
                        Text("Due: \(a.dueDateFormatted)").font(.caption).foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(course.courseCode)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let cid = course.id else { return }
            assignments = (try? await firestore.fetchAssignments(for: cid)) ?? []
            isLoading = false
        }
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
