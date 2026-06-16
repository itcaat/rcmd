import AppKit

@main
enum Main {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = RcmdApp()
        app.delegate = delegate
        app.run()
    }
}
