import SwiftUI

struct ProfessorTabView: View {
    var body: some View {
        TabView {
            ProfessorAdminView()
                .tabItem {
                    Label("Courses", systemImage: "books.vertical.fill")
                }
            ProfessorStudentsView()
                .tabItem {
                    Label("Students", systemImage: "person.3.fill")
                }
        }
        .tint(Color(hex: "4361ee"))
    }
}
