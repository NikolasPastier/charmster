## Charmster — App Plan

Charmster is a dating/social-skills coaching app: audio-first lectures taught by AI coaches, then live practice roleplay with scoring, spaced-repetition review, and a Duolingo-style path.

### Core flow
- Roadmap/path → lecture story player (5-beat audio-first) → practice handoff → scored session → review queue (SM-2).
- Coaches have real voice + avatar clips streamed from Supabase Storage.

### Lecture audio (FX5 + FX5.1 — shipped)
- Per-beat narration plays pre-generated MP3s from the public Supabase Storage bucket `lecture-audio` at `{lectureId}/{coachId}/{beatId}.mp3` (e.g. `t1-l1/leo/hook.mp3`) via `LectureAudioURL`.
- `lectureId` = `t{track}-l{number}`; `coachId` is `CoachPersona.id` verbatim (`theo`, `dr_ray`, `cole`, `noah`, `leo`) — NO `dr_ray -> ray` remap for audio. `beatId` ∈ `hook`, `coreInsight`, `goodVsBad`, `recallQuestion`, `recallWhy`, `takeawayHandoff`.
- `LectureBeatNarrator` streams the MP3 and fails over to on-device `AVSpeechSynthesizer` TTS only on a genuine load failure, logging the exact resolved URL via `TenXPreviewSupport.log` before falling back.

### Coach voice model (FX6 — shipped)
- `CoachPersona` no longer carries OpenAI TTS voice names. The old `voiceId` field was replaced with a DATA-ONLY `elevenVoiceId: String?` (nil for all coaches), reserved for future on-demand ElevenLabs lines. It never drives lecture TTS — lectures always come from the `lecture-audio` MP3s.

### Backend / integration state
- Supabase connected (project ref uvjtrhvhldeeslgnvhyd). Coach/lecture media served as public Storage URLs. Audio degrades to TTS, so a missing/private object does not break playback.

### Known blocker
- Storage bucket public-flip + inspection blocked by Supabase `502 No such refresh token found`. Needs Supabase reconnect + re-approval before the bucket can be set public from here.</plan>
</invoke>