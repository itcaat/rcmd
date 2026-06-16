import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppStateModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("rcmd bootstrap")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This build validates the menu bar shell, Accessibility flow, right Command routing, and focusing or launching assigned apps.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            statusRow(
                title: "Accessibility",
                value: appState.accessibilityTrusted ? "Granted" : "Missing"
            )

            statusRow(
                title: "Keyboard monitor",
                value: appState.eventTapRunning ? "Running" : "Stopped"
            )

            Text(appState.statusMessage)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(appState.lastShortcutMessage)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            HStack {
                Button("Request Permission") {
                    AccessibilityPermission.request()
                    appState.refreshAccessibilityStatus()
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Dynamic app assignments")
                    .font(.headline)

                if appState.assignments.isEmpty {
                    Text("No regular apps found.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(appState.assignments) { assignment in
                            Text(assignment.displayText)
                                .font(.system(.caption, design: .monospaced))
                                .lineLimit(1)
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent key events")
                    .font(.headline)

                if appState.recentEvents.isEmpty {
                    Text("No events captured yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.recentEvents, id: \.self) { event in
                        Text(event)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(width: 560, height: 420)
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}
