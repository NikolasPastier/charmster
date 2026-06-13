import SwiftUI

/// Step 10 — full parity with the Account Settings spec. All pricing /
/// purchase / restore actions live in Superwall, never in this view.
struct SettingsView: View {
  @Environment(AppState.self) private var app
  @State private var showDeleteConfirm = false
  @State private var showResetConfirm = false
  @State private var showCancelSurvey = false
  @State private var showRedoOnboarding = false

  var body: some View {
    Group {
      Form {
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
      .scrollContentBackground(.hidden)
      .background(Theme.bg.ignoresSafeArea())
      .navigationTitle("Settings")
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
    Section("Profile & account") {
      HStack {
        Text("Name")
        Spacer()
        TextField("Your name", text: bindingFor(\.profile.name))
          .multilineTextAlignment(.trailing)
      }
      HStack {
        Text("Profile picture")
        Spacer()
        Image(systemName: "person.crop.circle.fill")
          .font(.system(size: 22)).foregroundStyle(Theme.textMuted)
      }
      HStack {
        Text("Sign-in method")
        Spacer()
        Text("Apple").foregroundStyle(Theme.textMuted)
      }
      HStack {
        Text("Email")
        Spacer()
        Text("alex@example.com").foregroundStyle(Theme.textMuted)
      }
      HStack {
        Text("Age")
        Spacer()
        Text("17+").foregroundStyle(Theme.textMuted)
      }
      Button("Manage devices / Sign out") { /* TODO real auth */  }
    }
  }

  // MARK: - Personalization

  private var personalizationSection: some View {
    Section("Personalization") {
      Picker(
        "Goal", selection: bindingFor(\.profile.goal, then: { app.recomputePersonalization() })
      ) {
        ForEach(
          ["Date with intention", "Date casually", "Get unstuck", "Confidence in general"],
          id: \.self
        ) {
          Text($0).tag($0)
        }
      }
      Picker(
        "Experience",
        selection: bindingFor(\.profile.experience, then: { app.recomputePersonalization() })
      ) {
        ForEach(["Brand new", "Some experience", "Plenty, but mixed", "Veteran"], id: \.self) {
          Text($0).tag($0)
        }
      }
      Picker(
        "Flirting style",
        selection: bindingFor(\.profile.flirtingStyle, then: { app.recomputePersonalization() })
      ) {
        ForEach(["Warm", "Playful", "Dry", "Direct"], id: \.self) { Text($0).tag($0) }
      }
      Stepper(
        value: bindingFor(\.profile.confidence, then: { app.recomputePersonalization() }),
        in: 1...10
      ) {
        HStack {
          Text("Confidence")
          Spacer()
          Text("\(app.profile.confidence)/10").foregroundStyle(Theme.textMuted)
        }
      }
      NavigationLink("Focus areas") { FocusAreasView() }
      NavigationLink("Attachment check-in") { AttachmentCheckInView() }
      NavigationLink("Practice partner & name") { AvatarLookView() }
      Button("Redo personalization") { showRedoOnboarding = true }
        .foregroundStyle(Theme.accent)
    }
  }

  // MARK: - Coaching

  private var coachingSection: some View {
    Section("Coaching & difficulty") {
      NavigationLink {
        CoachGalleryView().environment(app)
      } label: {
        HStack(spacing: 12) {
          CoachAvatarView(coach: app.selectedCoach)
            .frame(width: 38, height: 38)
            .clipShape(Circle())
          VStack(alignment: .leading, spacing: 2) {
            Text("Coach")
            Text("\(app.selectedCoach.humanName) · \(app.selectedCoach.roleTag)")
              .font(.caption).foregroundStyle(Theme.textMuted)
          }
          Spacer()
          Text("Switch").font(.caption).foregroundStyle(Theme.accent)
        }
      }
      Picker("Difficulty", selection: bindingFor(\.difficultyTier)) {
        ForEach(DifficultyTier.allCases) { Text($0.title).tag($0) }
      }
      HStack {
        Text("Feedback gentleness")
        Slider(value: bindingFor(\.profile.feedbackGentleness), in: 0...1)
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
    Section("Learning goals & reminders") {
      Picker("Daily goal", selection: bindingFor(\.profile.dailyGoalMinutes)) {
        Text("Casual (~5 min)").tag(5)
        Text("Regular (~10 min)").tag(10)
        Text("Serious (15+ min)").tag(15)
      }
      Toggle(
        "Daily reminder",
        isOn: Binding(
          get: { app.profile.dailyReminderTime != nil },
          set: { app.profile.dailyReminderTime = $0 ? .now : nil }
        ))
      if app.profile.dailyReminderTime != nil {
        DatePicker(
          "Reminder time",
          selection: Binding(
            get: { app.profile.dailyReminderTime ?? .now },
            set: { app.profile.dailyReminderTime = $0 }
          ),
          displayedComponents: .hourAndMinute)
      }
      Picker("Default practice mode", selection: bindingFor(\.profile.practiceModeDefault)) {
        ForEach(PracticeMode.allCases) { Text($0.title).tag($0) }
      }
      HStack {
        Text("Streak freeze / rest days")
        Spacer()
        Text("2 left").foregroundStyle(Theme.textMuted)
      }
    }
  }

  // MARK: - Notifications

  private var notificationsSection: some View {
    Section("Notifications") {
      Toggle("Streak reminders", isOn: bindingFor(\.profile.notificationsStreak))
      Toggle("Daily challenge", isOn: bindingFor(\.profile.notificationsDailyChallenge))
      Toggle("New content", isOn: bindingFor(\.profile.notificationsNewContent))
      Toggle("Re-engagement", isOn: bindingFor(\.profile.notificationsReengagement))
      Toggle("Weekly email digest", isOn: bindingFor(\.profile.emailDigest))
      Toggle("Product emails", isOn: bindingFor(\.profile.emailProduct))
      Toggle("Marketing emails", isOn: bindingFor(\.profile.emailMarketing))
      DatePicker(
        "Quiet hours start",
        selection: Binding(
          get: { app.profile.quietHoursStart ?? .now },
          set: { app.profile.quietHoursStart = $0 }),
        displayedComponents: .hourAndMinute)
      DatePicker(
        "Quiet hours end",
        selection: Binding(
          get: { app.profile.quietHoursEnd ?? .now },
          set: { app.profile.quietHoursEnd = $0 }),
        displayedComponents: .hourAndMinute)
    }
  }

  // MARK: - Privacy

  private var privacySection: some View {
    Section("Privacy & permissions") {
      Toggle("Analytics opt-in", isOn: bindingFor(\.profile.analyticsOptIn))
      Button("Manage camera permission") { openSystemSettings() }
      Button("Manage microphone permission") { openSystemSettings() }
      NavigationLink("Your data") {
        Text("Download a copy of your data + summary of what's stored.").padding()
      }
      Text("Sessions are analyzed in real time. We never store raw video or audio.")
        .font(.caption).foregroundStyle(Theme.textMuted)
    }
  }

  // MARK: - Membership (routed entirely through Superwall placements)

  private var membershipSection: some View {
    Section("Membership") {
      HStack {
        Text("Current plan")
        Spacer()
        Text(planLabel).foregroundStyle(Theme.textMuted)
      }
      HStack {
        Text("Today's sessions")
        Spacer()
        Text("\(app.dailyLiveSessionsUsed) / \(app.dailyLiveSessionsCap)")
          .foregroundStyle(Theme.textMuted)
      }
      Button("Open membership options") {
        CharmsterSuperwall.register(.upgradePrompt)
      }
      if app.isPro {
        Button("End membership") { showCancelSurvey = true }
          .foregroundStyle(Theme.coral)
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
    Section("Appearance & accessibility") {
      Picker("Theme", selection: bindingFor(\.profile.themePreference)) {
        Text("System").tag("system")
        Text("Light").tag("light")
        Text("Dark").tag("dark")
      }
      Picker("Text size", selection: bindingFor(\.profile.textSize)) {
        Text("Standard").tag("standard")
        Text("Large").tag("large")
      }
      Toggle("Captions during practice", isOn: bindingFor(\.profile.captionsEnabled))
      Toggle("Sound & haptics", isOn: bindingFor(\.profile.soundAndHaptics))
    }
  }

  // MARK: - Support

  private var supportSection: some View {
    Section("Support & legal") {
      NavigationLink("Help center / FAQ") { Text("Help center").padding() }
      Button("Contact support") { /* mailto */  }
      NavigationLink("Terms of service") { Text("Terms").padding() }
      NavigationLink("Privacy policy") { Text("Privacy").padding() }
      HStack {
        Text("Version")
        Spacer()
        Text("1.0.0").foregroundStyle(Theme.textMuted)
      }
      HStack {
        Text("Age rating")
        Spacer()
        Text("17+").foregroundStyle(Theme.textMuted)
      }
    }
  }

  // MARK: - Danger zone

  private var dangerZoneSection: some View {
    Section("Danger zone") {
      Button("Reset progress") { showResetConfirm = true }
        .foregroundStyle(Theme.warn)
      Button("Delete account") { showDeleteConfirm = true }
        .foregroundStyle(Theme.coral)
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

// MARK: - Focus areas

private struct FocusAreasView: View {
  @Environment(AppState.self) private var app
  private let options = [
    "Opening", "Flow", "Calibration", "Frame", "Closing", "Repair", "Presence",
  ]
  var body: some View {
    List {
      ForEach(options, id: \.self) { f in
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
        }
      }
    }
    .scrollContentBackground(.hidden)
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
    Form {
      ForEach(prompts.indices, id: \.self) { i in
        VStack(alignment: .leading) {
          Text(prompts[i])
          Slider(value: $answers[i])
        }
      }
      Button("Save") {
        // Persist raw 1–5 answers so `recomputePersonalization` derives anxiety,
        // avoidance, and the strength-framed label from one source of truth.
        app.profile.attachmentAnswers = answers.map { Int(($0 * 4).rounded()) + 1 }
        app.recomputePersonalization()
      }
      .foregroundStyle(Theme.accent)
    }
    .scrollContentBackground(.hidden)
    .background(Theme.bg.ignoresSafeArea())
    .navigationTitle("Attachment check-in")
  }
}

// MARK: - Avatar look + name editor

private struct AvatarLookView: View {
  @Environment(AppState.self) private var app
  @State private var name: String = ""

  var body: some View {
    Form {
      Section("Partner look") {
        ForEach(AvatarPersona.library) { persona in
          Button {
            app.profile.avatarLookId = persona.id
            if name.trimmingCharacters(in: .whitespaces).isEmpty
              || AvatarPersona.library.contains(where: { $0.displayName == name })
            {
              name = persona.displayName
              app.profile.avatarName = persona.displayName
            }
          } label: {
            HStack {
              Image(systemName: persona.gender == .masculine ? "person.fill" : "person.fill")
                .foregroundStyle(Theme.accent)
              Text(persona.displayName).foregroundStyle(Theme.text)
              Spacer()
              if app.profile.avatarLookId == persona.id {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
              }
            }
          }
        }
      }
      Section("Partner name") {
        TextField("Mia", text: $name)
          .onChange(of: name) { _, v in
            app.profile.avatarName = v.trimmingCharacters(in: .whitespaces)
          }
      }
    }
    .scrollContentBackground(.hidden)
    .background(Theme.bg.ignoresSafeArea())
    .navigationTitle("Practice partner")
    .onAppear { name = app.profile.avatarName.isEmpty ? "Mia" : app.profile.avatarName }
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
    .background(Theme.bg.ignoresSafeArea())
  }
}

#Preview {
  NavigationStack { SettingsView() }
    .environment(AppState.preview)
}
