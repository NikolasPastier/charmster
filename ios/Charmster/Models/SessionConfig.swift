import Foundation

/// Per-session configuration. Does NOT mutate AppState globals.
struct SessionConfig: Hashable {
    var persona: PartnerPersona
    var setting: PracticeSetting
    var tier: DifficultyTier
    var coach: CoachStyle
    var mode: PracticeMode
    var isSandbox: Bool
    var sandboxScored: Bool  // "Coached" vs "Just Vibe"
    var sandboxPremise: String?

    static func recommended(from app: AppState, lecture: Lecture?) -> SessionConfig {
        SessionConfig(
            persona: app.selectedPersona,
            setting: app.selectedSetting,
            tier: app.difficultyTier,
            coach: app.coachMode,
            mode: app.profile.practiceModeDefault,
            isSandbox: lecture == nil,
            sandboxScored: true,
            sandboxPremise: nil
        )
    }
}
