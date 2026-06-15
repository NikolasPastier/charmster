import SwiftUI

/// Step 10 — full parity with the Account Settings spec. All pricing /
/// purchase / restore actions live in Superwall, never in this view.
///
/// Rebuilt off the native `Form` onto the app's own design system
/// (GlassCard + SectionHeader over `Theme.bg`) so it re-skins exactly like the
/// other tabs in both Light and Dark instead of rendering as a white sheet.
struct SettingsView: View {
  @Environment(AppState.self) private var app
  @State private var showDeleteConfirm = false
  @State private var showResetConfirm = false
  @State private var showCancelSurvey = false
  @State private var showRedoOnboarding = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 18) {
          profileSection
          personalizationSection
          coachingSection
          learningGoalsSection
          notificationsSection
          privacySection
          membershipSection
          appearanceSection
          supportSection
          dangerZoneSection
        }
        .padding(18)
      }
      .background(Theme.bg.ignoresSafeArea())
      .navigationTitle("Settings")
      .tint(Theme.accent)
      .fullScreenCover(isPresented: $showRedoOnboarding) {
        NavigationStack { OnboardingFlowView().environment(app) }
      }
      .sheet(isPresented: $showCancelSurvey) {
        CancelSurveyView().environment(app)
          .presentationDetents([.medium])
      }
    }
    .trackView("SettingsView")
  }

  // MARK: - Profile

  private var profileSection: some View {
    SettingsCard(title: "Profile & account", icon: "person.crop.circle.fill") {
      SettingsRow {
        Text("Name").foregroundStyle(Theme.text)
        Spacer()
        TextField("Your name", text: bindingFor(\.profile.name))
          .multilineTextAlignment(.trailing)
          .foregroundStyle(Theme.text)
      }
      SettingsDivider()
      SettingsRow {
        Text("Profile picture").foregroundStyle(Theme.text)
        Spacer()
        UserAvatarPicker(size: 44, showsRemove: false)
      }
      SettingsDivider()
      infoRow("Sign-in method", "Apple")
      SettingsDivider()
      infoRow("Email", "alex@example.com")
      SettingsDivider()
      infoRow("Age", "17+")
      SettingsDivider()
      SettingsButtonRow("Manage devices / Sign out") { /* TODO real auth */  }
    }
  }

  // MARK: - Personalization

  private var personalizationSection: some View {
    SettingsCard(title: "Personalization", icon: "slider.horizontal.below.rectangle") {
      pickerRow(
        "Goal", selection: bindingFor(\.profile.goal, then: { app.recomputePersonalization() }),
        options: [
          "Date with intention", "Date casually", "Get unstuck", "Confidence in general",
        ])
      SettingsDivider()
      pickerRow(
        "Experience",
        selection: bindingFor(\.profile.experience, then: { app.recomputePersonalization() }),
        options: ["Brand new", "Some experience", "Plenty, but mixed", "Veteran"])
      SettingsDivider()
      pickerRow(
        "Flirting style",
        selection: bindingFor(\.profile.flirtingStyle, then: { app.recomputePersonalization() }),
        options: ["Warm", "Playful", "Dry", "Direct"])
      SettingsDivider()
      SettingsRow {
        Stepper(
          value: bindingFor(\.profile.confidence, then: { app.recomputePersonalization() }),
          in: 1...10
        ) {
          HStack {
            Text("Confidence").foregroundStyle(Theme.text)
            Spacer()
            Text("\(app.profile.confidence)/10").foregroundStyle(Theme.textMuted)
          }
        }
      }
      SettingsDivider()
      navRow("Focus areas") { FocusAreasView() }
      SettingsDivider()
      navRow("Attachment check-in") { AttachmentCheckInView() }
      SettingsDivider()
      navRow("Practice partner & name") { AvatarLookView() }
      SettingsDivider()
      SettingsButtonRow("Redo personalization", tint: Theme.accent) {
        showRedoOnboarding = true
      }
    }
  }

  // MARK: - Coaching

  private var coachingSection: some View {
    SettingsCard(title: "Coaching & difficulty", icon: "person.2.fill") {
      NavigationLink {
        CoachGalleryView().environment(app)
      } label: {
        SettingsRow {
          CoachAvatarView(coach: app.selectedCoach)
            .frame(width: 38, height: 38)
            .clipShape(Circle())
          VStack(alignment: .leading, spacing: 2) {
            Text("Coach").foregroundStyle(Theme.text)
            Text("\(app.selectedCoach.humanName) · \(app.selectedCoach.roleTag)")
              .font(.caption).foregroundStyle(Theme.textMuted)
          }
          Spacer()
          Text("Switch").font(.caption).foregroundStyle(Theme.accent)
        }
      }
      .buttonStyle(.plain)
      SettingsDivider()
      SettingsRow {
        Text("Difficulty").foregroundStyle(Theme.text)
        Spacer()
        Picker("Difficulty", selection: bindingFor(\.difficultyTier)) {
          ForEach(DifficultyTier.allCases) { Text($0.title).tag($0) }
        }
        .labelsHidden().pickerStyle(.menu).tint(Theme.accent)
      }
      SettingsDivider()
      SettingsRow {
        Text("Feedback gentleness").foregroundStyle(Theme.text)
        Slider(value: bindingFor(\.profile.feedbackGentleness), in: 0...1)
          .tint(Theme.accent)
        Text(
          app.profile.feedbackGentleness > 0.6
            ? "Gentle" : (app.profile.feedbackGentleness < 0.4 ? "Direct" : "Mid")
        )
        .font(.caption).foregroundStyle(Theme.textMuted)
      }
    }
  }

  // MARK: - Learning goals

  private var learningGoalsSection: some View {
    SettingsCard(title: "Learning goals & reminders", icon: "target") {
      SettingsRow {
        Text("Daily goal").foregroundStyle(Theme.text)
        Spacer()
        Picker("Daily goal", selection: bindingFor(\.profile.dailyGoalMinutes)) {
          Text("Casual (~5 min)").tag(5)
          Text("Regular (~10 min)").tag(10)
          Text("Serious (15+ min)").tag(15)
        }
        .labelsHidden().pickerStyle(.menu).tint(Theme.accent)
      }
      SettingsDivider()
      SettingsRow {
        Toggle(
          "Daily reminder",
          isOn: Binding(
            get: { app.profile.dailyReminderTime != nil },
            set: { app.profile.dailyReminderTime = $0 ? .now : nil }
          )
        )
        .foregroundStyle(Theme.text).tint(Theme.accent)
      }
      if app.profile.dailyReminderTime != nil {
        SettingsDivider()
        SettingsRow {
          DatePicker(
            "Reminder time",
            selection: Binding(
              get: { app.profile.dailyReminderTime ?? .now },
              set: { app.profile.dailyReminderTime = $0 }
            ),
            displayedComponents: .hourAndMinute
          )
          .foregroundStyle(Theme.text).tint(Theme.accent)
        }
      }
      SettingsDivider()
      SettingsRow {
        Text("Default practice mode").foregroundStyle(Theme.text)
        Spacer()
        Picker("Default practice mode", selection: bindingFor(\.profile.practiceModeDefault)) {
          ForEach(PracticeMode.allCases) { Text($0.title).tag($0) }
        }
        .labelsHidden().pickerStyle(.menu).tint(Theme.accent)
      }
      SettingsDivider()
      infoRow("Streak freeze / rest days", "2 left")
    }
  }

  // MARK: - Notifications

  private var notificationsSection: some View {
    SettingsCard(title: "Notifications", icon: "bell.fill") {
      toggleRow("Streak reminders", bindingFor(\.profile.notificationsStreak))
      SettingsDivider()
      toggleRow("Daily challenge", bindingFor(\.profile.notificationsDailyChallenge))
      SettingsDivider()
      toggleRow("New content", bindingFor(\.profile.notificationsNewContent))
      SettingsDivider()
      toggleRow("Re-engagement", bindingFor(\.profile.notificationsReengagement))
      SettingsDivider()
      toggleRow("Weekly email digest", bindingFor(\.profile.emailDigest))
      SettingsDivider()
      toggleRow("Product emails", bindingFor(\.profile.emailProduct))
      SettingsDivider()
      toggleRow("Marketing emails", bindingFor(\.profile.emailMarketing))
      SettingsDivider()
      SettingsRow {
        DatePicker(
          "Quiet hours start",
          selection: Binding(
            get: { app.profile.quietHoursStart ?? .now },
            set: { app.profile.quietHoursStart = $0 }),
          displayedComponents: .hourAndMinute
        )
        .foregroundStyle(Theme.text).tint(Theme.accent)
      }
      SettingsDivider()
      SettingsRow {
        DatePicker(
          "Quiet hours end",
          selection: Binding(
            get: { app.profile.quietHoursEnd ?? .now },
            set: { app.profile.quietHoursEnd = $0 }),
          displayedComponents: .hourAndMinute
        )
        .foregroundStyle(Theme.text).tint(Theme.accent)
      }
    }
  }

  // MARK: - Privacy

  private var privacySection: some View {
    SettingsCard(title: "Privacy & permissions", icon: "hand.raised.fill") {
      toggleRow("Analytics opt-in", bindingFor(\.profile.analyticsOptIn))
      SettingsDivider()
      SettingsButtonRow("Manage camera permission") { openSystemSettings() }
      SettingsDivider()
      SettingsButtonRow("Manage microphone permission") { openSystemSettings() }
      SettingsDivider()
      navRow("Your data") {
        Text("Download a copy of your data + summary of what's stored.").padding()
      }
      SettingsDivider()
      SettingsRow {
        Text("Sessions are analyzed in real time. We never store raw video or audio.")
          .font(.caption).foregroundStyle(Theme.textMuted)
        Spacer(minLength: 0)
      }
    }
  }

  // MARK: - Membership (routed entirely through Superwall placements)

  private var membershipSection: some View {
    SettingsCard(title: "Membership", icon: "crown.fill") {
      infoRow("Current plan", planLabel)
      SettingsDivider()
      infoRow("Today's sessions", "\(app.dailyLiveSessionsUsed) / \(app.dailyLiveSessionsCap)")
      SettingsDivider()
      SettingsButtonRow("Open membership options", tint: Theme.accent) {
        CharmsterSuperwall.register(.upgradePrompt)
      }
      if app.isPro {
        SettingsDivider()
        SettingsButtonRow("End membership", tint: Theme.coral) {
          showCancelSurvey = true
        }
      }
    }
  }

  private var planLabel: String {
    switch app.subscriptionStatus {
    case .locked: return "Free"
    case .trial:
      if let end = app.trialEndsAt {
        let d = Calendar.current.dateComponents([.day], from: .now, to: end).day ?? 0
        return "Pro trial · \(max(0, d))d left"
      }
      return "Pro trial"
    case .pro: return "Pro"
    case .expired: return "Expired"
    }
  }

  // MARK: - Appearance

  private var appearanceSection: some View {
    SettingsCard(title: "Appearance & accessibility", icon: "paintbrush.fill") {
      SettingsRow {
        Text("Theme").foregroundStyle(Theme.text)
        Spacer()
        Picker("Theme", selection: bindingFor(\.profile.themePreference)) {
          Text("System").tag("system")
          Text("Light").tag("light")
          Text("Dark").tag("dark")
        }
        .labelsHidden().pickerStyle(.menu).tint(Theme.accent)
      }
      SettingsDivider()
      SettingsRow {
        Text("Text size").foregroundStyle(Theme.text)
        Spacer()
        Picker("Text size", selection: bindingFor(\.profile.textSize)) {
          Text("Standard").tag("standard")
          Text("Large").tag("large")
        }
        .labelsHidden().pickerStyle(.menu).tint(Theme.accent)
      }
      SettingsDivider()
      toggleRow("Captions during practice", bindingFor(\.profile.captionsEnabled))
      SettingsDivider()
      toggleRow("Sound & haptics", bindingFor(\.profile.soundAndHaptics))
    }
  }

  // MARK: - Support

  private var supportSection: some View {
    SettingsCard(title: "Support & legal", icon: "questionmark.circle.fill") {
      navRow("Help center / FAQ") { Text("Help center").padding() }
      SettingsDivider()
      SettingsButtonRow("Contact support") { /* mailto */  }
      SettingsDivider()
      navRow("Terms of service") { Text("Terms").padding() }
      SettingsDivider()
      navRow("Privacy policy") { Text("Privacy").padding() }
      SettingsDivider()
      infoRow("Version", "1.0.0")
      SettingsDivider()
      infoRow("Age rating", "17+")
    }
  }

  // MARK: - Danger zone

  private var dangerZoneSection: some View {
    SettingsCard(title: "Danger zone", icon: "exclamationmark.triangle.fill") {
      SettingsButtonRow("Reset progress", tint: Theme.warn) { showResetConfirm = true }
      SettingsDivider()
      SettingsButtonRow("Delete account", tint: Theme.coral) { showDeleteConfirm = true }
    }
    .confirmationDialog(
      "Reset all progress?",
      isPresented: $showResetConfirm, titleVisibility: .visible
    ) {
      Button("Reset", role: .destructive) { app.resetProgress() }
      Button("Cancel", role: .cancel) {}
    }
    .confirmationDialog(
      "Delete account? This removes your profile, progress, sessions, and membership locally.",
      isPresented: $showDeleteConfirm, titleVisibility: .visible
    ) {
      Button("Delete account", role: .destructive) { app.deleteAccount() }
      Button("Cancel", role: .cancel) {}
    }
  }

  // MARK: - Row helpers

  private func infoRow(_ title: String, _ value: String) -> some View {
    SettingsRow {
      Text(title).foregroundStyle(Theme.text)
      Spacer()
      Text(value).foregroundStyle(Theme.textMuted)
    }
  }

  private func toggleRow(_ title: String, _ binding: Binding<Bool>) -> some View {
    SettingsRow {
      Toggle(title, isOn: binding)
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
    }
  }

  private func pickerRow(
    _ title: String, selection: Binding<String>, options: [String]
  ) -> some View {
    SettingsRow {
      Text(title).foregroundStyle(Theme.text)
      Spacer()
      Picker(title, selection: selection) {
        ForEach(options, id: \.self) { Text($0).tag($0) }
      }
      .labelsHidden().pickerStyle(.menu).tint(Theme.accent)
    }
  }

  private func navRow<Destination: View>(
    _ title: String, @ViewBuilder destination: @escaping () -> Destination
  ) -> some View {
    NavigationLink {
      destination()
    } label: {
      SettingsRow {
        Text(title).foregroundStyle(Theme.text)
        Spacer()
        Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold))
          .foregroundStyle(Theme.textFaint)
      }
    }
    .buttonStyle(.plain)
  }

  // MARK: - Helpers

  private func bindingFor<T>(
    _ key: ReferenceWritableKeyPath<AppState, T>,
    then: (() -> Void)? = nil
  ) -> Binding<T> {
    Binding(
      get: { app[keyPath: key] },
      set: {
        app[keyPath: key] = $0
        then?()
      })
  }

  private func openSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
    }
  }
}

// MARK: - Settings layout primitives (match the other tabs)

/// A titled section: SectionHeader above a GlassCard that stacks its rows.
private struct SettingsCard<Content: View>: View {
  let title: String
  var icon: String? = nil
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      SectionHeader(title: title, systemImage: icon)
      GlassCard(padding: 0) {
        VStack(spacing: 0) {
          content()
        }
      }
    }
  }
}

/// One row of content with consistent inset.
private struct SettingsRow<Content: View>: View {
  @ViewBuilder var content: () -> Content
  var body: some View {
    HStack(spacing: 12) {
      content()
    }
    .font(.system(size: 15))
    .padding(.horizontal, 16)
    .padding(.vertical, 13)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A tappable button styled as a settings row.
private struct SettingsButtonRow: View {
  let title: String
  var tint: Color = Theme.text
  let action: () -> Void

  init(_ title: String, tint: Color = Theme.text, action: @escaping () -> Void) {
    self.title = title
    self.tint = tint
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      SettingsRow {
        Text(title).foregroundStyle(tint)
        Spacer()
      }
    }
    .buttonStyle(.plain)
  }
}

private struct SettingsDivider: View {
  var body: some View {
    Rectangle().fill(Theme.divider)
      .frame(height: 1)
      .padding(.leading, 16)
  }
}

// MARK: - Focus areas

private struct FocusAreasView: View {
  @Environment(AppState.self) private var app
  private let options = [
    "Opening", "Flow", "Calibration", "Frame", "Closing", "Repair", "Presence",
  ]
  var body: some View {
    ScrollView {
      VStack(spacing: 10) {
        GlassCard(padding: 0) {
          VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { idx, f in
              Button {
                if app.profile.focusAreas.contains(f) {
                  app.profile.focusAreas.remove(f)
                } else {
                  app.profile.focusAreas.insert(f)
                }
                app.recomputePersonalization()
              } label: {
                HStack {
                  Text(f).foregroundStyle(Theme.text)
                  Spacer()
                  if app.profile.focusAreas.contains(f) {
                    Image(systemName: "checkmark").foregroundStyle(Theme.accent)
                  }
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
              }
              .buttonStyle(.plain)
              if idx < options.count - 1 {
                Rectangle().fill(Theme.divider).frame(height: 1).padding(.leading, 16)
              }
            }
          }
        }
      }
      .padding(18)
    }
    .background(Theme.bg.ignoresSafeArea())
    .navigationTitle("Focus areas")
  }
}

// MARK: - Attachment check-in

private struct AttachmentCheckInView: View {
  @Environment(AppState.self) private var app
  @State private var answers: [Double] = Array(repeating: 0.5, count: 6)
  private let prompts = [
    "I worry about being abandoned.",
    "I find it hard to depend on people.",
    "I get anxious when people are slow to reply.",
    "I prefer not to share too much too soon.",
    "I feel safe being myself with new people.",
    "I trust my instincts in social moments.",
  ]
  var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        ForEach(prompts.indices, id: \.self) { i in
          GlassCard {
            VStack(alignment: .leading, spacing: 10) {
              Text(prompts[i]).foregroundStyle(Theme.text)
              Slider(value: $answers[i]).tint(Theme.accent)
            }
          }
        }
        AuraButton(title: "Save", systemImage: "checkmark") {
          // Persist raw 1–5 answers so `recomputePersonalization` derives anxiety,
          // avoidance, and the strength-framed label from one source of truth.
          app.profile.attachmentAnswers = answers.map { Int(($0 * 4).rounded()) + 1 }
          app.recomputePersonalization()
        }
      }
      .padding(18)
    }
    .background(Theme.bg.ignoresSafeArea())
    .navigationTitle("Attachment check-in")
  }
}

// MARK: - Avatar look + name editor

private struct AvatarLookView: View {
  @Environment(AppState.self) private var app
  @State private var name: String = ""

  /// Trim, cap ~20 chars, fall back to the selected look's default name when
  /// blank. Display-only — never affects clip lookup or scoring.
  private static func resolvedName(_ raw: String, lookId: String) -> String {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let fallback = AvatarPersona.resolve(from: lookId).defaultDisplayName
    if trimmed.isEmpty { return fallback }
    return String(trimmed.prefix(20))
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 10) {
          SectionHeader(title: "Partner look", systemImage: "person.fill")
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(AvatarPersona.library) { persona in
                lookCard(persona)
              }
            }
            .padding(.vertical, 4)
          }
        }
        VStack(alignment: .leading, spacing: 10) {
          SectionHeader(title: "Partner name", systemImage: "textformat")
          GlassCard {
            TextField("Mia", text: $name)
              .foregroundStyle(Theme.text)
              .submitLabel(.done)
              .onChange(of: name) { _, v in
                if v.count > 20 { name = String(v.prefix(20)) }
              }
              .onSubmit {
                name = Self.resolvedName(name, lookId: app.profile.avatarLookId)
                app.profile.avatarName = name
              }
          }
          Text("Display-only — pick a custom name or leave blank to use the look's name.")
            .font(.system(size: 12)).foregroundStyle(Theme.textFaint)
        }
        VStack(alignment: .leading, spacing: 10) {
          SectionHeader(title: "Partner voice", systemImage: "waveform")
          AvatarVoicePicker(
            selectedId: Binding(
              get: { app.profile.avatarVoiceId },
              set: { app.profile.avatarVoiceId = $0 }
            ),
            onChange: { _ in app.persistSettings() }
          )
        }
      }
      .padding(18)
    }
    .background(Theme.bg.ignoresSafeArea())
    .navigationTitle("Practice partner")
    .onAppear {
      name =
        app.profile.avatarName.isEmpty
        ? AvatarPersona.resolve(from: app.profile.avatarLookId).defaultDisplayName
        : app.profile.avatarName
    }
    .onDisappear {
      // Commit a clean, capped, fallback-resolved name on the way out.
      let resolved = Self.resolvedName(name, lookId: app.profile.avatarLookId)
      name = resolved
      app.profile.avatarName = resolved
    }
  }

  private func lookCard(_ persona: AvatarPersona) -> some View {
    let selected = app.profile.avatarLookId == persona.id
    return Button {
      #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      #endif
      app.profile.avatarLookId = persona.id
      // Prefill name with the look's default if the field is empty or still a
      // catalog default the user hasn't customized.
      let isDefaulted =
        name.trimmingCharacters(in: .whitespaces).isEmpty
        || AvatarPersona.library.contains { $0.defaultDisplayName == name }
      if isDefaulted {
        name = persona.defaultDisplayName
        app.profile.avatarName = persona.defaultDisplayName
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
                .font(.system(size: 36))
                .foregroundStyle(selected ? Theme.text : Theme.textMuted)
            }
          }
        }
        .frame(width: 110, height: 138)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
              selected ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.border),
              lineWidth: selected ? 3 : 1)
        )
        .overlay(alignment: .topTrailing) {
          if selected {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 22))
              .foregroundStyle(Theme.accent)
              .background(Circle().fill(Theme.bg).padding(2))
              .padding(8)
          }
        }
        Text(persona.displayName).font(.system(size: 14, weight: .heavy))
          .foregroundStyle(Theme.text)
      }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Cancel survey (reason capture only; save-offer routes to Superwall)

private struct CancelSurveyView: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State private var selected: String?
  private let reasons = [
    "Too expensive", "Not using it enough", "Found something better",
    "Bugs / quality", "Just exploring",
  ]
  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Before you go").font(.system(size: 20, weight: .heavy))
        .foregroundStyle(Theme.text)
      Text("What's the main reason?").foregroundStyle(Theme.textMuted)
      ForEach(reasons, id: \.self) { r in
        Button {
          selected = r
        } label: {
          HStack {
            Text(r).foregroundStyle(Theme.text)
            Spacer()
            if selected == r { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
          }
          .padding(12)
          .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        }
        .buttonStyle(.plain)
      }
      AuraButton(title: "See an offer before you go", systemImage: "gift.fill") {
        if let r = selected { app.recordCancelReason(r) }
        app.markSaveOfferClaimed()
        CharmsterSuperwall.register(.upgradePrompt)
        dismiss()
      }
      GlassButton(title: "End anyway", systemImage: "xmark") {
        if let r = selected { app.recordCancelReason(r) }
        app.subscriptionStatus = .locked
        dismiss()
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Theme.bg.ignoresSafeArea())
  }
}

#Preview {
  SettingsView()
    .environment(AppState.preview)
}
