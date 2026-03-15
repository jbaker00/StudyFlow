import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthService
    @State private var isSigningIn = false

    var body: some View {
        ZStack {
            Color(hex: "1a1a2e").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "4361ee"))
                            .frame(width: 96, height: 96)
                            .shadow(color: Color(hex: "4361ee").opacity(0.5), radius: 20, y: 8)
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                    }
                    Text("Study Planner")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    Text("Dr. Baker-Kimmons · Chicago State University")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 48)

                // Feature list
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "calendar", text: "Track all your assignments in one place")
                    FeatureRow(icon: "checkmark.circle", text: "Smart task breakdowns to keep you on track")
                    FeatureRow(icon: "bell", text: "Daily reminders before deadlines")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "See your progress across all courses")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

                // Sign in button
                Button {
                    Task {
                        isSigningIn = true
                        await auth.signInWithGoogle()
                        isSigningIn = false
                    }
                } label: {
                    HStack(spacing: 12) {
                        if isSigningIn {
                            ProgressView().tint(Color(hex: "1a1a2e"))
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: "4285F4"))
                                    .frame(width: 24, height: 24)
                                Text("G")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(.white)
                            }
                            Text("Sign in with Google")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "1a1a2e"))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white)
                    .cornerRadius(14)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                }
                .disabled(isSigningIn)
                .padding(.horizontal, 32)

                if let error = auth.error {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top, 12)
                        .padding(.horizontal, 32)
                }

                Text("Sign in with the Google account you use for school")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.top, 12)
                    .padding(.horizontal, 32)

                Spacer()

                Text("By signing in you agree to use this app for academic purposes only.")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "4361ee").opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(Color(hex: "4361ee"))
            }
            Text(text)
                .foregroundColor(.white.opacity(0.85))
                .font(.system(size: 15))
        }
    }
}

// MARK: - Color hex helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
