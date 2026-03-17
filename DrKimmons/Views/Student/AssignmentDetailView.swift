import SwiftUI
import SwiftData
import EventKit

struct AssignmentDetailView: View {
    let assignment: LocalAssignment
    @Environment(\.modelContext) private var context

    @State private var reminderResult: String?
    @State private var showingAlert = false

    private let eventStore = EKEventStore()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(assignment.type.capitalized, systemImage: assignment.typeIcon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(assignment.totalPoints) pts")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("Due: \(assignment.dueDateFormatted)")
                        .font(.subheadline)
                        .foregroundColor(assignment.daysUntilDue < 3 && !assignment.isCompleted ? .red : .secondary)
                    if !assignment.assignmentDescription.isEmpty {
                        Text(assignment.assignmentDescription)
                            .font(.body)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Complete toggle
                Button {
                    toggleComplete()
                } label: {
                    Label(
                        assignment.isCompleted ? "Mark Incomplete" : "Mark Complete",
                        systemImage: assignment.isCompleted ? "arrow.uturn.left.circle" : "checkmark.circle.fill"
                    )
                    .font(.subheadline).fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(assignment.isCompleted ? Color(.systemGray5) : Color(hex: "4361ee"))
                    .foregroundColor(assignment.isCompleted ? .primary : .white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                // Calendar / Reminders
                HStack(spacing: 12) {
                    Button { Task { await addToCalendar() } } label: {
                        Label("Calendar", systemImage: "calendar.badge.plus")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                    Button { Task { await addToReminders() } } label: {
                        Label("Reminder", systemImage: "bell.badge.plus")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(10)
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .alert(reminderResult ?? "", isPresented: $showingAlert) {
                    Button("OK", role: .cancel) {}
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(assignment.title)
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Complete toggle

    private func toggleComplete() {
        assignment.isCompleted.toggle()
        assignment.completedAt = assignment.isCompleted ? Date() : nil
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
            reminderResult = "Please allow Calendar access in Settings."
            showingAlert = true
            return
        }
        let event = EKEvent(eventStore: eventStore)
        event.title = assignment.title
        event.notes = assignment.assignmentDescription.isEmpty ? nil : assignment.assignmentDescription
        event.startDate = assignment.dueDate
        event.endDate   = assignment.dueDate.addingTimeInterval(3600)
        event.calendar  = eventStore.defaultCalendarForNewEvents
        event.addAlarm(EKAlarm(relativeOffset: -86400))
        do {
            try eventStore.save(event, span: .thisEvent)
            reminderResult = "Added to Calendar! You'll get a reminder the day before."
        } catch {
            reminderResult = "Couldn't save: \(error.localizedDescription)"
        }
        showingAlert = true
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
            showingAlert = true
            return
        }
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = assignment.title
        reminder.notes = assignment.assignmentDescription.isEmpty ? nil : assignment.assignmentDescription
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        var components = Calendar.current.dateComponents(
            [.year, .month, .day], from: assignment.dueDate)
        components.hour = 8; components.minute = 0
        reminder.dueDateComponents = components
        if let alertDate = Calendar.current.date(from: components) {
            reminder.addAlarm(EKAlarm(absoluteDate: alertDate))
        }
        do {
            try eventStore.save(reminder, commit: true)
            reminderResult = "Reminder set for 8 AM on the due date."
        } catch {
            reminderResult = "Couldn't save: \(error.localizedDescription)"
        }
        showingAlert = true
    }
}
