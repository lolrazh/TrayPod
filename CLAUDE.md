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
- [ ] Volume level persistence (NOT last screen)
- [ ] Media key capture (keyboard play/pause/skip)
- [ ] Auto-launch option in settings
- [ ] Improved error handling (when Spotify not running)

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
- No seek functionality yet (wheel could scrub progress bar)

---

## Design Principles & Learnings

### Haptic Feedback on macOS

**Key insight:** macOS trackpad haptics via `NSHapticFeedbackManager` are subtle. To make them feel substantial:

1. **Use `.levelChange` not `.generic`** - designed for discrete stepping (like iPod wheel ticks)
2. **Double-tap pattern** - fire 2 haptics 15-20ms apart; they blur into one "thicker" click
3. **Sync with UI** - one haptic per selection change, not continuous on scroll
4. **Timing matters** - haptics must fire within 10-20ms of visual change to feel responsive

**Available patterns:**
| Pattern | Use Case |
|---------|----------|
| `.alignment` | Snapping, dragging items |
| `.levelChange` | Discrete value steps (sliders, pickers, wheels) |
| `.generic` | General fallback |

**What doesn't work on Apple Silicon:**
- Private `MultitouchSupport.framework` APIs (MTActuatorCreateFromDeviceID fails)
- CoreHaptics reports `supportsHaptics: false` on MacBooks (it's for iOS Taptic Engine)

### Spotify Integration on macOS

**Don't poll AppleScript** - it's laggy (200-500ms) and CPU-intensive.

**Use `DistributedNotificationCenter` instead:**
```swift
DistributedNotificationCenter.default().addObserver(
    self,
    selector: #selector(handlePlaybackChange),
    name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
    object: nil
)
```

**Notification userInfo keys:**
- `Player State` → "Playing", "Paused", "Stopped"
- `Name` → Track title
- `Artist`, `Album` → Metadata
- `Duration` → Milliseconds
- `Playback Position` → Seconds

**Architecture pattern:**
- Notifications for state changes (instant)
- Local timer for position interpolation (no AppleScript)
- AppleScript only for commands (play, pause, next, volume)

### Aqua "Glass Tube" Design (iPod 5G Progress/Volume Bar)

**Mental model:** A transparent glass cylinder with colored liquid inside. The 3D belongs to the container, not the fill.

**3-layer hierarchy (bottom to top):**
1. **Track background** — recessed cool gray gradient (the empty tube)
2. **Fill** — flat aqua gradient + soft banding (the liquid — NO 3D on the fill itself)
3. **Glass tube overlay** — full-width transparent white/black overlays (the cylinder illusion)

**Key principles:**
- Highlights/shadows span the **entire bar** (filled + unfilled) — they belong to the glass, not the liquid
- The right edge of the fill has **no shadow/darkening** — it's just where the liquid level ends
- Use only `.opacity()` on white/black — **never** an opaque base `Rectangle()`
- Banding uses high blur (1.2+) for smooth interpolation — sharp bands look wrong

**Glass tube lighting stack (top to bottom of cylinder):**
1. Top edge bright pixel line (`.white.opacity(0.40)`, 0.5px)
2. Top gloss highlight (`.white.opacity(0.60)` → clear, top 45%)
3. Top rim shadow OVER the gloss (`.black.opacity(0.36)` → clear, top 30%, blurred)
4. Equator shadow (`.black.opacity(0.20)`, centered at 54%, blurred)
5. Bottom edge dark pixel line (`.black.opacity(0.10)`, 0.5px)
6. Drop shadow below bar (`.shadow(opacity: 0.24, radius: 4, y: 2)`)

**The rim shadow must render ABOVE the gloss** in the ZStack — otherwise the white gloss drowns it out.

### NSView Coordinate System
- Y increases **upward** (opposite of iOS)
- `location.y > center.y` means **above** center
- Easy to get button zones wrong if you forget this

---

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
