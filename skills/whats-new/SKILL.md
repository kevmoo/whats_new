---
name: whats-new
description: >-
  Summarizes weekly What's New activity across Dart packages (pub.dev
  publishers), the Dart SDK (next stable CHANGELOG.md diffs and stable/beta
  dot-release hotfixes), and dart-lang/google-cloud-dart GitHub repositories,
  then guides human curation into Notable Commits reports, social media copy
  packs, and video scripts.
---

# Dart Ecosystem "What's New" Skill (`whats-new`)

Guides a 2-stage workflow combining the deterministic `whats_new` harvester CLI
with human editorial selection to produce weekly Dart ecosystem recaps, social
posts (X, Bluesky, LinkedIn), and YouTube video scripts/show notes.

## Stage 1: Deterministic Harvesting & Shortlist Curation

1. **Run the Deterministic Harvester CLI**: Execute `whats_new` over the target
   time window (default: last 7 days):

   ```bash
   dart bin/whats_new.dart --days 7 --output /tmp/whats_new_digest.md
   ```

   _(For custom windows, pass `--since YYYY-MM-DD --until YYYY-MM-DD`.)_

2. **Apply the Selection Rubric
   ([references/rubric.md](references/rubric.md))**: Read
   `/tmp/whats_new_digest.md` and propose a **curated shortlist of 8–16
   highlights** across four streams:
   - **🆕 New & Updated Packages (`pub.dev`)**: Brand-new packages (`0.1.0` /
     `1.0.0`) and significant feature releases across `dart.dev`,
     `tools.dart.dev`, and `labs.dart.dev`.
   - **🎯 Dart SDK Next Stable (`main` `CHANGELOG.md`)**: User-facing additions
     to the language, core libraries (`dart:js_interop`, `dart:ffi`,
     `dart:typed_data`), and CLI/analyzer tooling. Use the per-commit work-back
     metadata (`🛠️ N code/test files` vs. `🧹 CHANGELOG.md-only edit/cleanup`)
     to exclude copy-edits or typo fixes from feature highlights.
   - **🛡️ Dart SDK Stable "Dot" Releases (`stable` / `beta`)**: Patch releases
     and critical `[cp]` cherry-pick bug fixes.
   - **🚀 Notable Merged PRs & 🎉 First-Time Contributors**: High-scoring human
     PRs (`score` ranked by reactions, media demos, `P0`–`P2` labels, and diff
     size) and first-time community contributors.

3. **Standalone Repository-Grouped Atomic Table Artifact & Human Gate
   (`ask_question`)**:
   - Write a **standalone artifact** (`whats_new_recommended_table.md`)
     containing **ONLY** the recommended highlights grouped by **GitHub
     Repository** (`### [org/repo](https://github.com/org/repo)`).
   - Under each repository heading, render a 5-column Markdown table
     (`| Type | Target | Version / Ref | Summary | Author |`).
   - **Strict 1-Item-Per-Row Invariant**: Every table row MUST represent
     **strictly one atomic item** (one package release, one SDK commit, or one
     PR/spec change). **NEVER** merge multiple packages or combine different
     commits/PRs into a single compound row.
   - Present the standalone table and use `ask_question`
     (`is_multi_select: true` or confirmation) so the human can approve, trim,
     or swap rows before drafting Stage 2 copy.

---

## Stage 2: Multi-Format Deliverable Generation

Once the human confirms the highlight selection, generate the requested output
formats using [references/templates.md](references/templates.md):

1. **Weekly "Notable Changes" Markdown Report** (modeled on
   [flutter/flutter#181433](https://github.com/flutter/flutter/issues/181433)):
   - Group into thematic sentence-case `####` headings (`Packages & ecosystem`,
     `Language & core libraries`, `Web & native interop`,
     `Tooling & developer experience`, `First-time contributors`).
   - Include a 1–2 sentence benefit summary ending with 1–2 relevant emojis,
     embedded media links (when present in the digest), and exact
     `Authored by ... and reviewed by ...` attributions.
2. **Social Media Copy Pack (X / Twitter, Bluesky, LinkedIn)**:
   - **Concise Single Post (`<= 280` weighted chars)**: Enforce `t.co` URL
     accounting where every URL counts as **23 characters**
     (`len(non_url_text) + 23 * num_urls <= 280`).
   - **Multi-Post Thread / LinkedIn Summary**: Highlight top 3–5 releases/PRs
     with direct links to `pub.dev` and GitHub.
3. **Video Script & Show Notes Rundown** (modeled on
   [Flutter Notable Commits](https://www.youtube.com/watch?v=auiTKREzsXA)):
   - 15-second cold open hook naming the top 2 headlines.
   - Segment-by-segment talking points with
     `[ON SCREEN: <URL / code snippet / media URL>]` cues.
   - Copy-pasteable YouTube description with chapter timestamps and links.

---

## Mandatory Writing & Data Integrity Guardrails

- **Zero Hallucinated Links or Contributors**: Every version number, PR URL,
  issue number, author handle, and reviewer handle MUST come verbatim from the
  deterministic `whats_new` CLI output.
- **Anti-AI-Slop Style Rules** (adapted from Kate Lovett's release blog guide):
  - **Banned Vocabulary**: Never use `robust`, `seamless`, `elevate`, `unlocks`,
    `empower`, `foundational`, `granular`, `streamline`, `resilient`,
    `paramount`, `tapestry`, `state-of-the-art`, `significantly`, or
    `revolutionary`.
  - **Plain Active Verbs**: Use concrete verbs (`adds`, `fixes`, `supports`,
    `publishes`, `reduces`, `removes`).
  - **No Formulaic Triples or Negative Parallelisms**: Avoid
    `"not only X, but also Y"` and `"X rather than Y"`. Lead every bullet with
    the concrete API, package, or developer benefit.
