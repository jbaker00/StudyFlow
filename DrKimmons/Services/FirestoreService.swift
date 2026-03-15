import Foundation
import Combine
import FirebaseFirestore

@MainActor
class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()

    // MARK: - Courses

    func fetchAllCourses() async throws -> [Course] {
        let snap = try await db.collection("courses").getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Course.self) }
    }

    func fetchEnrolledCourses(for userId: String) async throws -> [Course] {
        let userSnap = try await db.collection("users").document(userId).getDocument()
        let user = try userSnap.data(as: AppUser.self)
        guard !user.enrolledCourses.isEmpty else { return [] }

        let snap = try await db.collection("courses")
            .whereField(FieldPath.documentID(), in: user.enrolledCourses)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Course.self) }
    }

    func enrollInCourse(userId: String, courseId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "enrolledCourses": FieldValue.arrayUnion([courseId])
        ])
    }

    func unenrollFromCourse(userId: String, courseId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "enrolledCourses": FieldValue.arrayRemove([courseId])
        ])
    }

    // MARK: - Assignments

    func fetchAssignments(for courseId: String) async throws -> [Assignment] {
        let snap = try await db.collection("assignments")
            .whereField("courseId", isEqualTo: courseId)
            .order(by: "dueDate")
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Assignment.self) }
    }

    func fetchUpcomingAssignments(for courseIds: [String]) async throws -> [Assignment] {
        guard !courseIds.isEmpty else { return [] }
        let now = Timestamp()
        let snap = try await db.collection("assignments")
            .whereField("courseId", in: courseIds)
            .whereField("dueDate", isGreaterThan: now)
            .order(by: "dueDate")
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: Assignment.self) }
    }

    // MARK: - Tasks

    func fetchTasks(for assignmentId: String) async throws -> [AssignmentTask] {
        let snap = try await db.collection("tasks")
            .whereField("assignmentId", isEqualTo: assignmentId)
            .order(by: "order")
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: AssignmentTask.self) }
    }

    // MARK: - Progress

    func fetchProgress(userId: String, assignmentId: String) async throws -> [TaskProgress] {
        let snap = try await db.collection("userProgress")
            .document(userId)
            .collection("taskProgress")
            .whereField("assignmentId", isEqualTo: assignmentId)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: TaskProgress.self) }
    }

    func toggleTaskComplete(userId: String, task: AssignmentTask, completed: Bool) async throws {
        let ref = db.collection("userProgress")
            .document(userId)
            .collection("taskProgress")
            .document(task.id ?? UUID().uuidString)

        let progress = TaskProgress(
            taskId: task.id ?? "",
            assignmentId: task.assignmentId,
            courseId: task.courseId,
            completed: completed,
            completedAt: completed ? Timestamp() : nil
        )
        try ref.setData(from: progress, merge: true)
    }

    // MARK: - Professor: create course

    func createCourse(_ course: Course) async throws {
        _ = try db.collection("courses").addDocument(from: course)
    }

    func updateCourse(_ course: Course) async throws {
        guard let id = course.id else { return }
        try db.collection("courses").document(id).setData(from: course, merge: true)
    }

    func addAssignment(_ assignment: Assignment) async throws {
        _ = try db.collection("assignments").addDocument(from: assignment)
    }

    func fetchAllStudents() async throws -> [AppUser] {
        let snap = try await db.collection("users")
            .whereField("role", isEqualTo: "student")
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: AppUser.self) }
    }
}
