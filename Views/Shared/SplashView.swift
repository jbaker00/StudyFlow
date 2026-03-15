import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(hex: "1a1a2e").ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "4361ee"))
                        .frame(width: 80, height: 80)
                    Image(systemName: "graduationcap.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }
                ProgressView().tint(.white)
            }
        }
    }
}
