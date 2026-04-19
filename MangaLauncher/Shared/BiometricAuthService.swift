import LocalAuthentication

enum BiometricAuthService {
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics, error: &error
        ) ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        do {
            return try await context.evaluatePolicy(policy, localizedReason: reason)
        } catch {
            return false
        }
    }
}
