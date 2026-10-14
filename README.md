# Raptorr

Plex client for Apple TV, built for movie and TV libraries.

- SwiftUI, tvOS 27, stock tvOS styling
- Sign in by scanning a QR code (or entering the code at plex.tv/link)
- Home with Continue Watching and each library's hubs, poster grids per library, search
- Show pages with seasons and episodes
- Playback through [VLCKit](https://code.videolan.org/videolan/VLCKit), so files direct play without transcoding

## Building

Open `Raptorr.xcodeproj` in Xcode 27 and run the `Raptorr` scheme on an Apple TV or the tvOS simulator. Xcode resolves VLCKit through Swift Package Manager on first open.

`plex-api.json` is the Plex Media Server API spec the app is built against.
