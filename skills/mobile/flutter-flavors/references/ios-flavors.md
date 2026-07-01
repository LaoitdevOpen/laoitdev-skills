# iOS flavors

iOS is the hard platform for flavors. Unlike Android, Xcode has no native
"product flavor" concept — the equivalent is assembled out of three
separate pieces that all have to agree by name: an Xcode **scheme**, a set
of flavor-specific **build configurations**, and (for services like
Firebase) a **Run Script build phase** that swaps a resource file in based
on which configuration is active. `project.pbxproj` is Xcode's own
serialization format for all of this — it's technically a plist, but it's
fragile to hand-edit (duplicate/rename the wrong ID and the project stops
opening in Xcode). Prefer the automated path below whenever it's available.

## Option A — automated via flutter_flavorizr (preferred)

Check first: `gem list xcodeproj` (or `gem list -i xcodeproj`). This gem is
what `flutter_flavorizr` shells out to in order to safely mutate
`project.pbxproj` — if it's not installed, either `gem install xcodeproj`
(if the user is fine installing a Ruby gem) or fall back to Option B.

1. Add the dev dependency:
   ```bash
   flutter pub add --dev flutter_flavorizr
   ```
2. Add a `flavorizr:` section to `pubspec.yaml` (top-level key, sibling to
   `flutter:`) — see `templates/flavorizr_pubspec_section.yaml.template`
   for the structure. One entry per flavor, each needs at minimum an
   `app.name` and distinct `android.applicationId` / `ios.bundleId`. If the
   project uses Firebase, add `firebase.config` paths per flavor pointing
   at a `GoogleService-Info.plist` you (or the user) provide — ask for
   these rather than fabricating them.
3. Generate — **always pass an explicit `-p` processor list scoped to
   `ios:*`.** Running flavorizr with no `-p` (or a bare `-p ios`, which
   isn't a valid value — it errors) falls back to its full default
   instruction set, which includes `flutter:main`, `flutter:app`,
   `flutter:pages` — these **overwrite `lib/main.dart`, generate their own
   `lib/app.dart`/`lib/flavors.dart`**, and will clobber the entrypoints
   built in Step 3 of the main skill. Scope it to just the iOS processors:
   ```bash
   flutter pub run flutter_flavorizr -p ios:podfile,ios:xcconfig,ios:buildTargets,ios:schema,ios:plist -f
   ```
   Add `ios:icons`/`ios:launchScreen` only if the user wants per-flavor
   app icons/launch screens too. Verified empirically (flutter_flavorizr
   2.5.0): with this exact processor list, files under `lib/` are left
   completely untouched — only `ios/` changes.
4. This creates, per flavor: an Xcode scheme
   (`ios/Runner.xcodeproj/xcshareddata/xcschemes/<flavor>.xcscheme`) and
   three new build configurations named `Debug-<flavor>`, `Release-<flavor>`,
   `Profile-<flavor>` (confirmed via `xcodebuild -list -project
   Runner.xcodeproj` — note this differs from the `<Flavor>Debug` naming
   used in the manual Option B below; flavorizr's convention is
   authoritative when you're using flavorizr). It also updates
   `ios/Flutter/*.xcconfig` and the Podfile for per-flavor CocoaPods
   target support. Firebase config copying isn't handled by this processor
   set — if the project uses Firebase, still add the Run Script phase from
   B.4 manually (or via Xcode) after running flavorizr.
5. Verify: `flutter build ios --flavor <flavor> --no-codesign -t lib/main_<flavor>.dart`
   for each flavor. A clean build with no "scheme not found" or
   "PRODUCT_BUNDLE_IDENTIFIER" errors confirms it worked.

flutter_flavorizr is idempotent-ish but not perfectly so — re-running it
after manual edits can overwrite them. Once flavors are generated, treat
further tweaks (icons, entitlements) as manual Xcode edits, not
re-generation.

## Option B — manual (no Ruby/xcodeproj gem available)

Do this via Xcode itself where possible rather than hand-editing
`project.pbxproj` text — Xcode keeps the file internally consistent; raw
text edits can silently corrupt it (duplicate object IDs, dangling
references). If Xcode's GUI isn't available in the current environment,
proceed carefully with the text edits below and validate the result with
`plutil -lint ios/Runner.xcodeproj/project.pbxproj` after every change (a
`.pbxproj` is plist format, so `plutil` can catch structural corruption
even though it won't catch scheme/config mismatches).

### B.1 Duplicate build configurations

For each flavor, duplicate the existing `Debug` and `Release`
`XCBuildConfiguration` entries in `project.pbxproj`, renaming the copies
`<Flavor>Debug` / `<Flavor>Release` (e.g. `DevDebug`, `DevRelease`). Each
new config needs its own 24-character hex `isa` object ID (any unused
hex string of the right length/format works — check no other object in the
file already uses it) and must be added to the config's parent
`XCConfigurationList`'s `buildConfigurations` array. In each duplicated
config, override:
```
PRODUCT_BUNDLE_IDENTIFIER = com.example.myapp.dev;
DISPLAY_NAME = "MyApp Dev";
```
(`DISPLAY_NAME` isn't a built-in Xcode setting — it's a custom key you're
defining here so `Info.plist` can reference it; see B.3.)

### B.2 Add a scheme per flavor

Duplicate `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` to
`<flavor>.xcscheme` (plain XML, safe to copy/edit directly — this is much
lower risk than the `.pbxproj` edits above). In the copy, change
`LaunchAction buildConfiguration` and `ArchiveAction buildConfiguration` to
point at the flavor's `<Flavor>Debug` / `<Flavor>Release` configs
respectively (leave `TestAction`/`ProfileAction`/`AnalyzeAction` on the
generic configs unless the project specifically needs flavor-scoped
testing/profiling too). The scheme's **filename** (minus `.xcscheme`) is
what Flutter's `--flavor <name>` looks for — it must match the flavor name
exactly.

### B.3 Wire Info.plist to the per-flavor build settings

In `ios/Runner/Info.plist`, use build-setting indirection instead of
maintaining a separate plist per flavor:
```xml
<key>CFBundleDisplayName</key>
<string>$(DISPLAY_NAME)</string>
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
```
`$(VAR)` is resolved from whichever `XCBuildConfiguration` is active for
the current scheme/configuration — this is the mechanism that makes one
`Info.plist` serve every flavor.

### B.4 Per-flavor Firebase config (only if the project uses Firebase)

Xcode has no source-set convention like Android's `src/<flavor>/` for
resource files, so this is done with a build-time copy step:

1. Create `ios/<flavor>/GoogleService-Info.plist` per flavor (ask the user
   for each one — don't fabricate credentials).
2. Add a **Run Script build phase** to the Runner target (via Xcode, or by
   inserting a `PBXShellScriptBuildPhase` object referenced from the
   target's `buildPhases` array) that runs before "Compile Sources":
   ```bash
   CONFIG="${CONFIGURATION}"
   if [[ "$CONFIG" == "DevDebug" || "$CONFIG" == "DevRelease" ]]; then
     cp -r "${PROJECT_DIR}/dev/GoogleService-Info.plist" "${PROJECT_DIR}/Runner/GoogleService-Info.plist"
   elif [[ "$CONFIG" == "StageDebug" || "$CONFIG" == "StageRelease" ]]; then
     cp -r "${PROJECT_DIR}/stage/GoogleService-Info.plist" "${PROJECT_DIR}/Runner/GoogleService-Info.plist"
   elif [[ "$CONFIG" == "ProdDebug" || "$CONFIG" == "ProdRelease" ]]; then
     cp -r "${PROJECT_DIR}/prod/GoogleService-Info.plist" "${PROJECT_DIR}/Runner/GoogleService-Info.plist"
   fi
   ```
   Generate one `elif` branch per flavor, matching the `<Flavor>Debug`/
   `<Flavor>Release` config names from B.1.

### B.5 Verify

```bash
plutil -lint ios/Runner.xcodeproj/project.pbxproj
flutter build ios --flavor <flavor> --no-codesign -t lib/main_<flavor>.dart
```
for each flavor. If `plutil -lint` reports a syntax error, stop and fix
the `.pbxproj` before attempting a build — Xcode will otherwise fail with
an opaque error or silently ignore the corrupted section.

## Secrets note

Per-flavor `GoogleService-Info.plist` files (and the Android
`google-services.json` equivalents) contain real API keys/project IDs.
Check whether the project's `.gitignore` covers them — a root-level
`ios/Runner/GoogleService-Info.plist` ignore rule does **not** automatically
cover `ios/dev/GoogleService-Info.plist`, `ios/stage/...`, etc. Add
explicit entries for each per-flavor path if they should stay untracked.
