import Foundation

enum AnimationTiming {
    /// スワイプアニメーション完了後の処理遅延
    static let swipeCompletion: TimeInterval = 0.3
    /// タブタップ後のViewModel更新遅延
    static let tabTransition: TimeInterval = 0.35
    /// ページループ（循環スワイプ）のジャンプ遅延
    static let pageLoop: TimeInterval = 0.3
    /// 完了画面のアニメーション開始遅延
    static let completionAppear: TimeInterval = 0.15
    /// アチーブメントのアニメーション開始遅延
    static let achievementAppear: TimeInterval = 0.45
    /// フィードバックメッセージの表示時間
    static let feedbackDuration: TimeInterval = 2.0
}
