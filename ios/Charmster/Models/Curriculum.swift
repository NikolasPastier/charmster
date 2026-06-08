import Foundation

/// Canonical curriculum loaded from `Resources/curriculum.json` in the app bundle.
/// 16 content tracks (1–16) + Track 0 onboarding shell = 17 tracks total.
/// 117 lectures + 16 capstones.
///
/// This is the SINGLE SOURCE OF TRUTH for the app's curriculum shape at runtime.
/// Per-lecture teaching copy / quizzes / scenarios still come from `LectureContentStore`.
enum Curriculum {

    // MARK: - Public surface (signatures preserved for call sites)

    static var tracks: [Track] { current.tracks }
    static var lectures: [Lecture] { current.lectures }

    static func lectures(in trackId: Int) -> [Lecture] {
        current.byTrack[trackId, default: []]
    }

    static func lecture(id: String) -> Lecture? {
        current.byId[id]
    }

    static func capstone(in trackId: Int) -> Lecture? {
        current.byTrack[trackId, default: []].first { $0.isCapstone }
    }

    /// Source the curriculum is currently reading from. Starts as `.bundle`.
    /// Flips to `.remote` once `CurriculumService` overlays Supabase data.
    enum Source { case bundle, remote }
    static private(set) var source: Source = .bundle

    /// Overlay a remotely-loaded curriculum. Called by `CurriculumService` on
    /// successful Supabase fetch. Bundle remains the fallback on failure.
    static func overlayRemote(tracks remoteTracks: [Track], lectures remoteLectures: [Lecture]) {
        var byTrack: [Int: [Lecture]] = [:]
        var byId: [String: Lecture] = [:]
        for l in remoteLectures {
            byTrack[l.trackId, default: []].append(l)
            byId[l.id] = l
        }
        for key in byTrack.keys {
            byTrack[key]?.sort { $0.number < $1.number }
        }
        overlay = LoadedCurriculum(
            tracks: remoteTracks.sorted { $0.order < $1.order },
            lectures: remoteLectures,
            byTrack: byTrack,
            byId: byId
        )
        source = .remote
    }

    private static var overlay: LoadedCurriculum?
    private static var current: LoadedCurriculum { overlay ?? loaded }

    /// Migration helper: rewrite legacy "t{N}_l{N}" lecture IDs from the old
    /// 4-track placeholder curriculum to the new "<track>.<number>" scheme so
    /// existing user progress survives the cutover.
    static func migrateLegacyLectureId(_ legacyId: String) -> String? {
        legacyIdMap[legacyId]
    }

    // MARK: - Loaded model

    fileprivate struct LoadedCurriculum {
        let tracks: [Track]
        let lectures: [Lecture]
        let byTrack: [Int: [Lecture]]
        let byId: [String: Lecture]
    }

    private static let loaded: LoadedCurriculum = {
        do {
            return try decodeFromBundle()
        } catch {
            #if DEBUG
            assertionFailure("Curriculum failed to load from bundle: \(error). Falling back to preview sample.")
            #endif
            return previewSampleLoaded
        }
    }()

    // MARK: - Decoding

    private struct Manifest: Decodable {
        let version: Int
        let tracks: [TrackEntry]
    }

    private struct TrackEntry: Decodable {
        let id: Int
        let slug: String
        let emoji: String
        let title: String
        let coreQuestion: String
        let subtitle: String
        let symbol: String
        let order: Int
        let accessDefault: LectureAccess
        let lectures: [LectureEntry]
        let capstone: CapstoneEntry?
    }

    private struct LectureEntry: Decodable {
        let number: Int
        let title: String
        let access: LectureAccess
        let format: LectureFormat
        let minutes: Int
        let skill: String
        let scenario: String?
    }

    private struct CapstoneEntry: Decodable {
        let title: String
        let scenario: String
        let minutes: Int
        let access: LectureAccess
        let format: LectureFormat
    }

    private static func decodeFromBundle() throws -> LoadedCurriculum {
        guard let url = Bundle.main.url(forResource: "curriculum", withExtension: "json") else {
            throw NSError(domain: "Curriculum", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "curriculum.json missing from bundle"])
        }
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(Manifest.self, from: data)
        return assemble(from: manifest)
    }

    private static func assemble(from manifest: Manifest) -> LoadedCurriculum {
        var tracks: [Track] = []
        var lectures: [Lecture] = []
        var byTrack: [Int: [Lecture]] = [:]
        var byId: [String: Lecture] = [:]

        for entry in manifest.tracks.sorted(by: { $0.order < $1.order }) {
            var trackLectures: [Lecture] = []
            for lec in entry.lectures.sorted(by: { $0.number < $1.number }) {
                let id = "\(entry.id).\(lec.number)"
                let scenario = lec.scenario ?? "\(entry.title) · \(lec.title)"
                let lecture = Lecture(
                    id: id,
                    trackId: entry.id,
                    number: lec.number,
                    title: lec.title,
                    scenario: scenario,
                    minutes: lec.minutes,
                    skill: lec.skill,
                    isCapstone: false,
                    access: lec.access,
                    format: lec.format
                )
                trackLectures.append(lecture)
            }
            if let cap = entry.capstone {
                let capLecture = Lecture(
                    id: "\(entry.id).capstone",
                    trackId: entry.id,
                    number: trackLectures.count + 1,
                    title: "Capstone — \(cap.title)",
                    scenario: cap.scenario,
                    minutes: cap.minutes,
                    skill: "\(entry.title) capstone",
                    isCapstone: true,
                    access: cap.access,
                    format: cap.format
                )
                trackLectures.append(capLecture)
            }

            let track = Track(
                id: entry.id,
                slug: entry.slug,
                title: entry.title,
                subtitle: entry.subtitle,
                coreQuestion: entry.coreQuestion,
                emoji: entry.emoji,
                symbol: entry.symbol,
                order: entry.order,
                accessDefault: entry.accessDefault,
                lectureCount: trackLectures.count
            )
            tracks.append(track)
            lectures.append(contentsOf: trackLectures)
            byTrack[entry.id] = trackLectures
            for lecture in trackLectures { byId[lecture.id] = lecture }
        }

        #if DEBUG
        let contentLectureCount = lectures.filter { !$0.isCapstone && $0.trackId != 0 }.count
        let capstoneCount = lectures.filter { $0.isCapstone }.count
        let contentTrackCount = tracks.filter { $0.id != 0 }.count
        if contentTrackCount != 16 || contentLectureCount != 117 || capstoneCount != 16 {
            assertionFailure("Curriculum manifest counts off: tracks=\(contentTrackCount) lectures=\(contentLectureCount) capstones=\(capstoneCount); expected 16/117/16")
        }
        #endif

        return LoadedCurriculum(tracks: tracks, lectures: lectures, byTrack: byTrack, byId: byId)
    }

    // MARK: - Legacy ID migration (placeholder → canonical)

    /// Old placeholder curriculum used 4 tracks × 5 entries. Map every key the
    /// app may have written to UserDefaults onto the closest canonical lecture
    /// so existing user progress isn't silently wiped.
    private static let legacyIdMap: [String: String] = [
        // Track 0 placeholder → Foundations of Attraction (Track 1)
        "t0_l1": "1.1",
        "t0_l2": "1.4",
        "t0_l3": "1.7",
        "t0_l4": "1.5",
        "t0_l5": "1.capstone",

        // Track 1 placeholder → Conversation Flow / Humor
        "t1_l1": "4.4",
        "t1_l2": "3.5",
        "t1_l3": "4.3",
        "t1_l4": "3.4",
        "t1_l5": "3.capstone",

        // Track 2 placeholder → Confidence / Connection
        "t2_l1": "8.5",
        "t2_l2": "7.3",
        "t2_l3": "13.7",
        "t2_l4": "6.6",
        "t2_l5": "7.capstone",

        // Track 3 placeholder → Mastery / Calibration
        "t3_l1": "5.2",
        "t3_l2": "5.4",
        "t3_l3": "5.6",
        "t3_l4": "13.4",
        "t3_l5": "12.capstone"
    ]
}

// MARK: - Preview / debug fallback (NEVER referenced in production code paths)

#if DEBUG
extension Curriculum {
    /// Tiny, clearly-named sample used only if `Resources/curriculum.json` is
    /// missing during a SwiftUI preview. Not wired into runtime code paths.
    fileprivate static let previewSampleLoaded: Curriculum.LoadedCurriculum = {
        let track = Track(
            id: 1, slug: "preview", title: "Preview Track",
            subtitle: "Debug-only fallback", coreQuestion: "Preview",
            emoji: "🧪", symbol: "hammer.fill", order: 1,
            accessDefault: .free, lectureCount: 1
        )
        let lecture = Lecture(
            id: "1.1", trackId: 1, number: 1,
            title: "Preview lecture", scenario: "Preview scenario",
            minutes: 5, skill: "Preview", isCapstone: false,
            access: .free, format: .video
        )
        return LoadedCurriculum(
            tracks: [track], lectures: [lecture],
            byTrack: [1: [lecture]], byId: ["1.1": lecture]
        )
    }()
}
#else
extension Curriculum {
    /// Production builds return an empty curriculum on load failure so the bug
    /// is visible (empty roadmap) rather than masked by fake placeholders.
    fileprivate static let previewSampleLoaded: Curriculum.LoadedCurriculum =
        LoadedCurriculum(tracks: [], lectures: [], byTrack: [:], byId: [:])
}
#endif
