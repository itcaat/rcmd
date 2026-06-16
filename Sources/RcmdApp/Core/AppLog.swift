import OSLog

enum AppLog {
    static let app = Logger(subsystem: "dev.local.rcmd", category: "app")
    static let hotkeys = Logger(subsystem: "dev.local.rcmd", category: "hotkeys")
    static let accessibility = Logger(subsystem: "dev.local.rcmd", category: "accessibility")
}
