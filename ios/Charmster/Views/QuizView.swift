import SwiftUI

struct QuizView: View {
    @Environment(AppState.self) private var app
    let lecture: Lecture
    let onDone: (Int) -> Void

    @State private var index: Int = 0
    @State private var selected: Int? = nil
    @State private var correctCount: Int = 0
    @State private var questions: [QuizQuestion] = []

    var body: some View {
        Group {
            VStack(spacing: 18) {
                if questions.isEmpty {
                    ProgressView().tint(Theme.accent)
                } else {
                    ProgressView(value: Double(index + 1), total: Double(questions.count))
                        .tint(Theme.accent)
                    let q = questions[index]
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Q\(index + 1) of \(questions.count)")
                            .font(.system(size: 12, weight: .bold)).tracking(1.4)
                            .foregroundStyle(Theme.textMuted).textCase(.uppercase)
                        Text(q.prompt)
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Theme.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
            
                    VStack(spacing: 10) {
                        ForEach(Array(q.options.enumerated()), id: \.offset) { i, opt in
                            Button {
                                selected = i
                                if i == q.correctIndex { correctCount += 1 }
                                Task {
                                    try? await Task.sleep(nanoseconds: 400_000_000)
                                    advance()
                                }
                            } label: {
                                HStack {
                                    Text(opt).font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Theme.text)
                                    Spacer()
                                    if selected == i {
                                        Image(systemName: i == q.correctIndex ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(i == q.correctIndex ? Theme.accent : Theme.coral)
                                    }
                                }
                                .padding(14)
                                .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                                .overlay(RoundedRectangle(cornerRadius: 14)
                                    .stroke(borderColor(for: i, q: q), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                            .disabled(selected != nil)
                        }
                    }
                    Spacer()
                }
            }
            .padding(18)
            .background(Theme.bg.ignoresSafeArea())
            .onAppear {
                questions = LectureContentStore.shared.quiz(for: lecture, coach: app.coachMode)
            }
        }
        .trackView("QuizView")
    }

    private func borderColor(for i: Int, q: QuizQuestion) -> Color {
        guard let selected else { return Theme.border }
        if i == q.correctIndex { return Theme.accent }
        if i == selected       { return Theme.coral }
        return Theme.border
    }

    private func advance() {
        if index < questions.count - 1 {
            withAnimation { index += 1; selected = nil }
        } else {
            onDone(correctCount)
        }
    }
}

#Preview {
    QuizView(lecture: Curriculum.lectures.first!, onDone: { _ in })
        .environment(AppState.preview)
}
