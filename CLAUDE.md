# GenEngine iOS agent guide

Read `README.md` and `project.yml` before changing code.

## Product intent

GenEngine is a premium interactive-fiction client, not a backend tester. Every change should keep the offline demo navigable and preserve the real GenEngine API path.

## Non-negotiable rules

- Communicate with the maintainer in French; write code, commits, and technical identifiers in English.
- Treat `project.yml` as the Xcode project source of truth. Never hand-edit `project.pbxproj`.
- Keep the application universal for iPhone and iPad.
- Keep fixtures in the demo boundary; never silently replace a failed production response with mock data.
- Keep Authoring imports, raw logs, and endpoint editing behind `#if DEBUG`.
- Never commit credentials, tokens, machine IP addresses, signing teams, or generated user data.
- Do not weaken App Transport Security globally.
- Preserve Dynamic Type, VoiceOver labels, contrast, Reduce Motion behavior, and minimum touch targets.
- Prefer SwiftUI, Observation, structured concurrency, value types, and protocol-backed dependencies.

## Validation

After changing sources:

1. Run `xcodegen generate`.
2. Build the `GenEngine` scheme for a generic iOS Simulator.
3. Run `GenEngineTests` when a simulator runtime is available.
4. Check `git status` and ensure generated projects and user data are not staged.

## Visual direction

Use midnight ink surfaces, ember/amber actions, verdigris accents, and warm ivory text. Narrative content uses a serif design; controls use the system design. Use system glass sparingly for navigation chrome and preserve a calm, readable story canvas.
