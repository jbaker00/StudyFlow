//
//  DrKimmonsApp.swift
//  DrKimmons
//
//  Created by James Baker on 3/15/26.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct DrKimmonsApp: App {
    @StateObject private var auth = AuthService()
    @StateObject private var firestore = FirestoreService()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .environmentObject(firestore)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
