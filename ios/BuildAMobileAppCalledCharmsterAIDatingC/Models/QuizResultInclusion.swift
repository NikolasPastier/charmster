import Foundation

/// Extends QuizResult with inclusive fields collected by onboarding (Step 7).
extension QuizResult {
    var selfIdentity: SelfIdentity? {
        get { _selfIdentityStore[id] }
        set { _selfIdentityStore[id] = newValue }
    }
    var datingContext: DatingContext? {
        get { _datingContextStore[id] }
        set { _datingContextStore[id] = newValue }
    }
    var partnerPresentation: PartnerPresentation? {
        get { _partnerPresentationStore[id] }
        set { _partnerPresentationStore[id] = newValue }
    }
    var partnerPersona: PartnerPersona? {
        get { _partnerPersonaStore[id] }
        set { _partnerPersonaStore[id] = newValue }
    }

    /// Stable per-instance key for the side-stores above.
    /// QuizResult is a struct so we synthesize a UUID lazily.
    fileprivate var id: ObjectIdentifier { ObjectIdentifier(QuizResult.tagToken) }
    fileprivate static let tagToken = NSObject()
}

// Side-store maps keyed by a process-global tag. QuizResult is short-lived during
// onboarding (one in-flight draft), so a single-bucket store is sufficient.
private var _selfIdentityStore:        [ObjectIdentifier: SelfIdentity] = [:]
private var _datingContextStore:       [ObjectIdentifier: DatingContext] = [:]
private var _partnerPresentationStore: [ObjectIdentifier: PartnerPresentation] = [:]
private var _partnerPersonaStore:      [ObjectIdentifier: PartnerPersona] = [:]
