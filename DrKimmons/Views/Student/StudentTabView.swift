import SwiftUI

struct StudentTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }
            CoursesView()
                .tabItem {
                    Label("Courses", systemImage: "books.vertical.fill")
                }
            ProgressView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .tint(Color(hex: "4361ee"))
    }
}
