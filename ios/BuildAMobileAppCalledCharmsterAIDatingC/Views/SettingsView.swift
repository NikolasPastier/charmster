import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var app
    @State private var confirmReset = false

    var body: some View {
        @Bindable var bind = app
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    section("Profile") {
                        textRow("Name", binding: $bind.username)
                    }
                    section("Personalization") {
                        pickerRow("Goal", value: app.goal?.rawValue ?? "Not set") { goalSheet }
                        pickerRow("Experience", value: app.experience?.rawValue ?? "Not set") { expSheet }
                        pickerRow("Flirting style", value: app.flirting.rawValue) { flirtSheet }
                        sliderRow("Confidence", value: $bind.confidenceBaseline, range: 0...100) {
                            app.recomputePersonalization()
                        }
                    }
                    section("Coaching & difficulty") {
                        pickerRow("Coach", value: "\(app.coachMode.emoji) \(app.coachMode.displayName)") { coachSheet }
                        tierPicker
                    }
                    section("Learning goals") {
                        Stepper(value: $bind.dailyGoalMinutes, in: 5...60, step: 5) {
                            HStack {
                                Text("Daily goal").foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Text("\(app.dailyGoalMinutes) min")
                                    .foregroundStyle(Theme.textMuted).monospacedDigit()
                            }
                        }
                        .tint(Theme.pink)
                        Toggle(isOn: $bind.dailyReminderOn) {
                            Text("Daily reminder").foregroundStyle(Theme.textPrimary)
                        }
                        .tint(Theme.pink)
                    }
                    section("Subscription") {
                        HStack {
                            Text(app.isPro ? "Pro" : "Free")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Button {
                                app.isPro.toggle()
                            } label: {
                                Text(app.isPro ? "Cancel" : "Upgrade")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(Capsule().fill(Theme.aura))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    section("Privacy & legal") {
                        plainRow("Camera & mic — never recorded", "lock.shield.fill", tint: Theme.calmBlue)
                        plainRow("Terms of Service", "doc.text")
                        plainRow("Privacy Policy", "hand.raised.fill")
                        plainRow("17+ age requirement", "person.badge.shield.checkmark.fill")
                    }
                    section("Danger zone") {
                        Button(role: .destructive) {
                            confirmReset = true
                        } label: {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset progress")
                                Spacer()
                            }
                            .foregroundStyle(Theme.alertRed)
                        }
                    }
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.textPrimary)
                }
            }
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .alert("Reset progress?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) {
                app.progress = [:]; app.totalXP = 0; app.level = 1
                app.aura = 0; app.charmCoins = 0; app.streakDays = 0
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears mastery, XP, coins and streak. Personalization is kept.")
        }
        .trackView("SettingsView")
    }

    // MARK: Components

    @ViewBuilder
    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
            VStack(spacing: 10) { content() }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                )
        }
    }

    private func textRow(_ label: String, binding: Binding<String>) -> some View {
        HStack {
            Text(label).foregroundStyle(Theme.textSecondary)
            Spacer()
            TextField("", text: binding)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func sliderRow(_ label: String, value: Binding<Double>,
                           range: ClosedRange<Double>, onCommit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("\(Int(value.wrappedValue))")
                    .foregroundStyle(Theme.textPrimary).monospacedDigit()
            }
            Slider(value: value, in: range, step: 1, onEditingChanged: { _ in onCommit() })
                .tint(Theme.pink)
        }
    }

    @ViewBuilder
    private func pickerRow<S: View>(_ label: String, value: String,
                                    @ViewBuilder sheet: () -> S) -> some View {
        NavigationLink {
            ScrollView { sheet().padding(20) }
                .background(Theme.background)
                .navigationTitle(label)
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Theme.background, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        } label: {
            HStack {
                Text(label).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(value).foregroundStyle(Theme.textPrimary)
                Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
            }
        }
        .buttonStyle(.plain)
    }

    private func plainRow(_ label: String, _ icon: String, tint: Color = Theme.textMuted) -> some View {
        HStack {
            Image(systemName: icon).foregroundStyle(tint)
            Text(label).foregroundStyle(Theme.textPrimary)
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.textMuted)
        }
    }

    // MARK: Picker sheets

    private var goalSheet: some View {
        VStack(spacing: 10) {
            ForEach(OnbGoal.allCases) { g in
                rowPick(g.rawValue, selected: app.goal == g) {
                    app.goal = g; app.recomputePersonalization()
                }
            }
        }
    }
    private var expSheet: some View {
        VStack(spacing: 10) {
            ForEach(OnbExperience.allCases) { e in
                rowPick(e.rawValue, selected: app.experience == e) {
                    app.experience = e; app.recomputePersonalization()
                }
            }
        }
    }
    private var flirtSheet: some View {
        VStack(spacing: 10) {
            ForEach(OnbFlirtingStyle.allCases) { f in
                rowPick(f.rawValue, selected: app.flirting == f) { app.flirting = f }
            }
        }
    }
    private var coachSheet: some View {
        VStack(spacing: 10) {
            ForEach(CoachMode.allCases) { c in
                rowPick("\(c.emoji) \(c.displayName)", selected: app.coachMode == c) {
                    app.coachMode = c
                }
            }
        }
    }

    private var tierPicker: some View {
        HStack(spacing: 8) {
            ForEach(DifficultyTier.allCases) { t in
                let on = app.difficultyTier == t
                Button { app.difficultyTier = t } label: {
                    VStack(spacing: 2) {
                        Text(t.label).font(.system(size: 13, weight: .heavy))
                        Text(t.blurb).font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(on ? AnyShapeStyle(Theme.aura) : AnyShapeStyle(Theme.elevated))
                    )
                    .foregroundStyle(on ? .white : Theme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func rowPick(_ text: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(text).foregroundStyle(Theme.textPrimary)
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.aura)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selected ? AnyShapeStyle(Theme.aura) : AnyShapeStyle(Theme.border),
                                    lineWidth: selected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView().environment(AppState()).preferredColorScheme(.dark)
}
