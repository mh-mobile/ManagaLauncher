import SwiftUI

struct CatchUpCompletedView: View {
    let message: String
    let remainingUnread: Int
    @Binding var streakAchievement: Int?
    @Binding var milestoneAchievement: Int?
    @Binding var completionAnimated: Bool
    @Binding var achievementAnimated: Bool
    let checkStreak: () -> Int?
    let checkMilestone: () -> Int?
    var hasGradientBackground: Bool = false
    var onRecheck: (() -> Void)?

    private var theme: ThemeStyle { ThemeManager.shared.style }
    private var textColor: Color { hasGradientBackground ? .white : theme.onSurface }

    private var hasAchievement: Bool {
        streakAchievement != nil || milestoneAchievement != nil
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme.catchUpReadColor)
                .scaleEffect(completionAnimated ? 1.0 : 0.3)
                .opacity(completionAnimated ? 1.0 : 0.0)
            Text(message)
                .font(theme.title2Font)
                .foregroundStyle(textColor)
                .opacity(completionAnimated ? 1.0 : 0.0)

            if hasAchievement {
                VStack(spacing: 12) {
                    if let streak = streakAchievement {
                        achievementCard(icon: "flame.fill", iconColor: theme.primary, text: "\(streak)日連続！")
                    }
                    if let milestone = milestoneAchievement {
                        achievementCard(icon: "trophy.fill", iconColor: theme.tertiary, text: "\(milestone)話達成！")
                    }
                }
                .scaleEffect(achievementAnimated ? 1.0 : 0.3)
                .opacity(achievementAnimated ? 1.0 : 0.0)
            }

            if remainingUnread > 0, let onRecheck {
                switch ThemeManager.shared.mode {
                case .ink:
                    Button {
                        onRecheck()
                    } label: {
                        Label("未読を再チェック（\(remainingUnread)件）", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .buttonStyle(SpeechBubbleButtonStyle())
                    .opacity(completionAnimated ? 1.0 : 0.0)
                case .classic:
                    Button {
                        onRecheck()
                    } label: {
                        Label("未読を再チェック（\(remainingUnread)件）", systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .opacity(completionAnimated ? 1.0 : 0.0)
                case .retro:
                    Button {
                        onRecheck()
                    } label: {
                        Label("未読を再チェック（\(remainingUnread)件）", systemImage: "arrow.counterclockwise")
                            .font(theme.headlineFont)
                            .foregroundStyle(theme.onSurface)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(theme.surfaceContainerHigh, in: RoundedRectangle(cornerRadius: theme.cornerRadius))
                    }
                    .opacity(completionAnimated ? 1.0 : 0.0)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            completionAnimated = false
            achievementAnimated = false
            streakAchievement = checkStreak()
            milestoneAchievement = checkMilestone()
            let showAchievement = streakAchievement != nil || milestoneAchievement != nil
            DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.completionAppear) {
                withAnimation(.spring(duration: 0.6, bounce: 0.5)) {
                    completionAnimated = true
                }
            }
            if showAchievement {
                DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.achievementAppear) {
                    withAnimation(.spring(duration: 0.6, bounce: 0.5)) {
                        achievementAnimated = true
                    }
                }
            }
        }
    }

    private func achievementCard(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(theme.title2Font)
                .foregroundStyle(iconColor)
            Text(text)
                .font(theme.headlineFont)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Group {
                switch ThemeManager.shared.mode {
                case .ink:
                    RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                        .fill(theme.surfaceContainerHighest)
                case .classic:
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                case .retro:
                    RoundedRectangle(cornerRadius: theme.cardCornerRadius)
                        .fill(theme.surfaceContainerHigh)
                }
            }
        )
    }
}
