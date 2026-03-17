import SwiftUI
import SwiftData

// MARK: - Course

@Model
final class LocalCourse {
    var id: UUID
    var courseCode: String
    var title: String
    var courseDescription: String
    var professorName: String
    var term: String
    var meetingTimes: String?
    var location: String?
    var color: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \LocalAssignment.course)
    var assignments: [LocalAssignment] = []

    init(courseCode: String, title: String, courseDescription: String,
         professorName: String, term: String,
         meetingTimes: String? = nil, location: String? = nil,
         color: String = "4361ee") {
        self.id = UUID()
        self.courseCode = courseCode
        self.title = title
        self.courseDescription = courseDescription
        self.professorName = professorName
        self.term = term
        self.meetingTimes = meetingTimes
        self.location = location
        self.color = color
        self.createdAt = Date()
    }
}

// MARK: - Assignment

@Model
final class LocalAssignment {
    var id: UUID
    var title: String
    var assignmentDescription: String
    var dueDate: Date
    var type: String       // "homework", "quiz", "exam", etc.
    var totalPoints: Int
    var isCompleted: Bool
    var completedAt: Date?

    var course: LocalCourse?

    init(title: String, description: String, dueDate: Date,
         type: String, totalPoints: Int, course: LocalCourse? = nil) {
        self.id = UUID()
        self.title = title
        self.assignmentDescription = description
        self.dueDate = dueDate
        self.type = type
        self.totalPoints = totalPoints
        self.isCompleted = false
        self.course = course
    }

    var daysUntilDue: Int {
        Calendar.current.dateComponents([.day], from: .now, to: dueDate).day ?? 0
    }

    var dueDateFormatted: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        return df.string(from: dueDate)
    }

    var typeIcon: String {
        switch type {
        case "reading":      return "book"
        case "essay":        return "doc.text"
        case "quiz", "exam": return "pencil.and.list.clipboard"
        case "project":      return "folder"
        case "presentation": return "person.wave.2"
        case "response":     return "text.bubble"
        default:             return "checkmark.circle"
        }
    }
}
