# rcmd-like macOS App Project Plan

Last updated: 2026-06-16

## Purpose

Build a native macOS application inspired by rcmd: fast keyboard-driven app,
window, and workspace switching using the right-side modifier keys.

This repository is currently at the bootstrap stage. A minimal SwiftPM macOS
menu bar app shell exists, and the first app-switching behavior can focus or
launch assigned apps.

## Current Repository State

Done:

- Repository exists at `/Users/nicosha/Documents/my/rcmd`.
- `README.md` documents build/run/logging basics.
- `AGENTS.md` documents workflow rules for future AI agents.
- Product research was done against:
  - https://lowtechguys.com/rcmd/
  - https://files.lowtechguys.com/rcmd/changelog.html
- Recommended MVP scope was chosen.
- SwiftPM package exists in `Package.swift`.
- App target exists in `Sources/RcmdApp`.
- App launches as a menu bar utility.
- Settings window exists.
- Accessibility permission status and request helper exist.
- Active `CGEventTap` exists for key event logging and handled shortcut
  suppression.
- Basic right/left Command key identification exists.
- Layout-aware key translation exists for Latin keyboard layouts.
- Non-Latin keyboard layouts currently use physical QWERTY fallback.
- Key mapping mode is configurable and persisted in config.
- Dynamic assignments for running and installed apps exist.
- `right cmd + letter` can focus or launch assigned apps.
- Manual assignment capture exists through `right cmd + right option + letter`.
- Assignments persist in `~/.config/rcmd/config.yaml`.
- Holding right Command opens a polished, scrollable OSD assignment overlay.
- Visual assignment editor exists in Settings.
- GitHub Actions CI exists for branch pushes and pull requests.
- Tag-driven GitHub Actions release publishing exists for `v*.*.*` tags.
- Local `make` targets exist for CI, DMG packaging, and release tag creation.

Not done:

- No Xcode project exists yet.
- YAML support is minimal and currently stores key mapping mode and assignments.
- No tests exist yet; current CommandLineTools install does not expose `XCTest`
  or Swift `Testing`.
- No signed/notarized app bundle, installer, or polished distribution pipeline
  exists yet.

## Product Target

The app should become a native macOS menu bar utility that lets users switch
apps, windows, Spaces, and saved workspaces with fast keyboard gestures.

The long-term target includes both free/core features and advanced Pro-like
features, but implementation should start with a narrow MVP.

## MVP v0.1 Scope

The first milestone should validate the core technical foundation:

1. Native macOS menu bar app.
2. Onboarding screen for required permissions.
3. Accessibility permission detection and prompt.
4. Global keyboard event capture through `CGEventTap`.
5. Correctly distinguish right Command from left Command.
6. `right cmd + letter` focuses an already running app.
7. `right cmd + letter` launches an app if it is not running.
8. Dynamic app-to-letter assignments.
9. Manual assignment shortcut: `right cmd + right option + letter`.
10. Simple on-screen display showing current key assignments.
11. Basic Settings window.
12. YAML config persisted at `~/.config/rcmd/config.yaml`.

The MVP should not include Spaces, Stages, licensing, or full Cmd-Tab
replacement. Those should wait until the keyboard/app/window foundation is
stable.

## Recommended Technical Stack

- Language: Swift.
- UI: SwiftUI for Settings and onboarding.
- macOS integration: AppKit for menu bar app, OSD windows, and app lifecycle.
- Global keys: `CGEventTap`.
- App discovery and launching: `NSWorkspace`.
- Window metadata and focus: Accessibility API / `AXUIElement`.
- Observability: `os.Logger`.
- Config: readable YAML file.
- CLI later: XPC or Unix domain socket to the running app.

## Proposed Source Layout

Use this structure when bootstrapping the project:

```text
rcmd/
  README.md
  PROJECT_PLAN.md
  rcmd.xcodeproj/ or Package.swift
  Sources/
    RcmdApp/
      AppDelegate.swift
      RcmdApp.swift
      MenuBarController.swift
    Core/
      AppRegistry.swift
      AssignmentStore.swift
      ConfigStore.swift
      Logger.swift
    Hotkeys/
      EventTapController.swift
      KeyEventRouter.swift
      ModifierSideDetector.swift
    Accessibility/
      AccessibilityPermission.swift
      AccessibilityClient.swift
      WindowRegistry.swift
    UI/
      Onboarding/
      Settings/
      OSD/
    Windowing/
    Spaces/
    Stages/
    CLI/
  Tests/
```

`Spaces`, `Stages`, and `CLI` can be placeholder modules at first, but should
not be implemented before MVP basics work.

## Full Feature Inventory

Core/free-like features:

- Instant app switching with right Command plus first app letter.
- Launch app when it is not already running.
- Dynamic app-to-key assignment.
- Custom key assignment with right Command + right Option + letter.
- Avoid conflicts with normal left Command shortcuts.
- Cycle same-letter apps/windows with Tab.
- Replace Cmd-Tab with an app/window switcher.
- Cmd-backtick same-app window cycling.
- Numbered Space navigation.
- Adjacent Space navigation with `[` and `]`.
- On-screen key hints / OSD.
- Themes and customization.
- Keylume-like on-screen keyboard for current bindings.
- Settings UI.
- First-run onboarding.
- Logging and diagnostics.

Advanced/Pro-like features:

- Fuzzy search across apps and windows.
- Double-tap trigger for open-window-only search.
- Close, quit, or hide search results from the switcher.
- Instant Space switching without the standard macOS slide animation.
- Stages: save, restore, activate, and close groups of apps/windows.
- Window jumping with right Option + letter.
- Move focused window to another Space with right Option + digit.
- Mouse follows focused app.
- Command-line tool with JSON output.
- YAML config import/export.
- Trial and license gating.

## Milestones

### Milestone 0: Bootstrap

Goal: create a buildable native macOS project.

Tasks:

- Create Swift macOS app project.
- Configure menu bar only behavior.
- Add a minimal Settings window.
- Add logging.
- Add basic unit test target.
- Add CI for branch pushes and pull requests.
- Add tag-driven release publishing.

Acceptance criteria:

- App builds locally.
- App launches as a menu bar utility.
- Settings can be opened from the menu bar.
- Branch pushes run build/test CI.
- Version tags publish a GitHub Release artifact.

### Milestone 1: Permissions and Event Tap

Goal: validate global keyboard capture.

Tasks:

- Detect Accessibility permission.
- Show onboarding if permission is missing.
- Install `CGEventTap`.
- Log key down/up events.
- Distinguish right Command from left Command.
- Ensure left Command shortcuts keep working.

Acceptance criteria:

- Pressing right Command can be detected.
- Pressing left Command is ignored by app-specific switching logic.
- App handles permission denial gracefully.

### Milestone 2: App Switching MVP

Goal: switch and launch apps with right Command + letter.

Tasks:

- Build `AppRegistry` from installed and running apps.
- Assign letters dynamically.
- Focus running apps by bundle identifier or process id.
- Launch apps through `NSWorkspace`.
- Add manual assignments.
- Persist assignments.

Acceptance criteria:

- `right cmd + S` can focus or launch Safari if assigned.
- Dynamic assignment works for common apps.
- Manual assignment survives app restart.

### Milestone 3: OSD and Settings

Goal: provide visible feedback and basic configuration.

Tasks:

- Create non-activating OSD window.
- Show current key assignments while trigger is held.
- Add Settings UI for trigger behavior and assignments.
- Add ignored apps list.
- Write config as YAML.

Acceptance criteria:

- Holding right Command displays a compact OSD.
- Settings can edit assignments.
- Config file is readable and stable.

### Milestone 4: Window Foundation

Goal: build the data model needed for Cmd-Tab and future window features.

Tasks:

- Read windows via Accessibility API.
- Track window title, owning app, minimized state, bounds, screen, and focus
  time.
- Add AX observers where practical.
- Keep blocking Accessibility calls off the main thread.

Acceptance criteria:

- App can list visible windows for running apps.
- Window focus metadata updates as user switches apps.
- Frozen or busy apps do not hang the switcher.

### Milestone 5: Cmd-Tab Replacement

Goal: implement keyboard window cycling.

Tasks:

- Intercept Cmd-Tab and Cmd-backtick.
- Cycle windows by MRU order.
- Add same-app cycling.
- Add OSD list for cycling.
- Support typing to filter while cycling.

Acceptance criteria:

- Fast tap switches immediately.
- Holding modifier shows OSD.
- Typing filters windows by app name or title.

### Milestone 6: Search

Goal: add fuzzy search across apps and windows.

Tasks:

- Implement ranked fuzzy matcher.
- Search installed apps, running apps, and open windows.
- Remember selected result per query.
- Add close/quit/hide actions for hovered results.

Acceptance criteria:

- Holding trigger and typing finds apps/windows quickly.
- Repeated queries prefer previously selected results.

### Milestone 7: Spaces

Goal: add Space-aware behavior.

Tasks:

- Implement numbered Space switching.
- Implement adjacent Space switching.
- Add menu bar Space indicators.
- Experiment with instant switching.
- Implement moving windows to Spaces.

Risks:

- macOS does not provide a stable public Spaces API.
- Some behavior may require private APIs, Mission Control automation, or
  brittle workarounds.
- This code must be isolated behind a `SpacesController` abstraction.

Acceptance criteria:

- Basic Space switching works on supported macOS versions.
- Failure modes are visible and recoverable.

### Milestone 8: Stages

Goal: save and restore workspaces.

Tasks:

- Save visible windows into a Stage.
- Store app identity, title, bounds, screen, and reopen target when available.
- Restore apps/windows.
- Activate a Stage by bringing its windows forward.
- Close/minimize/offscreen Stage windows.
- Add Stage editor.

Risks:

- Many apps do not expose enough state to reopen exact documents, tabs, or
  project folders.
- App-specific adapters may be required for Safari, Terminal, VS Code, etc.

Acceptance criteria:

- A simple Stage with Safari, Terminal, and Finder can be saved and restored.

### Milestone 9: CLI and Advanced Features

Goal: make the app scriptable and polish Pro-like workflows.

Tasks:

- Add local control server through XPC or Unix domain socket.
- Add CLI commands:
  - `rcmd status`
  - `rcmd app focus safari`
  - `rcmd window place left-half`
  - `rcmd stage activate w`
  - `rcmd space switch 3`
- Add `--json` output.
- Add config import/export.
- Add mouse-follow behavior.

Acceptance criteria:

- CLI can drive the running app.
- JSON output is stable enough for scripts.

## Key Engineering Risks

1. Right/left modifier detection can be keyboard-layout and hardware dependent.
2. Accessibility APIs are asynchronous in practice and can stall on broken apps.
3. Spaces are not officially supported by public macOS APIs.
4. Capturing Cmd-Tab-like behavior may conflict with user expectations and
   system security behavior.
5. Restoring exact app/window state is app-specific.
6. Sandboxing may block required functionality; early builds should not be
   sandboxed until capabilities are proven.

## Implementation Guidance for Future AI Agents

When continuing this project:

- First read this file and `README.md`.
- Check `git status --short` before edits.
- Do not start with Spaces or Stages.
- Build the MVP in small verifiable increments.
- Keep macOS integration modules isolated behind protocols or narrow classes.
- Prefer native Swift/AppKit/SwiftUI APIs before introducing dependencies.
- Use `apply_patch` for manual edits.
- Do not revert user changes.
- After code exists, run the smallest relevant build/test command before
  reporting completion.

Recommended next action:

1. Broaden config parsing if more YAML settings are introduced.
2. Add tests once a usable XCTest/Swift Testing toolchain is available.
3. Start window foundation only after MVP app switching feels stable.
4. Create an Xcode project or app bundle when packaging becomes necessary.

## Definition of Done for MVP v0.1

MVP v0.1 is done when:

- App builds and launches on macOS.
- App lives in the menu bar.
- User can grant Accessibility permission.
- Holding right Command opens a simple OSD.
- Pressing right Command + assigned letter focuses or launches an app.
- Manual assignments persist across restart.
- Config is saved as YAML.
- README explains how to build and run locally.
