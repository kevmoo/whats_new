# Selection Rubric for Dart "What's New"

Use this rubric during Stage 1 to distill the deterministic `whats_new` CLI
digest into 5–10 high-signal items.

## 1. Prioritize (High Signal)

- **Brand-New Packages (`0.1.0` / `1.0.0`)**: Any newly published package under
  `dart.dev`, `tools.dart.dev`, or `labs.dart.dev`, or a package reaching its
  `1.0.0` milestone.
- **Major & Minor Package Feature Releases**: `pub.dev` updates whose extracted
  `CHANGELOG.md` section introduces new APIs, CLI flags, performance speedups,
  or platform support.
- **Dart SDK Next-Stable Additions (`main` `CHANGELOG.md`)**:
  - Language features and spec evolutions (`dart-lang/language`).
  - Core library additions (`dart:js_interop`, `dart:ffi`, `dart:typed_data`,
    `dart:io`, `dart:async`).
  - `dart` CLI subcommands, analyzer lints/quick-fixes, and `dart install` /
    native compilation improvements.
- **Dart SDK Dot Releases & Critical Hotfixes (`stable` / `beta`)**:
  - Stable patch tags (`3.x.y`) and cherry-picked (`[cp]`) fixes resolving
    crashes, regressions, or OS/toolchain incompatibilities.
- **High-Scoring Merged PRs & First-Time Contributors**:
  - Merged PRs with high deterministic `score` (reactions, embedded media demos,
    `P0`–`P2` issue fixes).
  - External community contributors landing their first commit/PR.

## 2. De-Prioritize / Exclude (Noise)

- Routine dependency bumps, constraint widenings (`>=X <Y` with no user-facing
  change), or internal CI workflow tweaks.
- Minor typo fixes or internal-only compiler/VM refactors that do not alter
  developer-facing behavior or performance.
- Changes that were reverted within the same reporting window.
