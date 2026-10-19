# Croc: a video converter for the web (to build)

Written 2026-10-19 for whoever opens this folder next. Last updated 2026-10-19: the app works (steps 1–2 done), not released yet.

## What it is

A small, native macOS app that turns `.mov` / `.mp4` files into videos fit for the web, using ffmpeg. Drop files on the
window, pick a preset, get small, fast-starting files back. Tagline idea: *"Chews big videos down to size."*

Croc is the saltwater crocodile: heavy, and the chomp fits an app that cuts files down. The name is free
(`kimiyuch/croc.app` and `kimiyuch/croc.web` don't exist yet, checked 2026-10-19).

| | |
|---|---|
| Repos | `kimiyuch/croc.app` (native app) + `kimiyuch/croc.web` (site), per the `.app` / `.web` suffix rule |
| Local folders | `Webroot/croc.app`, `Webroot/croc.web` (created 2026-10-19; croc.web still empty) |
| Site | `https://croc.kimiyu.ch` on Hostpoint, `https://croc.web.test` in Herd |
| Bundle ID | `ch.kimiyu.Croc` |
| Colour | `billabong`: murky olive-green, set apart from Joey's `gum` (green) and Bilby's `chip` (teal) |

## Model it on Wombat

Copy the structure of `kimiyuch/wombat.app` and `kimiyuch/wombat.web` (both cloned read-only in `/tmp/kimiyu-ref`).

### croc.app

- **SwiftPM, no Xcode project.** `Package.swift`, `Info.plist`, `build.sh` (ad hoc `codesign --sign -`),
  `make-dmg.sh`, `release.sh <ver>` + `release.env` (`REPO=kimiyuch/croc.app`), `CHANGELOG.md` with `## 0.1 (date)`.
  macOS 14+, Apple Silicon.
- **GPLv3**, like Wombat. That lets us bundle a GPL ffmpeg with libx264/libvpx without trouble.
- **Fonts / theme:** Figtree in `Resources/Fonts` (+ `OFL.txt`), `Theme.swift` matching croc.kimiyu.ch.
- **Files:**
  - `Sources/Croc/CrocApp.swift`: the app and main window
  - `Sources/Croc/Views.swift`: drop zone, queue rows with progress, preset picker
  - `Sources/Croc/Theme.swift`: colours, Figtree, button styles
  - `Sources/Croc/Presets.swift`: the presets as ffmpeg argument lists
  - `Sources/Croc/Encoder.swift`: runs ffprobe (duration, size) and ffmpeg via `Process`, parses `-progress pipe:1`
    (`out_time_us` / duration) and supports cancelling
  - `scripts/fetch-ffmpeg.sh`: downloads static arm64 `ffmpeg` + `ffprobe` into `Resources/bin` (git-ignored),
    like Joey's `fetch-sparkle.sh`. Decided: martin-riedl.de static arm64 ffmpeg 9.0.2 (GPLv3, has libx264,
    libvpx, libopus, SVT-AV1, VideoToolbox), pinned by SHA-256. No ffprobe: AVFoundation reads length, size and HDR.
    ffmpeg goes into `Contents/MacOS/ffmpeg`; the app is 64 MB.
  - `scripts/make-icon.mjs`: the icon, rendered with headless Chrome like Wombat's

### Features for 0.1

- Drop `.mov` / `.mp4` (or open them) → queue; one at a time, each row with a progress bar, before → after size.
- Presets:
  - **Web MP4**: H.264 CRF 23, `-preset slow`, `yuv420p`, AAC 128k, `-movflags +faststart`
  - **WebM**: VP9 CRF 32 `-b:v 0 -row-mt 1`, Opus 96k
  - **Silent loop**: like Web MP4, `-an` (for hero/background videos)
- Max size: 1080p / 720p / original (`scale='min(W,iw)':-2`, never upscales).
- Output next to the original as `name.web.mp4` / `name.webm` (never overwrite), or a chosen folder; "Show in Finder".
- Nothing leaves the Mac, no network.
- Later: poster frame export (JPG/WebP of the first frame), AV1, hardware encoding (`h264_videotoolbox`) as a
  "fast" toggle, Sparkle updates like Joey.

### The icon

Drawn 2026-10-19, first version (may want another pass): a croc peeking over the app's object on a rounded `billabong` gradient tile, like the others: eyes and snout just
above a film clapperboard, with the kimiyu bear debossed on the clapper (the way Wombat has it on the drive).
Copy `artwork/kimiyu-bear.svg` from kimiyu.web. Outputs `artwork/icon.svg/png`, `Resources/icon.png`, `docs/icon.png`.

### croc.web

Copy `wombat.web`: Laravel 13, Tailwind 4 (`billabong` palette under `@theme`), Inter + Figtree, heroicons,
`home` / `changelog` / `legal`, an OG image (`scripts/og-image.sh`), `/download` with a counter (`downloads.sh`), and
`deploy.sh` to `~/www/croc.kimiyu.ch` on `pumutuxu@pumutuxu.myhostpoint.ch`. `config/croc.php` points at
`releases/latest/download/Croc.dmg` and `CHANGELOG.md`. A Croc window mock in the hero
(`components/app-window.blade.php`). Build the page with the `/ui` skill.

### kimiyu.web

Add a Croc card to `config/kimiyu.php` (icon `images/croc.webp`, colour `billabong`) and the `billabong` colours
to its `app.css`; update the GitHub bio ("Joey, Bilby and Wallaby") while at it.

## Order

1. ~~Create the two GitHub repos and clone kimiyu.web into Webroot.~~ Done 2026-10-19 (Marcel created the repos).
2. ~~Build croc.app: encoder + presets first (test from the command line), then the UI, then the icon.~~ Done 2026-10-19.
   Tested with a 4K ProRes MOV, a portrait HLG HEVC MOV and a silent MP4 (all three formats, stop, " 2" names).
   Still to try with real iPhone HDR footage and a long video.
3. Release 0.1: set the date in `CHANGELOG.md` first (`make-dmg.sh`, `release.sh 0.1`).
4. Build croc.web, set up the subdomain on Hostpoint (PHP 8.3 in `public/.htaccess`), deploy.
5. Add the card to kimiyu.ch and deploy it.
