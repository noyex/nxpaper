# Contributing to nxpaper

Thanks for helping out. Bug fixes, small improvements and new wallpapers are all welcome.
For anything bigger, open an issue first so we can agree on the approach before you write the code.

## Setup

You need macOS 14+ and the Xcode command line tools (Xcode 26 to build the Liquid Glass app icon).
There is no Package.swift: the Swift sources in `Sources/` are compiled directly with `swiftc`.

```sh
scripts/build-app.sh             # builds build/nxpaper.app for this Mac (arm64)
scripts/build-app.sh --install   # builds it, copies it to /Applications and launches it
```

## Pull requests

You can't push to this repo directly: every change goes through a pull request from your fork,
and only the maintainer (@noyex) can approve and merge it.

1. Fork the repo on GitHub, then clone your fork and create a branch:

   ```sh
   git clone https://github.com/<you>/nxpaper.git
   cd nxpaper
   git switch -c fix/<short-name>   # or feat/<short-name>
   ```

2. Make the change. Keep the PR focused on one thing: small PRs get merged faster.
3. Check that it builds and works: `scripts/build-app.sh --universal`, then run the app with your change
   (`scripts/build-app.sh --install`).
4. Push the branch to your fork and open a PR against `noyex/nxpaper` `main`
   (GitHub shows a "Compare & pull request" button, or run `gh pr create --repo noyex/nxpaper`).
5. Fill in the PR template: what and why, how to test, screenshots for anything visible.

### What happens next

- On your first PR, the checks (build, title, screenshots) start only after a maintainer approves the run.
  That's a GitHub safety rule for outside contributors, not a sign anything is wrong.
- The maintainer reviews the PR. Pushing new commits after an approval needs a fresh approval.
- All checks must pass and all review comments must be resolved before the PR can be merged.
- PRs are squash-merged into `main` by the maintainer. A new release with your change follows when the
  maintainer cuts one.

### Title

PRs are squash-merged, so the title becomes the commit on `main`. Use
[Conventional Commits](https://www.conventionalcommits.org): `feat: …`, `fix: …`, `refactor: …`,
`perf: …`, `style: …`, `docs: …`, `test: …`, `build: …`, `ci: …`, `chore: …`. Imperative mood, in English,
for example `feat: add a rain wallpaper`.

### Screenshots

**Every change you can see in the app needs a screenshot or a short video in the PR description.**
If you change something that already exists, show it before and after.

A check enforces this: PRs that touch `Sources/PanelView.swift`, `Sources/Panel.swift`, `Resources/wallpapers/`,
`Resources/AppIcon.icon/` or `docs/` fail until the description has an image or video. If you only refactored
and nothing visible changed, say so in the description and a maintainer will add the `no-ui` label.

## Adding a wallpaper

Drop one self-contained HTML file into `Resources/wallpapers/`, rebuild and run the app. Wallpapers must be
OLED friendly: pure black background, everything lit keeps moving, `window.setPaused(bool)`, `?t=<seconds>`
for stills, sizes that scale with the screen height, WebGL at about 30 fps, and no network. The exact
rules are in [AGENTS.md](AGENTS.md), and `Resources/wallpapers/fala.html` is the reference. Include a
screenshot or a short video of the wallpaper in the PR.

## Code style

Match the code around you: AppKit + SwiftUI, small focused files. Comments explain why, not what.
No new dependencies: no Swift packages, no JavaScript libraries, no network code. If you think one is
needed, open an issue first.

## Releases

Maintainers release from GitHub: **Actions → Release → Run workflow** with a version like `v1.2.3`.
