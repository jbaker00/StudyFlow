import SwiftUI
import EventKit
import FirebaseFirestore

struct AssignmentDetailView: View {
    let assignment: Assignment
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var firestore: FirestoreService
    @State private var tasks: [AssignmentTask] = []
    @State private var progress: [String: TaskProgress] = [:]
    @State private var isLoading = true
    @State private var reminderResult: String?
    @State private var showingReminderAlert = false

    private let eventStore = EKEventStore()

    var completedCount: Int { progress.values.filter { $0.completed }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(assignment.type.rawValue.capitalized, systemImage: typeIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(assignment.totalPoints) pts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Due: \(assignment.dueDateFormatted)")
                        .font(.subheadline)
                        .foregroundColor(assignment.daysUntilDue < 3 ? .red : .secondary)
                    if !assignment.description.isEmpty {
                        Text(assignment.description)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Add to Calendar / Reminders
                HStack(spacing: 12) {
                    Button {
                        Task { await addToCalendar() }
                    } label: {
                        Label("Add to Calendar", systemImage: "calendar.badge.plus")
                            .font(.subheadline).fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    Button {
                        Task { await addToReminders() }
                    } label: {
                        Label("Add Reminder", systemImage: "bell.badge.plus")
                            .font(.subheadline).fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .alert(reminderResult ?? "", isPresented: $showingReminderAlert) {
                    Button("OK", role: .cancel) {}
                }

                // Progress bar
                if !tasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tasks")
                                .font(.headline)
                            Spacer()
                            Text("\(completedCount)/\(tasks.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        ProgressBar(value: Double(completedCount) / Double(tasks.count))
                    }
                    .padding(.horizontal)
                }

                // Task list
                if isLoading {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 8) {
                        ForEach(tasks) { task in
                            TaskRow(
                                task: task,
                                isCompleted: progress[task.id ?? ""]?.completed ?? false
                            ) {
                                Task { await toggleTask(task) }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(assignment.title)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadData() }
    }

    private var typeIcon: String {
        switch assignment.type {
        case .reading: return "book"
        case .essay: return "doc.text"
        case .quiz, .exam: return "pencil.and.list.clipboard"
        case .project: return "folder"
        case .presentation: return "person.wave.2"
        default: return "checkmark.circle"
        }
    }

    private func loadData() async {
        guard let uid = auth.currentUser?.uid, let aid = assignment.id else { return }
        do {
            async let t = firestore.fetchTasks(for: aid)
            async let p = firestore.fetchProgress(userId: uid, assignmentId: aid)
            let (taskList, progressList) = try await (t, p)
            tasks = taskList
            progress = Dictionary(uniqueKeysWithValues: progressList.compactMap { p in
                guard let tid = p.taskId.isEmpty ? nil : p.taskId else { return nil }
                return (tid, p)
            })
        } catch { print(error) }
        isLoading = false
    }

    private func toggleTask(_ task: AssignmentTask) async {
        guard let uid = auth.currentUser?.uid else { return }
        let current = progress[task.id ?? ""]?.completed ?? false
        do {
            try await firestore.toggleTaskComplete(userId: uid, task: task, completed: !current)
            if !current {
                progress[task.id ?? ""] = TaskProgress(
                    taskId: task.id ?? "", assignmentId: task.assignmentId,
                    courseId: task.courseId, completed: true
                )
            } else {
                progress[task.id ?? ""]?.completed = false
            }
        } catch { print(error) }
    }

    // MARK: - Calendar

    private func addToCalendar() async {
        let granted: Bool
        if #available(iOS 17, *) {
            granted = (try? await eventStore.requestWriteOnlyAccessToEvents()) ?? false
        } else {
            granted = await withCheckedContinuation { cont in
                eventStore.requestAccess(to: .event) { ok, _ in cont.resume(returning: ok) }
            }
        }
        guard granted else {
            reminderResult = "Please allow Calendar access in Settings to add events."
            showingReminderAlert = true
            return
        }

        let event = EKEvent(eventStore: eventStore)
        event.title = assignment.title
        event.notes = assignment.description.isEmpty ? nil : assignment.description
        event.startDate = assignment.dueDate.dateValue()
        event.endDate = assignment.dueDate.dateValue().addingTimeInterval(3600)
        event.calendar = eventStore.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -86400))  // 1 day before

        do {
            try eventStore.save(event, span: .thisEvent)
            reminderResult = "Added to Calendar! You'll get a reminder the day before."
        } catch {
            reminderResult = "Couldn't save to Calendar: \(error.localizedDescription)"
        }
        showingReminderAlert = true
    }

    // MARK: - Reminders

    private func addToReminders() async {
        let granted: Bool
        if #available(iOS 17, *) {
            granted = (try? await eventStore.requestFullAccessToReminders()) ?? false
        } else {
            granted = await withCheckedContinuation { cont in
                eventStore.requestAccess(to: .reminder) { ok, _ in cont.resume(returning: ok) }
            }
        }
        guard granted else {
            reminderResult = "Please allow Reminders access in Settings."
            showingReminderAlert = true
            return
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = assignment.title
        reminder.notes = assignment.description.isEmpty ? nil : assignment.description
        reminder.calendar = eventStore.defaultCalendarForNewReminders()

        // Due date alarm
        var components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: assignment.dueDate.dateValue()
        )
        components.hour = 8
        components.minute = 0
        reminder.dueDateComponents = components
        reminder.addAlarm(EKAlarm(absoluteDate: Calendar.current.date(from: components) ?? assignment.dueDate.dateValue()))

        do {
            try eventStore.save(reminder, commit: true)
            reminderResult = "Reminder added! You'll be reminded on the due date at 8 AM."
        } catch {
            reminderResult = "Couldn't save reminder: \(error.localizedDescription)"
        }
        showingReminderAlert = true
    }
}

struct TaskRow: View {
    let task: AssignmentTask
    let isCompleted: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isCompleted ? Color(hex: "4361ee") : .secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 15))
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                if let desc = task.description, !desc.isEmpty {
                    Text(desc).font(.caption).foregroundColor(.secondary).lineLimit(2)
                }
                Text("~\(task.estimatedMinutes) min")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
}

struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: "4361ee"))
                    .frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: 8)
    }
}
