import SwiftUI

/// Step-by-step guided fix walkthrough for a specific diagnostic issue.
/// Shows numbered steps the user can check off as they go.
struct FixGuideView: View {
    let issue: DiagnosticIssue
    @Environment(\.dismiss) private var dismiss

    @State private var completedSteps: Set<Int> = []
    @State private var allDone = false

    private let primary = FullBars.Design.Colors.accentCyan

    private var steps: [String] {
        issue.fixSteps.isEmpty
            ? DiagnosticIssue.defaultFixSteps(for: issue.category)
            : issue.fixSteps
    }

    var body: some View {
        NavigationStack {
            ZStack {
                FullBars.Design.Colors.primaryBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Issue summary header
                        issueHeader

                        // Steps
                        VStack(spacing: 0) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                                stepRow(index: idx, text: step, isLast: idx == steps.count - 1)
                            }
                        }
                        .padding(16)
                        .background(cardBackground)

                        // Done state
                        if allDone {
                            VStack(spacing: 12) {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 44))
                                    .foregroundStyle(.green)
                                Text("All steps complete!")
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Run another scan to see if the issue is resolved.")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(20)
                            .frame(maxWidth: .infinity)
                            .background(cardBackground)
                        }

                        // Bottom button
                        Button {
                            dismiss()
                        } label: {
                            Text(allDone ? "Done — Back to Diagnostics" : "Close")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(allDone ? .black : .white.opacity(0.7))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(allDone ? primary : Color.white.opacity(0.1))
                                )
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Fix: \(issue.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
    }

    // MARK: - Issue Header

    private var issueHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: issue.severity.icon)
                    .foregroundStyle(issue.severity.color)
                    .font(.system(size: 20))
                Text(issue.title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(issue.description)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            if !issue.suggestion.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(issue.suggestion)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    // MARK: - Step Row

    private func stepRow(index: Int, text: String, isLast: Bool) -> some View {
        let isDone = completedSteps.contains(index)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isDone {
                    completedSteps.remove(index)
                } else {
                    completedSteps.insert(index)
                }
                allDone = completedSteps.count == steps.count
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                // Timeline connector
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(isDone ? primary : Color.white.opacity(0.1))
                            .frame(width: 30, height: 30)
                        if isDone {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.black)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                    if !isLast {
                        Rectangle()
                            .fill(isDone ? primary.opacity(0.4) : Color.white.opacity(0.1))
                            .frame(width: 2, height: 32)
                    }
                }

                // Step text
                VStack(alignment: .leading, spacing: 4) {
                    Text(text)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(isDone ? .white.opacity(0.5) : .white)
                        .strikethrough(isDone, color: .white.opacity(0.3))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                .padding(.top, 4)

                Spacer()
            }
        }
    }

    // MARK: - Helpers

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(red: 0.10, green: 0.12, blue: 0.16))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }
}
