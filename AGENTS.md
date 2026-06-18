# Agent Instructions

This repository is for a native macOS app inspired by rcmd: fast keyboard
switching for apps, windows, Spaces, and saved workspaces.

## Read First

Before making changes, read:

1. `PROJECT_PLAN.md` - primary product plan, milestones, risks, and MVP scope.
2. `README.md` - short project entry point.

`PROJECT_PLAN.md` is the source of truth for what is planned, what is done, and
what should happen next.

## Current State

The project is in MVP/window-foundation development. The bootstrap shell and
core app-switching loop are implemented; current work is focused on making
window search/cycling feel fast, predictable, and native.

Implemented:

- SwiftPM package;
- native macOS menu bar app shell;
- Settings window;
- Accessibility permission status/request helper;
- active `CGEventTap`;
- basic right/left Command key event logging;
- layout-aware key translation for Latin keyboard layouts;
- physical QWERTY fallback for non-Latin keyboard layouts;
- configurable key mapping mode persisted in config;
- optional repeated app shortcut behavior to minimize the active window,
  persisted in config and disabled by default;
- dynamic assignments for running and installed apps;
- `right cmd + letter` focusing or launching assigned apps;
- manual assignment capture with `right cmd + right option + letter`;
- assignment persistence in `~/.config/rcmd/config.yaml`;
- polished OSD overlay with app icons while right Command is held;
- visual assignment editor with app icons in Settings;
- Launch at Login setting through `SMAppService`;
- read-only window diagnostics through Accessibility API;
- minimal `right cmd + tab` window cycling through Accessibility API;
- OSD-integrated `right cmd + space` window search by app name/title;
- window search typing, Backspace, Escape, Enter-to-focus, click selection,
  and Up/Down navigation;
- stable OSD footer search input with smoothed selection and edge scrolling;
- event-tap-driven window search input that preserves system language-switching
  shortcuts;
- `.app` bundle packaging with Info.plist, generated AppIcon.icns, DMG output,
  and ad-hoc signing.

Not implemented:

- Xcode project;
- MRU window cycling, ranked fuzzy search, and dedicated window switcher UI;
- close/quit/hide actions from window search results;
- no tests;
- no Developer ID signing or notarization pipeline.

## Immediate Priority

Continue MVP v0.1 from `PROJECT_PLAN.md`.

The next practical tasks are:

1. improve window search ranking so exact title/app matches and recently active
   windows appear first;
2. add MRU tracking for windows and use it in `right cmd + tab` and search;
3. continue window foundation by adding AX observers or a lightweight refresh
   strategy for window title/focus/order updates;
4. improve config parsing if broader YAML settings are added;
5. add tests once a usable XCTest/Swift Testing toolchain is available;
6. add Developer ID signing/notarization when distribution becomes necessary.

Do not start with Spaces, Stages, licensing, or Cmd-Tab replacement. Those are
later milestones and depend on the app/window foundation.

## Engineering Rules

- Prefer Swift, SwiftUI, AppKit, `CGEventTap`, `NSWorkspace`, and Accessibility
  APIs.
- Keep system integrations isolated behind narrow types or protocols.
- Treat Spaces as high risk because macOS has no stable public Spaces API.
- Keep the first implementation small and verifiable.
- Do not introduce third-party dependencies unless there is a clear need.
- Do not enable sandboxing until required capabilities are proven.
- Use readable YAML config at `~/.config/rcmd/config.yaml` for persistent
  key mapping mode and assignments.

## Workflow Rules

- Run `git status --short` before editing.
- Do not revert user changes.
- Use small, focused commits if committing is requested.
- After code exists, run the smallest relevant build/test command before
  reporting completion.
- Current verification commands are `swift build` and `make package`.
  `swift test` reports no tests because the selected CommandLineTools install
  does not expose a test module.
- Update `PROJECT_PLAN.md` whenever scope, status, or milestone order changes.
- Update this file only for agent workflow rules, not detailed product planning.

## Definition of Done for Bootstrap Work

Bootstrap work is currently done when:

- the app builds locally;
- it launches as a menu bar utility;
- Settings or onboarding can be opened;
- permission state is visible to the user;
- keyboard event logging is implemented enough to validate right Command
  detection.
