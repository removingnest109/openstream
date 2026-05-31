# OpenStream Flutter Client

Modern Flutter client for [openstream-lite](https://github.com/removingnest109/openstream-lite), inspired by the React UI from [openstream-frontend](https://github.com/removingnest109/openstream-frontend).

## Features

- Library browsing with search
- Album and artist views
- Playlist viewing and creation
- Track metadata editing and deletion (with optional file delete)
- Track upload and server-side rescan
- Album art upload
- Built-in player bar (play/pause, previous/next, shuffle, loop, seek, volume)
- Theme controls (dark mode + accent color)
- Multi-server support on Android/iOS/Linux/macOS/Windows
- Web support with a single configurable server URL

## Supported Platforms

- Android
- iOS
- Linux
- Windows
- macOS
- Web

## Requirements

- Flutter `3.44.0`
- Dart `3.12.0`
- Running `openstream-lite` backend

## Quick Start

```bash
flutter pub get
flutter run
```

## Backend URL Setup

- Non-web builds: use the server picker in the app bar to add/switch multiple servers (IP or domain).
- Web builds: set one server URL in Settings.

Common example:

- `http://localhost:9090`
- `http://192.168.1.20:9090`
- `https://music.example.com`

## Notes

- The backend currently exposes open endpoints (no auth), so this client follows that model.
- On web, ensure your backend/proxy is configured with CORS for your web origin.
