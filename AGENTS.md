# AGENTS.md

## What this is
LÖVE 11.5 (Lua) puzzle game. The entire game lives in `love/`; `love/main.lua` is the entrypoint and defines all `love.*` callbacks, requiring the rest as modules. Docs are in Italian (`DINAMICHE_DI_GIOCO.md`, `bonus.md`, `minigames.md`, `love/SPRITE_MANCANTI.md`).

## Layout gotchas
- The runtime asset root is `love/assets/...` (paths such as `assets/emoji/star.png` are resolved relative to `love/`).
- Root `assets/` and `openmoji-72x72-color/` are **not** loaded at runtime. Root `assets/` is a near-duplicate that has diverged, so editing it changes nothing in-game — edit `love/assets/`.
- Saves/settings go through `love.filesystem` under identity `tilemama` (`love/conf.lua`), not the repo.
- Architecture: `main.lua` callbacks → `src/ui/router.lua` + `src/ui/scenes/`; game rules in `src/engine/`; meta systems in `src/systems/`; balance/tuning constants in `src/config.lua`. `src/ui/emoji.lua` maps logical names to `assets/emoji/*.png`.

## Run / verify
- Run from repo root: `love love` (LÖVE 11.5 installed). Window is 720×1280 portrait (`love/conf.lua`).
- No test, lint, or typecheck tooling exists. Verify by running the game; tune behavior via `love/src/config.lua`.

## Build & CI
- CI: `.github/workflows/build.yml`. Job `package` builds `tilemama.love`; `android`, `linux`, `windows` consume it; `release` publishes on `v*` tags.
- Packaging must run inside `love/`: `cd love && 7z a -tzip -mx=0 ../tilemama.love main.lua conf.lua src assets`. The archive root must contain `main.lua`/`conf.lua` (no top-level `love/` dir) or LÖVE will not boot it.
- Pass **relative** paths to all `love-actions/*` inputs. Absolute `${{ github.workspace }}` breaks the Windows job: bash strips the `\` in `D:\a\...` and 7z then fails on a bogus path.
- Android uses `love-actions-android@v2` plus `.github/android/portrait.patch`, which forces portrait because the action hardcodes `app.orientation=landscape`. If you bump `LOVE_REF`, regenerate the patch against that love-android tag.
- Icons live under `.github/{assets,android,linux,windows}/`. Android needs `mipmap-*/ic_launcher.png` matching `icon-specifier: "@mipmap/ic_launcher"`; `.github/assets/icon.png` (copied from `love/assets/rosso/1.png`) is the placeholder source.
- APK is debug-only until the four `ANDROID_KEYSTORE_*` secrets are set. Windows produces zips only (no installer).

## Conventions
- If you add/replace emoji, keep the OpenMoji CC BY-SA 4.0 attribution in `love/assets/emoji/README.md` and register names in `src/ui/emoji.lua`.
- `*.love` is gitignored; `love/tilemamav5.love` is a stale untracked artifact — do not commit it.
