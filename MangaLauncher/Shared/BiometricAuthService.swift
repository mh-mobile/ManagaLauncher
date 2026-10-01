import LocalAuthentication

enum BiometricAuthService {
    /// - Returns: 認証できた、または端末にパスコードも生体認証も無く保護しようがない場合 true。
    ///   後者で false を返すと、非表示の作品や最近削除した項目に二度とアクセスできなくなる。
    static func authenticate(reason: String, context: LAContext = LAContext()) async -> Bool {
        var error: NSError?
        let policy: LAPolicy
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            policy = .deviceOwnerAuthenticationWithBiometrics
        } else if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            policy = .deviceOwnerAuthentication
        } else {
            // パスコード未設定の端末だけを素通しする。それ以外の失敗で保護を外さない
            return error?.code == LAError.passcodeNotSet.rawValue
        }
        do {
            return try await context.evaluatePolicy(policy, localizedReason: reason)
        } catch {
            return false
        }
    }
}
