import SwiftUI

struct SettingsView: View {
    private let editableLetters = Array("abcdefghijklmnopqrstuvwxyz")

    @ObservedObject var appState: AppStateModel
    let actions: SettingsActions

    @State private var selectedLetter: Character = "a"
    @State private var selectedBundleIdentifier = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("rcmd bootstrap")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("This build validates the menu bar shell, Accessibility flow, right Command routing, and persistent app assignments.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider()

                accessibilityStatusRow

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

                launchAtLoginControl

                keyMappingModeControl

                assignmentEditor

                VStack(alignment: .leading, spacing: 8) {
                    Text("App assignments")
                        .font(.headline)

                    if appState.assignments.isEmpty {
                        Text("No regular apps found.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], alignment: .leading, spacing: 8) {
                            ForEach(appState.assignments) { assignment in
                                assignmentSummaryRow(assignment)
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
            }
            .padding(24)
        }
        .frame(width: 560, height: 420)
        .onAppear {
            syncDefaultSelectedApp()
        }
    }

    private func statusRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }

    private var accessibilityStatusRow: some View {
        HStack {
            Text("Accessibility")
            Spacer()

            if appState.accessibilityTrusted {
                Text("Granted")
                    .fontWeight(.medium)
            } else {
                Button {
                    AccessibilityPermission.request()
                    appState.refreshAccessibilityStatus()
                } label: {
                    Text("Missing")
                        .fontWeight(.medium)
                }
            }
        }
    }

    private var launchAtLoginControl: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(
                "Launch at Login",
                isOn: Binding(
                    get: { appState.launchAtLoginEnabled },
                    set: { enabled in actions.setLaunchAtLogin(enabled) }
                )
            )

            Text(appState.launchAtLoginStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var keyMappingModeControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key mapping")
                .font(.headline)

            Picker(
                "Key mapping",
                selection: Binding(
                    get: { appState.keyMappingMode },
                    set: { mode in actions.setKeyMappingMode(mode) }
                )
            ) {
                ForEach(KeyMappingMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(keyMappingDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var assignmentEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Manual assignment editor")
                .font(.headline)

            HStack(spacing: 10) {
                Picker("Letter", selection: $selectedLetter) {
                    ForEach(editableLetters, id: \.self) { letter in
                        Text(String(letter).uppercased()).tag(letter)
                    }
                }
                .frame(width: 120)

                Picker("App", selection: $selectedBundleIdentifier) {
                    ForEach(appState.appCatalog) { app in
                        Text(app.displayText).tag(app.bundleIdentifier)
                    }
                }
                .frame(minWidth: 240)

                Button("Assign") {
                    guard !selectedBundleIdentifier.isEmpty else {
                        return
                    }

                    actions.assignApp(selectedBundleIdentifier, selectedLetter)
                }
                .disabled(selectedBundleIdentifier.isEmpty)
            }

            manualAssignmentRows
        }
        .onChange(of: appState.appCatalog) { _, _ in
            syncDefaultSelectedApp()
        }
    }

    private var manualAssignmentRows: some View {
        let manualAssignments = appState.assignments.filter(\.isManual)

        return VStack(alignment: .leading, spacing: 6) {
            if manualAssignments.isEmpty {
                Text("No manual assignments.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manualAssignments) { assignment in
                    HStack(spacing: 8) {
                        assignmentSummaryRow(assignment)

                        Spacer()

                        Button("Remove") {
                            actions.removeManualAssignment(assignment.letter)
                        }
                    }
                }
            }
        }
    }

    private func assignmentSummaryRow(_ assignment: AppAssignment) -> some View {
        HStack(spacing: 8) {
            Text(String(assignment.letter).uppercased())
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .frame(width: 22, height: 22)
                .background(assignment.isManual ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            AppIconView(appURL: assignment.appURL, size: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(assignment.appName)
                    .font(.caption)
                    .lineLimit(1)

                Text(assignmentDetailText(assignment))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 28)
    }

    private func assignmentDetailText(_ assignment: AppAssignment) -> String {
        let state = assignment.isRunning ? "running" : "closed"

        if assignment.isManual {
            return "\(state), manual"
        }

        return state
    }

    private func syncDefaultSelectedApp() {
        if selectedBundleIdentifier.isEmpty || !appState.appCatalog.contains(where: { $0.bundleIdentifier == selectedBundleIdentifier }) {
            selectedBundleIdentifier = appState.appCatalog.first?.bundleIdentifier ?? ""
        }
    }

    private var keyMappingDetail: String {
        switch appState.keyMappingMode {
        case .activeLayout:
            "Uses the active Latin macOS keyboard layout, with physical QWERTY fallback for non-Latin layouts."
        case .physical:
            "Uses physical QWERTY letter positions regardless of active keyboard layout."
        }
    }
}
