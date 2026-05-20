# TrayPod

TrayPod is a native macOS menu bar app that recreates an iPod Classic-style controller for desktop music apps.

## Canonical Project

Use the nested Xcode project:

```bash
cd /Users/lolrazh/Documents/Projects/tray-ipod/TrayPod
xcodebuild -project TrayPod.xcodeproj -scheme TrayPod -configuration Debug build
```

The root-level `TrayPod.xcodeproj` is an older duplicate and is not the active build target.

## Current Scope

- SwiftUI menu bar popover
- iPod-style screen, wheel, color themes, haptics, and click sound
- Spotify desktop control through AppleScript
- Spotify playback updates from distributed notifications
- Spotify PKCE sign-in using the `traypod://callback` URL scheme
- Spotify library browsing for playlists, albums, artists, and saved tracks
- Spotify Web API playback for signed-in users, with desktop Spotify fallback
- Local progress interpolation and volume control
- Launch-at-login toggle

## Spotify Testing Notes

The Spotify app registration must include this exact redirect URI:

```text
traypod://callback
```

Spotify Web API playback needs a Spotify Premium account and an active Spotify Connect device. If no active device is available, TrayPod opens the Spotify desktop app and falls back to local AppleScript control.

## Next Milestones

1. Add Apple Music support through local Music.app control, then MusicKit where standalone playback or library access is useful.
2. Add onboarding, provider selection, and launch-at-login error polish.
3. Exercise the full sign-in, library browsing, and playback flows on a real Spotify account.
