import Foundation
import ServiceManagement

struct LaunchAtLoginState: Sendable, Equatable {
    let isEnabled: Bool
    let statusText: String
}

enum LaunchAtLoginResult: Sendable, Equatable {
    case enabled
    case disabled
    case requiresApproval
    case failed(String)

    var displayMessage: String {
        switch self {
        case .enabled:
            "Launch at Login enabled."
        case .disabled:
            "Launch at Login disabled."
        case .requiresApproval:
            "Launch at Login requires approval in System Settings."
        case .failed(let message):
            "Launch at Login failed: \(message)"
        }
    }
}

@MainActor
final class LaunchAtLoginController {
    func currentState() -> LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .enabled:
            LaunchAtLoginState(isEnabled: true, statusText: "Enabled")
        case .requiresApproval:
            LaunchAtLoginState(isEnabled: false, statusText: "Requires approval")
        case .notRegistered:
            LaunchAtLoginState(isEnabled: false, statusText: "Disabled")
        case .notFound:
            LaunchAtLoginState(isEnabled: false, statusText: "Unavailable")
        @unknown default:
            LaunchAtLoginState(isEnabled: false, statusText: "Unknown")
        }
    }

    func setEnabled(_ enabled: Bool) -> LaunchAtLoginResult {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }

                if SMAppService.mainApp.status == .requiresApproval {
                    return .requiresApproval
                }

                return .enabled
            } else {
                if SMAppService.mainApp.status != .notRegistered {
                    try SMAppService.mainApp.unregister()
                }

                return .disabled
            }
        } catch {
            AppLog.app.error("Launch at Login update failed: \(error.localizedDescription, privacy: .public)")
            return .failed(error.localizedDescription)
        }
    }
}
