import SwiftUI

/// Step 6 — due-review queue surface.
struct ReviewHubView: View {
  @Environment(AppState.self) private var app
  @State private var presentedLecture: Lecture?

  var body: some View {
    Group {
      NavigationStack {
        ScrollView {
          VStack(spacing: 14) {
            intro
            if app.dueReviews.isEmpty {
              emptyState
            } else {
              ForEach(app.dueReviews) { lec in
                row(for: lec)
              }
            }
            masterySummary
          }
          .padding(18)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Review")
      }
      .sheet(item: $presentedLecture) { lec in
        LectureDetailSheet(lecture: lec).environment(app)
      }
    }
    .trackView("ReviewHubView")
  }

  private var intro: some View {
    GlassCard {
      VStack(alignment: .leading, spacing: 6) {
        Text("Daily Drill")
          .font(.system(size: 22, weight: .heavy))
          .foregroundStyle(Theme.text)
        Text("Spaced reviews to lock in what you've learned. Bronze → Silver → Gold.")
          .font(.system(size: 14))
          .foregroundStyle(Theme.textMuted)
      }
    }
  }

  private func row(for lec: Lecture) -> some View {
    Button {
      presentedLecture = lec
    } label: {
      GlassCard {
        HStack(spacing: 12) {
          Image(systemName: "arrow.triangle.2.circlepath")
            .font(.system(size: 18, weight: .heavy))
            .foregroundStyle(Theme.accent)
            .frame(width: 38, height: 38)
            .background(Circle().fill(Theme.accent.opacity(0.12)))
          VStack(alignment: .leading, spacing: 4) {
            Text(lec.title)
              .font(.system(size: 15, weight: .heavy))
              .foregroundStyle(Theme.text)
            if let p = app.progress[lec.id] {
              Text("\(p.mastery.title) · due now")
                .font(.system(size: 12))
                .foregroundStyle(p.mastery.color)
            }
          }
          Spacer()
          Image(systemName: "chevron.right").foregroundStyle(Theme.textFaint)
        }
      }
    }
    .buttonStyle(.plain)
  }

  private var emptyState: some View {
    VStack(spacing: 14) {
      GlassCard {
        VStack(spacing: 10) {
          Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 38)).foregroundStyle(Theme.accent)
            .auraGlow(radius: 18, intensity: 0.4)
          Text("You're ahead").font(.system(size: 18, weight: .heavy))
            .foregroundStyle(Theme.text)
          Text("Nothing's due — your skills are holding. Want a stretch to push higher?")
            .multilineTextAlignment(.center)
            .font(.system(size: 13))
            .foregroundStyle(Theme.textMuted)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
      }
      if let stretch = DailyRouter.goldStretch(app: app) ?? app.tasterLecture {
        Button {
          presentedLecture = stretch
        } label: {
          GlassCard {
            HStack(spacing: 12) {
              Image(systemName: "crown.fill")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Theme.gold)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Theme.gold.opacity(0.14)))
              VStack(alignment: .leading, spacing: 3) {
                Text("Optional stretch")
                  .font(.system(size: 11, weight: .heavy)).tracking(1.4)
                  .foregroundStyle(Theme.gold)
                Text(stretch.title)
                  .font(.system(size: 15, weight: .heavy))
                  .foregroundStyle(Theme.text)
              }
              Spacer()
              Image(systemName: "chevron.right").foregroundStyle(Theme.textFaint)
            }
          }
        }
        .buttonStyle(.plain)
      }
    }
  }

  private var masterySummary: some View {
    let buckets = MasteryTier.allCases.dropFirst().map { tier -> (MasteryTier, Int) in
      (tier, app.progress.values.filter { $0.mastery == tier }.count)
    }
    return GlassCard {
      VStack(alignment: .leading, spacing: 10) {
        SectionHeader(title: "Mastery", systemImage: "rosette")
        HStack(spacing: 10) {
          ForEach(buckets, id: \.0) { tier, count in
            VStack(spacing: 4) {
              Text("\(count)").font(.system(size: 22, weight: .heavy))
                .foregroundStyle(tier.color)
              Text(tier.title).font(.system(size: 12)).foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surfaceRaised))
          }
        }
      }
    }
  }
}

#Preview {
  ReviewHubView().environment(AppState.preview)
}
