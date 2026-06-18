import Foundation
import SuperwallKit

/// Single entry point for Superwall. Views never touch `Superwall.shared` directly.
enum CharmsterSuperwall {

  enum Placement: String {
    case upgradePrompt = "upgrade_prompt"
    case onboardingComplete = "onboarding_complete"
    case trialExpired = "trial_expired"
    case premiumDailyPracticeCap = "premium_daily_practice_cap"
    case premiumCapstone = "premium_capstone"
    case premiumPartnerPersona = "premium_partner_persona"
  }

  static func configure() {
    let key =
      ProcessInfo.processInfo.environment["SUPERWALL_PUBLIC_API_KEY"]
      ?? (Bundle.main.object(forInfoDictionaryKey: "SUPERWALL_PUBLIC_API_KEY") as? String)
      ?? ""
    guard !key.isEmpty else { return }
    #if DEBUG
      let swOptions = SuperwallOptions()
      swOptions.paywalls.shouldShowPurchaseFailureAlert = true
      Superwall.configure(apiKey: key, options: swOptions)
    #else
      Superwall.configure(apiKey: key)
    #endif
  }

  static func identify(userId: String) {
    #if DEBUG
      Superwall.shared.identify(userId: userId)
      Superwall.shared.setUserAttributes(["tenx_preview": true])
    #else
      Superwall.shared.identify(userId: userId)
    #endif
  }

  static func register(
    _ placement: Placement, params: [String: Any]? = nil, feature: (() -> Void)? = nil
  ) {
    Superwall.shared.register(placement: placement.rawValue, params: params) {
      feature?()
    }
  }

  static func presentUpgrade(feature: (() -> Void)? = nil) {
    register(.upgradePrompt, feature: feature)
  }
}
