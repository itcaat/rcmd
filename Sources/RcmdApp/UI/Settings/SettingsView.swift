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
            case .overview: L10n.tr("settings.pane.overview")
            case .shortcuts: L10n.tr("settings.pane.shortcuts")
            case .assignments: L10n.tr("settings.pane.assignments")
            case .windows: L10n.tr("settings.pane.windows")
            case .diagnostics: L10n.tr("settings.pane.diagnostics")
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

                Text(L10n.tr("settings.keyboardControl"))
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
                    title: L10n.tr("settings.accessibility"),
                    isGood: appState.accessibilityTrusted,
                    value: appState.accessibilityTrusted ? L10n.tr("state.granted") : L10n.tr("state.missing")
                )

                statusDotRow(
                    title: L10n.tr("settings.monitor"),
                    isGood: appState.eventTapRunning,
                    value: appState.eventTapRunning ? L10n.tr("state.runningCapitalized") : L10n.tr("state.stopped")
                )
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
        }
        .frame(width: 190)
        .background(Color(nsColor: .windowBackgroundColor))
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
            L10n.tr("settings.subtitle.overview")
        case .shortcuts:
            L10n.tr("settings.subtitle.shortcuts")
        case .assignments:
            L10n.tr("settings.subtitle.assignments")
        case .windows:
            L10n.tr("settings.subtitle.windows")
        case .diagnostics:
            L10n.tr("settings.subtitle.diagnostics")
        }
    }

    private var overviewPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup(L10n.tr("settings.group.systemAccess")) {
                VStack(spacing: 0) {
                    accessibilityRow
                    separator
                    settingsRow(
                        systemImage: "keyboard.badge.eye",
                        title: L10n.tr("settings.keyboardMonitor"),
                        subtitle: appState.statusMessage,
                        value: appState.eventTapRunning ? L10n.tr("state.runningCapitalized") : L10n.tr("state.stopped"),
                        valueColor: appState.eventTapRunning ? .green : .orange
                    )
                }
            }

            settingsGroup(L10n.tr("settings.group.startup")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(
                        L10n.tr("settings.launchAtLogin"),
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

            settingsGroup(L10n.tr("settings.group.snapshot")) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 10)], spacing: 10) {
                    metricTile(title: L10n.tr("settings.metric.assignments"), value: "\(appState.assignments.count)", systemImage: "square.grid.2x2")
                    metricTile(title: L10n.tr("settings.metric.apps"), value: "\(appState.appCatalog.count)", systemImage: "app.dashed")
                    metricTile(title: L10n.tr("settings.metric.windows"), value: "\(appState.windows.count)", systemImage: "macwindow")
                }
            }
        }
    }

    private var accessibilityRow: some View {
        HStack(spacing: 12) {
            rowIcon("figure.wave")

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr("settings.accessibility"))
                    .font(.callout.weight(.medium))

                Text(appState.accessibilityTrusted ? L10n.tr("settings.accessibilityGrantedSubtitle") : L10n.tr("settings.accessibilityMissingSubtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            if appState.accessibilityTrusted {
                statusPill(L10n.tr("state.granted"), color: .green)
            } else {
                Button {
                    AccessibilityPermission.request()
                    appState.refreshAccessibilityStatus()
                } label: {
                    Label(L10n.tr("state.missing"), systemImage: "exclamationmark.triangle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .frame(minHeight: 46)
    }

    private var shortcutsPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsGroup(L10n.tr("settings.group.shortcuts")) {
                VStack(spacing: 0) {
                    shortcutRow(keys: "Right Cmd + Letter", title: L10n.tr("settings.shortcut.focusOrLaunch"))
                    separator
                    shortcutRow(keys: "Right Cmd + Space", title: L10n.tr("settings.shortcut.searchWindows"))
                    separator
                    shortcutRow(keys: "Right Cmd + Tab", title: L10n.tr("settings.shortcut.focusNextWindow"))
                    separator
                    shortcutRow(keys: "Right Cmd + Right Option + Letter", title: L10n.tr("settings.shortcut.assignFrontmost"))
                }
            }

            settingsGroup(L10n.tr("settings.group.behavior")) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(
                        L10n.tr("settings.minimizeRepeatedShortcut"),
                        isOn: Binding(
                            get: { appState.minimizeActiveWindowOnRepeatedShortcut },
                            set: { enabled in actions.setMinimizeActiveWindowOnRepeatedShortcut(enabled) }
                        )
                    )

                    Text(L10n.tr("settings.minimizeRepeatedShortcutDetail"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            settingsGroup(L10n.tr("settings.group.keyMapping")) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(
                        L10n.tr("settings.keyMapping"),
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
            settingsGroup(L10n.tr("settings.group.manualAssignment")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        Picker(L10n.tr("settings.letter"), selection: $selectedLetter) {
                            ForEach(editableLetters, id: \.self) { letter in
                                Text(String(letter).uppercased()).tag(letter)
                            }
                        }
                        .frame(width: 118)

                        Picker(L10n.tr("settings.app"), selection: $selectedBundleIdentifier) {
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
                            Label(L10n.tr("settings.assign"), systemImage: "plus.circle.fill")
                        }
                        .disabled(selectedBundleIdentifier.isEmpty)
                    }

                    manualAssignmentRows
                }
            }
            .onChange(of: appState.appCatalog) { _, _ in
                syncDefaultSelectedApp()
            }

            settingsGroup(L10n.tr("settings.group.currentAssignments")) {
                if appState.assignments.isEmpty {
                    emptyState(L10n.tr("settings.empty.noRegularApps"), systemImage: "app.dashed")
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
                emptyState(L10n.tr("settings.empty.noManualAssignments"), systemImage: "pin.slash")
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
                .help(L10n.tr("settings.removeAssignment"))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var windowsPane: some View {
        settingsGroup(L10n.tr("settings.group.readableWindows")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(L10n.tr("settings.windowsCount", appState.windows.count))
                        .font(.headline)

                    Spacer()

                    statusPill(appState.accessibilityTrusted ? L10n.tr("state.live") : L10n.tr("state.permissionNeeded"), color: appState.accessibilityTrusted ? .green : .orange)
                }

                if !appState.accessibilityTrusted {
                    emptyState(L10n.tr("settings.empty.grantAccessibilityForWindows"), systemImage: "figure.wave")
                } else if appState.windows.isEmpty {
                    emptyState(L10n.tr("settings.empty.noReadableWindows"), systemImage: "macwindow.badge.plus")
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
            settingsGroup(L10n.tr("settings.group.status")) {
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

            settingsGroup(L10n.tr("settings.group.recentKeyEvents")) {
                if appState.recentEvents.isEmpty {
                    emptyState(L10n.tr("settings.empty.noEvents"), systemImage: "keyboard.badge.ellipsis")
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
        let state = assignment.isRunning ? L10n.tr("state.running") : L10n.tr("state.closed")

        if assignment.isManual {
            return "\(state)\(L10n.tr("state.manualSuffix"))"
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
            L10n.tr("settings.keyMappingActiveLayoutDetail")
        case .physical:
            L10n.tr("settings.keyMappingPhysicalDetail")
        }
    }
}
