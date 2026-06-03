import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var notificationsEnabled = true
    @State private var reminderTime: Date = Calendar.current.date(bySettingHour: 19, minute: 30, second: 0, of: .now) ?? .now

    var body: some View {
        Group {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 22) {
                        coachSection
                        notificationsSection
                        accountSection
                        legalSection
            
                        Button {
                            app.hasOnboarded = false
                        } label: {
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.coral)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMed))
                                .overlay(RoundedRectangle(cornerRadius: Theme.rMed).stroke(Theme.coral.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
            
                        Text("Charmster v1.0.0")
                            .font(.caption).foregroundStyle(Theme.textTertiary)
                            .padding(.top, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 6)
                }
                .background(Theme.background)
                .scrollIndicators(.hidden)
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(Theme.background, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
            }
        }
        .trackView("SettingsView")
    }

    private var coachSection: some View {
        SettingsSection(title: "COACH MODE") {
            VStack(spacing: 8) {
                ForEach(CoachMode.allCases) { coach in
                    Button {
                        app.coachMode = coach
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: coach.icon)
                                .foregroundStyle(app.coachMode == coach ? Theme.accent : Theme.textSecondary)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(coach.displayName)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(coach.tagline)
                                    .font(.bodyS).foregroundStyle(Theme.textSecondary)
                            }
                            Spacer()
                            if app.coachMode == coach {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Theme.accent)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    if coach != CoachMode.allCases.last {
                        Divider().background(Theme.border)
                    }
                }
            }
        }
    }

    private var notificationsSection: some View {
        SettingsSection(title: "PRACTICE REMINDERS") {
            VStack(spacing: 0) {
                Toggle(isOn: $notificationsEnabled) {
                    HStack(spacing: 12) {
                        Image(systemName: "bell.fill").foregroundStyle(Theme.accent).frame(width: 24)
                        Text("Daily reminder")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .tint(Theme.accent)
                .padding(.vertical, 8)
                if notificationsEnabled {
                    Divider().background(Theme.border)
                    HStack {
                        Image(systemName: "clock.fill").foregroundStyle(Theme.textSecondary).frame(width: 24)
                        Text("Time")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .colorScheme(.dark)
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }

    private var accountSection: some View {
        SettingsSection(title: "ACCOUNT") {
            VStack(spacing: 0) {
                SettingsRow(icon: "envelope.fill", label: "Email", trailing: "you@charmster.app")
                Divider().background(Theme.border)
                SettingsRow(icon: "key.fill", label: "Password", trailing: "Change")
                Divider().background(Theme.border)
                SettingsRow(icon: "creditcard.fill", label: "Subscription",
                            trailing: app.isPro ? "Pro · Active" : "Free")
            }
        }
    }

    private var legalSection: some View {
        SettingsSection(title: "MORE") {
            VStack(spacing: 0) {
                SettingsRow(icon: "star.fill", label: "Rate the App")
                Divider().background(Theme.border)
                SettingsRow(icon: "questionmark.circle.fill", label: "Contact Support")
                Divider().background(Theme.border)
                SettingsRow(icon: "lock.shield.fill", label: "Privacy Policy")
                Divider().background(Theme.border)
                SettingsRow(icon: "doc.text.fill", label: "Terms of Service")
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.6).foregroundStyle(Theme.textSecondary)
                .padding(.leading, 4)
            VStack(spacing: 0) { content }
                .padding(.horizontal, 16)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.rMed))
                .overlay(RoundedRectangle(cornerRadius: Theme.rMed).stroke(Theme.border, lineWidth: 1))
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let label: String
    var trailing: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.textSecondary).frame(width: 24)
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
            if let trailing {
                Text(trailing).font(.bodyS).foregroundStyle(Theme.textSecondary)
            }
            Image(systemName: "chevron.right").foregroundStyle(Theme.textTertiary).font(.system(size: 12, weight: .bold))
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    SettingsView().environment(AppState()).preferredColorScheme(.dark)
}
