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
- visual assignment editor in Settings.

See [PROJECT_PLAN.md](PROJECT_PLAN.md) for the product plan and milestones.
See [AGENTS.md](AGENTS.md) for instructions for future AI agents.

## Build

```sh
swift build
```

## Run

```sh
swift run rcmd-app
```

The app launches as a menu bar utility with a keyboard icon and `rcmd` text in
the top-right macOS menu bar. If Accessibility permission is missing, the
Settings window should also open automatically. Click `Request Permission`,
then grant the app in macOS System Settings.

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

## Current Limitations

- YAML support is intentionally minimal and currently stores key mapping mode
  and assignments.
- No tests yet; the currently selected CommandLineTools install does not expose
  `XCTest` or Swift `Testing`, so `swift test` reports no tests.
