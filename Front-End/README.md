# Octopus POS — Flutter client

The touch POS client. Builds to a Windows `.exe` (installed by an Inno Setup
installer), an Android `.apk`, and a macOS `.app` shipped in a `.dmg`.

## Releasing

Both desktop installers come from **one tag**. Everything runs in GitHub
Actions — you never need a Mac to produce the macOS build.

1. Bump `version:` in `pubspec.yaml` (this file is the single source of truth —
   the installers, the About tab and the in-app updater all read it).
2. Commit, then tag and push:

   ```
   git tag v1.2.3
   git push origin v1.2.3
   ```

3. Two workflows fire on that tag:
   * `release-windows.yml` — `windows-latest`: builds, runs `flutter analyze`
     and `flutter test`, packages `octopus_setup.iss` with Inno Setup, and
     writes the Release body.
   * `release-macos.yml` — `macos-latest`: builds the `.app` and packages it
     into a drag-to-Applications DMG.

   The tag must match `pubspec.yaml` exactly or both fail on purpose.

4. Download the `.exe` / `.dmg` from the GitHub Release.

`workflow_dispatch` runs either workflow without publishing — the installer
comes out as a build artifact instead. Use that to test a pipeline change.

### Why macOS needs the runner

`flutter build macos` requires Xcode, Apple's SDK and `codesign`, none of which
exist on Windows — there is no cross-compiler, and Flutter refuses to run on a
non-Mac host. The macOS runner is the build Mac.

### Gatekeeper

The macOS build is signed **ad-hoc**, not with an Apple Developer ID, so a
downloaded DMG is quarantined and the first launch is blocked. Clear it once per
machine:

```
xattr -dr com.apple.quarantine "/Applications/Octopus POS.app"
```

To remove that step for end users you need an Apple Developer account, a
Developer ID Application certificate, and `codesign` + `notarytool` +
`stapler` steps added to `release-macos.yml` (certificate and app-specific
password stored as repository secrets).

### What the macOS build does not have

`update_service` (in-app updater), the serial weighing scale and the VFD
customer display are Windows-only and are gated off at runtime. Install a new
macOS version by dragging the next DMG over the old app.

## Development

```
flutter pub get
flutter run -d windows      # or -d macos, or an Android device
flutter analyze lib test
flutter test
```
