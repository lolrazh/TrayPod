# TrayPod Spotify Web API Integration Plan

## Overview

Transform TrayPod from a "Spotify remote control" into a standalone iPod experience by adding Spotify Web API library browsing. Users sign in once, then browse playlists/artists/albums/songs through the classic iPod menu hierarchy.

**Two layers:**
- **Browsing layer** (NEW) — Spotify Web API fetches library data via HTTP/JSON
- **Playback layer** (EXISTING) — AppleScript + DistributedNotificationCenter controls Spotify desktop app

The browsing layer tells the playback layer *what* to play.

## Credentials

- **Client ID:** `aea26d100ffd41a592847f9a5350a10d`
- **Redirect URI:** `traypod://callback`
- **Bundle ID:** `com.traypod.app`
- **No client secret** (PKCE flow doesn't need one)

## OAuth Scopes

```
user-library-read
playlist-read-private
playlist-read-collaborative
user-follow-read
user-read-playback-state
user-modify-playback-state
user-read-currently-playing
```

## Build & Validate

```bash
cd /Users/lolrazh/Documents/Projects/tray-ipod/TrayPod
xcodebuild -project TrayPod.xcodeproj -scheme TrayPod -configuration Debug build 2>&1 | tail -5
```

Every milestone MUST pass this build check before moving on.

## Important: Xcode Project File

The project uses **manual file references** in `TrayPod.xcodeproj/project.pbxproj`. Every new `.swift` file must be:
1. Created on disk
2. Added as a `PBXFileReference` entry in pbxproj
3. Added to the appropriate `PBXGroup` (parent folder)
4. Added as a `PBXBuildFile` in the Sources build phase

All source files live under `TrayPod/TrayPod/` (e.g., `TrayPod/TrayPod/Services/SpotifyAuthManager.swift`).

---

## Milestone Dependency Graph

```
A (Auth) → B (API Client) → C (Menu System) → D (Views) + E (Playback)
                                                    ↓           ↓
                                              [PARALLEL - independent of each other]
```

**Execution order:**
1. A → build & verify
2. B → build & verify
3. C → build & verify
4. D + E → **in parallel** (two sub-agents) → build & verify together

---

## Milestone A: Spotify OAuth Authentication

**Goal:** User signs into Spotify from Settings. Tokens stored in Keychain. Auto-refresh.

### A1. Info.plist — Register Custom URL Scheme

Add `CFBundleURLTypes` to `TrayPod/TrayPod/Info.plist` so macOS routes `traypod://callback` to our app:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.traypod.app</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>traypod</string>
        </array>
    </dict>
</array>
```

Also add network entitlement to `TrayPod/TrayPod/TrayPod.entitlements`:
```xml
<key>com.apple.security.network.client</key>
<true/>
```

(Note: Sandbox is already `false`, so outgoing HTTP works without this, but it's good practice.)

### A2. NEW FILE: `TrayPod/TrayPod/Utilities/KeychainHelper.swift`

Simple wrapper for Keychain read/write/delete:

```swift
import Security
import Foundation

enum KeychainHelper {
    static func save(key: String, data: Data) -> Bool
    static func load(key: String) -> Data?
    static func delete(key: String)
}
```

- Uses `kSecClassGenericPassword` with service = `"com.traypod.spotify"`
- Keys: `"access_token"`, `"refresh_token"`, `"token_expiry"`

### A3. NEW FILE: `TrayPod/TrayPod/Services/SpotifyAuthManager.swift`

Singleton `ObservableObject` managing the full OAuth lifecycle.

**Published properties:**
- `isSignedIn: Bool`
- `userName: String?`
- `isAuthenticating: Bool` (for loading state)

**Constants:**
- `clientId = "aea26d100ffd41a592847f9a5350a10d"`
- `redirectURI = "traypod://callback"`
- `scopes` = all 7 scopes listed above
- `tokenURL = "https://accounts.spotify.com/api/token"`
- `authorizeURL = "https://accounts.spotify.com/authorize"`

**PKCE Flow:**
1. `signIn()`:
   - Generate 128-char random `codeVerifier` (A-Za-z0-9-._~)
   - SHA256 hash → base64url encode → `codeChallenge`
   - Build authorize URL with params: `client_id`, `response_type=code`, `redirect_uri`, `scope`, `code_challenge_method=S256`, `code_challenge`
   - Open URL in default browser via `NSWorkspace.shared.open(url)`
   - Store `codeVerifier` in memory (needed for token exchange)

2. `handleCallback(url: URL)`:
   - Extract `code` from URL query params
   - POST to token endpoint with: `grant_type=authorization_code`, `code`, `redirect_uri`, `client_id`, `code_verifier`
   - Parse response: `access_token`, `refresh_token`, `expires_in`
   - Save all three to Keychain
   - Set `isSignedIn = true`
   - Fetch user profile to get `userName`

3. `refreshTokenIfNeeded() async -> String?`:
   - Check if stored token is expired (compare `token_expiry` vs now)
   - If expired, POST to token endpoint with: `grant_type=refresh_token`, `refresh_token`, `client_id`
   - Save new `access_token` and `expires_in` to Keychain
   - Return valid access token

4. `signOut()`:
   - Delete all tokens from Keychain
   - Set `isSignedIn = false`, `userName = nil`

5. `getAccessToken() async -> String?`:
   - If not signed in, return nil
   - Call `refreshTokenIfNeeded()` and return token

**On init:** Check Keychain for existing tokens → set `isSignedIn` accordingly → fetch user profile if signed in.

### A4. MODIFY: `TrayPod/TrayPod/App/AppDelegate.swift`

Add URL handling for OAuth callback:

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    // ... existing code ...

    // Register for URL scheme callbacks
    NSAppleEventManager.shared().setEventHandler(
        self,
        andSelector: #selector(handleURL(_:withReplyEvent:)),
        forEventClass: AEEventClass(kInternetEventClass),
        andEventID: AEEventID(kAEGetURL)
    )
}

@objc func handleURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
    guard let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
          let url = URL(string: urlString) else { return }

    Task {
        await SpotifyAuthManager.shared.handleCallback(url: url)
    }
}
```

### A5. MODIFY: `TrayPod/TrayPod/ViewModels/iPodViewModel.swift`

Add Spotify sign-in/out item to settings menu:

```swift
var settingsMenuItems: [MenuItem] {
    var items = [
        MenuItem(title: "Color", action: .navigate(.colorSelection)),
        MenuItem(title: "Sounds: \(soundEnabled ? "On" : "Off")", action: .custom { [weak self] in
            self?.soundEnabled.toggle()
        }),
        MenuItem(title: "Haptics: \(hapticEnabled ? "On" : "Off")", action: .custom { [weak self] in
            self?.hapticEnabled.toggle()
        })
    ]

    // Spotify sign in/out
    let authManager = SpotifyAuthManager.shared
    if authManager.isSignedIn {
        items.append(MenuItem(title: "Spotify: \(authManager.userName ?? "Connected")", action: .custom {
            authManager.signOut()
        }))
    } else {
        items.append(MenuItem(title: "Spotify: Sign In", action: .custom {
            authManager.signIn()
        }))
    }

    return items
}
```

Also need to observe `SpotifyAuthManager.shared.objectWillChange` to refresh the menu when auth state changes.

### A6. Files Summary

| Action | File | What |
|--------|------|------|
| NEW | `TrayPod/TrayPod/Utilities/KeychainHelper.swift` | Keychain CRUD |
| NEW | `TrayPod/TrayPod/Services/SpotifyAuthManager.swift` | OAuth PKCE + token mgmt |
| MODIFY | `TrayPod/TrayPod/Info.plist` | Add URL scheme |
| MODIFY | `TrayPod/TrayPod/App/AppDelegate.swift` | Handle URL callback |
| MODIFY | `TrayPod/TrayPod/ViewModels/iPodViewModel.swift` | Settings menu sign-in item |
| MODIFY | `TrayPod.xcodeproj/project.pbxproj` | Register new files |

### A7. Verification

1. Build succeeds: `xcodebuild ... build`
2. Settings shows "Spotify: Sign In"
3. Tapping opens browser to Spotify auth page
4. After auth, redirects back → Settings shows "Spotify: [username]"
5. Kill & relaunch → still signed in
6. Tapping signed-in item signs out

---

## Milestone B: Spotify API Client + Data Models

**Goal:** Fetch user's playlists, saved tracks, albums, followed artists from Spotify Web API.

### B1. NEW FILE: `TrayPod/TrayPod/Models/SpotifyModels.swift`

Codable structs mapping Spotify JSON responses:

```swift
// Top-level paginated response wrapper
struct SpotifyPage<T: Codable>: Codable {
    let items: [T]
    let total: Int
    let limit: Int
    let offset: Int
    let next: String?  // URL for next page, nil if last
}

// For the artist "cursor-based" pagination
struct SpotifyArtistPage: Codable {
    let artists: SpotifyArtistCursorPage
}
struct SpotifyArtistCursorPage: Codable {
    let items: [SpotifyArtist]
    let total: Int
    let cursors: SpotifyCursors?
}
struct SpotifyCursors: Codable {
    let after: String?
}

struct SpotifyUser: Codable {
    let id: String
    let displayName: String?
    let images: [SpotifyImage]?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case images
    }
}

struct SpotifyPlaylist: Codable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let tracks: SpotifyPlaylistTrackInfo
    let uri: String

    struct SpotifyPlaylistTrackInfo: Codable {
        let total: Int
    }

    var imageURL: URL? {
        images?.first.flatMap { URL(string: $0.url) }
    }
    var trackCount: Int { tracks.total }
}

struct SpotifyAlbum: Codable, Identifiable {
    let id: String
    let name: String
    let artists: [SpotifySimpleArtist]
    let images: [SpotifyImage]?
    let totalTracks: Int?
    let uri: String

    enum CodingKeys: String, CodingKey {
        case id, name, artists, images, uri
        case totalTracks = "total_tracks"
    }

    var imageURL: URL? {
        images?.first.flatMap { URL(string: $0.url) }
    }
    var artistName: String {
        artists.first?.name ?? "Unknown Artist"
    }
}

// Saved album comes wrapped: { "album": { ... }, "added_at": "..." }
struct SpotifySavedAlbum: Codable {
    let album: SpotifyAlbum
    let addedAt: String?

    enum CodingKeys: String, CodingKey {
        case album
        case addedAt = "added_at"
    }
}

struct SpotifyArtist: Codable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]?
    let uri: String

    var imageURL: URL? {
        images?.first.flatMap { URL(string: $0.url) }
    }
}

struct SpotifySimpleArtist: Codable {
    let id: String?
    let name: String
}

struct SpotifyTrack: Codable, Identifiable {
    let id: String?
    let name: String
    let artists: [SpotifySimpleArtist]
    let album: SpotifyAlbumRef?
    let durationMs: Int
    let uri: String

    enum CodingKeys: String, CodingKey {
        case id, name, artists, album, uri
        case durationMs = "duration_ms"
    }

    var artistName: String {
        artists.map(\.name).joined(separator: ", ")
    }
    var albumName: String {
        album?.name ?? ""
    }
    var duration: TimeInterval {
        TimeInterval(durationMs) / 1000.0
    }
    var imageURL: URL? {
        album?.images?.first.flatMap { URL(string: $0.url) }
    }
}

// Track in a "saved tracks" response comes wrapped
struct SpotifySavedTrack: Codable {
    let track: SpotifyTrack
}

// Track in a playlist response comes wrapped
struct SpotifyPlaylistTrack: Codable {
    let track: SpotifyTrack?  // Can be nil if track was removed
}

struct SpotifyAlbumRef: Codable {
    let id: String?
    let name: String
    let images: [SpotifyImage]?
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

// For top tracks response (not paginated)
struct SpotifyTopTracksResponse: Codable {
    let tracks: [SpotifyTrack]
}
```

### B2. NEW FILE: `TrayPod/TrayPod/Services/SpotifyAPIClient.swift`

Lightweight async HTTP client. No third-party dependencies.

```swift
import Foundation

actor SpotifyAPIClient {
    private let baseURL = "https://api.spotify.com/v1"
    private let authManager: SpotifyAuthManager

    init(authManager: SpotifyAuthManager = .shared)

    // MARK: - Library Endpoints

    func fetchUserProfile() async throws -> SpotifyUser
    func fetchPlaylists(limit: Int = 50) async throws -> [SpotifyPlaylist]
    func fetchPlaylistTracks(playlistId: String, limit: Int = 50) async throws -> [SpotifyTrack]
    func fetchSavedTracks(limit: Int = 50) async throws -> [SpotifyTrack]
    func fetchSavedAlbums(limit: Int = 50) async throws -> [SpotifyAlbum]
    func fetchAlbumTracks(albumId: String) async throws -> [SpotifyTrack]
    func fetchFollowedArtists(limit: Int = 50) async throws -> [SpotifyArtist]
    func fetchArtistTopTracks(artistId: String) async throws -> [SpotifyTrack]

    // MARK: - Internal

    /// Build authenticated request (adds Bearer token)
    private func authenticatedRequest(url: URL) async throws -> URLRequest

    /// Perform request, decode JSON, handle 401 (token refresh + retry once)
    private func perform<T: Codable>(_ request: URLRequest) async throws -> T
}
```

**Key behaviors:**
- Every request calls `authManager.getAccessToken()` for the Bearer token
- If a request returns 401, refresh the token and retry once
- Uses `JSONDecoder` with default settings (Spotify uses snake_case, handled by CodingKeys)
- Errors are typed: `SpotifyAPIError.unauthorized`, `.networkError`, `.decodingError`, `.rateLimited`

### B3. NEW FILE: `TrayPod/TrayPod/Services/SpotifyLibraryManager.swift`

Observable cache layer between API and UI.

```swift
@MainActor
class SpotifyLibraryManager: ObservableObject {
    static let shared = SpotifyLibraryManager()

    @Published var playlists: [SpotifyPlaylist] = []
    @Published var savedTracks: [SpotifyTrack] = []
    @Published var savedAlbums: [SpotifyAlbum] = []
    @Published var followedArtists: [SpotifyArtist] = []
    @Published var isLoading: Bool = false

    // Detail caches (loaded on-demand when user navigates into a playlist/album/artist)
    @Published var playlistTracks: [String: [SpotifyTrack]] = [:]    // playlistId → tracks
    @Published var albumTracks: [String: [SpotifyTrack]] = [:]       // albumId → tracks
    @Published var artistTopTracks: [String: [SpotifyTrack]] = [:]   // artistId → tracks

    private let apiClient = SpotifyAPIClient()
    private var lastFetchTime: Date?
    private let cacheTimeout: TimeInterval = 300  // 5 minutes

    /// Load all top-level library data (called on sign-in and popover open)
    func loadLibrary() async

    /// Load tracks for a specific playlist (lazy, on navigation)
    func loadPlaylistTracks(_ playlistId: String) async

    /// Load tracks for a specific album (lazy, on navigation)
    func loadAlbumTracks(_ albumId: String) async

    /// Load top tracks for a specific artist (lazy, on navigation)
    func loadArtistTopTracks(_ artistId: String) async

    /// Refresh if cache is stale (>5 min)
    func refreshIfNeeded() async

    /// Clear all data (called on sign-out)
    func clear()
}
```

### B4. Files Summary

| Action | File | What |
|--------|------|------|
| NEW | `TrayPod/TrayPod/Models/SpotifyModels.swift` | All Codable API models |
| NEW | `TrayPod/TrayPod/Services/SpotifyAPIClient.swift` | HTTP client |
| NEW | `TrayPod/TrayPod/Services/SpotifyLibraryManager.swift` | Cached library state |
| MODIFY | `TrayPod.xcodeproj/project.pbxproj` | Register new files |

### B5. Verification

1. Build succeeds
2. After sign-in, debug log shows playlists/tracks/albums loading
3. Data matches actual Spotify library (spot-check names and counts)

---

## Milestone C: Menu System Expansion

**Goal:** "Music" on the main menu opens a submenu with Now Playing, Playlists, Artists, Albums, Songs.

### C1. MODIFY: `TrayPod/TrayPod/Models/MenuItem.swift`

Expand `MenuScreen` enum:

```swift
enum MenuScreen: Equatable, Hashable {
    case main
    case nowPlaying
    case settings
    case colorSelection
    // Library screens:
    case musicMenu
    case playlists
    case playlistDetail(id: String, name: String)
    case artists
    case artistDetail(id: String, name: String)
    case albums
    case albumDetail(id: String, name: String)
    case songs
}
```

Add subtitle support to `MenuItem`:

```swift
struct MenuItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String?     // NEW — artist name, track count, etc.
    let icon: String?
    let action: MenuAction

    init(title: String, subtitle: String? = nil, icon: String? = nil, action: MenuAction) { ... }
}
```

Add new action type:

```swift
enum MenuAction: Equatable {
    case navigate(MenuScreen)
    case togglePlayPause
    case playTrack(uri: String, contextURI: String?)  // NEW
    case custom(() -> Void)
    case none
}
```

### C2. MODIFY: `TrayPod/TrayPod/ViewModels/iPodViewModel.swift`

**Change main menu:** "Music" navigates to `.musicMenu` instead of `.nowPlaying`.

**Add new computed menu items:**

```swift
var musicMenuItems: [MenuItem] {
    [
        MenuItem(title: "Now Playing", action: .navigate(.nowPlaying)),
        MenuItem(title: "Playlists", action: .navigate(.playlists)),
        MenuItem(title: "Artists", action: .navigate(.artists)),
        MenuItem(title: "Albums", action: .navigate(.albums)),
        MenuItem(title: "Songs", action: .navigate(.songs)),
    ]
}
```

**Dynamic items from library data:**

```swift
var playlistItems: [MenuItem] {
    guard SpotifyAuthManager.shared.isSignedIn else {
        return [MenuItem(title: "Sign in via Settings", action: .none)]
    }
    let library = SpotifyLibraryManager.shared
    if library.isLoading && library.playlists.isEmpty {
        return [MenuItem(title: "Loading...", action: .none)]
    }
    return library.playlists.map { playlist in
        MenuItem(
            title: playlist.name,
            subtitle: "\(playlist.trackCount) songs",
            action: .navigate(.playlistDetail(id: playlist.id, name: playlist.name))
        )
    }
}
```

Similar computed properties for: `albumItems`, `artistItems`, `songItems`, and detail screens (`playlistDetailItems(id:)`, `albumDetailItems(id:)`, `artistDetailItems(id:)`).

**Update `currentMenuItems`:**

```swift
var currentMenuItems: [MenuItem] {
    switch currentScreen {
    case .main:             return mainMenuItems
    case .settings:         return settingsMenuItems
    case .musicMenu:        return musicMenuItems
    case .playlists:        return playlistItems
    case .playlistDetail(let id, _): return playlistDetailItems(id: id)
    case .artists:          return artistItems
    case .artistDetail(let id, _):   return artistDetailItems(id: id)
    case .albums:           return albumItems
    case .albumDetail(let id, _):    return albumDetailItems(id: id)
    case .songs:            return songItems
    case .nowPlaying, .colorSelection: return []
    }
}
```

**Update `moveSelection`:** Add all new menu-type screens to the existing `case .main, .settings:` branch:
```swift
case .main, .settings, .musicMenu, .playlists, .playlistDetail,
     .artists, .artistDetail, .albums, .albumDetail, .songs:
```

**Update `centerButtonPressed`:** Same — add new cases to the menu branch. Also handle `.playTrack`:
```swift
case .playTrack(let uri, let contextURI):
    playerViewModel.playURI(uri, inContext: contextURI)
    navigateTo(.nowPlaying)
```

**Lazy loading trigger:** When navigating to a detail screen, trigger data fetch if not cached:
```swift
private func navigateTo(_ screen: MenuScreen) {
    // ... existing navigation code ...

    // Trigger lazy loading for detail screens
    Task {
        switch screen {
        case .playlistDetail(let id, _):
            await SpotifyLibraryManager.shared.loadPlaylistTracks(id)
        case .albumDetail(let id, _):
            await SpotifyLibraryManager.shared.loadAlbumTracks(id)
        case .artistDetail(let id, _):
            await SpotifyLibraryManager.shared.loadArtistTopTracks(id)
        case .playlists, .artists, .albums, .songs:
            await SpotifyLibraryManager.shared.refreshIfNeeded()
        default: break
        }
    }
}
```

### C3. MODIFY: `TrayPod/TrayPod/Views/ScreenView.swift`

**Update `screenTitle`:**

```swift
private var screenTitle: String {
    switch viewModel.currentScreen {
    case .main:                        return "iPod"
    case .nowPlaying:                  return "Now Playing"
    case .settings:                    return "Settings"
    case .colorSelection:              return "Color"
    case .musicMenu:                   return "Music"
    case .playlists:                   return "Playlists"
    case .playlistDetail(_, let name): return name
    case .artists:                     return "Artists"
    case .artistDetail(_, let name):   return name
    case .albums:                      return "Albums"
    case .albumDetail(_, let name):    return name
    case .songs:                       return "Songs"
    }
}
```

**Update `screenContent`:** All new menu-type screens use `MenuListView`:

```swift
case .main, .settings, .musicMenu, .playlists, .playlistDetail,
     .artists, .artistDetail, .albums, .albumDetail, .songs:
    MenuListView(viewModel: viewModel)
```

**Update `MenuListView` to render subtitles:**

When `item.subtitle` is non-nil, render it below the title in a smaller, dimmer font:

```swift
VStack(alignment: .leading, spacing: 1) {
    Text(item.title)
        .font(.custom("Helvetica Neue", size: 13).weight(.medium))
    if let subtitle = item.subtitle {
        Text(subtitle)
            .font(.custom("Helvetica Neue", size: 10))
            .opacity(isSelected ? 0.8 : 0.5)
    }
}
```

### C4. Files Summary

| Action | File | What |
|--------|------|------|
| MODIFY | `TrayPod/TrayPod/Models/MenuItem.swift` | Expand MenuScreen, add subtitle, add playTrack action |
| MODIFY | `TrayPod/TrayPod/ViewModels/iPodViewModel.swift` | Dynamic menu items, lazy loading, new screen handling |
| MODIFY | `TrayPod/TrayPod/Views/ScreenView.swift` | New screen titles, subtitle rendering |

### C5. Verification

1. Build succeeds
2. Music → shows submenu (Now Playing, Playlists, Artists, Albums, Songs)
3. Playlists → shows your Spotify playlists with track counts
4. Select a playlist → shows tracks with artist subtitles
5. Artists/Albums/Songs → show correct data
6. Menu button goes back through entire navigation stack correctly
7. Title bar updates for every screen
8. Scroll works on all new screens
9. Not signed in → shows "Sign in via Settings"

---

## Milestone D: Track List View Polish (PARALLEL with E)

**Goal:** Library lists look and feel like the iPod Classic. Loading states are smooth.

**Can run in parallel with Milestone E** — D only touches view code, E only touches service/playback code.

### D1. Loading State View

When data is loading, instead of "Loading..." menu item, show a centered spinner matching iPod aesthetics.

Add a small loading view in `ScreenView.swift` that renders when the library manager is loading for the current screen.

### D2. Empty State

When a playlist has no tracks or the user has no saved albums:
- Show "No [items] Found" centered in the content area
- Same font/color as the placeholder on Now Playing

### D3. Track Row Improvements

Track list rows (in playlist detail, album detail, songs) should show:
```
Song Title                     3:45
Artist Name
```

Add `formattedDuration` to the right side of track rows. This requires `MenuItem` to carry an optional `accessoryText: String?` rendered right-aligned (instead of a chevron).

### D4. Scroll Position Reset

When navigating into a new screen, `selectedIndex` resets to 0. Verify this works for all new screens and that `ScrollViewReader` auto-scrolls correctly.

### D5. Files Touched

| Action | File | What |
|--------|------|------|
| MODIFY | `TrayPod/TrayPod/Models/MenuItem.swift` | Add `accessoryText` field |
| MODIFY | `TrayPod/TrayPod/Views/ScreenView.swift` | Loading/empty states, accessoryText rendering |

---

## Milestone E: Play from Library (PARALLEL with D)

**Goal:** Selecting a track from any library screen plays it in Spotify and navigates to Now Playing.

**Can run in parallel with Milestone D** — E only touches service/protocol/viewmodel code.

### E1. MODIFY: `TrayPod/TrayPod/Services/MusicServiceProtocol.swift`

Add URI-based playback:

```swift
protocol MusicServiceProtocol: AnyObject {
    // ... existing ...
    func play(uri: String)
    func play(uri: String, inContext contextURI: String)
}

extension MusicServiceProtocol {
    // Default no-op implementations so existing code doesn't break
    func play(uri: String) {}
    func play(uri: String, inContext contextURI: String) { play(uri: uri) }
}
```

### E2. MODIFY: `TrayPod/TrayPod/Services/SpotifyService.swift`

Implement URI playback via AppleScript:

```swift
func play(uri: String) {
    guard isRunning else { return }
    let script = """
        tell application "Spotify"
            play track "\(uri)"
        end tell
    """
    _ = executeAppleScript(script)
}

func play(uri: String, inContext contextURI: String) {
    guard isRunning else { return }
    let script = """
        tell application "Spotify"
            play track "\(uri)" in context "\(contextURI)"
        end tell
    """
    _ = executeAppleScript(script)
}
```

### E3. MODIFY: `TrayPod/TrayPod/ViewModels/PlayerViewModel.swift`

Add `playURI` method:

```swift
func playURI(_ uri: String, inContext contextURI: String? = nil) {
    guard let service = musicService ?? spotifyService as MusicServiceProtocol? else { return }

    // If Spotify isn't the active service yet, activate it
    if musicService == nil && spotifyService.isRunning {
        musicService = spotifyService
        activeServiceName = spotifyService.serviceName
    }

    if let context = contextURI {
        service.play(uri: uri, inContext: context)
    } else {
        service.play(uri: uri)
    }

    state.isPlaying = true
}
```

### E4. MODIFY: `TrayPod/TrayPod/ViewModels/iPodViewModel.swift`

Handle `.playTrack` action in `centerButtonPressed()`:

```swift
case .playTrack(let uri, let contextURI):
    playerViewModel.playURI(uri, inContext: contextURI)
    navigateTo(.nowPlaying)
```

(This may already be partially done in Milestone C — just ensure it's wired up.)

### E5. Files Summary

| Action | File | What |
|--------|------|------|
| MODIFY | `TrayPod/TrayPod/Services/MusicServiceProtocol.swift` | Add play(uri:) methods |
| MODIFY | `TrayPod/TrayPod/Services/SpotifyService.swift` | Implement URI playback |
| MODIFY | `TrayPod/TrayPod/ViewModels/PlayerViewModel.swift` | Add playURI() |
| MODIFY | `TrayPod/TrayPod/ViewModels/iPodViewModel.swift` | Wire up .playTrack action |

### E6. Verification

1. Build succeeds
2. Browse to a playlist → select a track → Spotify starts playing it
3. TrayPod auto-navigates to Now Playing
4. Track info updates via DistributedNotificationCenter (existing flow)
5. Play/pause/next/previous still work from Now Playing
6. Playing from Albums works (album context)
7. Playing from Songs works (no context)

---

## Parallel Execution Strategy

### Phase 1: Sequential (A → B → C)

These must run in order — each depends on the previous.

**Sub-agent usage:** Single agent per milestone. Build-verify after each.

### Phase 2: Parallel (D + E)

After C is complete and building:

**Sub-Agent 1 (D - Views):** Touches only:
- `Models/MenuItem.swift` (adds `accessoryText` field)
- `Views/ScreenView.swift` (loading states, empty states, accessory text)

**Sub-Agent 2 (E - Playback):** Touches only:
- `Services/MusicServiceProtocol.swift`
- `Services/SpotifyService.swift`
- `ViewModels/PlayerViewModel.swift`

**Conflict zone:** `iPodViewModel.swift` — both D and E might touch it. Solution:
- **E handles `centerButtonPressed` → `.playTrack` wiring** (already partially in C)
- **D does NOT touch iPodViewModel** — it only touches the view layer

After both complete, build-verify the combined result.

---

## Full File Manifest

### New Files (5)
| File | Milestone | Purpose |
|------|-----------|---------|
| `Utilities/KeychainHelper.swift` | A | Keychain CRUD |
| `Services/SpotifyAuthManager.swift` | A | OAuth PKCE + tokens |
| `Models/SpotifyModels.swift` | B | API response models |
| `Services/SpotifyAPIClient.swift` | B | HTTP client |
| `Services/SpotifyLibraryManager.swift` | B | Cached library state |

### Modified Files (8)
| File | Milestones | What Changes |
|------|-----------|--------------|
| `Info.plist` | A | URL scheme |
| `TrayPod.entitlements` | A | Network entitlement |
| `App/AppDelegate.swift` | A | URL callback handler |
| `Models/MenuItem.swift` | C, D | MenuScreen expansion, subtitle, accessoryText, playTrack action |
| `ViewModels/iPodViewModel.swift` | A, C, E | Settings sign-in, dynamic menus, playTrack handling |
| `Views/ScreenView.swift` | C, D | New screen routing, subtitles, loading states |
| `Services/MusicServiceProtocol.swift` | E | play(uri:) methods |
| `Services/SpotifyService.swift` | E | URI playback implementation |
| `ViewModels/PlayerViewModel.swift` | E | playURI() method |
| `project.pbxproj` | A, B | Register 5 new files |

---

## Validation Strategy

**Closed-loop feedback for each milestone:**

1. **Compile check:** `xcodebuild -project TrayPod.xcodeproj -scheme TrayPod -configuration Debug build`
   - Catches type errors, missing imports, protocol conformance issues
   - Runs after every milestone

2. **Runtime testing (requires human):**
   - Launch app, test the specific milestone's verification checklist
   - User reports any issues → fix → rebuild

3. **What we CAN'T automate:**
   - OAuth browser redirect (requires human to click "Agree")
   - Visual inspection of menu rendering
   - Spotify playback verification

**Best approach:** Build-verify after each milestone. User tests milestones A and C (the most interactive ones). B and E can be verified by build + debug logs. D is purely visual.
