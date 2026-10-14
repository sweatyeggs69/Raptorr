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
- The Home header's title area uses fixed slots (`HeaderLayout`): a 768x180 logo box, one episode title line (episodes only), one metadata line and three lines of description. The header switches items as one unit: `HomeViewModel` publishes a `HomeHeader` only once its logo and backdrop are in memory (or after 1.5s), and the header crossfades as a whole.
- Artwork, backdrops and logos load through `CrossfadeImage`, which starts on the memory-cached image when there is one (backdrops use their own memory cache, `ImageLoader.backdrops`, so they never evict cards), which keeps the old image until the new one loads and crossfades between them, and loads through `ImageLoader`: decoded images in `ImageMemoryCache`, then downloaded files in `ImageDiskCache` (Caches, keyed by the request without host or token), then the server. Show pages prefetch every season's episodes and stills on open. Home prefetches every row's card artwork (the first 20 per row decoded into memory, the rest to disk) and backdrops after it loads, using `ShelfStyle.artwork(for:)` so the sizes match the cards. Don't use `AsyncImage` for artwork.
- Titles show the movie or show's clear logo (`Image` of type `clearLogo`) through `TitleLogo`, centered vertically in its box (equal space above and below), fitted to fill its box's height but never wider than 40% of the screen (`TitleLogo.widthLimit`, 768pt), falling back to text when there is no logo. Episodes use their show's logo.
- Show pages switch seasons with a segmented picker (a menu past 8 seasons) and list episodes vertically: 16:9 still on the left, episode number, name and description on the right.
- Movie, episode and show pages end with a Cast row (the item's `Role` tags) and, for movies and shows, a Related row from `/library/metadata/{ids}/similar`.
- Cast cards open `PersonView` (pushed `PlexTag`): photo left, name and bio right, then Movies and TV Shows rows. It loads `/library/people/{personId}` (tag `id`, else `tagKey`) and `/library/people/{personId}/media`; the spec's tag has no bio field, so the bio is the server's `summary` if present, else the lead of the actor's Wikipedia article (`WikipediaClient`, REST page summary by name, accepted only when its description reads like a performer; Kyle's choice). Birth and death dates above the bio come from that article's Wikidata item (`WikidataClient`, P569/P570).
- Metadata lines use `ItemMetadataLine` on Home and movie and episode pages: year, `RatingBadge` (outlined rounded box, as in the TV app), runtime. Home's library rows leave out the year. An episode's S#E# sits before its name in the secondary color (`EpisodeTitleLine`) on Home, episode pages and in the player.
- Subtitles follow the TV app's menu: Off, Auto (forced subtitles only, matching the audio language), or a specific track.
- Library grids overlay a letter column on a glass capsule at the right edge (`LetterJumpBar`). Counts come from the title sort's `firstCharacterKey` in `/library/sections/{sectionId}/sorts` (servers 404 on `/firstCharacters`); if that fails, the letters are read off every title's `titleSort`. Selecting a letter loads through that title, scrolls to it and focuses it.
- Tabs are labeled through `TabLabel`; Settings > Interface > Tab Bar Icons (on by default, `InterfaceSettings`) hides their symbols. Search shows only its magnifying glass, never a title.
- Switching to Home from another tab starts Home over (`TabRouter.homeReturns`): its stack pops, it scrolls to the first row, and focus lands on that row's first card rather than the card last focused.
- Settings and the server picker follow the system Settings app: a large symbol on the left half and a grouped `List` on the right. Info rows are no-op buttons so the focus engine can reach them.

## STRICT RULE: Always Use Stock Apple First

Before implementing any feature, control, layout, or behavior, check whether tvOS provides it and use that. Only build custom when Apple has no equivalent.

- Navigation: `NavigationStack` and `TabView` with `Tab` / `Tab(role: .search)`. Never custom tab bars.
- Tab bars, toolbars and navigation bars get Liquid Glass automatically. Only use `.glassEffect` on custom views the system doesn't style (e.g. the player info overlay).
- Focus: cards (posters, 16:9 cards, episode rows, cast) use `.buttonStyle(.focusBorder)` with `.focusBorder(shape)` on their artwork, a white border instead of the system zoom (Kyle's call). Other controls keep the system focus effects.
- Rows of cards and button rows use `.fullWidthFocusSection()`, so up or down reaches a short row from anywhere across the screen.
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
- Library data is cached: `PlexAPIClient` writes library GET responses (raw JSON) to `PlexResponseCache` in Caches, keyed by server and request, never by URI or token. Screens read `from: .cache` first, then refresh `from: .network`. Search and playback are not cached. After launch, `LibraryPrefetcher` warms the cache in the background (at most every 6 hours per server): library pages, every title's metadata via batched `/library/metadata/{ids}`, and each show's seasons plus its opening season's episodes. Signing out or switching servers purges everything with `clearCache()`: responses, images on disk and in memory, and the prefetch schedule.
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
- Resume seeks (`player.time`) once VLC's video output is running (seeking as soon as VLC reports playing froze the picture), with the video hidden, audio muted and the timeline on the resume point until playback moves on from it; the `:start-time=` option left resumed playback stuck at 0:00. Media uses `:input-fast-seek`, and MKVs `:demux=mkv_trusted,any` (the default MKV demuxer distrusts cues and, unable to scan ahead over HTTP, seeked from the first frame). Local connections use `:network-caching=300` (VLC's default buffers 1s before starting and after each seek).
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
