# Android flavors

Android flavor setup is plain Gradle text editing — safe to do directly, no
special tooling needed. `flutter build`/`flutter run --flavor <name>` maps
1:1 to a Gradle `productFlavor` of the same name; the names must match
exactly (case-sensitive).

## 1. Locate the build file

Check for either `android/app/build.gradle` (Groovy) or
`android/app/build.gradle.kts` (Kotlin DSL) — modern `flutter create` output
defaults to Kotlin DSL since Flutter 3.19+. Find the existing `android {}`
block and the current `defaultConfig { applicationId "..." }` — that
`applicationId` is the base package name flavors will suffix.

## 2. Add flavorDimensions + productFlavors

**Groovy (`build.gradle`):**
```groovy
android {
    // ...existing config...

    flavorDimensions "flavor-type"
    productFlavors {
        dev {
            dimension "flavor-type"
            resValue "string", "app_name", "MyApp Dev"
            applicationIdSuffix ".dev"
            versionNameSuffix "-dev"
        }
        stage {
            dimension "flavor-type"
            resValue "string", "app_name", "MyApp Staging"
            applicationIdSuffix ".staging"
            versionNameSuffix "-staging"
        }
        prod {
            dimension "flavor-type"
            resValue "string", "app_name", "MyApp"
            // no suffix — prod keeps the base applicationId, this is the
            // one that ships to the store under the original package name
        }
    }
}
```

**Kotlin DSL (`build.gradle.kts`):**
```kotlin
android {
    // ...existing config...

    flavorDimensions += "flavor-type"
    productFlavors {
        create("dev") {
            dimension = "flavor-type"
            resValue(type = "string", name = "app_name", value = "MyApp Dev")
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
        }
        create("stage") {
            dimension = "flavor-type"
            resValue(type = "string", name = "app_name", value = "MyApp Staging")
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-staging"
        }
        create("prod") {
            dimension = "flavor-type"
            resValue(type = "string", name = "app_name", value = "MyApp")
        }
    }
}
```

Generate one flavor block per name the user asked for, following this
pattern — don't hardcode dev/stage/prod if the user named different
flavors.

## 3. Point the app label at the flavor's resValue

In `android/app/src/main/AndroidManifest.xml`, the `<application>` tag
should read `android:label="@string/app_name"` (not a hardcoded string). If
it's currently hardcoded, change it to `@string/app_name` — each flavor's
`resValue "string" "app_name" ...` then supplies the right value at build
time automatically. No per-flavor manifest file needed for this.

## 4. Per-flavor Firebase config (only if the project uses Firebase)

If `android/app/google-services.json` exists (or the Google Services Gradle
plugin is applied), Android supports one config file per flavor via
source-set convention — no extra Gradle wiring required:

```
android/app/src/dev/google-services.json
android/app/src/stage/google-services.json
android/app/src/prod/google-services.json
```

The Google Services plugin auto-selects the file under `src/<flavor>/`
matching the active build flavor. Ask the user for each flavor's Firebase
project config, or leave a `TODO` placeholder file and tell them explicitly
what's missing — don't fabricate credentials.

## 5. Per-flavor app icon (optional, only if requested)

If the user wants distinct launcher icons per flavor, Android supports
source-set-scoped resources the same way as the Firebase config:
`android/app/src/<flavor>/res/mipmap-*/ic_launcher.png` overrides the
shared one in `src/main/res/`. Only do this if asked — it's easy to add
later and shouldn't block the core flavor setup.

## 6. Verify

```bash
flutter build apk --flavor <flavor> --debug -t lib/main_<flavor>.dart
```
for each flavor, or use the generated run script's `build apk <flavor>`
command. A successful build with no Gradle "flavor not found" error
confirms the flavor name threading (Gradle ↔ `--flavor` ↔ entrypoint) is
correct.

## Common mistakes to avoid

- Flavor name containing a hyphen or starting with a digit — Gradle turns
  the flavor name into a Kotlin/Groovy identifier internally (e.g. via
  `create("dev-qa")` is fine in Kotlin DSL but breaks Groovy's
  `devqa { }` block-name syntax). Stick to lowercase letters/digits only
  (`dev`, `stage`, `prod`, `qa`, `uat`) so the same flavor name works
  everywhere without special-casing.
- Forgetting `dimension "flavor-type"` inside a flavor block — Gradle
  requires every flavor to declare which dimension it belongs to once
  `flavorDimensions` is non-empty.
- Giving `prod` an `applicationIdSuffix` — this changes the package name
  that ships to the Play Store away from the one already registered there.
  Only add a suffix to non-production flavors so they can be installed
  side-by-side with the production app.
