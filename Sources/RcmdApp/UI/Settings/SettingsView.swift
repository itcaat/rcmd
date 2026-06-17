import SwiftUI

struct SettingsView: View {
    private enum Pane: String, CaseIterable, Identifiable {
        case overview
        case shortcuts
        case assignments
        case windows
        case diagnostics

        var id: Self { self }

        var title: String {
            switch self {
            case .overview: "Overview"
            case .shortcuts: "Shortcuts"
            case .assignments: "Assignments"
            case .windows: "Windows"
            case .diagnostics: "Diagnostics"
            }
        }

        var systemImage: String {
            switch self {
            case .overview: "switch.2"
            case .shortcuts: "keyboard"
            case .assignments: "square.grid.2x2"
            case .windows: "macwindow.on.rectangle"
            case .diagnostics: "waveform.path.ecg"
            }
        }
    }

    private let editableLetters = Array("abcdefghijklmnopqrstuvwxyz")

    @ObservedObject var appState: AppStateModel
    let actions: SettingsActions

    @State private var selectedPane: Pane = .overview
    @State private var selectedLetter: Character = "a"
    @State private var selectedBundleIdentifier = ""

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            content
        }
        .frame(width: 860, height: 600)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            syncDefaultSelectedApp()
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "command.square.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white, Color.accentColor)

                    Text("rcmd")
                        .font(.title3.weight(.semibold))
                }

                Text("Keyboard control")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 18)

            VStack(spacing: 4) {
                ForEach(Pane.allCases) { pane in
                    sidebarButton(pane)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 8) {
                statusDotRow(
                    title: "Accessibility",
                    isGood: appState.accessibilityTrusted,
                    value: appState.accessibilityTrusted ? "Granted" : "Missing"
                )

                statusDotRow(
                    title: "Monitor",
                    isGood: appState.eventTapRunning,
                    value: appState.eventTapRunning ? "Running" : "Stopped"
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .frame(width: 190)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func sidebarButton(_ pane: Pane) -> some View {
        Button {
            selectedPane = pane
        } label: {
            Label(pane.title, systemImage: pane.systemImage)
                .font(.callout.weight(selectedPane == pane ? .semibold : .regular))
                .foregroundStyle(selectedPane == pane ? .primary : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if selectedPane == pane {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color.accentColor.opacity(0.16))
                    }
                }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                paneHeader

                switch selectedPane {
                case .overview:
                    overviewPane
                case .shortcuts:
                    shortcutsPane
                case .assignments:
                    assignmentsPane
                case .windows:
                    windowsPane
                case .diagnostics:
                    diagnosticsPane
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.visible)
    }

    private var paneHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: selectedPane.systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34, height: 34)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(selectedPane.title)
                    .font(.title2.weight(.semibold))

                Text(paneSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var paneSubtitle: String {
        switch selectedPane {
        case .overview:
            "Permission, startup, and active keyboard monitor state."
        case .shortcuts:
            "Trigger behavior and keyboard layout mapping."
        case .assignments:
            "Manual and dynamic app bindings used by right Command."
        case .windows:
            "Readable windows exposed through Accessibility."
        case .diagnostics:
            "Recent events and internal status for debugging."
        }
    }

    private var overviewPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup("System access") {
                VStack(spacing: 0) {
                    accessibilityRow
                    separator
                    settingsRow(
                        systemImage: "keyboard.badge.eye",
                        title: "Keyboard monitor",
                        subtitle: appState.statusMessage,
                        value: appState.eventTapRunning ? "Running" : "Stopped",
                        valueColor: appState.eventTapRunning ? .green : .orange
                    )
                }
            }

            settingsGroup("Startup") {
                VStack(alignment: .leading, spacing: 10) {
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

            settingsGroup("Snapshot") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 10)], spacing: 10) {
                    metricTile(title: "Assignments", value: "\(appState.assignments.count)", systemImage: "square.grid.2x2")
                    metricTile(title: "Apps", value: "\(appState.appCatalog.count)", systemImage: "app.dashed")
                    metricTile(title: "Windows", value: "\(appState.windows.count)", systemImage: "macwindow")
                }
            }
        }
    }

    private var accessibilityRow: some View {
        HStack(spacing: 12) {
            rowIcon("figure.wave")

            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility")
                    .font(.callout.weight(.medium))

                Text(appState.accessibilityTrusted ? "Window focus and global shortcuts are available." : "Required for global shortcuts and window metadata.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            if appState.accessibilityTrusted {
                statusPill("Granted", color: .green)
            } else {
                Button {
                    AccessibilityPermission.request()
                    appState.refreshAccessibilityStatus()
                } label: {
                    Label("Missing", systemImage: "exclamationmark.triangle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .frame(minHeight: 46)
    }

    private var shortcutsPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup("Shortcuts") {
                VStack(spacing: 0) {
                    shortcutRow(keys: "Right Cmd + Letter", title: "Focus or launch assigned app")
                    separator
                    shortcutRow(keys: "Right Cmd + Space", title: "Search open windows")
                    separator
                    shortcutRow(keys: "Right Cmd + Tab", title: "Focus next readable window")
                    separator
                    shortcutRow(keys: "Right Cmd + Right Option + Letter", title: "Assign frontmost app")
                }
            }

            settingsGroup("Key mapping") {
                VStack(alignment: .leading, spacing: 10) {
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
        }
    }

    private var assignmentsPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup("Manual assignment") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Picker("Letter", selection: $selectedLetter) {
                            ForEach(editableLetters, id: \.self) { letter in
                                Text(String(letter).uppercased()).tag(letter)
                            }
                        }
                        .frame(width: 118)

                        Picker("App", selection: $selectedBundleIdentifier) {
                            ForEach(appState.appCatalog) { app in
                                Text(app.displayText).tag(app.bundleIdentifier)
                            }
                        }
                        .frame(minWidth: 260)

                        Button {
                            guard !selectedBundleIdentifier.isEmpty else {
                                return
                            }

                            actions.assignApp(selectedBundleIdentifier, selectedLetter)
                        } label: {
                            Label("Assign", systemImage: "plus.circle.fill")
                        }
                        .disabled(selectedBundleIdentifier.isEmpty)
                    }

                    manualAssignmentRows
                }
            }
            .onChange(of: appState.appCatalog) { _, _ in
                syncDefaultSelectedApp()
            }

            settingsGroup("Current assignments") {
                if appState.assignments.isEmpty {
                    emptyState("No regular apps found.", systemImage: "app.dashed")
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 10)], alignment: .leading, spacing: 10) {
                        ForEach(appState.assignments) { assignment in
                            assignmentSummaryRow(assignment, showRemove: false)
                        }
                    }
                }
            }
        }
    }

    private var manualAssignmentRows: some View {
        let manualAssignments = appState.assignments.filter(\.isManual)

        return VStack(alignment: .leading, spacing: 8) {
            if manualAssignments.isEmpty {
                emptyState("No manual assignments.", systemImage: "pin.slash")
            } else {
                ForEach(manualAssignments) { assignment in
                    assignmentSummaryRow(assignment, showRemove: true)
                }
            }
        }
    }

    private func assignmentSummaryRow(_ assignment: AppAssignment, showRemove: Bool) -> some View {
        HStack(spacing: 9) {
            Text(String(assignment.letter).uppercased())
                .font(.system(.callout, design: .monospaced).weight(.semibold))
                .frame(width: 28, height: 28)
                .background(assignment.isManual ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            AppIconView(appURL: assignment.appURL, size: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(assignment.appName)
                    .font(.callout)
                    .lineLimit(1)

                Text(assignmentDetailText(assignment))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)

            if showRemove {
                Button {
                    actions.removeManualAssignment(assignment.letter)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .imageScale(.medium)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Remove assignment")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var windowsPane: some View {
        settingsGroup("Readable windows") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("\(appState.windows.count) windows")
                        .font(.headline)

                    Spacer()

                    statusPill(appState.accessibilityTrusted ? "Live" : "Permission needed", color: appState.accessibilityTrusted ? .green : .orange)
                }

                if !appState.accessibilityTrusted {
                    emptyState("Grant Accessibility to read window metadata.", systemImage: "figure.wave")
                } else if appState.windows.isEmpty {
                    emptyState("No readable windows found.", systemImage: "macwindow.badge.plus")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.windows.prefix(24)) { window in
                            windowRow(window)
                        }
                    }
                }
            }
        }
    }

    private func windowRow(_ window: WindowInfo) -> some View {
        HStack(spacing: 10) {
            AppIconView(appURL: window.appURL, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.displayTitle)
                    .font(.callout)
                    .lineLimit(1)

                Text("\(window.appName) - \(window.detailText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .frame(height: 46)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var diagnosticsPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup("Status") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.statusMessage)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(appState.lastShortcutMessage)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            settingsGroup("Recent key events") {
                if appState.recentEvents.isEmpty {
                    emptyState("No events captured yet.", systemImage: "keyboard.badge.ellipsis")
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(appState.recentEvents, id: \.self) { event in
                            Text(event)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func settingsGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func settingsRow(
        systemImage: String,
        title: String,
        subtitle: String,
        value: String,
        valueColor: Color
    ) -> some View {
        HStack(spacing: 12) {
            rowIcon(systemImage)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            statusPill(value, color: valueColor)
        }
        .frame(minHeight: 46)
    }

    private func shortcutRow(keys: String, title: String) -> some View {
        HStack(spacing: 12) {
            rowIcon("keyboard")

            Text(title)
                .font(.callout)

            Spacer(minLength: 16)

            Text(keys)
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.secondary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .frame(minHeight: 42)
    }

    private func metricTile(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            rowIcon(systemImage)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.weight(.semibold))

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(height: 62)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func rowIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 28, height: 28)
            .background(Color.accentColor.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func statusDotRow(title: String, isGood: Bool, value: String) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isGood ? Color.green : Color.orange)
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
        }
    }

    private var separator: some View {
        Divider()
            .padding(.leading, 40)
    }

    private func emptyState(_ text: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
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
