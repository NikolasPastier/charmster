import SwiftUI

/// Placement registration stub. Real paywall UI is owned by Superwall.
/// When Superwall SDK is wired, replace the body of `present` with:
///     Superwall.shared.register(placement: "unlock_pro")
enum SuperwallPlacements {
    static func present(_ placement: String, completion: @escaping (Bool) -> Void) {
        // No-op until Superwall is connected. Treat as "user did not convert".
        // Hosted paywall UI lives in the Superwall dashboard, not in app code.
        completion(false)
    }
}
