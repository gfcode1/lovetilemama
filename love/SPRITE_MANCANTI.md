# Sprite mancanti

## Speciali — `assets/speciali/`

Formato: 256×224 RGBA, sfondo trasparente (come le esistenti).

- [x] `levelup_nobg_cropped.png` — bonus levelup (on board + toast)
- [x] `points_100_nobg_cropped.png` — bonus punti +100 (livello 1)
- [x] `points_200_nobg_cropped.png` — bonus punti +200 (livello 2)
- [x] `points_300_nobg_cropped.png` — bonus punti +300 (livello 3)
- [x] `points_nobg_cropped.png` — bonus punti generico (fallback)
- [ ] `leveldown_nobg_cropped.png` — malus (rif. morto)
- [ ] `rain_nobg_cropped.png` — malus (rif. morto)
- [ ] `invert_nobg_cropped.png` — malus (rif. morto)
- [x] `minigame_nobg_cropped.png` — bonus minigioco

## Tile valore 32

- [ ] `assets/verde/32.png`
- [ ] `assets/rosso/32.png`
- [ ] `assets/giallo/32.png`
- [ ] `assets/blue/32.png`

## Note

- `points_*` sono caricate in `src/ui/grid.lua` (nomi `points_1`/`points_2`/`points_3` = 100/200/300; `points` generico come fallback).
- Le sprite di board sono riusate in toast/banner via `Emoji.register` (`levelup`, `minigame`, `points*`).
- `leveldown`, `rain`, `invert` sono riferimenti morti: i malus non sono celle sulla board, quindi a schermo non servono.
- I tile `32.png` non sono strettamente necessari: il valore 32 esplode e non persiste mai (fallback a `16.png`).
