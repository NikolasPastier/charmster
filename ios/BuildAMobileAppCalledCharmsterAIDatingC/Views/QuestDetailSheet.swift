import SwiftUI

struct QuestDetailSheet: View {
    let quest: Quest
    let onStart: (Quest) -> Void
    @Environment(AppState.self) private var app
    @State private var showTextMission = false
    @State private var showVoiceSim = false
    @State private var showProNotice = false

    private var isVoiceQuest: Bool {
        quest.contentPreview.lowercased().contains("voice")
    }

    private var requiresPro: Bool {
        // Boss fights & voice sims gated for free users
        (quest.isBossFight || isVoiceQuest) && !app.isPro
    }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 18) {
                // Drag handle area handled by .presentationDragIndicator
                VStack(alignment: .leading, spacing: 10) {
                    if quest.isBossFight {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill").foregroundStyle(Theme.coral)
                            Text("BOSS FIGHT")
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(1.6).foregroundStyle(Theme.coral)
                        }
                    }
                    Text(quest.title)
                        .font(.titleXL).foregroundStyle(.white)
                    Text(quest.description)
                        .font(.bodyM).foregroundStyle(Theme.textSecondary)
                        .lineLimit(3)
                }
            
                HStack(spacing: 8) {
                    StatPill(icon: "bolt.fill", text: "+\(quest.xpReward) XP", tint: Theme.accent)
                    StatPill(icon: "clock.fill", text: "~\(quest.estimatedMinutes) min", tint: Theme.pathBlue)
                    StatPill(icon: "target", text: quest.skillTag, tint: Theme.pathGold)
                }
            
                SurfaceCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("INSIDE THIS QUEST")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.6).foregroundStyle(Theme.textSecondary)
                        Text(quest.contentPreview)
                            .font(.titleM).foregroundStyle(.white)
                        Divider().background(Theme.border)
                        HStack(spacing: 10) {
                            Image(systemName: app.coachMode.icon)
                                .foregroundStyle(Theme.accent)
                            Text("Coached by \(app.coachMode.displayName)")
                                .font(.bodyS).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            
                Spacer(minLength: 4)
            
                VStack(spacing: 12) {
                    if requiresPro {
                        PrimaryButton(title: "Unlock with Pro", icon: "sparkles", variant: .coral) {
                            // Register the Superwall placement. Hosted paywall UI handles the rest.
                            SuperwallPlacements.present("unlock_pro") { converted in
                                if converted { app.isPro = true }
                            }
                            showProNotice = true
                        }
                        Text("This quest is part of Charmster Pro.")
                            .font(.caption).foregroundStyle(Theme.textSecondary)
                    } else if quest.isBossFight {
                        PrimaryButton(title: "Enter Boss Fight", icon: "flame.fill", variant: .coral) {
                            showVoiceSim = true
                        }
                    } else if isVoiceQuest {
                        PrimaryButton(title: "Start Voice Sim", icon: "mic.fill") {
                            showVoiceSim = true
                        }
                    } else {
                        PrimaryButton(title: "Start Quest", icon: "play.fill") {
                            showTextMission = true
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fullScreenCover(isPresented: $showTextMission) {
                TextMissionView(quest: quest) { completed in
                    showTextMission = false
                    if completed { app.completeQuest(quest); onStart(quest) }
                }
            }
            .fullScreenCover(isPresented: $showVoiceSim) {
                VoiceSimView(quest: quest) { completed in
                    showVoiceSim = false
                    if completed { app.completeQuest(quest); onStart(quest) }
                }
            }
            .alert("Pro unlock", isPresented: $showProNotice) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Connect Superwall to show your hosted paywall here. The placement \"unlock_pro\" is already wired in code.")
            }
        }
        .trackView("QuestDetailSheet")
    }
}

#Preview {
    QuestDetailSheet(quest: Quest.sampleRoadmap[2]) { _ in }
        .environment(AppState())
        .preferredColorScheme(.dark)
        .background(Theme.surface)
}
