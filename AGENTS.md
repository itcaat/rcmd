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
- listen-only `CGEventTap`;
- basic right/left Command key event logging.

Not implemented:

- app switching;
- dynamic assignments;
- custom assignments;
- OSD;
- YAML config;
- Xcode project;
- no tests;
- no build or release pipeline.

## Immediate Priority

Start with MVP v0.1 from `PROJECT_PLAN.md`.

The next practical task is to turn the keyboard foundation into the first app
switching behavior:

1. track whether right Command is held;
2. map letter key codes to characters;
3. build a minimal `AppRegistry` from running apps;
4. focus one assigned running app with `right cmd + letter`;
5. add a simple on-screen display after the behavior is proven.

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
- Use readable YAML config at `~/.config/rcmd/config.yaml` for planned
  persistent settings.

## Workflow Rules

- Run `git status --short` before editing.
- Do not revert user changes.
- Use small, focused commits if committing is requested.
- After code exists, run the smallest relevant build/test command before
  reporting completion.
- Current verification command is `swift build`. `swift test` reports no tests
  because the selected CommandLineTools install does not expose a test module.
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
