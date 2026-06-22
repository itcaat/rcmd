import SwiftUI

struct QuickStartView: View {
    @ObservedObject var appState: AppStateModel
    let actions: QuickStartActions

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header

            VStack(alignment: .leading, spacing: 14) {
                permissionStep
                shortcutStep(
                    number: "2",
                    systemImage: "command.square",
                    title: L10n.tr("quickStart.holdRightCommandTitle"),
                    subtitle: L10n.tr("quickStart.holdRightCommandSubtitle")
                )
                shortcutStep(
                    number: "3",
                    systemImage: "keyboard",
                    title: L10n.tr("quickStart.coreShortcutsTitle"),
                    subtitle: L10n.tr("quickStart.coreShortcutsSubtitle")
                )
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(28)
        .frame(width: 640, height: 440)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "command.square.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.white, Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("quickStart.title"))
                    .font(.largeTitle.weight(.semibold))

                Text(L10n.tr("quickStart.subtitle"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var permissionStep: some View {
        HStack(alignment: .center, spacing: 12) {
            stepBadge("1")

            rowIcon("figure.wave")

            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.tr("quickStart.grantAccessibilityTitle"))
                    .font(.headline)

                Text(appState.accessibilityTrusted ? L10n.tr("quickStart.permissionGrantedSubtitle") : L10n.tr("quickStart.permissionMissingSubtitle"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 16)

            if appState.accessibilityTrusted {
                statusPill(L10n.tr("state.granted"), color: .green)
            } else {
                Button {
                    actions.requestAccessibilityPermission()
                } label: {
                    Label(L10n.tr("quickStart.grantPermission"), systemImage: "lock.open")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func shortcutStep(number: String, systemImage: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            stepBadge(number)

            rowIcon(systemImage)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var footer: some View {
        HStack(spacing: 10) {
            shortcutPill("Right Cmd + Letter")
            shortcutPill("Right Cmd + Space")
            shortcutPill("Right Cmd + Tab")

            Spacer(minLength: 12)

            Button {
                actions.openSettings()
            } label: {
                Label(L10n.tr("settings.title"), systemImage: "gearshape")
            }

            Button {
                actions.dismiss()
            } label: {
                Text(L10n.tr("quickStart.gotIt"))
                    .frame(minWidth: 62)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func stepBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced).weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Color.accentColor)
            .clipShape(Circle())
    }

    private func rowIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 30, height: 30)
            .background(Color.accentColor.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func statusPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func shortcutPill(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced).weight(.semibold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
