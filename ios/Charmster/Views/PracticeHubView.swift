import SwiftUI

/// Step 5 — Open sandbox configurator, NOT lecture-tied.
struct PracticeHubView: View {
  @Environment(AppState.self) private var app
  @State private var setting: PracticeSetting = .default
  @State private var customSetting: String = ""
  @State private var useCustom: Bool = false
  @State private var persona: PartnerPersona = .default
  @State private var premise: String = ""
  @State private var tier: DifficultyTier = .silver
  @State private var coachStyle: CoachStyle = .wingman
  @State private var focus: Set<String> = []
  @State private var mode: PracticeMode = .videoVoice
  @State private var coached: Bool = true
  @State private var presentedConfig: SessionConfig?

  private let focusOptions = ["Opening", "Flow", "Calibration", "Frame", "Closing"]

  var body: some View {
    Group {
      NavigationStack {
        ScrollView {
          VStack(spacing: 14) {
            intro
            settingCard
            personaCard
            premiseCard
            optionsCard
            sandboxModeCard
            startCard
          }
          .padding(18)
        }
        .background(AuraBackground())
        .navigationTitle("Sandbox")
      }
      .fullScreenCover(item: $presentedConfig) { cfg in
        SandboxRunner(config: cfg) { _ in
          presentedConfig = nil
        }
        .environment(app)
        .appThemedPresentation()
      }
    }
    .trackView("PracticeHubView")
  }

  private var intro: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 6) {
        Text("Free roleplay")
          .font(.system(size: 22, weight: .heavy))
          .foregroundStyle(Theme.text)
        Text("Set the scene. Coached for tips + scoring, or Just Vibe for no pressure.")
          .font(.system(size: 14))
          .foregroundStyle(Theme.textMuted)
      }
    }
  }

  private var settingCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        SectionHeader(title: "Setting", systemImage: "map.fill")
        LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
          ForEach(PracticeSetting.library) { s in
            Button {
              useCustom = false
              setting = s
            } label: {
              HStack(spacing: 6) {
                Image(systemName: s.icon).foregroundStyle(Theme.accent)
                Text(s.title).font(.system(size: 13, weight: .bold))
                  .foregroundStyle(Theme.text)
                Spacer()
              }
              .padding(10)
              .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(
                    !useCustom && setting.id == s.id ? Theme.accent : Theme.border,
                    lineWidth: !useCustom && setting.id == s.id ? 2 : 1))
            }
            .buttonStyle(.plain)
          }
        }
        TextField("Or describe your own setting…", text: $customSetting)
          .textFieldStyle(.plain)
          .padding(12)
          .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(useCustom ? Theme.accent : Theme.border, lineWidth: 1)
          )
          .onChange(of: customSetting) { _, new in useCustom = !new.isEmpty }
      }
    }
  }

  private var personaCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        SectionHeader(title: "Persona", systemImage: "person.crop.circle")
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(PartnerPersona.library) { p in
              Button {
                persona = p
              } label: {
                VStack(alignment: .leading, spacing: 4) {
                  Text(p.displayName).font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.text)
                  Text(p.pronouns).font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
                }
                .frame(width: 140, alignment: .leading)
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
                .overlay(
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(
                      persona.id == p.id ? Theme.accent : Theme.border,
                      lineWidth: persona.id == p.id ? 2 : 1))
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
  }

  private var premiseCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 8) {
        SectionHeader(title: "What's the situation?", systemImage: "text.bubble.fill")
        TextField("e.g. she just sat down across from me…", text: $premise, axis: .vertical)
          .lineLimit(2...4)
          .padding(12)
          .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
      }
    }
  }

  private var optionsCard: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 12) {
        SectionHeader(title: "Options", systemImage: "slider.horizontal.3")
        HStack {
          Text("Difficulty").foregroundStyle(Theme.textMuted)
            .font(.system(size: 13, weight: .bold))
          Spacer()
          ForEach(DifficultyTier.allCases) { t in
            Button {
              tier = t
            } label: {
              Text(t.title)
                .font(.system(size: 12, weight: .heavy))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Capsule().fill(tier == t ? t.color.opacity(0.25) : Theme.surfaceRaised))
                .overlay(Capsule().stroke(tier == t ? t.color : Theme.border, lineWidth: 1))
                .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
          }
        }
        VStack(alignment: .leading, spacing: 6) {
          Text("Focus skills").font(.system(size: 13, weight: .bold))
            .foregroundStyle(Theme.textMuted)
          FlowLayout(spacing: 6) {
            ForEach(focusOptions, id: \.self) { f in
              let on = focus.contains(f)
              Button {
                if on { focus.remove(f) } else { focus.insert(f) }
              } label: {
                Text(f).font(.system(size: 12, weight: .bold))
                  .padding(.horizontal, 10).padding(.vertical, 6)
                  .background(Capsule().fill(on ? Theme.accent.opacity(0.18) : Theme.surfaceRaised))
                  .overlay(Capsule().stroke(on ? Theme.accent : Theme.border, lineWidth: 1))
                  .foregroundStyle(Theme.text)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
  }

  private var sandboxModeCard: some View {
    GlassCard {
      HStack(spacing: 10) {
        Button {
          coached = true
        } label: {
          sandboxChip("Coached", "Tips + scoring", on: coached)
        }
        Button {
          coached = false
        } label: {
          sandboxChip("Just Vibe", "No tips, no score", on: !coached)
        }
      }
      .buttonStyle(.plain)
    }
  }

  private func sandboxChip(_ title: String, _ sub: String, on: Bool) -> some View {
    VStack(spacing: 4) {
      Text(title).font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.text)
      Text(sub).font(.system(size: 11)).foregroundStyle(Theme.textMuted)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 12)
    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(on ? Theme.accent : Theme.border, lineWidth: on ? 2 : 1))
  }

  private var startCard: some View {
    VStack(spacing: 10) {
      if !app.canStartLivePractice {
        GlassCard {
          HStack {
            Image(systemName: "bolt.fill").foregroundStyle(Theme.coral)
            Text("Daily live sessions used. Upgrade to keep going.")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(Theme.text)
            Spacer()
          }
        }
      }
      AuraButton(
        title: "Start session", systemImage: "play.fill",
        enabled: app.canStartLivePractice
      ) {
        if !app.canStartLivePractice {
          CharmsterSuperwall.register(.premiumDailyPracticeCap)
          return
        }
        presentedConfig = SessionConfig(
          persona: persona,
          setting: setting,
          tier: tier,
          coach: coachStyle,
          mode: mode,
          isSandbox: true,
          sandboxScored: coached,
          sandboxPremise: useCustom ? customSetting : (premise.isEmpty ? nil : premise)
        )
      }
    }
  }
}

private struct SandboxRunner: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  let config: SessionConfig
  let onClose: (SessionResult?) -> Void
  @State private var result: SessionResult?

  var body: some View {
    ZStack {
      if let r = result {
        ResultsView(
          result: r, lecture: nil, onQuiz: {},
          onDone: {
            dismiss()
            onClose(r)
          })
      } else {
        LivePracticeView(
          lecture: nil, config: config,
          onFinish: { r in
            app.completeSandbox(result: r, scored: config.sandboxScored)
            result = r
          },
          onClose: {
            dismiss()
            onClose(nil)
          }
        )
      }
    }
  }
}

// MARK: - Simple flow layout

struct FlowLayout: Layout {
  var spacing: CGFloat = 6
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rowHeight: CGFloat = 0
    for sub in subviews {
      let s = sub.sizeThatFits(.unspecified)
      if x + s.width > maxWidth {
        x = 0
        y += rowHeight + spacing
        rowHeight = 0
      }
      x += s.width + spacing
      rowHeight = max(rowHeight, s.height)
    }
    return CGSize(width: maxWidth, height: y + rowHeight)
  }
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    var x: CGFloat = bounds.minX
    var y: CGFloat = bounds.minY
    var rowHeight: CGFloat = 0
    for sub in subviews {
      let s = sub.sizeThatFits(.unspecified)
      if x + s.width > bounds.maxX {
        x = bounds.minX
        y += rowHeight + spacing
        rowHeight = 0
      }
      sub.place(
        at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: s.width, height: s.height))
      x += s.width + spacing
      rowHeight = max(rowHeight, s.height)
    }
  }
}

extension SessionConfig: Identifiable {
  var id: String { "\(persona.id)-\(setting.id)-\(tier.rawValue)-\(isSandbox ? "sb" : "lec")" }
}

#Preview {
  PracticeHubView().environment(AppState.preview)
}
