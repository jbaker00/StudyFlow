import SwiftUI
import SwiftData

@main
struct StudyFlowApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [LocalCourse.self, LocalAssignment.self])
    }
}
