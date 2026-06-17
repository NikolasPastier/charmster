## Charmster — App Plan

Charmster is a dating/social-skills coaching app: audio-first lectures taught by AI coaches, then live practice roleplay with scoring, spaced-repetition review, and a Duolingo-style path.

### Core flow
- Roadmap/path → lecture story player (5-beat audio-first) → practice handoff → scored session → review queue (SM-2).
- Coaches have real voice + avatar clips streamed from the public Supabase `Avatars` bucket.

### Lecture audio (FX5 — shipped)
- Per-beat narration now plays pre-generated MP3s from `Avatars/Lectures/{coachStorageId}/t{track}-l{number}/{beat}.mp3` via `LectureAudioURL`.
- `LectureBeatNarrator` streams the MP3 with `AVPlayer` and fails over to on-device `AVSpeechSynthesizer` TTS when a clip is missing/unreachable, so beats are never silent.
- Recall beat plays two clips: `recall-question`, then `recall-why` after the user answers.

### Backend / integration state
- Supabase connected (project ref uvjtrhvhldeeslgnvhyd). Coach/lecture media served as public Storage URLs.
- Audio degrades gracefully to TTS, so a missing/private bucket does not break playback.

### Known blocker
- Storage bucket public-flip + inspection currently blocked by Supabase `502 No such refresh token found` (session/auth error). Needs Supabase reconnect + re-approval before the bucket can be set public from here.