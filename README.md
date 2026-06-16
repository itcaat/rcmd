# rcmd

Native macOS menu bar app inspired by rcmd.

The project is currently in bootstrap/MVP development. The implemented app
shell validates:

- menu bar utility lifecycle;
- Settings window;
- Accessibility permission request/status;
- active `CGEventTap`;
- right/left Command key event logging;
- dynamic assignments for running and installed apps;
- `right cmd + letter` focusing or launching assigned apps;
- manual assignments persisted in `~/.config/rcmd/config.yaml`;
- polished OSD overlay while right Command is held;
- layout-aware key translation for Latin keyboard layouts;
- key mapping mode setting;
- visual assignment editor in Settings;
- `.app` bundle packaging with Info.plist and app icon.

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the product plan and milestones.
See [AGENTS.md](AGENTS.md) for instructions for future AI agents.

## Build

```sh
swift build
```

The repository also provides Make targets used by CI:

```sh
make ci
make package VERSION=0.1.0
```

`make ci` builds the SwiftPM package, runs tests when a `Tests/` directory is
available, and verifies app bundle packaging. The current project state has no
tests, so the test step is skipped locally and in CI until tests are added.

## Run

```sh
swift run rcmd-app
```

For app-style manual testing, build a local DMG and open the bundled app:

```sh
make package
open dist/rcmd-local-macos.dmg
```

The DMG contains `rcmd.app` and an `Applications` shortcut. Drag the app onto
the shortcut to install it.

The app launches as a menu bar utility with a keyboard icon and `rcmd` text in
the top-right macOS menu bar. If Accessibility permission is missing, the
Settings window should also open automatically. Click `Request Permission`,
then grant the app in macOS System Settings. The keyboard monitor starts
automatically after permission is granted.

After permission is granted, hold right Command to show the OSD assignment
overlay. Press one of the listed letters to focus a running app or launch a
closed app. The OSD is scrollable for larger assignment lists and appears on
the screen containing the pointer.

Key mapping mode is configurable in Settings:

- `Physical keys` uses QWERTY letter positions regardless of active keyboard
  layout.
- `Active layout` uses the active Latin macOS keyboard layout, with physical
  QWERTY fallback for non-Latin layouts.

To set a manual assignment, focus the target app and press
`right cmd + right option + letter`. Manual assignments take priority over
dynamic assignments and are saved to:

```text
~/.config/rcmd/config.yaml
```

Manual assignments can also be edited in Settings: choose a letter, choose an
installed app, click `Assign`, or remove an existing manual assignment.

The config currently stores:

```yaml
keyMappingMode: activeLayout
assignments:
  c: com.google.Chrome
```

If the menu bar item is not visible, check whether the process is still running:

```sh
pgrep -fl rcmd-app
```

## Logs

Keyboard bootstrap logs use the `dev.local.rcmd` subsystem:

```sh
log stream --level debug --style compact --predicate 'subsystem == "dev.local.rcmd"'
```

## Release

Every branch push and pull request runs the GitHub Actions CI workflow. Pushing
a semantic version tag like `v0.1.0` runs the release workflow, builds the app,
packages `rcmd.app` into a DMG, and publishes a GitHub Release.

Create the next patch tag locally, then push the tag printed by the command:

```sh
make release
git push origin vX.Y.Z
```

Useful variants:

```sh
make release BUMP=minor
make release VERSION=0.2.0
make release-push
```

`make release-push` creates the next patch tag and pushes it to `origin`,
triggering the release workflow. The published DMG is not notarized yet; the
app bundle is ad-hoc signed for local integrity only.

## Current Limitations

- YAML support is intentionally minimal and currently stores key mapping mode
  and assignments.
- No tests yet; the currently selected CommandLineTools install does not expose
  `XCTest` or Swift `Testing`, so `swift test` reports no tests.
- Release artifacts are not Developer ID signed or notarized yet.
