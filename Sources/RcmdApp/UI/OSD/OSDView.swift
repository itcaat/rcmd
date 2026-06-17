import SwiftUI

struct OSDView: View {
    @ObservedObject var appState: AppStateModel
    let actions: OSDActions

    @State private var searchWindows: [WindowInfo] = []
    @State private var visibleSearchStartIndex = 0
    @Namespace private var selectionNamespace

    private let columns = [
        GridItem(.adaptive(minimum: 178), spacing: 8)
    ]
    private let contentHeight: CGFloat = 340
    private let visibleSearchRowCount = 7
    private let scrollComfortRows = 1
    private let selectionAnimation = Animation.interactiveSpring(response: 0.22, dampingFraction: 0.86)
    private let scrollAnimation = Animation.easeInOut(duration: 0.18)

    private var filteredWindows: [WindowInfo] {
        WindowSearchFilter.filteredWindows(searchWindows, query: appState.windowSearchQuery)
    }

    private var selectedWindow: WindowInfo? {
        if let selectedWindowID = appState.selectedWindowID,
           let selectedWindow = displayedWindows.first(where: { $0.id == selectedWindowID }) {
            return selectedWindow
        }

        return displayedWindows.first
    }

    private var displayedWindows: [WindowInfo] {
        Array(filteredWindows.prefix(18))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            contentArea

            bottomSearchBar
        }
        .padding(16)
        .frame(minWidth: 420, idealWidth: 620, maxWidth: 720)
        .frame(height: 430)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.26), radius: 20, x: 0, y: 12)
        .onAppear {
            syncSearchWindows()
            updateSelection()
        }
        .onChange(of: appState.osdMode) { _, mode in
            if mode == .windowSearch {
                visibleSearchStartIndex = 0
                syncSearchWindows()
            }

            updateSelection()
        }
        .onChange(of: appState.windowSearchQuery) { _, _ in
            DispatchQueue.main.async {
                visibleSearchStartIndex = 0
                updateSelection()
            }
        }
        .onChange(of: appState.windows) { _, _ in
            visibleSearchStartIndex = 0
            syncSearchWindows()
            updateSelection()
        }
        .onExitCommand {
            if appState.osdMode == .windowSearch {
                actions.closeSearch()
            }
        }
    }

    private var contentArea: some View {
        ZStack(alignment: .topLeading) {
            if appState.osdMode == .assignments {
                assignmentContent
            } else {
                searchResults
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: contentHeight)
    }

    private var assignmentContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appState.assignments.isEmpty {
                Text("No app assignments")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                        ForEach(appState.assignments.prefix(48)) { assignment in
                            assignmentRow(assignment)
                        }
                    }
                    .padding(.trailing, 2)
                }
                .frame(height: contentHeight)
                .scrollIndicators(.hidden)

                if appState.assignments.count > 48 {
                    Text("+\(appState.assignments.count - 48) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .imageScale(.medium)

                Text("rcmd")
                    .font(.headline)

                Spacer(minLength: 0)

                Text(headerCountText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
        }
    }

    private var headerCountText: String {
        switch appState.osdMode {
        case .assignments:
            "\(appState.assignments.count) apps"
        case .windowSearch:
            "\(searchWindows.count) windows"
        }
    }

    private var bottomSearchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            SearchTextField(
                text: Binding(
                    get: {
                        appState.windowSearchQuery
                    },
                    set: { query in
                        appState.setWindowSearchQuery(query)
                    }
                ),
                isActive: appState.osdMode == .windowSearch,
                placeholder: "Search windows",
                onMoveUp: {
                    moveSelection(by: -1)
                },
                onMoveDown: {
                    moveSelection(by: 1)
                },
                onSubmit: {
                    focusSelectedWindow()
                },
                onEscape: {
                    actions.closeSearch()
                }
            )
            .frame(height: 20)

            Text("Space")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            if appState.osdMode == .assignments {
                Text("\(appState.windows.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 22, alignment: .trailing)
            } else {
                Text("\(filteredWindows.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 22, alignment: .trailing)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var searchResults: some View {
        ZStack(alignment: .topLeading) {
            if !appState.accessibilityTrusted {
                emptySearchText("Grant Accessibility to search windows.")
            } else if filteredWindows.isEmpty {
                emptySearchText(searchWindows.isEmpty ? "No readable windows." : "No matching windows.")
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(displayedWindows) { window in
                                Button {
                                    actions.focusWindow(window)
                                } label: {
                                    windowRow(window, isSelected: window.id == appState.selectedWindowID)
                                }
                                .buttonStyle(.plain)
                                .id(window.id)
                            }
                        }
                        .animation(selectionAnimation, value: appState.selectedWindowID)
                    }
                    .onChange(of: appState.selectedWindowID) { _, selectedWindowID in
                        guard let selectedWindowID else {
                            return
                        }

                        scrollSelectionIntoComfortZone(selectedWindowID, proxy: proxy)
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .frame(height: contentHeight)
    }

    private func emptySearchText(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
    }

    private func windowRow(_ window: WindowInfo, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            AppIconView(appURL: window.appURL, size: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(window.displayTitle)
                    .font(.callout)
                    .lineLimit(1)

                Text("\(window.appName) - \(window.detailText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.accentColor.opacity(0.16))
                    .matchedGeometryEffect(id: "window-search-selection", in: selectionNamespace)
            }
        }
        .contentShape(Rectangle())
    }

    private func assignmentRow(_ assignment: AppAssignment) -> some View {
        HStack(spacing: 8) {
            Text(String(assignment.letter).uppercased())
                .font(.system(.headline, design: .monospaced))
                .frame(width: 28, height: 28)
                .background(assignment.isManual ? Color.accentColor.opacity(0.24) : Color.secondary.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            AppIconView(appURL: assignment.appURL, size: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(assignment.appName)
                    .font(.callout)
                    .lineLimit(1)

                Text(detailText(for: assignment))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 34)
        .padding(.trailing, 4)
        .contentShape(Rectangle())
    }

    private func detailText(for assignment: AppAssignment) -> String {
        let state = assignment.isRunning ? "running" : "closed"

        if assignment.isManual {
            return "\(state), manual"
        }

        return state
    }

    private func updateSelection() {
        guard appState.osdMode == .windowSearch else {
            appState.selectWindow(id: nil)
            return
        }

        if let selectedWindowID = appState.selectedWindowID,
           displayedWindows.contains(where: { $0.id == selectedWindowID }) {
            return
        }

        appState.selectWindow(id: displayedWindows.first?.id)
    }

    private func syncSearchWindows() {
        guard appState.osdMode == .windowSearch else {
            return
        }

        searchWindows = appState.windows
    }

    private func focusSelectedWindow() {
        guard let selectedWindow else {
            return
        }

        actions.focusWindow(selectedWindow)
    }
    private func moveSelection(by offset: Int) {
        guard appState.osdMode == .windowSearch else {
            return
        }

        guard !displayedWindows.isEmpty else {
            appState.selectWindow(id: nil)
            return
        }

        let currentIndex = appState.selectedWindowID.flatMap { selectedWindowID in
            displayedWindows.firstIndex(where: { $0.id == selectedWindowID })
        } ?? displayedWindows.startIndex

        let nextIndex = max(
            displayedWindows.startIndex,
            min(displayedWindows.index(before: displayedWindows.endIndex), currentIndex + offset)
        )
        appState.selectWindow(id: displayedWindows[nextIndex].id)
    }

    private func scrollSelectionIntoComfortZone(_ selectedWindowID: WindowInfo.ID, proxy: ScrollViewProxy) {
        guard let selectedIndex = displayedWindows.firstIndex(where: { $0.id == selectedWindowID }) else {
            return
        }

        let maxStartIndex = max(0, displayedWindows.count - visibleSearchRowCount)
        let currentStartIndex = min(visibleSearchStartIndex, maxStartIndex)
        let comfortTopIndex = currentStartIndex + scrollComfortRows
        let comfortBottomIndex = currentStartIndex + visibleSearchRowCount - scrollComfortRows - 1

        let nextStartIndex: Int
        if selectedIndex < comfortTopIndex {
            nextStartIndex = max(0, selectedIndex - scrollComfortRows)
        } else if selectedIndex > comfortBottomIndex {
            nextStartIndex = min(maxStartIndex, selectedIndex - visibleSearchRowCount + scrollComfortRows + 1)
        } else {
            visibleSearchStartIndex = currentStartIndex
            return
        }

        visibleSearchStartIndex = nextStartIndex
        let targetWindowID = displayedWindows[nextStartIndex].id

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.07) {
            guard appState.osdMode == .windowSearch else {
                return
            }

            guard appState.selectedWindowID == selectedWindowID else {
                return
            }

            withAnimation(scrollAnimation) {
                proxy.scrollTo(targetWindowID, anchor: .top)
            }
        }
    }
}
