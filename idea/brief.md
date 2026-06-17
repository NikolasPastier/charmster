## Charmster — App Plan

Charmster is a dating/social-skills coaching app: audio-first lectures taught by AI coaches, then live practice roleplay with scoring, spaced-repetition review, and a Duolingo-style path.

### Core flow
- Roadmap/path → lecture story player (5-beat audio-first) → practice handoff → scored session → review queue (SM-2).
- Coaches have real voice + avatar clips streamed from Supabase Storage.

### Lecture audio (FX5 + FX5.1 — shipped)
- Per-beat narration plays pre-generated MP3s from the public Supabase Storage bucket `lecture-audio` at `{lectureId}/{coachId}/{beatId}.mp3` (e.g. `t1-l1/leo/hook.mp3`) via `LectureAudioURL`.
- `lectureId` = `t{track}-l{number}`; `coachId` is `CoachPersona.id` verbatim (`theo`, `dr_ray`, `cole`, `noah`, `leo`) — NO `dr_ray -> ray` remap for audio (that remap is video-clips only). `beatId` ∈ `hook`, `coreInsight`, `goodVsBad`, `recallQuestion`, `recallWhy`, `takeawayHandoff`.
- FX5.1 corrected the previously-wrong `Avatars/Lectures/...` path that caused every clip to 404 and silently degrade to TTS.
- `LectureBeatNarrator` streams the MP3 with `AVPlayer` and fails over to on-device `AVSpeechSynthesizer` TTS only on a genuine load failure, which now logs the exact resolved URL (+ underlying error) via `TenXPreviewSupport.log` before falling back.
- Recall beat plays two clips: `recallQuestion`, then `recallWhy` after the user answers.

### Backend / integration state
- Supabase connected (project ref uvjtrhvhldeeslgnvhyd). Coach/lecture media served as public Storage URLs.
- Audio degrades gracefully to TTS, so a missing/private object does not break playback.

### Known blocker
- Storage bucket public-flip + inspection blocked by Supabase `502 No such refresh token found` (session/auth error). Needs Supabase reconnect + re-approval before the bucket can be set public from here.