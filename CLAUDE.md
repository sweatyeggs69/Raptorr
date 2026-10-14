# Project Context

## Overview

- Raptorr is a Plex client for Apple TV that plays movie and TV libraries.
- tvOS 27 SwiftUI app, minimum deployment tvOS 27.
- SwiftUI first, UIKit only as a fallback (the VLC video surface is the one UIKit view).
- All UI uses the default tvOS 27 design language and Liquid Glass styling.
- Always use lean changelogs when pushing commits.

## Design Reference: the Apple TV App

Use Apple's TV app on tvOS as the reference for layout and behavior.

- Navigation is the top tab bar (`.tabViewStyle(.tabBarOnly)`): Home, one tab per library, Settings, and Search on the right. Tab pages have no large navigation title.
- Home shows the focused card's backdrop, logo, metadata and description above the rows; Continue Watching uses 16:9 cards. The active row is locked to the bottom of the screen and rows above it scroll out of view, so the header never pushes it around.
- The Home header's title area uses fixed slots (`HeaderLayout`): a 640x180 logo box, one episode title line, one metadata line and three lines of description.
- Artwork, backdrops and logos load through `CrossfadeImage`, which keeps the old image until the new one loads and crossfades between them, and loads through `ImageLoader`: decoded images in `ImageMemoryCache`, then downloaded files in `ImageDiskCache` (Caches, keyed by the request without host or token), then the server. Show pages prefetch every season's episodes and stills on open. Don't use `AsyncImage` for artwork.
- Titles show the movie or show's clear logo (`Image` of type `clearLogo`) through `TitleLogo`, falling back to text when there is no logo. Episodes use their show's logo.
- Show pages switch seasons with a segmented picker (a menu past 8 seasons) and list episodes vertically: 16:9 still on the left, episode number, name and description on the right.
- Movie, episode and show pages end with a Cast row (the item's `Role` tags) and, for movies and shows, a Related row from `/library/metadata/{ids}/similar`.
- Subtitles follow the TV app's menu: Off, Auto (forced subtitles only, matching the audio language), or a specific track.
- Settings and the server picker follow the system Settings app: a large symbol on the left half and a grouped `List` on the right. Info rows are no-op buttons so the focus engine can reach them.

## STRICT RULE: Always Use Stock Apple First

Before implementing any feature, control, layout, or behavior, check whether tvOS provides it and use that. Only build custom when Apple has no equivalent.

- Navigation: `NavigationStack` and `TabView` with `Tab` / `Tab(role: .search)`. Never custom tab bars.
- Tab bars, toolbars and navigation bars get Liquid Glass automatically. Only use `.glassEffect` on custom views the system doesn't style (e.g. the player info overlay).
- Focus: cards (posters, 16:9 cards, episode rows, cast) use `.buttonStyle(.focusBorder)` with `.focusBorder(shape)` on their artwork, a white border instead of the system zoom (Kyle's call). Other controls keep the system focus effects.
- Watched items show `WatchedBadge`: a small black check in a white circle.
- Remote input: `.onPlayPauseCommand`, `.onMoveCommand`, `.onExitCommand`. Back (`onExitCommand`) pops detail pages (`PopOnExitModifier`) and on another tab's top level switches to Home (`TabRouter` in the environment); only Home leaves the app.
- Search: `Tab(role: .search)` with `.searchable`.
- Sheets, covers and alerts: system presentations. Confirmations use `.alert` with a destructive action and explicit cancel, never `.confirmationDialog`.
- Progress: `ProgressView`. Empty and error states: `ContentUnavailableView`.
- Animated icon changes: `.contentTransition(.symbolEffect(.replace))`. Toggles and buttons with different states should transform.

## Architecture

- MVVM with `@Observable` view models (not `ObservableObject`). Views own their view model as `@State`.
- View models hold the logic; views stay declarative.
- `NavigationStack` with `NavigationPath`, never `NavigationView`. Pushed `PlexMetadata` values route through `.metadataDestinations()`.
- Dependency injection through the SwiftUI Environment (`AuthStore`, `ServerConnectionManager`, `PlaybackCoordinator`, `\.plexClient`, `\.plexServer`).
- The target uses `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. Plex model types and `PlexAPIClient` are explicitly `nonisolated` and `Sendable`.
- Storage on tvOS: app file storage (Caches) can be purged at any time, so small persistent state (selected server, client identifier, preferences) goes in UserDefaults/AppStorage and secrets in the Keychain. Anything on disk must be treated as a re-creatable cache.
- Library data is cached: `PlexAPIClient` writes library GET responses (raw JSON) to `PlexResponseCache` in Caches, keyed by server and request, never by URI or token. Screens read `from: .cache` first, then refresh `from: .network`. Search and playback are not cached. After launch, `LibraryPrefetcher` warms the cache in the background (at most every 6 hours per server): library pages, every title's metadata via batched `/library/metadata/{ids}`, and each show's seasons plus its opening season's episodes.
- Server connections are picked in order local, then remote (WAN), then relay (`PlexConnection.tiers`), and a URI only counts if `/identity` returns the server's `machineIdentifier`. The pick re-runs at launch, on return to the foreground and on network changes.

## Build System

- SPM only, no CocoaPods.
- VLCKit comes from `https://code.videolan.org/videolan/VLCKit.git`, pinned to an exact 4.0 prerelease tag. Bump the pin deliberately; the 4.0 API differs from 3.x (`TVVLCKit`).
- The Xcode project uses folder-synchronized groups: new files under `Raptorr/` and `RaptorrTests/` are picked up automatically, no project file edits needed.
- Build target: "Raptorr" (tvOS). Test target: "RaptorrTests".

## Testing

- Swift Testing only (`@Test`, `#expect`), not XCTest.

## STRICT RULE: Plex API Must Match the Documented Architecture 1:1

`plex-api.json` at the repo root is the source of truth for Plex Media Server requests.

1. Before adding or changing any PMS request, look up the exact endpoint, path, and parameter names in `plex-api.json`.
2. Only call documented endpoints with documented parameter names. Never carry over undocumented paths from other clients.
3. Use the purpose-built endpoint family for each task.
4. If a behavior has no documented endpoint, re-check the spec or ask; don't fall back to something that "happens to work".

Paging uses the `X-Plex-Container-Start` / `X-Plex-Container-Size` headers (required on `/children` and `/grandchildren`).

## Plex Sign-In

- Uses the PIN flow from "Authenticating with Plex" in `plex-api.json`.
- A short PIN (no `strong=true`) is created so the same code works both ways: the QR code encodes `https://plex.tv/link/?pin=<code>` and the code is shown for typing at plex.tv/link.
- Poll `GET /api/v2/pins/{id}` until `authToken` is set; replace the PIN when it expires.
- The client identifier is a UUID generated once per install.

## Playback

- VLCKit plays the original file directly from the documented part endpoint `/library/parts/{partId}/{changestamp}/{filename}` (the part `key`), with the token in the query string.
- Resume uses the VLC `:start-time=` media option.
- Sidecar subtitles (`Stream` with a `key`) are added with `addPlaybackSlave`.
- VLC tracks are paired with Plex streams by order (`TrackMatching`): embedded streams by `index`, then sidecars in the order they were added. Plex supplies names, language and the `forced` flag; if the counts differ, VLC's names are used.
- Playback starts on the server's preferred audio/subtitle (`selected`), else subtitles on Auto. Choices are saved with `PUT /library/parts/{partId}` (`audioStreamID`, `subtitleStreamID`, 0 = none).
- Report `POST /:/timeline` on every state change and every 10 seconds; send `stopped` on exit and `PUT /:/scrobble` when the item finished.

## Code Style

- Every new view includes a `#Preview`.
- SF Symbols by exact name.
- One type per file, grouped by feature (Auth/, Library/, Player/...).

## Logging & Diagnostics

- Verbose diagnostics only in `#if DEBUG`. Release builds must not print internal traces.
