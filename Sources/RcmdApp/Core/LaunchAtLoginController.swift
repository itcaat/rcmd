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
            L10n.tr("launchAtLogin.enabledMessage")
        case .disabled:
            L10n.tr("launchAtLogin.disabledMessage")
        case .requiresApproval:
            L10n.tr("launchAtLogin.requiresApprovalMessage")
        case .failed(let message):
            L10n.tr("launchAtLogin.failedMessage", message)
        }
    }
}

@MainActor
final class LaunchAtLoginController {
    func currentState() -> LaunchAtLoginState {
        switch SMAppService.mainApp.status {
        case .enabled:
            LaunchAtLoginState(isEnabled: true, statusText: L10n.tr("state.enabled"))
        case .requiresApproval:
            LaunchAtLoginState(isEnabled: false, statusText: L10n.tr("state.requiresApproval"))
        case .notRegistered:
            LaunchAtLoginState(isEnabled: false, statusText: L10n.tr("state.disabled"))
        case .notFound:
            LaunchAtLoginState(isEnabled: false, statusText: L10n.tr("state.unavailable"))
        @unknown default:
            LaunchAtLoginState(isEnabled: false, statusText: L10n.tr("state.unknown"))
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
