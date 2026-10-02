# Mirai

Mirai is a Flutter anime-streaming app for Android backed by a Cloudflare
Worker (worker8652) that talks to aniwaves.ru. The catalog and playback
resolver live server-side; the app stores its own settings, favorites, and
watch history locally on the device.

## Building

The build runs entirely in GitHub Actions (this sandbox has no Flutter SDK).
Push to `main` and the workflow at `.github/workflows/build.yml` runs
`flutter analyze`, `flutter test`, and builds the release APK, publishing a
pre-release on every merge and a full release for `v*` tags.

Signing environment variables (set on the repo):

```
ANDROID_KEYSTORE_B64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS,
ANDROID_KEY_PASSWORD
```

## Design

"Night broadcast" identity: near-black ink canvas, volt-lime signal accent
(`#C6F84E`), Syne display type, hairline dividers, and an editorial section
tab strip. This deliberately reads differently from Kumi — the two apps share
only the release workflow and the resolve/embed playback strategy.

## Playback

Same sources strategy as Kumi: direct-file sources are preferred, with the
embed as the fallback.

DoodStream (`sv=2`) resolves to a real MP4 via the worker and plays natively
with media_kit. Echovideo and gn1r5n/byse sources can only be handed back as
embed pages; those play in the WebView with the ad-click layer stripped, and
top-level navigation is confined to the known embed hosts. The source
switcher in the player lets you move between the direct player and the embed.

Uses only what the user confirmed or public info.
Version 1.0.0.