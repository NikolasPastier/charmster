import Foundation

// MARK: - Conversation mode
//
// Whether the skill in this lecture is practiced FACE TO FACE (spoken out loud)
// or over TEXT (messaging). Drives how the GoodVsBad beat renders: in-person
// shows spoken-line cards; texting shows chat-bubble mockups. Default is
// `inPerson` — a lecture is `texting` ONLY when it's explicitly about
// texting/messaging. Stored on the derived story so it stays editable.
enum ConversationMode: String, Codable, Hashable {
  case inPerson
  case texting
}

// MARK: - Beat kind (the proven 5-beat structure, ordered)

enum LectureBeatKind: String, Codable, Hashable, CaseIterable {
  case hook
  case coreInsight
  case goodVsBad
  case recallCheck
  case takeawayHandoff
}

// MARK: - Visual type

/// How a beat renders on screen WHILE the coach voice plays. The narration is
/// always audio-first; on-screen we show the visual + a single signal phrase,
/// never the full script.
enum LectureBeatVisual: String, Codable, Hashable {
  /// Coach avatar talking loop (face + voice) — the emotional beats.
  case avatar
  /// Quoted lines said OUT LOUD (in-person good/bad), voice-wave styled.
  case spokenLineCards
  /// Chat-bubble messaging mockup (texting good/bad).
  case chatMockup
  /// Generic side-by-side good/bad contrast (insight emphasis).
  case contrastCards
  /// The active-recall question with tappable options.
  case recallQuestion
}

// MARK: - Recall payload

struct RecallCheck: Codable, Hashable {
  let question: String
  let options: [String]
  let correctIndex: Int
  /// One-line reason shown after answering, in the coach's framing.
  let why: String
}

// MARK: - Good vs Bad example pair

struct ContrastExample: Codable, Hashable {
  /// The quoted line / message text.
  let line: String
  /// Optional "how she'd feel" reaction tag (spoken-line cards only).
  let reactionTag: String?
}

// MARK: - LectureBeat

/// One ordered story-card. Narration is delivered as AUDIO in the coach's
/// voice; `signalPhrase` is the ONLY text shown on screen during playback.
struct LectureBeat: Identifiable, Hashable, Codable {
  let id: String
  let kind: LectureBeatKind
  /// Coach-voice narration (used for TTS / pre-generated audio). NOT rendered
  /// as on-screen body text — captions can reveal it for accessibility.
  let narrationText: String
  /// The single key phrase shown on screen (signaling principle).
  let signalPhrase: String
  let visual: LectureBeatVisual

  // Beat-specific payloads (only the relevant one is populated).
  var goodExample: ContrastExample? = nil
  var badExample: ContrastExample? = nil
  var recall: RecallCheck? = nil

  /// Highlight-reel phrases revealed as the coach narrates (Hook / Core Insight /
  /// Takeaway beats). 2–3 short phrases (≤ 6 words each) — a caption highlight,
  /// not a transcript. Empty for GoodVsBad and Recall, whose on-screen content
  /// already IS the beat. Defaulted so older decoded LectureStory values stay valid.
  var keyPoints: [String] = []

  /// Whether this beat leads with the coach's face (talking loop under audio).
  var isAvatarBeat: Bool { visual == .avatar }
}

// MARK: - LectureStory

/// The full derived, ordered 5-beat story for one (lecture, coach) pair.
struct LectureStory: Identifiable, Hashable, Codable {
  var id: String { "\(lectureId)#\(coachId)" }
  let lectureId: String
  let coachId: String
  let conversationMode: ConversationMode
  let beats: [LectureBeat]
  /// UX5 — 2–3 outcome lines previewed on the intro "What you'll learn" card
  /// (Card 0). Derived from existing lecture metadata; never a curriculum
  /// rewrite. Each line is a short "You'll be able to…" / "Say…" / "Avoid…"
  /// outcome. Defaulted so older decoded stories stay valid.
  var learningObjectives: [String] = []
}
