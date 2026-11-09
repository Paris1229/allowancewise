# AllowanceWise

AllowanceWise is a Flutter app for tracking a weekly allowance and expenses. It
stores data locally on the device and supports light and dark themes.

## Download for Android

Open the repository's **Releases** page and download the APK attached to the
latest release. On Android, open the downloaded APK to install it. Android may
ask you to allow installation from your browser or file manager.

## Build locally

From the project root:

```powershell
flutter pub get
flutter build apk --release
```

The APK is written to
`build/app/outputs/flutter-apk/app-release.apk`.

## Publish a downloadable release

After pushing the project to GitHub, create and push a version tag:

```powershell
git tag v1.0.0
git push origin v1.0.0
```

The GitHub Actions workflow builds the Android APK and attaches it to a GitHub
Release for that tag. Update the version in `pubspec.yaml` before creating later
release tags.

> The current Android release configuration uses the default debug signing
> key. This APK is suitable for testing and direct download, but configure a
> private release signing key before distributing production updates or
> publishing to Google Play. Never commit signing keys or passwords.
