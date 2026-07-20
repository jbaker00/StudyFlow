import SwiftUI
import SwiftData
import GoogleMobileAds

@main
struct StudyFlowApp: App {
    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [LocalCourse.self, LocalAssignment.self])
    }
}
