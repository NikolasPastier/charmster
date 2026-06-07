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
    /// Returns true if Superwall was actually configured.
    @discardableResult
    static func configure() -> Bool {
        let key = ProcessInfo.processInfo.environment["SUPERWALL_PUBLIC_API_KEY"]
            ?? Bundle.main.object(forInfoDictionaryKey: "SUPERWALL_PUBLIC_API_KEY") as? String
            ?? ""
        guard !key.isEmpty else {
            isConfigured = false
            return false
        }
        Superwall.configure(apiKey: key)
        isConfigured = true

        #if DEBUG
        Superwall.shared.options.paywalls.shouldPreload = true
        // Preview test-user wiring for the 10x simulator.
        let previewId = "tenx-preview-charmster"
        Superwall.shared.identify(userId: previewId)
        Superwall.shared.setUserAttributes(["tenx_preview": true])
        #endif
        return true
    }

    /// Whether `configure()` actually wired the SDK. We never touch
    /// `Superwall.shared` when this is false — it would crash.
    private(set) static var isConfigured: Bool = false

    /// Register a placement and report whether the paywall blocked entry / converted.
    /// Source param is recorded as an analytics attribute on the placement.
    /// If Superwall is not configured (e.g. dev simulator with no API key),
    /// this falls through and runs `feature` directly so the app remains usable.
    static func register(_ placement: String,
                         source: String,
                         params: [String: Any] = [:],
                         feature: (() -> Void)? = nil) {
        Analytics.log("paywall_opened", ["placement": placement, "source": source])
        guard isConfigured else {
            // Dev fallback: no paywall available, just unlock the feature.
            feature?()
            return
        }
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
        guard isConfigured else { return false }
        return Superwall.shared.subscriptionStatus.isActive
    }

    /// Reset identity (sign out etc.).
    static func reset() {
        guard isConfigured else { return }
        Superwall.shared.reset()
    }
}
