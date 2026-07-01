# Web flavors

Flutter web has no native flavor mechanism — there's no `--flavor` flag
for `flutter run -d chrome` / `flutter build web`, and no build-variant
system like Gradle's. "Flavors" on web reduce to two things:

1. **Which entrypoint compiles** — pass `-t lib/main_<flavor>.dart`, same
   as mobile.
2. **Which dart-defines get baked in** — same `--dart-define` flags loaded
   from `config/<flavor>.env`, same as mobile.

That's sufficient for anything read via `String.fromEnvironment()` (API
URLs, feature flags, app display name, etc). No extra platform-specific
work is needed for those.

## Runtime-loaded config (e.g. Firebase web SDK)

Some services can't be configured purely through compile-time dart-defines
— Firebase's web SDK, for example, expects its config as a JS/JSON object
initialized at runtime, not baked into the compiled bundle. For anything
like that, the pattern is:

1. Store one config file per flavor: `web/<flavor>/firebase_config.json`
   (or whatever the service's config format is).
2. Before `flutter run -d chrome` / `flutter build web`, copy the active
   flavor's file into the path the app actually reads at runtime:
   ```bash
   cp web/<flavor>/firebase_config.json web/firebase_config.json
   ```
   (the generated run script does this automatically if a
   `web/<flavor>/` directory exists — see `templates/run.sh.template`).
3. In Dart, fetch and parse it at startup, e.g.:
   ```dart
   final configJson = await html.HttpRequest.getString('firebase_config.json');
   final config = json.decode(configJson);
   // pass config values into the service's initialization call
   ```

Only add this step if the project actually has a service that needs
runtime (not compile-time) config — most projects don't, and
`String.fromEnvironment()` dart-defines cover everything else.

## Shared web assets

`web/index.html`, favicon, and `web/manifest.json` are typically shared
across all flavors (a web app doesn't install as a separate icon on a home
screen the way mobile apps do, so there's usually no need for a distinct
icon/name per flavor). Only fork these per-flavor if the user explicitly
asks for it — e.g. a different page `<title>` or favicon to visually tell
a staging tab apart from production in a browser.

## Keep each flavor's build output separate

`flutter build web` always writes to `build/web` unless told otherwise —
building `prod` right after `dev` silently overwrites the dev output. If
the user might build/deploy more than one flavor's web output side by side
(e.g. deploying a staging site alongside production), pass `-o
build/web/<flavor>` so each flavor lands in its own directory:
```bash
flutter build web "${DART_DEFINES[@]}" -t "lib/main_${flavor}.dart" -o "build/web/${flavor}"
```

## Verify

```bash
flutter build web --dart-define=FLUTTER_ENV_NAME=<flavor> ... -t lib/main_<flavor>.dart
```
or via the generated script: `./<script>.sh build web <flavor>`. A
successful build with the correct entrypoint compiled confirms the setup.
