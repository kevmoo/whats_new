# `whats_new`

Deterministic weekly "What's New" harvester CLI and co-located Agent Skill
([`skills/whats-new/SKILL.md`](skills/whats-new/SKILL.md)) for the Dart
ecosystem.

## Features

- **`pub.dev` Publisher Harvester**: Queries `pub.dev` publishers (`dart.dev`,
  `tools.dart.dev`, `labs.dart.dev`) using the server-side `updated:<N>d`
  fast-path, separates **🆕 New Packages** from **📦 Updated Packages**, and
  slices the matching `## <version>` release notes from each package's GitHub
  `CHANGELOG.md`.
- **Dart SDK Dual-Stream Analyzer (`dart-lang/sdk`)**:
  - **Next Stable (`main`)**: Diffs `CHANGELOG.md` over the window to extract
    newly added `### Language`, `### Libraries` (`dart:js_interop`, `dart:ffi`,
    `dart:typed_data`), and `### Tools` entries alongside the commits and issues
    that introduced them.
  - **Stable & Beta Dot Releases (`stable` / `beta`)**: Surfaces branch commits
    and linked cherry-pick (`[cp]`) issues.
- **Batched GitHub PR Harvester & Notability Scorer**: Queries merged human PRs
  across `dart-lang/*` and `googleapis/google-cloud-dart`, ranks them using Loïc
  Sharma's deterministic notability score (reactions, embedded media, `P0`–`P3`
  labels, diff size), extracts `Co-authored-by:` attributions and visual media
  URLs, cancels out reverted PRs, and highlights **🎉 First-Time Contributors**.

## Usage

```bash
# Run a 7-day harvest and print the Markdown digest
dart bin/whats_new.dart --days 7

# Run for an explicit UTC date range and write to a file
dart bin/whats_new.dart --since 2026-09-12 --until 2026-09-19 -o digest.md

# Emit structured JSON
dart bin/whats_new.dart --days 7 --format json
```

## Install Globally

```bash
dart install . --overwrite
```
