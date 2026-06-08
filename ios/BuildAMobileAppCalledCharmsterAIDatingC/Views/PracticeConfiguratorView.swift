import SwiftUI

struct PracticeConfiguratorView: View {
    @Environment(AppState.self) private var app
    let lecture: Lecture?
    let onStart: (SessionConfig) -> Void
    let onCancel: () -> Void

    @State private var cfg: SessionConfig

    init(lecture: Lecture?,
         initial: SessionConfig? = nil,
         onStart: @escaping (SessionConfig) -> Void,
         onCancel: @escaping () -> Void) {
        self.lecture = lecture
        self.onStart = onStart
        self.onCancel = onCancel
        _cfg = State(initialValue: initial ?? SessionConfig(
            persona: .default, setting: .default,
            tier: .silver, coach: .wingman, mode: .videoVoice,
            isSandbox: lecture == nil, sandboxScored: true, sandboxPremise: nil
        ))
    }

    var body: some View {
        Group {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    personaPicker
                    settingPicker
                    tierPicker
                    coachPicker
                    modePicker
            
                    if cfg.isSandbox {
                        sandboxModePicker
                    }
            
                    AuraButton(title: "Start practice", systemImage: "play.fill") {
                        onStart(cfg)
                    }
            
                    GlassButton(title: "Use recommended defaults", systemImage: "wand.and.stars") {
                        cfg = SessionConfig.recommended(from: app, lecture: lecture)
                        cfg.isSandbox = lecture == nil
                    }
                    GlassButton(title: "Cancel", systemImage: "xmark", action: onCancel)
                }
                .padding(18)
            }
            .background(Theme.bg.ignoresSafeArea())
            .onAppear {
                if cfg.persona == .default && cfg.setting == .default {
                    cfg = SessionConfig.recommended(from: app, lecture: lecture)
                    cfg.isSandbox = lecture == nil
                }
            }
        }
        .trackView("PracticeConfiguratorView")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Configure this rep")
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(Theme.text)
            Text(lecture?.title ?? "Free roleplay sandbox")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var personaPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Persona", systemImage: "person.crop.circle")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(PartnerPersona.library) { p in
                            chip(title: p.displayName, sub: p.pronouns,
                                 selected: cfg.persona.id == p.id) {
                                cfg.persona = p
                            }
                        }
                    }
                }
            }
        }
    }

    private var settingPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Setting", systemImage: "map.fill")
                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                    ForEach(PracticeSetting.library) { s in
                        Button {
                            cfg.setting = s
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: s.icon).foregroundStyle(Theme.accent)
                                Text(s.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(Theme.text)
                                Spacer()
                            }
                            .padding(.horizontal, 10).padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.surfaceRaised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(cfg.setting.id == s.id ? Theme.accent : Theme.border,
                                            lineWidth: cfg.setting.id == s.id ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var tierPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Difficulty", systemImage: "flame.fill")
                HStack(spacing: 10) {
                    ForEach(DifficultyTier.allCases) { t in
                        Button {
                            cfg.tier = t
                        } label: {
                            VStack(spacing: 4) {
                                Text(t.title)
                                    .font(.system(size: 14, weight: .heavy))
                                    .foregroundStyle(Theme.text)
                                Text(String(format: "×%.1f XP", t.xpMultiplier))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(t.color)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Theme.surfaceRaised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(cfg.tier == t ? t.color : Theme.border,
                                            lineWidth: cfg.tier == t ? 2 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var coachPicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Coach style", systemImage: "person.line.dotted.person.fill")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CoachStyle.allCases) { c in
                            chip(title: c.title, sub: c.blurb,
                                 selected: cfg.coach == c) { cfg.coach = c }
                        }
                    }
                }
            }
        }
    }

    private var modePicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Mode", systemImage: "waveform")
                ForEach(PracticeMode.allCases) { m in
                    Button {
                        cfg.mode = m
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: m.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.title).font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.text)
                                Text(m.blurb).font(.system(size: 12)).foregroundStyle(Theme.textMuted)
                            }
                            Spacer()
                            Image(systemName: cfg.mode == m ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(cfg.mode == m ? Theme.accent : Theme.textFaint)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sandboxModePicker: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Sandbox mode", systemImage: "sparkles")
                HStack(spacing: 10) {
                    sandboxChip(title: "Coached", sub: "Tips + scoring (½ XP)",
                                selected: cfg.sandboxScored) { cfg.sandboxScored = true }
                    sandboxChip(title: "Just Vibe", sub: "No tips, no scoring",
                                selected: !cfg.sandboxScored) { cfg.sandboxScored = false }
                }
            }
        }
    }

    private func chip(title: String, sub: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.text)
                Text(sub).font(.system(size: 11)).foregroundStyle(Theme.textMuted).lineLimit(2)
            }
            .frame(width: 160, alignment: .leading)
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Theme.accent : Theme.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private func sandboxChip(title: String, sub: String, selected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(title).font(.system(size: 14, weight: .heavy)).foregroundStyle(Theme.text)
                Text(sub).font(.system(size: 11)).foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Theme.accent : Theme.border, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PracticeConfiguratorView(lecture: Curriculum.lectures.first, onStart: { _ in }, onCancel: {})
        .environment(AppState.preview)
}
