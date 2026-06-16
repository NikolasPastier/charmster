import SwiftUI

/// First-run onboarding. One hero + the optimal-order personalization quiz +
/// name/avatar + privacy primer + account/age gate + a growth-framed plan +
/// a free taster session, with the paywall handed off only afterward.
///
/// Flow order (spec):
/// 1 Hero · 2 Goal · 3 Experience · 4 Where you freeze · 5 Confidence ·
/// 6 Coach style · 7 Attachment + flirting (skippable) · 8 Daily goal ·
/// 9 Name + avatar · 10 Privacy primer · 11 Account + 17+ ·
/// 12 Personalized plan · 13 Free taster → paywall.
struct OnboardingFlowView: View {
  @Environment(AppState.self) private var app

  /// Logical steps. `plan` and `taster` sit after the progress-bar steps.
  private enum Step: Int, CaseIterable {
    case hero, goal, experience, freeze, confidence, coach, psych, daily, name, privacy, account
    case plan, taster
  }

  @State private var step: Step = .hero

  /// Steps that show the gradient progress bar (everything from goal..account).
  private static let progressSteps: [Step] = [
    .goal, .experience, .freeze, .confidence, .coach, .psych, .daily, .name, .privacy, .account,
  ]

  private func progressIndex(_ s: Step) -> Int {
    (Self.progressSteps.firstIndex(of: s) ?? 0) + 1
  }
  private var progressTotal: Int { Self.progressSteps.count }

  var body: some View {
    ZStack {
      Theme.bg.ignoresSafeArea()
      content
        .transition(
          .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
          )
        )
        .id(step)
    }
    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: step)
    .trackView("OnboardingFlowView")
  }

  @ViewBuilder
  private var content: some View {
    switch step {
    case .hero:
      HeroStep { go(.goal) }
    case .goal:
      GoalStep(
        step: progressIndex(.goal), total: progressTotal,
        onBack: { go(.hero) }, onNext: { go(.experience) })
    case .experience:
      ExperienceStep(
        step: progressIndex(.experience), total: progressTotal,
        onBack: { go(.goal) }, onNext: { go(.freeze) })
    case .freeze:
      FreezeStep(
        step: progressIndex(.freeze), total: progressTotal,
        onBack: { go(.experience) }, onNext: { go(.confidence) })
    case .confidence:
      ConfidenceStep(
        step: progressIndex(.confidence), total: progressTotal,
        onBack: { go(.freeze) }, onNext: { go(.coach) })
    case .coach:
      CoachStyleStep(
        step: progressIndex(.coach), total: progressTotal,
        onBack: { go(.confidence) }, onNext: { go(.psych) })
    case .psych:
      PsychStep(
        step: progressIndex(.psych), total: progressTotal,
        onBack: { go(.coach) }, onNext: { go(.daily) })
    case .daily:
      DailyGoalStep(
        step: progressIndex(.daily), total: progressTotal,
        onBack: { go(.psych) }, onNext: { go(.name) })
    case .name:
      NameAvatarStep(
        step: progressIndex(.name), total: progressTotal,
        onBack: { go(.daily) }, onNext: { go(.privacy) })
    case .privacy:
      PrivacyPrimerStep(
        step: progressIndex(.privacy), total: progressTotal,
        onBack: { go(.name) }, onNext: { go(.account) })
    case .account:
      AccountStep(
        step: progressIndex(.account), total: progressTotal,
        onBack: { go(.privacy) },
        onNext: {
          app.recomputePersonalization()
          app.unlockRecommendedStart()
          app.persistSettings()
          go(.plan)
        })
    case .plan:
      PersonalizedPlanStep { go(.taster) }
    case .taster:
      TasterStep { finish() }
    }
  }

  private func go(_ s: Step) {
    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) { step = s }
  }

  /// Final handoff: the paywall is shown only here, after the free taster.
  private func finish() {
    app.recomputePersonalization()
    app.persistSettings()
    app.hasCompletedOnboarding = true
    CharmsterSuperwall.register(.onboardingComplete)
  }
}

// MARK: - 1 · Hero

private struct HeroStep: View {
  let onContinue: () -> Void

  var body: some View {
    ZStack {
      AuraGlowLayer(intensity: 0.55, partnerSpeaking: false)
        .opacity(0.9)
      GeometryReader { geo in
        VStack(spacing: 0) {
          Spacer(minLength: geo.size.height * 0.08)

          CharmsterLogo(height: 240)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 28)

          Text("Practice love.\nBuild real confidence.")
            .font(.system(size: 34, weight: .heavy))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 16)

          Text("Your private coach for real conversations — judgment-free.")
            .font(.system(size: 16))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.textMuted)
            .padding(.horizontal, 32)
            .padding(.top, 10)

          VStack(spacing: 14) {
            OnboardingBenefitRow(
              systemImage: "waveform",
              title: "Live AI practice",
              subtitle: "Talk to a realistic partner and get real-time feedback.")
            OnboardingBenefitRow(
              systemImage: "map.fill",
              title: "A science-based path",
              subtitle: "Built around how attraction and connection actually work.")
            OnboardingBenefitRow(
              systemImage: "person.crop.circle.badge.checkmark",
              title: "Your coach, your pace",
              subtitle: "Pick a voice and difficulty that fit you.")
          }
          .padding(.horizontal, 26)
          .padding(.top, 30)

          Spacer(minLength: 0)

          AuraButton(title: "Get started", systemImage: "arrow.right", action: onContinue)
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .frame(width: geo.size.width, height: geo.size.height)
      }
    }
  }
}

// MARK: - 2 · Goal (sets recommended start track)

private struct GoalStep: View {
  @Environment(AppState.self) private var app
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  private let options: [(String, String, String)] = [
    ("Date with intention", "Looking for something real", "heart.fill"),
    ("Date casually", "Keep it light and fun", "sparkles"),
    ("Get unstuck", "Quiet the overthinking", "arrow.up.heart.fill"),
    ("Confidence in general", "Feel sure of myself anywhere", "figure.stand"),
  ]

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "What are you here for?",
      subtitle: "This sets where your path starts. You can change it anytime.",
      onBack: onBack
    ) {
      VStack(spacing: 10) {
        ForEach(options, id: \.0) { opt in
          OnboardingOptionCard(
            title: opt.0, subtitle: opt.1, systemImage: opt.2,
            isSelected: app.profile.goal == opt.0
          ) { app.profile.goal = opt.0 }
        }
      }
    } footer: {
      AuraButton(title: "Continue", systemImage: "arrow.right", action: onNext)
    }
  }
}

// MARK: - 3 · Experience

private struct ExperienceStep: View {
  @Environment(AppState.self) private var app
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  private let options: [(String, String)] = [
    ("Brand new", "leaf.fill"),
    ("Some experience", "figure.walk"),
    ("Plenty, but mixed", "arrow.triangle.swap"),
    ("Veteran", "star.fill"),
  ]

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "How much dating experience\ndo you have?",
      subtitle: "This tunes your starting difficulty.",
      onBack: onBack
    ) {
      VStack(spacing: 10) {
        ForEach(options, id: \.0) { opt in
          OnboardingOptionCard(
            title: opt.0, systemImage: opt.1,
            isSelected: app.profile.experience == opt.0
          ) { app.profile.experience = opt.0 }
        }
      }
    } footer: {
      AuraButton(title: "Continue", systemImage: "arrow.right", action: onNext)
    }
  }
}

// MARK: - 4 · Where you freeze (multi-select)

private struct FreezeStep: View {
  @Environment(AppState.self) private var app
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  private let options: [(String, String, String)] = [
    ("Opening", "The first move", "hand.wave.fill"),
    ("Flow", "Keeping it going", "bubble.left.and.bubble.right.fill"),
    ("Calibration", "Reading their interest", "eye.fill"),
    ("Closing", "Asking for the next step", "arrow.right.circle.fill"),
  ]

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "Where do you usually freeze?",
      subtitle: "Pick all that apply — we'll emphasize these.",
      onBack: onBack
    ) {
      VStack(spacing: 10) {
        ForEach(options, id: \.0) { opt in
          OnboardingOptionCard(
            title: opt.0, subtitle: opt.1, systemImage: opt.2,
            isSelected: app.profile.focusAreas.contains(opt.0)
          ) {
            if app.profile.focusAreas.contains(opt.0) {
              app.profile.focusAreas.remove(opt.0)
            } else {
              app.profile.focusAreas.insert(opt.0)
            }
          }
        }
      }
    } footer: {
      AuraButton(title: "Continue", systemImage: "arrow.right", action: onNext)
    }
  }
}

// MARK: - 5 · Confidence slider

private struct ConfidenceStep: View {
  @Environment(AppState.self) private var app
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  @State private var value: Double = 5

  private var label: String {
    switch Int(value) {
    case ...3: return "Still building it"
    case 4...6: return "Some days good, some not"
    case 7...8: return "Pretty solid"
    default: return "Rock solid"
    }
  }

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "How's your day-to-day\nconfidence?",
      subtitle: "Be honest — there's no wrong answer.",
      onBack: onBack
    ) {
      VStack(spacing: 22) {
        ZStack {
          Circle().fill(Theme.surface)
          ScoreRing(value: Int(value) * 10, size: 150, lineWidth: 12, label: "out of 10")
        }
        .frame(width: 170, height: 170)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)

        Text(label)
          .font(.system(size: 17, weight: .heavy))
          .foregroundStyle(Theme.text)
          .frame(maxWidth: .infinity)

        Slider(value: $value, in: 1...10, step: 1)
          .tint(Theme.accent)
          .onChange(of: value) { _, v in
            app.profile.confidence = Int(v)
            #if canImport(UIKit)
              UISelectionFeedbackGenerator().selectionChanged()
            #endif
          }
      }
    } footer: {
      AuraButton(title: "Continue", systemImage: "arrow.right", action: onNext)
    }
    .onAppear { value = Double(app.profile.confidence) }
  }
}

// MARK: - 6 · Coach style (all five)

private struct CoachStyleStep: View {
  @Environment(AppState.self) private var app
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "Meet your coaches",
      subtitle: "Pick the one whose voice you want in your corner. Switch anytime.",
      onBack: onBack
    ) {
      CoachGalleryView(embedded: true)
    } footer: {
      AuraButton(
        title: "Continue with \(app.selectedCoach.humanName)", systemImage: "arrow.right",
        action: onNext)
    }
  }
}

// MARK: - 7 · Attachment + flirting (skippable)

private struct PsychStep: View {
  @Environment(AppState.self) private var app
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  // 6-item check-in: 0–2 anxiety, 3–5 avoidance.
  private let prompts: [String] = [
    "I worry the people I like will lose interest in me.",
    "I need a lot of reassurance that I'm wanted.",
    "I get anxious when someone takes a while to reply.",
    "I keep some distance until I really trust someone.",
    "I find it hard to fully open up.",
    "I prefer to rely on myself rather than lean on a partner.",
  ]
  private let flirtingOptions: [(String, String)] = [
    ("Warm", "heart.fill"),
    ("Playful", "sparkles"),
    ("Dry", "moon.stars.fill"),
    ("Direct", "arrow.right.circle.fill"),
  ]

  @State private var answers: [Int?] = Array(repeating: nil, count: 6)

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "A quick check-in",
      subtitle: "This shapes how I frame feedback. Totally optional — skip if you'd rather.",
      onBack: onBack
    ) {
      VStack(alignment: .leading, spacing: 18) {
        ForEach(prompts.indices, id: \.self) { i in
          LikertRow(prompt: prompts[i], value: answers[i]) { v in
            answers[i] = v
          }
        }

        Divider().overlay(Theme.border)

        Text("Your flirting style")
          .font(.system(size: 15, weight: .heavy))
          .foregroundStyle(Theme.text)
        VStack(spacing: 10) {
          ForEach(flirtingOptions, id: \.0) { opt in
            OnboardingOptionCard(
              title: opt.0, systemImage: opt.1,
              isSelected: app.profile.flirtingStyle == opt.0
            ) { app.profile.flirtingStyle = opt.0 }
          }
        }
      }
    } footer: {
      AuraButton(title: "Continue", systemImage: "arrow.right") {
        commitAttachment()
        onNext()
      }
      Button("Skip — use balanced defaults") {
        // Keep secure-leaning defaults already on the profile.
        app.profile.attachmentAnswers = []
        onNext()
      }
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(Theme.textMuted)
    }
    .onAppear {
      if app.profile.attachmentAnswers.count == 6 {
        answers = app.profile.attachmentAnswers.map { $0 }
      }
    }
  }

  private func commitAttachment() {
    // Only persist if fully answered; otherwise keep defaults.
    if answers.allSatisfy({ $0 != nil }) {
      app.profile.attachmentAnswers = answers.map { $0 ?? 3 }
    } else {
      app.profile.attachmentAnswers = []
    }
  }
}

// MARK: - 8 · Daily goal + reminder

private struct DailyGoalStep: View {
  @Environment(AppState.self) private var app
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  private let goals: [(Int, String)] = [
    (5, "Casual"), (10, "Steady"), (15, "Serious"), (20, "Intense"),
  ]
  @State private var wantsReminder = false
  @State private var reminderTime =
    Calendar.current.date(
      bySettingHour: 19, minute: 0, second: 0, of: .now) ?? .now

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "Set your daily goal",
      subtitle: "Short, consistent reps beat marathons. Pick a target.",
      onBack: onBack
    ) {
      VStack(spacing: 16) {
        VStack(spacing: 10) {
          ForEach(goals, id: \.0) { g in
            OnboardingOptionCard(
              title: "\(g.0) min / day", subtitle: g.1, systemImage: "timer",
              isSelected: app.profile.dailyGoalMinutes == g.0
            ) { app.profile.dailyGoalMinutes = g.0 }
          }
        }

        GlassCard {
          VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $wantsReminder) {
              VStack(alignment: .leading, spacing: 2) {
                Text("Daily reminder").font(.system(size: 15, weight: .heavy))
                  .foregroundStyle(Theme.text)
                Text("A nudge to keep your streak alive.")
                  .font(.system(size: 12)).foregroundStyle(Theme.textMuted)
              }
            }
            .tint(Theme.accent)

            if wantsReminder {
              DatePicker(
                "Remind me at", selection: $reminderTime, displayedComponents: .hourAndMinute
              )
              .tint(Theme.accent)
              .foregroundStyle(Theme.text)
              // The compact time pill is rendered by the system control, so its
              // label color follows the environment color scheme rather than
              // `foregroundStyle`. Force dark so the time reads as light text on
              // the dark chip instead of near-black-on-dark.
              .environment(\.colorScheme, .dark)
            }
          }
        }
      }
    } footer: {
      AuraButton(title: "Continue", systemImage: "arrow.right") {
        Task { await commitReminder() }
        onNext()
      }
    }
    .onAppear {
      wantsReminder = app.profile.dailyReminderTime != nil
      if let t = app.profile.dailyReminderTime { reminderTime = t }
    }
  }

  private func commitReminder() async {
    if wantsReminder {
      app.profile.notificationsStreak = true
      app.profile.dailyReminderTime = reminderTime
      // Request OS permission in-context only because the user opted in.
      _ = await NotificationManager.requestAuthorization()
      NotificationManager.applyDailyReminder(profile: app.profile)
    } else {
      app.profile.dailyReminderTime = nil
      NotificationManager.applyDailyReminder(profile: app.profile)
    }
  }
}

// MARK: - 9 · Name + pick your avatar

private struct NameAvatarStep: View {
  @Environment(AppState.self) private var app
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  @State private var name: String = ""

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "Who are you practicing with?",
      subtitle: "Pick a partner look and name them. You can change this later.",
      onBack: onBack
    ) {
      VStack(alignment: .leading, spacing: 18) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(AvatarPersona.library) { persona in
              avatarTile(persona)
            }
          }
          .padding(.vertical, 4)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Their name").font(.system(size: 14, weight: .heavy))
            .foregroundStyle(Theme.textMuted)
          TextField("Mia", text: $name)
            .textFieldStyle(.plain)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
          Text("This is just your practice partner's name — you'll pick your own on the next step.")
            .font(.system(size: 12)).foregroundStyle(Theme.textFaint)
        }

        VStack(alignment: .leading, spacing: 8) {
          Text("Their voice").font(.system(size: 14, weight: .heavy))
            .foregroundStyle(Theme.textMuted)
          AvatarVoicePicker(
            selectedId: Binding(
              get: { app.profile.avatarVoiceId },
              set: { app.profile.avatarVoiceId = $0 }
            ),
            onChange: { _ in app.persistSettings() }
          )
        }
      }
    } footer: {
      AuraButton(title: "Continue", systemImage: "arrow.right") {
        app.profile.avatarName = Self.resolvedName(name, lookId: app.profile.avatarLookId)
        onNext()
      }
      Button("Skip — use Mia") {
        app.profile.avatarLookId = "mia"
        app.profile.avatarName = "Mia"
        onNext()
      }
      .font(.system(size: 14, weight: .semibold))
      .foregroundStyle(Theme.textMuted)
    }
    .onAppear {
      name = app.profile.avatarName.isEmpty ? defaultName() : app.profile.avatarName
    }
  }

  private func avatarTile(_ persona: AvatarPersona) -> some View {
    let selected = app.profile.avatarLookId == persona.id
    return Button {
      #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      #endif
      withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        app.profile.avatarLookId = persona.id
        // Prefill name with the look's default if the field is empty/default.
        if name.trimmingCharacters(in: .whitespaces).isEmpty
          || AvatarPersona.library.contains(where: { $0.displayName == name })
        {
          name = persona.displayName
        }
      }
    } label: {
      VStack(spacing: 8) {
        ZStack {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Theme.surfaceRaised)
          PartnerStillImage(persona: persona) {
            ZStack {
              Theme.auraGradient.opacity(0.5)
              Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(selected ? Theme.text : Theme.textMuted)
            }
          }
        }
        .frame(width: 120, height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
              selected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.border),
              lineWidth: selected ? 3 : 1)
        )
        Text(persona.displayName).font(.system(size: 14, weight: .heavy))
          .foregroundStyle(Theme.text)
      }
    }
    .buttonStyle(.plain)
  }

  private func defaultName() -> String {
    AvatarPersona.resolve(from: app.profile.avatarLookId).defaultDisplayName
  }

  /// Trim, cap at ~20 chars, and fall back to the selected look's default name
  /// (global default "Mia") when blank/whitespace. avatarName is display-only.
  static func resolvedName(_ raw: String, lookId: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let fallback = AvatarPersona.resolve(from: lookId).defaultDisplayName
    if trimmed.isEmpty { return fallback }
    return String(trimmed.prefix(20))
  }
}

// MARK: - 10 · Privacy + trust + cam/mic primer

private struct PrivacyPrimerStep: View {
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "Your practice stays yours",
      subtitle: "Live practice feels real because it uses your camera and mic — here's the deal.",
      onBack: onBack
    ) {
      VStack(spacing: 12) {
        trustRow(
          "lock.shield.fill", "Never recorded or stored",
          "Video and audio are analyzed live and discarded. Nothing is saved.")
        trustRow(
          "waveform", "Always an audio-only option",
          "Camera shy? Practice with voice only, or text — your call.")
        trustRow(
          "hand.raised.fill", "Permission only when you start",
          "We ask for camera and mic at your first live session, never before.")
        trustRow(
          "person.2.fill", "Judgment-free by design",
          "Thousands practice the awkward parts here so the real thing feels easy.")
      }
    } footer: {
      AuraButton(title: "Got it", systemImage: "arrow.right", action: onNext)
    }
  }

  private func trustRow(_ icon: String, _ title: String, _ body: String) -> some View {
    GlassCard(padding: 14) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 16, weight: .bold))
          .foregroundStyle(Theme.accent)
          .frame(width: 38, height: 38)
          .background(Circle().fill(Theme.accent.opacity(0.12)))
        VStack(alignment: .leading, spacing: 2) {
          Text(title).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.text)
          Text(body).font(.system(size: 13)).foregroundStyle(Theme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
    }
  }
}

// MARK: - 11 · Account setup + 17+ gate

private struct AccountStep: View {
  @Environment(AppState.self) private var app
  let step: Int
  let total: Int
  let onBack: () -> Void
  let onNext: () -> Void

  @State private var username: String = ""
  @State private var ageConfirmed = false

  // Lightweight client-side profanity screen (server-side check is the source
  // of truth once auth lands — see TODO below).
  private static let blocklist = ["admin", "fuck", "shit", "bitch", "nazi", "cunt"]

  private var usernameValid: Bool {
    let u = username.trimmingCharacters(in: .whitespaces).lowercased()
    guard u.count >= 3, u.count <= 20 else { return false }
    if Self.blocklist.contains(where: { u.contains($0) }) { return false }
    return u.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }
  }

  private var canContinue: Bool { usernameValid && ageConfirmed }

  var body: some View {
    OnboardingStep(
      step: step, total: total,
      title: "Create your account",
      subtitle: "Pick a username. We'll keep your progress synced.",
      onBack: onBack
    ) {
      VStack(alignment: .leading, spacing: 16) {
        VStack(spacing: 8) {
          UserAvatarPicker(size: 96, showsRemove: true)
          Text("Add a profile photo (optional)")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)

        VStack(alignment: .leading, spacing: 8) {
          Text("Username").font(.system(size: 14, weight: .heavy))
            .foregroundStyle(Theme.textMuted)
          TextField("yourname", text: $username)
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.text)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
            .overlay(
              RoundedRectangle(cornerRadius: 14)
                .stroke(
                  username.isEmpty ? Theme.border : (usernameValid ? Theme.good : Theme.coral),
                  lineWidth: 1))
          if !username.isEmpty && !usernameValid {
            Text("3–20 letters, numbers or _ · keep it clean")
              .font(.system(size: 12)).foregroundStyle(Theme.coral)
          }
        }

        Button {
          #if canImport(UIKit)
            UISelectionFeedbackGenerator().selectionChanged()
          #endif
          withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { ageConfirmed.toggle() }
        } label: {
          HStack(spacing: 12) {
            Image(systemName: ageConfirmed ? "checkmark.square.fill" : "square")
              .font(.system(size: 22))
              .foregroundStyle(ageConfirmed ? Theme.accent : Theme.textFaint)
            Text("I confirm I'm 17 or older.")
              .font(.system(size: 15, weight: .semibold))
              .foregroundStyle(Theme.text)
            Spacer()
          }
          .padding(14)
          .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
          .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)

        Text(
          "A default avatar is used if you skip a profile photo. You can add one later in Settings."
        )
        .font(.system(size: 12)).foregroundStyle(Theme.textFaint)
      }
    } footer: {
      AuraButton(title: "Create account", systemImage: "checkmark", enabled: canContinue) {
        let cleaned = username.trimmingCharacters(in: .whitespaces)
        app.profile.username = cleaned
        // Single source of truth for the USER's display name: the account
        // username drives the greeting, Profile, and Settings. The partner
        // screen no longer writes `profile.name`, so there is no competing
        // path that could overwrite it with the partner's name.
        app.profile.name = cleaned
        app.profile.ageConfirmed17 = true
        app.profile.ageConfirmedAt = .now
        // TODO(backend): on real Supabase auth, check username uniqueness +
        // run server-side profanity screen, then create the profile row +
        // persist the personalization profile (one row per user).
        onNext()
      }
    }
    .onAppear {
      // Prefer an existing username; otherwise carry forward any name already set.
      username = app.profile.username.isEmpty ? app.profile.name : app.profile.username
      ageConfirmed = app.profile.ageConfirmed17
    }
  }
}

// MARK: - 12 · Personalized plan (payoff)

private struct PersonalizedPlanStep: View {
  @Environment(AppState.self) private var app
  let onStart: () -> Void

  var body: some View {
    ZStack {
      AuraGlowLayer(
        intensity: 0.4 + Double(app.profile.confidence) / 25.0, partnerSpeaking: false
      )
      .opacity(0.85)

      ScrollView {
        VStack(spacing: 18) {
          Text("Your plan is ready")
            .font(.system(size: 13, weight: .bold)).tracking(1.6)
            .foregroundStyle(Theme.textMuted).textCase(.uppercase)
            .padding(.top, 30)

          avatarBadge

          Text("You're starting strong, \(displayName).")
            .font(.system(size: 26, weight: .heavy))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 24)

          Text(strengthLine)
            .font(.system(size: 15))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.textMuted)
            .padding(.horizontal, 30)

          startTrackCard
          settingsCard

          Text("This is your starting point, not a verdict. It moves as you do.")
            .font(.system(size: 12))
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.textFaint)
            .padding(.horizontal, 30)
            .padding(.top, 4)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
      }

      VStack {
        Spacer()
        AuraButton(
          title: "Start your first lesson — free", systemImage: "play.fill", action: onStart
        )
        .padding(.horizontal, 22)
        .padding(.bottom, 28)
        .background(
          LinearGradient(
            colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom
          )
          .frame(height: 120)
          .allowsHitTesting(false),
          alignment: .bottom
        )
      }
    }
  }

  private var displayName: String {
    app.profile.name.isEmpty ? "you" : app.profile.name
  }

  private var avatarBadge: some View {
    let persona = AvatarPersona.resolve(from: app.profile.avatarLookId)
    let partnerName = app.profile.avatarName.isEmpty ? persona.displayName : app.profile.avatarName
    return VStack(spacing: 12) {
      UserAvatarView(
        name: app.profile.name, photoPath: app.profile.profilePhotoPath, size: 96
      )
      .auraGlow(color: Theme.accent, radius: 20, intensity: 0.38)

      // The AI partner is shown separately — never as the user's own picture.
      HStack(spacing: 8) {
        ZStack {
          Circle().fill(Theme.surfaceRaised)
          PartnerStillImage(persona: persona) {
            Image(systemName: "person.crop.circle.fill")
              .font(.system(size: 14)).foregroundStyle(Theme.text)
          }
        }
        .frame(width: 28, height: 28)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.accentGradient, lineWidth: 1.5))

        Text("Practicing with \(partnerName)")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Theme.textMuted)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Capsule().fill(Theme.surface))
      .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
    }
  }

  private var strengthLine: String {
    "Your style reads as \(app.profile.attachmentLabel.lowercased()) — that's a real strength we'll build on."
  }

  private var startTrackCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 8) {
        SectionHeader(title: "Start here", systemImage: app.recommendedStartTrack.symbol)
        Text(app.recommendedStartTrack.title)
          .font(.system(size: 18, weight: .heavy))
          .foregroundStyle(Theme.text)
        Text(app.recommendedStartReason)
          .font(.system(size: 14))
          .foregroundStyle(Theme.textMuted)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  private var settingsCard: some View {
    GlassCard {
      VStack(spacing: 10) {
        planRow("Coach", app.coachMode.title, app.coachMode.icon)
        Divider().overlay(Theme.border)
        planRow("Difficulty", app.difficultyTier.title, "dial.medium.fill")
        Divider().overlay(Theme.border)
        planRow("Daily goal", "\(app.profile.dailyGoalMinutes) min", "timer")
      }
    }
  }

  private func planRow(_ label: String, _ value: String, _ icon: String) -> some View {
    HStack(spacing: 10) {
      Image(systemName: icon).foregroundStyle(Theme.accent)
        .frame(width: 26)
      Text(label).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.textMuted)
      Spacer()
      Text(value).font(.system(size: 15, weight: .heavy)).foregroundStyle(Theme.text)
    }
  }
}

// MARK: - 13 · Free taster session → paywall

private struct TasterStep: View {
  @Environment(AppState.self) private var app
  let onComplete: () -> Void

  @State private var phase: Phase = .intro
  @State private var result: SessionResult?

  private enum Phase { case intro, running, results }

  var body: some View {
    ZStack {
      Theme.bg.ignoresSafeArea()
      switch phase {
      case .intro:
        intro
      case .running:
        if let cfg = tasterConfig {
          LivePracticeView(
            lecture: app.tasterLecture, config: cfg,
            onFinish: { r in
              app.completeSandbox(result: r, scored: true)
              result = r
              withAnimation(.smooth) { phase = .results }
            },
            onClose: { onComplete() }
          )
          .environment(app)
        } else {
          intro
        }
      case .results:
        if let r = result {
          ResultsView(
            result: r, lecture: app.tasterLecture, onQuiz: {},
            onDone: { onComplete() })
        }
      }
    }
  }

  private var tasterConfig: SessionConfig? {
    SessionConfig(
      persona: PartnerPersona.library.first { $0.id == app.profile.avatarLookId }
        ?? .default,
      setting: .default,
      tier: app.difficultyTier,
      coach: app.coachMode,
      mode: .videoVoice,
      isSandbox: true,
      sandboxScored: true,
      sandboxPremise: nil
    )
  }

  private var intro: some View {
    ZStack {
      AuraGlowLayer(intensity: 0.6, partnerSpeaking: false).opacity(0.85)
      VStack(spacing: 18) {
        Spacer()
        Image(systemName: "sparkles")
          .font(.system(size: 44, weight: .bold))
          .foregroundStyle(Theme.text)
          .auraGlow(color: Theme.pink, radius: 24, intensity: 0.5)
        Text("Try one on the house")
          .font(.system(size: 28, weight: .heavy))
          .foregroundStyle(Theme.text)
        Text(
          "A short, real practice session with \(app.profile.avatarName). You'll get a live feedback card at the end — no pressure, totally free."
        )
        .font(.system(size: 15))
        .multilineTextAlignment(.center)
        .foregroundStyle(Theme.textMuted)
        .padding(.horizontal, 34)
        Spacer()
        AuraButton(title: "Start free session", systemImage: "play.fill") {
          if app.canStartLivePractice {
            withAnimation(.smooth) { phase = .running }
          } else {
            onComplete()
          }
        }
        .padding(.horizontal, 22)
        Button("Skip for now") { onComplete() }
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Theme.textMuted)
          .padding(.bottom, 28)
      }
    }
  }
}

#Preview {
  OnboardingFlowView().environment(AppState())
}
