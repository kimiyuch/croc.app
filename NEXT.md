# Croc: handoff

Written 2026-10-19 at the end of the first Croc session, for the agent on Marcel's other Mac. Read this first, then
`README.md`.

## Where things stand

Croc (the Mac app), croc.kimiyu.ch (its website) and the Croc card on kimiyu.ch are **built, tested and pushed**.
**Nothing is deployed yet.** The other Mac couldn't deploy: Hostpoint rejects its SSH keys. That's why the
rest happens on this machine.

| Repo | State | Last commit (2026-10-19) |
|---|---|---|
| `kimiyuch/croc.app` | 0.1 and 0.2 released (2026-10-19); Sparkle updates added for 0.3, not released yet | |
| `kimiyuch/croc.web` | Site done, `public/build` committed, not deployed | `f8417f1` Hero heading on two lines |
| `kimiyuch/kimiyu.web` | Croc card + new OG image committed, not deployed | `e8a573e` Croc's colour: the croc's green instead of olive |

Marcel says croc.kimiyu.ch is set up on Hostpoint and ready.

## What to do, in this order

### 1. Get the code

```sh
cd ~/…/Webroot                      # wherever joey.web and wombat.web live on this Mac
git clone https://github.com/kimiyuch/croc.app.git
git clone https://github.com/kimiyuch/croc.web.git
git -C kimiyu.web pull
```

### 2. Release Croc 0.1

The website's download button and changelog page read the latest GitHub release, so release before deploying the site.

1. Optional but worth it: run `./build.sh`, then convert a **real iPhone HDR video** and a **long video** (10+ minutes)
   with each format. So far it has only been tested with generated clips (see "Testing done" below).
2. In `CHANGELOG.md`, change `## 0.1 (unreleased)` to `## 0.1 (2026-10-DD)`, then commit and push. `release.sh` needs
   a clean tree.
3. `./release.sh 0.1` (needs the GitHub CLI logged in as an account that can push to `kimiyuch`). It builds the app
   (downloading ffmpeg the first time, see below), makes `build/Croc.dmg` (about 32 MB), bumps `Info.plist`, commits
   "Release 0.1", tags `v0.1`, pushes and creates the GitHub release with `Croc.dmg` and `CHANGELOG.md` attached.
   `PUBLISH=0 ./release.sh 0.1` does a dry run.
4. Check that `https://github.com/kimiyuch/croc.app/releases/latest/download/Croc.dmg` downloads.

### 3. Deploy croc.kimiyu.ch

`croc.web/deploy.sh` is the same as joey.web's apart from the name: `HOST=pumutuxu@pumutuxu.myhostpoint.ch`,
`DEST=/home/pumutuxu/www/croc.kimiyu.ch`.

Before the first deploy, check the server once (deploy.sh never touches these):

```sh
ssh pumutuxu@pumutuxu.myhostpoint.ch 'cd ~/www/croc.kimiyu.ch && ls -A; head -1 public/.htaccess; grep -E "^APP_(URL|ENV|DEBUG)=" .env'
```

- `.env` should have `APP_URL=https://croc.kimiyu.ch`, `APP_ENV=production`, `APP_DEBUG=false` and an `APP_KEY`.
  Like the other sites, use file sessions and cache (`SESSION_DRIVER=file`, `CACHE_STORE=file`).
- `public/.htaccess` should be Laravel's, with the PHP version as its first line (Joey, Bilby and Amor use
  `Use php-fpm php83`). Copy the one from wombat.kimiyu.ch if it's missing.

Then, from `croc.web`:

```sh
./deploy.sh    # runs the tests, exports HEAD, composer install --no-dev, rsync, artisan optimize
```

Check: `https://croc.kimiyu.ch`, `/changelog` (shows 0.1 once released), `/legal`, `/download` (redirects to the DMG)
and the link preview (`/images/og.png`). Download counts: `./downloads.sh`.

### 4. Deploy kimiyu.ch

Only after croc.kimiyu.ch is live, so the new card never points at an empty site. From `kimiyu.web`: `./deploy.sh`.
Check that the apps section shows five cards ("Five critters, five small jobs") and that `/legal` links to Croc's legal
notice.

### 5. Small leftovers

- **GitHub bio** of `kimiyuch` still says "Joey, Bilby and Wallaby". Suggested:
  `Small, calm apps, each with a critter inside. Joey, Bilby, Wallaby, Wombat and Croc. Made with Claude.`
  (`gh api -X PATCH user -f bio='…'` as kimiyuch, or by hand on github.com.)
- Optionally add croc.kimiyu.ch to Google Search Console, like the others.

## What Croc is

A small, native macOS app (SwiftUI, macOS 14+, Apple Silicon) that turns MOV and MP4 files and animated GIFs into small,
fast-starting videos for the web, using a bundled ffmpeg. Tagline: *Chew big videos down to size.*

- Drop videos or folders on the window or the Dock icon (also File → Add Videos…, ⌘O). They're converted one at a
  time, and each row shows progress, then "412 MB → 9.8 MB, 98% smaller".
- **Formats:**
  - **Web MP4:** libx264 `-preset slow`, AAC 128k stereo, `+faststart`.
  - **WebM:** libvpx-vp9 with `-b:v 0`, Opus 96k.
  - **Silent loop:** H.264 with no audio.
- **Size:** 720p, 1080p, 1440p or the original. The limit applies to the short side, with the matching 16:9 length
  on the long side. Videos are never upscaled and both sides stay even.
- **Quality:** Smaller, Balanced or Better (x264 CRF 26/23/20, VP9 CRF 36/32/28).
- **HDR** (HLG or PQ, detected with AVFoundation) is tone-mapped to SDR with zscale + `tonemap=hable`.
- **Colour tags:** output is tagged bt709 through the `setparams` filter. ffmpeg 9 ignores `-color_trc` and friends as
  output options and takes the tags from the frames.
- **Output:** `clip.mov` → `clip.web.mp4`, `clip.webm` or `clip.loop.mp4`, next to the original or in a chosen
  folder. Croc never overwrites a file: it adds `" 2"`, `" 3"` and so on to the name instead.
  - ffmpeg first writes to a hidden `.clip.croc-xxxx.mp4`. Croc renames it when ffmpeg finishes and deletes it when
    the run is stopped or fails.
- **Stopping:** Stop (⌘.) or a row's ✕ terminates ffmpeg, and the row shows "Stopped" with a retry button. Quitting
  during a conversion asks first. The Mac doesn't idle-sleep while a conversion runs.
- **Settings and network:** format, size, quality and output folder are remembered in UserDefaults
  (`ch.kimiyu.Croc`). There's no analytics. The only network access is Sparkle's update check
  (from 0.3; automatic once a day by default, can be turned off in the Croc menu).

## How it's built

- Same setup as Wombat: SwiftPM (no Xcode project), `build.sh` (ad hoc signing), `make-dmg.sh`, `release.sh`,
  `release.env`, Figtree, GPLv3.
- **ffmpeg:**
  - `scripts/fetch-ffmpeg.sh` downloads Martin Riedl's static arm64 **ffmpeg 9.0.2** (GPLv3; includes libx264,
    libvpx, libopus, SVT-AV1 and VideoToolbox) into `Resources/bin/`.
  - It's pinned by SHA-256, and `Resources/bin/` is git-ignored. `build.sh` calls the script, so the first build
    needs internet.
  - `build.sh` copies the binary to `Croc.app/Contents/MacOS/ffmpeg` and signs it ad hoc.
  - To update it, change `VERSION`, `BUILD` and `SHA256` in the script.
- **Sparkle** 2.10 (like Joey): `scripts/fetch-sparkle.sh` fetches it into `vendor/` (git-ignored, SHA-256 pinned),
  `build.sh` copies the framework into `Contents/Frameworks` and signs it inside out, `release.sh` uploads
  `Croc-<version>.zip` and `appcast.xml` next to the DMG.
  - The EdDSA signing key is in the Keychain of Marcel's Mac (account `croc`, created 2026-10-19). It has to be
    exported (`generate_keys --account croc -x …`) and imported on any other Mac that releases. If it's lost, existing
    installs can't be updated any more.
- **GIFs** (from 0.4): AVFoundation can't open them, so `VideoInfo.readGIF` reads size and length with ImageIO.
  ffmpeg 9's GIF reader ignores `-min_delay`, so `Command` retimes frames with `setpts`: like browsers, a frame
  delay under 20 ms plays for 100 ms. Transparent pixels are put on white (video has no alpha), and `setsar=1`
  keeps the pixels square when an odd size is trimmed to even. Tested with generated GIFs (opaque, transparent,
  odd size, 20 ms and irregular delays), not yet with real ones from the web.
  - 0.1 and 0.2 have no updater; people on those versions have to download 0.3 by hand once.
  - Tested 2026-10-19 with a local feed: 0.2 found 0.3, downloaded, installed and relaunched as 0.3.
- **No ffprobe:** length, size, rotation, HDR and audio are read with AVFoundation (`VideoInfo` in `Encoder.swift`).
  That saves 66 MB, and the app is 64 MB.
- **Files:**

  | File | What it does |
  |---|---|
  | `CrocApp.swift` | The app, menus, open panels, Dock drops, quit confirmation |
  | `Views.swift` | The window |
  | `Converter.swift` | The queue: `Job`, output names |
  | `Presets.swift` | Formats, sizes, quality and the ffmpeg arguments (`Command`) |
  | `Encoder.swift` | `VideoInfo`, and running ffmpeg with `-progress pipe:1` |
  | `Theme.swift` | Palette, Figtree, pill buttons |

- **Icon:** `node scripts/make-icon.mjs` (needs Google Chrome) draws a green croc with yellow slit eyes and teeth along
  its snout. Its paws are on a clapperboard with the kimiyu bear chalked on the board, on a light green tile (billabong 100–300).
  - It writes `artwork/`, `Resources/icon.png` and `docs/icon.png`.
  - The site images (`croc.web/public/images/croc.png`, `croc.webp` 384 px, `favicon.png` 64 px,
    `public/apple-touch-icon.png` 256 px) and `kimiyu.web/public/images/croc.webp` (256 px) are resized from it with
    ImageMagick + cwebp.
- **Colour:** `billabong`, the croc's green (50 `#eff8f0` … 500 `#3a8d4b`, 600 `#2c733b`, 950 `#0c2113`).
  - It's the same scale in `Theme.swift`, `croc.web/resources/css/app.css` and kimiyu.web's `app.css` (50/700/950
    only).
  - It was olive at first; Marcel didn't like it, so it became the croc's green.

## croc.web

A copy of wombat.web (Laravel 13, Tailwind 4, Inter + Figtree, heroicons), with a Croc window mock in the hero
(`components/app-window.blade.php`).

- **Sections:**
  - Formats: dark, with a `<video>` snippet for each format.
  - Features
  - Under the hood
  - Install: four steps, including "Open Anyway", since the app isn't notarized.
- **Pages:** `/changelog` reads the release's `CHANGELOG.md`, `/legal` has a "Your videos" section and the FFmpeg
  trademark, and `/download` counts clicks.
- **Assets:** `resources/js/app.js` is empty on purpose (Wombat's usage-bar script isn't needed). The OG image comes
  from `/og-image`.
- **OG image gotcha:** `scripts/og-image.sh` uses `https://croc.web.test/og-image`. If headless Chrome can't resolve
  `.test`, add `--host-resolver-rules="MAP croc.web.test 127.0.0.1"`.

## Testing done (2026-10-19, other Mac)

- **Clips used:** a 4K ProRes MOV (170 MB), a portrait 1080×1920 HLG HEVC MOV with sound, and a 720p MP4 without
  sound. All three were generated with ffmpeg.
- **Formats:** all three work. The outputs have the right size and orientation, bt709 tags, faststart (`moov` at the
  front), no audio for Silent loop, and Opus in WebM.
- **Stop:** no partial file is left behind, no ffmpeg keeps running, and the row says "Stopped".
- **Names:** the `" 2"` suffix works, and WebM gets the right extension.
- **Bugs found and fixed:**
  - a crash on SDR videos (`CFEqual` with nil)
  - missing colour tags
  - `clip.webm.` (a trailing dot) instead of `clip.webm`
  - the settings row overflowing the default window width
- **Not tested yet:**
  - real iPhone HDR footage (the tone-mapping was only checked on a test pattern)
  - long videos
  - Intel Macs (not supported: the ffmpeg binary is arm64 only)
  - files with several audio tracks (Croc takes the first)
  - a second Mac (Gatekeeper's "Open Anyway" flow)

## Ideas for later

- A poster frame (the first frame as WebP/JPG) next to each video
- AV1 (SVT-AV1 is already in the bundled ffmpeg)
- A "fast" toggle that uses `h264_videotoolbox`
- Trimming
- Notarization: it needs an Apple Developer ID
- The icon is a first version and could use another pass

## Gotchas

- `gh` on the other Mac had two accounts; `kimiyuch` was left active. Commits in these repos are authored as
  `kimiyu <340246951+kimiyuch@users.noreply.github.com>` (set per repo with `git config user.name/user.email`).
- In zsh, a glob with no matches (`rm *.webm` when there are none) aborts the whole command line.
- Quokka is reserved for kimiyu.ch; don't use it for an app.
