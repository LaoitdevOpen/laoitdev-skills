---
name: flutter-flavors
description: Sets up or extends Flutter build flavors (dev/stage/prod, or any number/names of environments) with per-flavor environment config loading, across Android, iOS, and Web. Use this whenever the user wants to separate a Flutter app into multiple environments/build variants, add a new flavor (dev/staging/prod/qa/uat/whatever they call it) to an existing app, wire up per-environment API URLs or config, get `flutter run --flavor` / `flutter build --flavor` working, give each environment a distinct app icon/name/bundle id, or asks for "white-label" style environment separation. Trigger even if they don't say the word "flavor" — phrases like "I need a staging build", "different API URL for dev vs prod", "separate environments for this app", or "add a QA build variant" all mean this skill applies.
---

# Flutter flavors

A "flavor" is really one string (`dev`, `stage`, `prod`, or whatever the
user names it) that has to thread identically through five independent
places: an env file, a Dart entrypoint, a CLI flag, an Android product
flavor, and an iOS scheme. Nothing here is conceptually hard — the
difficulty is that native tooling (Xcode especially) doesn't unify these
automatically, so the config drifts easily if built by hand piecemeal. This
skill sets up all five in one consistent pass, so the user gets `./run.sh
run dev` (or whatever they name the script) working across every platform
they care about.

Everything this skill generates is generic — no assumption about state
management, DI framework, or backend. Adapt the templates to whatever
patterns already exist in the target project (if it uses GetX/Riverpod/Bloc,
Firebase, a `get_it` DI container, etc., wire the bootstrap step into that
instead of inventing a new pattern).

## Step 0 — Gather requirements

Don't guess silently on anything load-bearing. Ask (batch into one
question round if the user hasn't already answered):

- **Flavor names/count.** Default to `dev`, `stage`, `prod` if the user
  says "separate this into environments" without naming them. If they name
  specific flavors (e.g. `qa`, `uat`, `demo`), use exactly those. Flavor
  names must be lowercase letters/digits only (no hyphens, spaces, or
  leading digits) — see the "Common mistakes" note in
  `references/android-flavors.md` for why.
- **Platforms.** Auto-detect by checking which of `android/`, `ios/`,
  `web/` exist in the project root — don't ask about platforms the project
  doesn't have. If more than one exists, confirm whether the user wants
  all of them flavored or just specific ones.
- **App identity per flavor.** Base package name / bundle ID (read the
  current `applicationId` from `android/app/build.gradle*` and
  `PRODUCT_BUNDLE_IDENTIFIER` from the iOS project if they already exist —
  otherwise ask), and a display-name suffix per non-prod flavor (e.g.
  "MyApp Dev", "MyApp Staging").
- **Firebase or other native per-flavor service config.** If the project
  already depends on Firebase (check `pubspec.yaml` and for an existing
  `google-services.json`/`GoogleService-Info.plist`), ask whether each
  flavor needs its own Firebase project, and get those config files from
  the user rather than fabricating them.
- **Run/build script name.** Default `app.sh` if nothing exists already;
  don't silently overwrite an existing script with different behavior —
  read it first if one's already there (it may already partially implement
  flavors) and extend it rather than replacing it wholesale.

## Step 1 — Environment files

Create `config/<flavor>.env` per flavor: plain `KEY=value` shell syntax
(not JSON — this keeps compatibility with any Flutter/Dart SDK version,
supports comments, and is what the auto-forwarding trick in Step 4 relies
on), every key prefixed `FLUTTER_`. The prefix is load-bearing: the
generated script auto-forwards every `FLUTTER_*` shell variable as a
`--dart-define` without needing a separate maintained key list.

```
FLUTTER_ENV_NAME=development
FLUTTER_APP_NAME="MyApp Dev"
FLUTTER_API_URL=https://api-dev.example.com
```

Add `/config` to `.gitignore` (or confirm it's already covered) — these
files commonly carry API keys and shouldn't be committed.

## Step 2 — Dart environment accessor

Create/update `lib/environment.dart` using
`templates/environment.dart.template` as a starting point: one `static
String.fromEnvironment('FLUTTER_X')` getter per key defined across the
`.env` files. Getter names and dart-define keys must match exactly. If
`lib/environment.dart` already exists (partial flavor setup in progress),
extend it — add missing getters, don't regenerate and lose existing ones.

## Step 3 — Entrypoints

Prefer a **shared bootstrap** over N copy-pasted `main_<flavor>.dart`
files: use `templates/bootstrap.dart.template` for a `lib/bootstrap.dart`
with the app's actual startup sequence (DI, crash reporting, etc — inspect
the existing `lib/main.dart` if one exists and move its contents here),
then `templates/main_flavor.dart.template` for each thin
`lib/main_<flavor>.dart`. This is a deliberate improvement over hand-copying
a full main() per flavor — N copies of startup code drift silently when
someone updates one flavor's entrypoint and forgets the others; a shared
bootstrap makes that class of bug impossible. If the project already has
per-flavor entrypoints with real divergence between them (not just
copy-paste), read them first and preserve the actual per-flavor
differences inside `bootstrap()` (e.g. `if (Environment.envName ==
EnvName.development) { ... }`) rather than silently dropping them.

If `lib/main.dart` is being removed in favor of per-flavor entrypoints,
grep the project for anything that still imports it (commonly
`test/widget_test.dart` in a freshly-created Flutter project) and update
those imports to point at the new shared widget/app file instead — a
default `flutter test`/`flutter analyze` will fail otherwise with a
missing-target-of-URI error, not something a build-only check would catch.

## Step 4 — Run/build script

Generate the script from `templates/run.sh.template`, filling in the
script name and flavor list, and `chmod +x` it. This is the single command
surface the user interacts with (`./<script>.sh run dev`, `./<script>.sh
build apk prod`) — everything upstream (env files, entrypoints) exists to
serve this. If a `web/<flavor>/` directory pattern is used for runtime web
config (Step 7), make sure the script's web run/build path includes the
copy step.

## Step 5 — Android

Read `references/android-flavors.md` and apply it directly — it's plain
Gradle text editing (Groovy or Kotlin DSL depending on what the project
already uses), safe to do without extra tooling.

## Step 6 — iOS

Read `references/ios-flavors.md`. This is the platform most likely to go
wrong if rushed — prefer the `flutter_flavorizr`-automated path it
describes over hand-editing `project.pbxproj`, since the automated path
uses the same underlying library (`xcodeproj` Ruby gem) that Xcode itself
relies on to keep the project file internally consistent. Only fall back
to the manual steps if flavorizr genuinely isn't available.

## Step 7 — Web

Read `references/web-flavors.md`. Usually just the entrypoint +
dart-defines from Steps 1–4; only add the runtime-config-copy pattern if
the project has something that needs runtime (not compile-time) config,
like the Firebase web SDK.

## Step 8 — Verify

Don't declare the setup done without building. For every platform the
project targets, run each flavor through the generated script (or the
equivalent raw `flutter build`/`flutter run` command) and confirm success:

```bash
./<script>.sh build apk <flavor>       # per Android flavor
./<script>.sh build ipa <flavor>       # per iOS flavor, needs --no-codesign in CI/non-interactive contexts
./<script>.sh build web <flavor>       # per web flavor
```

A flavor that fails to build here means the name didn't thread through
correctly somewhere (env file name, entrypoint filename, Gradle flavor
name, or iOS scheme name mismatch) — go back to whichever step introduced
the flavor for the failing platform, don't just retry blindly.

## Step 9 — Summary

Tell the user exactly what was created/modified (env files, entrypoints,
Gradle/Xcode changes, the run script), which flavors are ready to use on
which platforms, and anything still needing their input (e.g. Firebase
config files you asked for but didn't receive, or a per-flavor app icon
they didn't request but might want).
