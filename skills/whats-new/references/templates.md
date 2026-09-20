# Deliverable Templates (`whats-new`)

## 1. Weekly "Notable Changes" Markdown Report (`#181433` Style)

```markdown
### MMMM DD, YYYY to MMMM DD, YYYY

Brief 2-sentence overview of the week (number of package releases, SDK updates,
and new community contributors).

#### Packages and ecosystem

* **[`package:foo` 1.2.0](https://pub.dev/packages/foo/versions/1.2.0) — Concise title in sentence case**
  Concrete 1–2 sentence summary explaining what the release adds or fixes and
  why it helps developers. 📦✨
  * Repository: [dart-lang/tools](https://github.com/dart-lang/tools)

#### Language and SDK (`next` & `stable`)

* **[dart-lang/sdk#12345](https://github.com/dart-lang/sdk/issues/12345) — Concise title in sentence case**
  Concrete 1–2 sentence summary of the new `dart:*` API, language change, or
  stable dot-release fix. 🎯⚡
  * Authored by [Full Name](https://github.com/login) and reviewed by [Reviewer](https://github.com/reviewer).

#### First-time contributors

Welcome and thank you to our first-time contributors this week:

* [Full Name](https://github.com/login), for [repo#123](https://github.com/org/repo/pull/123), which [concise description of fix/feature].
```

---

## 2. Social Media Copy Pack

### A. Single X / Twitter Post (`<= 280` Weighted Characters)

_Rule_: `Weighted Length = len(non_url_text) + (23 * num_urls) <= 280`.

```text
What's new in the Dart ecosystem this week! 🎯🚀

📦 package:foo 1.2.0: [1-line feature]
⚡ Dart SDK: [1-line SDK/interop addition]
🎉 Welcome to N first-time contributors!

Details: https://pub.dev/packages/foo
```

### B. Multi-Post Thread / LinkedIn & Bluesky Post

```text
Here is what landed across the Dart & pub.dev ecosystem this week (MMM DD – MMM DD):

🆕 Package releases:
• package:foo 1.2.0 — [concrete summary] (https://pub.dev/packages/foo)
• package:bar 0.5.0 — [concrete summary] (https://pub.dev/packages/bar)

🎯 Dart SDK & Language:
• [SDK highlight 1]
• [SDK highlight 2]

🙌 Shoutout to our first-time contributors: @user1, @user2!
```

---

## 3. Video Script & Show Notes Rundown (`Notable Commits` Format)

```markdown
### Video Rundown: Dart What's New (MMM DD, YYYY)

**00:00 — Cold Open Hook (15s)**
* **Spoken**: "This week in Dart: [Headline 1] lands in `package:foo`, plus [Headline 2] in `dart:js_interop`. Let's dive in."
* **[ON SCREEN]**: Title card + quick flash of the top 2 PRs/changelogs.

**00:15 — Segment 1: Package Releases (`pub.dev`)**
* **Spoken**: [2–3 conversational sentences explaining the problem solved and the new API.]
* **[ON SCREEN]**: `https://pub.dev/packages/...` changelog + 5-line code snippet.

**01:15 — Segment 2: Dart SDK & Language Updates**
* **Spoken**: [2–3 conversational sentences covering next-stable or stable dot-release fixes.]
* **[ON SCREEN]**: `dart-lang/sdk` `CHANGELOG.md` diff & linked issue.

**02:15 — Segment 3: Community & First-Time Contributors**
* **Spoken**: "Quick shoutout to our first-time contributors this week..."
* **[ON SCREEN]**: Contributor GitHub profiles and PR titles.

#### YouTube Description & Chapters
00:00 Intro
00:15 Package updates on pub.dev
01:15 Dart SDK & Language changes
02:15 First-time contributors

Links mentioned:
- package:foo: https://pub.dev/packages/foo
```
