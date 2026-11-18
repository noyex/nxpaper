# Instructions for coding agents

nxpaper puts animated wallpapers on every screen of a Mac, built for OLED displays
(`Sources/*.swift`, AppKit + SwiftUI, compiled with plain `swiftc`, no Package.swift). Wallpapers are
single HTML files in `Resources/wallpapers/` rendered in a WKWebView. Setup, PR rules and code style are
in [CONTRIBUTING.md](CONTRIBUTING.md). This file holds the rule that is easy to break by accident.

## Every wallpaper must be OLED friendly

The app loads each `Resources/wallpapers/*.html` as it is, so the file itself has to keep these promises.
`fala.html` is the reference.

1. **Pure black background.** `#000`, set on `html` and `body`, and the canvas clears to black. The web
   views are transparent, so a missing background shows the system wallpaper through.
2. **Every lit pixel keeps moving.** Nothing static is drawn. A still lit pixel burns in on OLED.
3. **`<title>` is the name.** The panel shows it. The app reads it as the literal text between `<title>`
   and `</title>` (no attributes on the tag); without one it falls back to the file name. The file name
   is the id.
4. **`window.setPaused(bool)`** stops and resumes the animation: stop requesting frames when paused, pick
   up from the current time on resume. The app calls it after the page loads and whenever the screens
   sleep, the Mac locks, a window covers the desktop or the user pauses.
5. **`?t=<seconds>` freezes time**, for stills and screenshots.
6. **Sizes scale with the screen height** (`res.y / 1000`), not fixed pixels, so it reads the same on a
   desktop and in the small preview tile in the panel.
7. **WebGL at about 30 fps and low CPU.** Cap the frame rate (`?fps=` overrides it), use
   `powerPreference: 'low-power'`, cap the pixel ratio at 2, and keep the work in the shader. Aim for
   roughly 10% of one core or less.
8. **Self-contained.** One HTML file: no network, no external scripts, fonts or images, no CDN. Inline
   everything. A wallpaper that loads from the network is a security issue (see [SECURITY.md](SECURITY.md)).
9. **Each screen starts at a different moment** (random start time unless `?t=` is set), so two monitors
   don't mirror each other.

The previews in the panel are live pages too, so a wallpaper that is heavy or ignores `setPaused` slows
the panel down as well.

## Other rules

- No new dependencies and no network code in the app.
- The app only ever reads `Resources/wallpapers/` and `Resources/Fonts/` inside its own bundle. It
  persists two `UserDefaults` keys (`wallpaper`, `paused`) and nothing else.
- Code comments are in English.

## Checks

```sh
scripts/build-app.sh --universal   # arm64 + x86_64, what CI runs
scripts/build-app.sh --install     # run the real app
```

To look at a wallpaper without the app, open the HTML file in a browser, add `?t=12` for a still.
