import SwiftUI

struct HealthQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var beans = HealthBeansStore.shared
    @State private var questions: [HealthQuizQuestion] = HealthQuizBank.questionsForToday()
    @State private var currentIndex = 0
    @State private var selectedIndex: Int?
    @State private var revealed = false
    @State private var sessionCorrect = 0
    @State private var finished = false

    private var current: HealthQuizQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var body: some View {
        Group {
            if finished || beans.quizRemainingToday == 0 && currentIndex == 0 && !revealed {
                resultView
            } else if let question = current {
                questionView(question)
            } else {
                resultView
            }
        }
        .background(AppTheme.screenBackground)
        .navigationTitle("健康测验")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }
            }
        }
        .onAppear {
            beans.rollDayIfNeeded()
            // 若今日答对额度已满，直接看结果
            if beans.quizRemainingToday == 0 {
                finished = true
                sessionCorrect = beans.quizCorrectToday
            }
        }
    }

    private func questionView(_ question: HealthQuizQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("第 \(currentIndex + 1)/\(questions.count) 题")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.brandTeal)
                    Spacer()
                    Text("答对 +\(HealthBeansStore.quizRewardPerCorrect) 豆")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(question.prompt)
                    .font(.headline)

                VStack(spacing: 10) {
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                        Button {
                            guard !revealed else { return }
                            selectedIndex = index
                            reveal(for: question, selected: index)
                        } label: {
                            HStack {
                                Text(choice)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if revealed {
                                    if index == question.correctIndex {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AppTheme.riskGreen)
                                    } else if index == selectedIndex {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(AppTheme.riskRed)
                                    }
                                }
                            }
                            .padding()
                            .background(choiceBackground(index: index, question: question))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(revealed)
                    }
                }

                if revealed {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(selectedIndex == question.correctIndex ? "回答正确" : "回答有误")
                            .font(.subheadline.bold())
                            .foregroundStyle(selectedIndex == question.correctIndex ? AppTheme.riskGreen : AppTheme.riskRed)
                        Text(question.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button(currentIndex + 1 < questions.count ? "下一题" : "查看结果") {
                            advance()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.brandTeal)
                        .padding(.top, 4)
                    }
                    .companionCard()
                }

                DisclaimerFooter()
            }
            .padding()
        }
    }

    private var resultView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "leaf.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
            Text("今日测验完成")
                .font(.title3.bold())
            Text("本场答对 \(sessionCorrect) 题\n今日累计答对 \(beans.quizCorrectToday)/\(HealthBeansStore.quizDailyLimit) 题")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("当前健康豆：\(beans.balance)")
                .font(.headline)
            Button("完成") { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brandTeal)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func choiceBackground(index: Int, question: HealthQuizQuestion) -> Color {
        guard revealed else {
            return AppTheme.cardBackground
        }
        if index == question.correctIndex {
            return AppTheme.riskGreen.opacity(0.18)
        }
        if index == selectedIndex {
            return AppTheme.riskRed.opacity(0.15)
        }
        return AppTheme.cardBackground
    }

    private func reveal(for question: HealthQuizQuestion, selected: Int) {
        revealed = true
        if selected == question.correctIndex {
            if beans.claimQuizCorrect() != nil {
                sessionCorrect += 1
            }
        }
    }

    private func advance() {
        if currentIndex + 1 < questions.count && beans.quizRemainingToday > 0 {
            currentIndex += 1
            selectedIndex = nil
            revealed = false
        } else if currentIndex + 1 < questions.count {
            // 额度用尽仍可浏览剩余题但不发豆：继续下一题
            currentIndex += 1
            selectedIndex = nil
            revealed = false
        } else {
            finished = true
        }
    }
}

#Preview {
    NavigationStack {
        HealthQuizView()
    }
}
