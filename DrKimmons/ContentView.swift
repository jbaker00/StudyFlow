//
//  RootView.swift — routes to login or dashboard based on auth state
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        Group {
            if auth.isLoading {
                SplashView()
            } else if auth.currentUser == nil {
                LoginView()
            } else if auth.currentUser?.isProfessor == true {
                ProfessorTabView()
            } else {
                StudentTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: auth.currentUser?.uid)
    }
}
