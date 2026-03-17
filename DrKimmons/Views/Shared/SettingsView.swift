import SwiftUI
import SwiftData

struct SettingsView: View {
    @Query private var courses: [LocalCourse]
    @Environment(\.modelContext) private var context

    @AppStorage("user_display_name") private var displayName = ""
    @State private var groqKey = GroqService.shared.apiKey
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Your name", text: $displayName)
                        .autocorrectionDisabled()
                }

                Section {
                    SecureField("gsk_…", text: $groqKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: groqKey) { _, new in
                            GroqService.shared.apiKey = new
                        }
                } header: {
                    Text("Groq API Key")
                } footer: {
                    Text("Free at console.groq.com — used to parse syllabus files with AI. Stored only on this device.")
                }

                Section("About") {
                    LabeledContent("Courses",    value: "\(courses.count)")
                    LabeledContent("AI Engine",  value: "Groq · llama-3.3-70b-versatile")
                    LabeledContent("Storage",    value: "Local (SwiftData)")
                    LabeledContent("Version",    value: "1.0")
                }

                Section {
                    Button("Delete All Courses & Assignments", role: .destructive) {
                        showClearConfirm = true
                    }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                "Delete everything?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete All", role: .destructive) { clearAll() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes all courses and assignments from this device. This cannot be undone.")
            }
            .onAppear { groqKey = GroqService.shared.apiKey }
        }
    }

    private func clearAll() {
        for course in courses { context.delete(course) }
    }
}
