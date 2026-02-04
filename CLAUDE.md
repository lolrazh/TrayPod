# TrayPod - iPod Classic Menu Bar Music Controller

## Project Overview
A native macOS menu bar app that replicates the pixel-perfect iPod Classic experience, acting as a remote control for Spotify, Apple Music, and YouTube Music.

## Tech Stack
- **Language:** Swift
- **UI:** SwiftUI
- **Architecture:** MVVM
- **Platform:** macOS 13.0+
- **Music Control:** AppleScript (Spotify), MusicKit (Apple Music planned)

## Project Structure
```
TrayPod/
├── TrayPod.xcodeproj
├── TrayPod/
│   ├── App/
│   │   ├── TrayPodApp.swift          # App entry point
│   │   └── AppDelegate.swift         # Menu bar + popover setup
│   ├── Views/
│   │   ├── iPodView.swift            # Main iPod container
│   │   ├── ScreenView.swift          # LCD screen + menu views
│   │   └── ClickWheelView.swift      # Click wheel with gestures
│   ├── ViewModels/
│   │   ├── iPodViewModel.swift       # Navigation + settings state
│   │   └── PlayerViewModel.swift     # Playback state + control
│   ├── Services/
│   │   ├── MusicServiceProtocol.swift
│   │   └── SpotifyService.swift      # Spotify AppleScript control
│   ├── Models/
│   │   ├── Track.swift, PlayerState.swift
│   │   ├── iPodColor.swift, MenuItem.swift
│   └── Utilities/
│       ├── PersistenceManager.swift  # UserDefaults
│       ├── HapticManager.swift, SoundManager.swift
```

## Build & Run
```bash
cd /Users/lolrazh/Documents/Projects/tray-ipod/TrayPod
xcodebuild -project TrayPod.xcodeproj -scheme TrayPod -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/TrayPod-*/Build/Products/Debug/TrayPod.app
```

---

## Development Milestones

### ✅ Milestone 1: Shell & UI (Complete)
- [x] Menu bar app with NSPopover
- [x] iPod body with screen and click wheel
- [x] 7 color themes (white, silver, black, red, blue, green, pink)
- [x] Navigation system (main menu, settings, now playing)
- [x] Haptic and sound feedback

### ✅ Milestone 2: Click Wheel Interaction (Complete)
- [x] Two-finger trackpad scroll for navigation
- [x] Click zones (Menu/top, Back/left, Forward/right, Play-Pause/bottom)
- [x] Visual press feedback
- [x] System click sounds

### ✅ Milestone 3: Spotify MVP (Complete)
- [x] SpotifyService with AppleScript control
- [x] Real-time track info display
- [x] Play/pause/next/previous controls
- [x] Volume control via wheel scroll on Now Playing
- [x] Progress bar with time display

### ⬜ Milestone 4: Polish & Persistence
- [ ] State persistence (last screen, volume level)
- [ ] Media key capture (keyboard play/pause/skip)
- [ ] Auto-launch option in settings
- [ ] Improved error handling

### ⬜ Milestone 5: Apple Music Integration
- [ ] AppleMusicService via MusicKit
- [ ] MusicKit authorization flow
- [ ] Service auto-detection (which app is playing)

### ⬜ Milestone 6: YouTube Music (Stretch)
- [ ] Research control options (browser automation?)
- [ ] YouTubeMusicService implementation

---

## Key Design Decisions
- **Size:** 350x560 pixels
- **Click Wheel:** Tap zones only (no drag gesture - was unreliable)
- **Scroll:** Two-finger trackpad scroll for menu navigation
- **Volume:** Scroll on Now Playing screen adjusts volume
- **Colors:** User-selectable, persisted in UserDefaults
- **Window:** Floating popover, closes on click outside

## Known Issues / TODO
- AppleScript requires user permission on first use
- No album artwork yet (Spotify API would be needed)
- No seek functionality yet (wheel could scrub progress bar)

## Verification Checklist
1. App appears in menu bar (music note icon)
2. Click icon → iPod popover appears
3. Click outside → popover closes
4. Scroll on wheel → menu items navigate
5. Click zones work (Menu/Back/Forward/Play)
6. Settings → Color → change works
7. Open Spotify, play song → Now Playing shows track
8. Play/Pause button → toggles Spotify
9. Forward/Back → skips tracks
10. Scroll on Now Playing → adjusts volume
