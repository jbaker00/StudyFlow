import SwiftUI

struct CoursesView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var firestore: FirestoreService
    @State private var allCourses: [Course] = []
    @State private var enrolledIds: Set<String> = []
    @State private var isLoading = true

    var enrolledCourses: [Course] { allCourses.filter { enrolledIds.contains($0.id ?? "") } }
    var availableCourses: [Course] { allCourses.filter { !enrolledIds.contains($0.id ?? "") } }

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
                    List {
                        if !enrolledCourses.isEmpty {
                            Section("My Courses") {
                                ForEach(enrolledCourses) { course in
                                    NavigationLink(destination: StudentCourseDetailView(course: course)) {
                                        CourseRow(course: course)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task { await toggleEnroll(course) }
                                        } label: {
                                            Label("Drop", systemImage: "minus.circle")
                                        }
                                    }
                                }
                            }
                        }
                        if !availableCourses.isEmpty {
                            Section("Available Courses") {
                                ForEach(availableCourses) { course in
                                    CourseRow(course: course)
                                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                            Button {
                                                Task { await toggleEnroll(course) }
                                            } label: {
                                                Label("Enroll", systemImage: "plus.circle")
                                            }
                                            .tint(Color(hex: "4361ee"))
                                        }
                                }
                            }
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

struct CourseRow: View {
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

// MARK: - Student Course Detail

struct StudentCourseDetailView: View {
    let course: Course
    @EnvironmentObject var firestore: FirestoreService
    @State private var assignments: [Assignment] = []
    @State private var isLoading = true

    var upcomingAssignments: [Assignment] {
        assignments.filter { $0.daysUntilDue >= 0 }
    }
    var pastAssignments: [Assignment] {
        assignments.filter { $0.daysUntilDue < 0 }
    }

    var body: some View {
        List {
            Section {
                if let times = course.meetingTimes {
                    LabeledContent("Schedule", value: times)
                }
                if let loc = course.location {
                    LabeledContent("Location", value: loc)
                }
                LabeledContent("Term", value: course.term)
                LabeledContent("Professor", value: course.professorName)
            }

            if isLoading {
                Section { SwiftUI.ProgressView() }
            } else {
                if !upcomingAssignments.isEmpty {
                    Section("Upcoming (\(upcomingAssignments.count))") {
                        ForEach(upcomingAssignments) { a in
                            NavigationLink(destination: AssignmentDetailView(assignment: a)) {
                                AssignmentListRow(assignment: a, courseColor: course.color)
                            }
                        }
                    }
                }
                if !pastAssignments.isEmpty {
                    Section("Past (\(pastAssignments.count))") {
                        ForEach(pastAssignments) { a in
                            NavigationLink(destination: AssignmentDetailView(assignment: a)) {
                                AssignmentListRow(assignment: a, courseColor: course.color)
                            }
                        }
                    }
                }
                if assignments.isEmpty {
                    Section { Text("No assignments yet.").foregroundColor(.secondary) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(course.courseCode)
        .navigationBarTitleDisplayMode(.large)
        .task {
            guard let cid = course.id else { return }
            assignments = (try? await firestore.fetchAssignments(for: cid)) ?? []
            isLoading = false
        }
    }
}

struct AssignmentListRow: View {
    let assignment: Assignment
    let courseColor: String

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: courseColor))
                .frame(width: 3, height: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(assignment.type.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color(hex: courseColor).opacity(0.15))
                        .foregroundColor(Color(hex: courseColor))
                        .cornerRadius(4)
                    Text(assignment.dueDateFormatted)
                        .font(.caption)
                        .foregroundColor(assignment.daysUntilDue < 3 && assignment.daysUntilDue >= 0 ? .red : .secondary)
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
