import SwiftUI

struct OSDView: View {
    @ObservedObject var appState: AppStateModel

    private let columns = [
        GridItem(.adaptive(minimum: 178), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

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
                .frame(maxHeight: 460)
                .scrollIndicators(.hidden)

                if appState.assignments.count > 48 {
                    Text("+\(appState.assignments.count - 48) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 420, idealWidth: 620, maxWidth: 720)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.26), radius: 20, x: 0, y: 12)
    }

    private var header: some View {
        HStack(spacing: 8) {
                Image(systemName: "keyboard")
                    .imageScale(.medium)

                Text("rcmd")
                    .font(.headline)

                Spacer(minLength: 0)

                Text("\(appState.assignments.count) apps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
        }
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
}
