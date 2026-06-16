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
- `right cmd + letter` focusing or launching assigned apps.

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

After permission is granted, open Settings to see dynamic running app
assignments. Hold right Command and press one of the listed letters to focus a
running app or launch a closed app. The current key mapping is QWERTY key-code
based and is not layout-aware yet.

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

- No custom assignments yet.
- No OSD yet.
- No YAML config yet.
- No tests yet; the currently selected CommandLineTools install does not expose
  `XCTest` or Swift `Testing`, so `swift test` reports no tests.
