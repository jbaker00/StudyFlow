import SwiftUI

struct StudentTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
            CoursesView()
                .tabItem { Label("Courses", systemImage: "books.vertical.fill") }
            StudentProgressView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Color(hex: "4361ee"))
    }
}
