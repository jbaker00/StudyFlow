import SwiftUI
import SwiftData

@main
struct DrKimmonsApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [LocalCourse.self, LocalAssignment.self])
    }
}
