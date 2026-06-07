import SwiftUI
import SuperwallKit

/// Single Superwall wrapper. Owns configure, placements, identity, and subscription state.
/// Paywall UI lives in the Superwall dashboard — never in app code.
enum CharmsterSuperwall {
    /// Placement names. One per monetization moment.
    enum Placement {
        static let upgradePrompt        = "upgrade_prompt"
        static let onboardingComplete   = "onboarding_complete"
        static let trialExpired         = "trial_expired"
        static let dailyCapHit          = "premium_daily_practice_cap"
        static let featureGateCapstone  = "premium_capstone"
        static let featureGatePersona   = "premium_partner_persona"
    }

    /// Configure on app launch. Safe to call once.
    static func configure() {
        let key = ProcessInfo.processInfo.environment["SUPERWALL_PUBLIC_API_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SUPERWALL_PUBLIC_API_KEY") as? String
            ?? ""
        guard !key.isEmpty else { return }
        Superwall.configure(apiKey: key)

        #if DEBUG
        Superwall.shared.options.paywalls.shouldPreload = true
        // Preview test-user wiring for the 10x simulator.
        let previewId = "tenx-preview-charmster"
        Superwall.shared.identify(userId: previewId)
        Superwall.shared.setUserAttributes(["tenx_preview": true])
        #endif
    }

    /// Register a placement and report whether the paywall blocked entry / converted.
    /// Source param is recorded as an analytics attribute on the placement.
    static func register(_ placement: String,
                         source: String,
                         params: [String: Any] = [:],
                         feature: (() -> Void)? = nil) {
        Analytics.log("paywall_opened", ["placement": placement, "source": source])
        var attrs = params
        attrs["source"] = source
        Superwall.shared.register(placement: placement, params: attrs) {
            feature?()
        }
    }

    /// Open the upgrade paywall. Use this from every upgrade CTA in the app.
    static func presentUpgrade(source: String) {
        register(Placement.upgradePrompt, source: source)
    }

    /// True if the active Superwall subscription status is active.
    static var hasActiveEntitlement: Bool {
        Superwall.shared.subscriptionStatus.isActive
    }

    /// Reset identity (sign out etc.).
    static func reset() {
        Superwall.shared.reset()
    }
}
