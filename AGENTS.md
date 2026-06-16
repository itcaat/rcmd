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

The project is at the bootstrap stage.

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
- dynamic assignments for running and installed apps;
- `right cmd + letter` focusing or launching assigned apps;
- manual assignment capture with `right cmd + right option + letter`;
- assignment persistence in `~/.config/rcmd/config.yaml`;
- polished OSD overlay while right Command is held;
- visual assignment editor in Settings;
- Launch at Login setting through `SMAppService`;
- `.app` bundle packaging with Info.plist, generated AppIcon.icns, DMG output,
  and ad-hoc signing.

Not implemented:

- Xcode project;
- no tests;
- no Developer ID signing or notarization pipeline.

## Immediate Priority

Start with MVP v0.1 from `PROJECT_PLAN.md`.

The next practical task is to complete the first MVP app-switching loop:

1. improve config parsing if broader YAML settings are added;
2. add tests once a usable XCTest/Swift Testing toolchain is available;
3. start window foundation only after MVP app switching feels stable;
4. add Developer ID signing/notarization when distribution becomes necessary.

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
