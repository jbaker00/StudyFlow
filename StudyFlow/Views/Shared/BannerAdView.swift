import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    private let adUnitID = "ca-app-pub-7871017136061682/7988883496"

    func makeUIView(context: Context) -> GADBannerView {
        let width = UIScreen.main.bounds.width
        let adSize = GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(width)
        let banner = GADBannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.rootViewController = context.coordinator.rootViewController
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        var rootViewController: UIViewController? {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })?
                .windows
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        }
    }

    /// Height of the adaptive banner for the current screen width.
    static var height: CGFloat {
        GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth(
            UIScreen.main.bounds.width
        ).size.height
    }
}
