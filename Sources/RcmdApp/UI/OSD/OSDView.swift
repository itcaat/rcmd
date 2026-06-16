import SwiftUI

struct OSDView: View {
    @ObservedObject var appState: AppStateModel

    private let columns = [
        GridItem(.adaptive(minimum: 160), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if appState.assignments.isEmpty {
                Text("No app assignments")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                    ForEach(appState.assignments.prefix(18)) { assignment in
                        assignmentRow(assignment)
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 560)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
    }

    private func assignmentRow(_ assignment: AppAssignment) -> some View {
        HStack(spacing: 8) {
            Text(String(assignment.letter).uppercased())
                .font(.system(.headline, design: .monospaced))
                .frame(width: 28, height: 28)
                .background(assignment.isManual ? Color.accentColor.opacity(0.22) : Color.secondary.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(assignment.appName)
                    .font(.callout)
                    .lineLimit(1)

                Text(detailText(for: assignment))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(height: 34)
    }

    private func detailText(for assignment: AppAssignment) -> String {
        let state = assignment.isRunning ? "running" : "closed"

        if assignment.isManual {
            return "\(state), manual"
        }

        return state
    }
}
