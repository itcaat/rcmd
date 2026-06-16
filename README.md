# rcmd

Native macOS menu bar app inspired by rcmd.

The project is currently in bootstrap/MVP development. The implemented app
shell validates:

- menu bar utility lifecycle;
- Settings window;
- Accessibility permission request/status;
- listen-only `CGEventTap`;
- right/left Command key event logging.

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

The app launches as a menu bar utility named `rcmd`. If Accessibility
permission is missing, open Settings from the menu bar and click
`Request Permission`, then grant the app in macOS System Settings.

## Logs

Keyboard bootstrap logs use the `dev.local.rcmd` subsystem:

```sh
log stream --level debug --style compact --predicate 'subsystem == "dev.local.rcmd"'
```

## Current Limitations

- No app switching behavior yet.
- No dynamic assignments yet.
- No OSD yet.
- No YAML config yet.
- No tests yet; the currently selected CommandLineTools install does not expose
  `XCTest` or Swift `Testing`, so `swift test` reports no tests.
