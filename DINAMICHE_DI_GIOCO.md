# TileMama — Guida Completa alle Dinamiche di Gioco

> Documento generato il 2026-09-08 analizzando il codice sorgente. Ogni sezione riporta il file di riferimento (`file:linea`).

---

## 1. Obiettivo e concetto base

TileMama è un puzzle arcade **8×8** su griglia fissa. Sposti blocchi colorati fino all'ostacolo, fondi blocchi compatibili per aumentarne il valore e accumuli punteggio. La griglia piena = **Game Over** (`src/lib/engine.ts:334`).

---

## 2. Griglia e blocchi iniziali

| Parametro | Valore | File |
|---|---|---|
| `GRID_SIZE` | `8` | `src/lib/types.ts:71` / `src/core/config/gameConfig.ts:2` |
| `grid[y][x]` | ` (Block \| Special \| null)[][] ` | `src/lib/engine.ts:64` |
| Colori | `green`, `red`, `yellow`, `blue` | `src/lib/types.ts:3` |
| Setup iniziale | 4 blocchi valore `1` per colore = **16 blocchi** | `src/lib/engine.ts:204` (`initialBlocksPerColor: 4`) |
| Valori possibili | `1, 2, 4, 8, 16, 32` (oltre esplode) | `src/services/persistence.ts:9` (`max 64` di validazione) |

`Block` (`src/lib/types.ts:18`): `{ id, x, y, color, value, jolly?, virus?, virusNextAt? }` — `virus` è legacy stub (`tickVirus` è no-op, `src/lib/engine.ts:525`).

---

## 3. Movimento — 8 direzioni, slide fino all'ostacolo

### 3.1 Direzioni
`DIRS` (`src/lib/types.ts:7`): `N,S,E,W` + diagonali `NE,NW,SE,SW`. L'input swipe è convertito via `angleToDir8()` con settori da 45° (`src/App.svelte:33`).

Se attivo **malus `invert`** le direzioni sono specchiate (`N↔S`, `E↔W`, diagonali invertite) in `src/lib/game.svelte.ts:313` e nel ghost preview `src/App.svelte:631`.

### 3.2 MoveResolver — logica pura
Delegato a `resolveMove(block, dir, grid)` (`src/core/engine/MoveResolver.ts:10`):

1. Avanza cella per cella `cx+dx, cy+dy`.
2. Fuori griglia → `slide` alla cella limite.
3. Cella vuota → continua a scorrere.
4. `isWall` → `wall` (ritorna `wall`, `finalX/Y`, `beforeX/Y`).
5. `isSpecial` → `special` (atterra sullo speciale).
6. `isBlock`:
   - `canMerge = (color uguale OR block.jolly OR target.jolly) && value uguale` → `merge`.
   - Altrimenti **strict**: se non ti sei mosso → `none` (mossa vuota, non conta), altrimenti `slide` fino a prima del blocco incompatibile (`src/core/engine/MoveResolver.ts:36`).

### 3.3 Engine.move() — effetti collaterali
`src/lib/engine.ts:210`:
- Bloccato se `gameOver` o `pendingMode` attivo.
- Gestisce i 4 esiti: `wall`, `special`, `merge`, `slide`.
- **Freeze** (`malus_freeze`) blocca l'input a monte in `game.svelte.ts:doMove/tapSpecial/triggerMalus` (`src/lib/game.svelte.ts:310`).
- Dopo mossa valida: verifica `freeCells().length === 0` → `gameOver = true`.
- Ogni mossa valida pusha snapshot per **undo singolo** (`pushHistory()` → `history = [snapshot]`, `src/lib/engine.ts:105`).

### 3.4 Ghost preview
`App.svelte:626` ricalcola `resolveMove` su `drag + swipeDir` ad ogni frame, mostrando:
- `path[]` evidenziato,
- badge finale: `＋` (merge), `★` (speciale), `🧱 + hp` (muro), freccia (slide).

---

## 4. Fusione (merge) ed esplosione

| Regola | Dettaglio |
|---|---|
| Compatibilità | `color ===` oppure uno dei due ha `jolly=true`, **e** `value ===` |
| `jolly` | Si consuma nella fusione (`block.jolly = false`, `src/lib/engine.ts:322`). Jolly applicato via pending (`src/lib/engine.ts:494`). |
| Valore nuovo | `sum = a.value + b.value` (es. 8+8=16) |
| Punteggio | `gain = round(sum * multiplier)` — vedi §8 Combo. Se `hasDecay()` attivo → `gain = floor(gain * 0.5)` (`src/lib/engine.ts:320`) |
| Score totale | `engine.score += gain` |
| Esplosione | Se `sum >= EXPLOSION_VALUE` (`32`, `src/lib/types.ts:52`) → il blocco appena creato **viene rimosso** (`removeAt`) e spawnano **4 blocchi** valore 1, uno per colore (`src/lib/engine.ts:330-333`) |
| Punteggio esplosione | Scatter di +4 blocchi (non dà punti extra oltre il merge che l'ha causata) |

---

## 5. Speciali (Bonus)

### 5.1 Generazione e timing
- `spawnSpecial(at?, forcedKind?)` (`src/lib/engine.ts:170`): `duration = wall ? 12000ms : 9000ms`, `hp = 2` se wall.
- **Scheduler** (`src/services/scheduler.ts`):
  - `bonus`: `6500–10500 ms` random, reschedulato ricorsivamente (`scheduleBonus`).
  - Pausato quando `view !== 'game'` o `pendingMode` o `gameOver` o `isFrozen` (`src/App.svelte:202` + `scheduler.setPaused`).
  - Visibility: `document.hidden → pause/resume` (`src/services/scheduler.ts:93`).
- Peso spawn `pickRandomBonusKind()` (`src/lib/engine.ts:705`):
  ```
  laser 20% | wall 14% | bombColor 14% | clone 12% | jolly 12% | x2 10% | vortex 9% | shuffle 9%
  ```
- Expiry: `cleanupExpiredSpecials()` ogni **250 ms** (`GAME_CONFIG.cleanupIntervalMs`, `src/services/scheduler.ts:34`), + tick malus ogni 100 ms (`src/App.svelte:143`).

### 5.2 Tabella 8 speciali

| Kind | Icona | Durata | Tipo | Effetto | File |
|---|---|---|---|---|---|
| `x2` | ×2 | 9s | **pending** | Tocca un blocco → `value *=2`. Se ≥32 esplode → +4 blocchi, `scoreGain = newVal` (con Decay dimezzato) | `src/lib/engine.ts:480` |
| `jolly` | 🌈 | 9s | **pending** | Rende un blocco jolly → si fonde con qualsiasi colore a parità valore. Si consuma al merge. | `src/lib/engine.ts:494` |
| `bombColor` | 💣 | 9s | **pending** | Tocca un blocco → rimuove **tutti** i blocchi di quel colore. Hint UI: colore più frequente. | `src/lib/engine.ts:497` |
| `clone` | ➕ | 9s | **pending** | Duplica il blocco scelto in cella libera random (stesso colore/valore). GameOver se griglia piena dopo. | `src/lib/engine.ts:504` |
| `laser` | — | 9s | **istant** | Pulisce **riga + colonna** del punto di attivazione (escluso il blocco in moto per `move`, incluso per `tap`) | `src/lib/engine.ts:349,364` |
| `vortex` | 🌀 | 9s | **istant** | Teletrasporta il blocco mosso in cella libera random. Via tap: teletrasporta un blocco random. | `src/lib/engine.ts:437` |
| `shuffle` | 🔀 | 9s | **istant** | Rimescola **solo le posizioni dei blocchi**, gli speciali restano fermi (`specialsPos` esclusi) | `src/lib/engine.ts:447` |
| `wall` | 🧱 | 12s | **istant / ostacolo** | Genera un muro con **2 HP**. Vedi §6. | `src/lib/engine.ts:251,389` |

`PENDING_KINDS = {x2,jolly,bombColor,clone}` → bloccano input finché non applichi/annulli. `INSTANT_KINDS = {laser,vortex,shuffle,wall}` → effetto immediato (`src/lib/types.ts:73`).

### 5.3 Pending mode — flusso UX
1. Entri in `pendingMode` scivolando su o **tappando** lo speciale (`move:279`, `tapSpecial:405`).
2. Griglia con ring colorato, tutti i blocchi evidenziati (tranne bombColor che dimma i colori non-target, `src/App.svelte:771`), banner `PendingBanner` con `Esc` per annullare.
3. Tap su un blocco → `applyPending(blockId)` (`src/lib/engine.ts:469`). Annullabile con `cancelPending()` (`Esc`).
4. Durante pending: `move`, `tapSpecial`, `spawnBonus`, `triggerMalus/Clutter`, `virus` sono **bloccati** (`src/lib/game.svelte.ts:204,236,310`).

### 5.4 Tap diretto sugli speciali
Alternativa allo slide: tap sullo speciale stesso (`src/lib/engine.ts:379`). Wall tap = 1 danno; altri = effetto identico allo slide.

---

## 6. Muri

- **Spawn**: come speciale `wall` (12s, `wallHp:2`) oppure da malus `wallAmbush` (2 muri, vedi §7).
- **HP 2**: Primo colpo (`move` con `hitWall` o `tapSpecial` su wall) → `hp 1`, blocco resta su `beforeX/Y`. Secondo colpo → muro distrutto e blocco avanza su `finalX/Y` (`src/lib/engine.ts:255,389`).
- **Scoring**: rompere un muro dà combo (`onMerge`) e conta per missioni/achievement `wall_break` (`src/lib/game.svelte.ts:349`).
- **Hint**: al primo wall spawna pop `Muro 2♥!` (`src/App.svelte:234`).

---

## 7. Sistema Malus — difficoltà automatica

### 7.1 Scheduler
`GameScheduler` (`src/services/scheduler.ts:61,78`):

| Timer | Intervallo | Grace iniziale |
|---|---|---|
| `malus` (generico) | `15000–25000 ms` random | `30000 ms + 0–4000 ms` |
| `clutter` (dedicato) | `12000 ms ±2000 ms` | `8000 ms + 0–2000 ms` |
| Effetto | `pickRandomMalusKind()` (vedi sotto) | `malus_clutter` fisso (1–3 blocchi) |

Pesi `pickRandomMalusKind()` (`src/lib/engine.ts:718`):
```
shuffle 15% | fog 13% | freeze 13% | tax 13% | wall 10% | halve 12% | clutter 12% | invert 6% | decay 6%
```

Entrambi pausati come i bonus (pending, gameOver, freeze, `view !== game`). Se in pausa, ritentano ogni 1s.

### 7.2 Attivazione e blocco
`engine.canApplyMalus()` (`src/lib/engine.ts:542`): bloccato se `gameOver` o `pendingMode`.
`isFrozen()` blocca TUTTO l'input (`doMove`, `tapSpecial`, `triggerMalus/Clutter`).

### 7.3 9 Malus nel dettaglio

| Kind | Icona | Durata | Tipo | Effetto dettagliato | `MALUS_DURATION_MS` |
|---|---|---|---|---|---|
| `malus_shuffle` | 🔀 | istant (flash 1.2s) | istant | Rimescola i blocchi (come shuffle) | `0` |
| `malus_fog` | 🌫️ | 5s | timed | Overlay `backdrop-blur + bg-stone/20` (`App.svelte:754`), blocchi `blur-[2px] opacity-60` | `5000` |
| `malus_freeze` | ❄️ | 3s | timed | **Blocca input**: overlay `bg-sky/25 + GHIACCIATO!` (`App.svelte:749`), `drag` azzerato, scheduler in pausa | `3000` |
| `malus_tax` | 💸 | istant | istant | `-15` punti (`GAME_CONFIG.malusTaxFlat`), `max(0, score-15)` | `0` |
| `malus_wallAmbush` | 🧱 | istant | istant | Spawna **2 muri** (2 HP, 12s) in celle libere random | `0` |
| `malus_halve` | ✂️ | istant | istant | Dimezza il blocco col valore più alto (se più candidati, random). `max(1, floor(v/2))`. Preferisce `value>1`. | `0` |
| `malus_clutter` | 📦 | istant | istant | Spawna **1–3 blocchi** valore 1 colore random (`clutterMin/Max`). GameOver se riempie. | `0` |
| `malus_invert` | ↔️ | 6s | timed | Inverte direzioni input + preview. Banner `CONTROLLI INVERTITI!` | `6000` |
| `malus_decay` | 🦠 | 8s | timed | **Punteggio dimezzato**: `gain = floor(gain*0.5)` su merge e su esplosione pending x2 (`engine.ts:320,488`). Badge `MARCIO -50%`. | `8000` |

Timed malus tiene `activeMalus = {kind, endsAt: now+dur}`; istant tiene `endsAt: now+1200ms` solo per flash `MalusBanner` (`src/lib/engine.ts:567`), poi `tickMalus()` lo pulisce ogni 100 ms.

### 7.4 Banner e feedback
`MalusBanner.svelte` mostra countdown `endsAt - now` per i timed; burst particellare + `sfx.error()` + vibrazione + `scorePop` dedicato (`src/App.svelte:147`) per ogni kind.

---

## 8. Punteggio e Combo

### 8.1 ComboState (`src/core/combo/ComboState.ts`)

- `combo`: 0 all'avvio / su `onMiss()`. `chainDepth = prevCombo`.
- `onMerge(now)`: `combo++`, `chain = 1 + min(chainDepth*0.5, 3)` → max chain bonus **3** (cioè max `×4` di chain). `timeBonus = 1.5` se `now - lastAt < 2500 ms` (`COMBO_WINDOW_MS`), altrimenti `1`. `multiplier = chain * timeBonus`. Esempio: combo 1→×1, combo 2 veloce→×2.25, combo 4 veloce→×3.75.
- `peekMultiplier(now)`: stessa formula ma con `combo` corrente (prima di incrementare) — usato per **pre-calcolare** il gain del merge in `engine.move(blockId, dir, peek)` così il punteggio è già moltiplicato (`src/lib/game.svelte.ts:321,324`).
- `onMiss()`: reset a 0 su **mossa slide vuota** o muro solo crepato (`src/lib/game.svelte.ts:335,380`), o tap/mossa fallita (`onMiss` in `doMove` else branch).

### 8.2 Buff missioni e permMult achievement
`game.comboMult` (`src/lib/game.svelte.ts:106`):
```
if buffActive  → combo.multiplier() * 1.5
else           → combo.multiplier() + permMult
```
- `buffActive`: 5s dopo aver completato una missione (`activateBuff()`, `src/lib/game.svelte.ts:60`, `MISSION_REWARD.buffMult:1.5`, `GAME_CONFIG.missionRewardMultiplier`).
- `permMult`: somma dei `permMult` degli achievement completati che lo prevedono (`explosion_3:0.05`, `combo_4:0.05`), **capped 0.1** (`src/core/achievements/AchievementManager.ts:103`).

### 8.3 Flusso scoring completo (`game.svelte.ts:doMove / applyPending`)
1. `peek = combo.peekMultiplier(now) + permMult` (o `*1.5` se buff).
2. `engine.move(id, dir, peek)` calcola `gain = round(sum * peek)` (o `*0.5` se decay).
3. Se scoring (`merged/hitSpecial/exploded/wallDestroyed`) → `combo.onMerge(now)` e salva `res.combo/multiplier`; altrimenti `combo.onMiss()`.

---

## 9. Missioni

Pool di **12 template** (`src/core/config/achievements.ts:44`, `MISSION_POOL`):

| ID | Label | Kind | Target | Difficoltà |
|---|---|---|---|---|
| `merge_red_3` | Fondi 3 rossi | `merge_color` (red) | 3 | easy |
| `merge_green_3` | Fondi 3 verdi | `merge_color` (green) | 3 | easy |
| `merge_total_4` | Fai 4 fusioni | `merge_total` | 4 | easy |
| `wall_break_1` | Rompi 1 muro | `wall_break` | 1 | easy |
| `value_16` | Crea valore 16 | `value_reach` (≥16) | 1 | med |
| `special_vortex` | Usa 1 vortex/shuffle | `special_use` | 1 | med |
| `combo_3` | Combo x3 | `combo` (≥3) | 3 | med |
| `clone_use_1` | Usa 1 clone | `clone_use` | 1 | med |
| `explosion_32` | Esplosione 32! | `explosion` | 1 | hard |
| `diagonal_2` | 2 fusioni diagonali | `diagonal` | 2 | hard |
| `jolly_use_1` | Usa 1 jolly | `jolly_use` | 1 | hard |
| `bomb_use_1` | Usa 1 bomba colore | `bomb_use` | 1 | hard |

- **Selezione run**: 1 easy + 1 med + 1 hard random (`rollMissions`, `src/core/achievements/AchievementManager.ts:31`), senza duplicati. `MissionBar.svelte` le mostra.
- **Avanzamento**: `manager.track(event, score)` incrementa `progress` in base a `event.type` (`merge/special/wall_break/explosion`). Combo usa `max(combo)` (`src/core/achievements/AchievementManager.ts:170`).
- **Completamento**: `progress >= scaledTarget` → toast `+80 score / +15 coins / x1.5 5s` (`GAME_CONFIG.missionReward*`, `src/lib/game.svelte.ts:68`), `activateBuff()`, `coins +=15` dentro `track` (`AchievementManager.ts:225`), reroll immediato con altra missione della stessa difficoltà evitando duplicati (`src/core/achievements/AchievementManager.ts:208`).
- **Scaling soft** (`scaledTarget`, `src/core/config/achievements.ts:93`): per kind count-based (`merge_color/merge_total/wall_break/diagonal/jolly/clone/bomb/special_use`) → `+1` se `score>=300`, `+2` se `score>=600`. `value_reach/explosion/combo` non scalano.

---

## 10. Achievement (traguardi globali, persistenti)

6 achievement (`src/core/config/achievements.ts:69`, `ACHIEVEMENTS`):

| ID | Label | Descrizione | Target | Ricompensa | permMult |
|---|---|---|---|---|---|
| `merge_50` | Fonditore | 50 fusioni totali | 50 | +150 score / +30🪙 | — |
| `value_16_5` | Artigiano | Crea 5× valore 16 | 5 | +150 / +30🪙 | — |
| `explosion_3` | Demolitore | 3 esplosioni 32 | 3 | +150 / +30🪙 | **+0.05** |
| `combo_4` | Catena | Combo x4 una volta | 1 | +150 / +30🪙 | **+0.05** |
| `special_15` | Collezionista | Usa 15 speciali | 15 | +150 / +30🪙 | — |
| `wall_10` | Muratore | Rompi 10 muri | 10 | +150 / +30🪙 | — |

- Counters cumulativi cross-run (`totalMerges`, `totalValue16`, `totalExplosions`, `totalSpecials`, `totalWalls`, `maxComboEver`, `src/core/achievements/AchievementManager.ts:43`).
- `track()` aggiorna `progress = min(cur, target)` (eccetto `combo_4` 0/1) e su completamento setta `completedAt` + `coins += rewardCoins` (`src/core/achievements/AchievementManager.ts:135`).
- `permMult()` somma i bonus e cappa a **0.1** (`src/core/achievements/AchievementManager.ts:103`) → applicato in `game.comboMult`.

---

## 11. Shop e valuta

- **Coins** (`🪙`): guadagnati da missioni (+15) e achievement (+30). Persistiti in `achievementManager.coins` e `snapshot()` (`src/core/achievements/AchievementManager.ts:225,148`).
- **Shop** (`src/core/shop/shopConfig.ts:9`, `SHOP_ITEMS`):
  - `theme_midnight` 100🪙, `theme_sunset` 80🪙, `border_rainbow` 60🪙 — cosmetici.
  - `purchaseShopItem(itemId, price)` scala coins solo se non posseduto e abbastanza fondi; attiva subito il tema (`src/lib/game.svelte.ts:499`).
  - `shopOwned: string[]`, `shopActive: string|null` persistiti (`src/services/persistence.ts:79`).

---

## 12. Sistema di gioco — Input e UX

| Input | Comportamento | File |
|---|---|---|
| **Drag swipe** su Tile | `pointerdown → pointermove → pointerup`. Threshold 28px: sotto = tap (selezione), sopra = swipe + `doMove`. Durante pending: tap su blocco = `applyPending`. Swipe azzera `selectedId`. | `src/App.svelte:441,464` |
| **Tap Tile** | Alterna `selectedId` → mostra anello + **8 frecce direzionali** attorno alla cella (`DIRS` overlay, `src/App.svelte:734`). Tap freccia → `handleTapDir(dir) → doMove`. | `src/App.svelte:321,329` |
| **Tap Speciale** | `tapSpecial(specialId)` — vedi §5.4. Bloccato in pending/freeze/gameOver. | `src/App.svelte:562` |
| **Ghost preview** | Evidenzia `path` + `label` finale durante drag. | `src/App.svelte:626` |
| **Undo** | Singola mossa (`history = [snapshot]`). Ripristina `grid/score/gameOver/pending/activeMalus` + `comboSnapshot`. Bottone + `Ctrl/Cmd+Z`. Disabilitato in pending/freeze/gameOver. | `src/lib/engine.ts:105,112` / `src/lib/game.svelte.ts:290,378` |
| **Esc** | Priorità: chiude `PauseSheet` > annulla `pendingMode` > torna al menu | `src/App.svelte:381` |
| **`N`** (new game) | Solo se non in pending | `src/App.svelte` (legacy help) |
| **`M`** | Mute toggle (`sfx.toggleMute()`) | `src/App.svelte:374` |
| **`?`** | Help overlay | `src/App.svelte:387` |
| **Menu/Pausa** | `TitleMenu` (new/continue se save valido, leaderboard, shop, credits, help, mute) + `PauseSheet` (resume/restart/exit + grille achievement) | `src/App.svelte:675` |

Feedback sensoriali: `sfx.*` (merge/move/error/explode/shuffle/laser/vortex/wallHit/wallBreak/pending/bonus…), `navigator.vibrate` su merge/combo/malus, `shake` + `flash` su errore/esplosione, `scorePops`, `ParticleLayer.burstAt`.

---

## 13. Game Over, Leaderboard, Persistenza, PWA

### Game Over
`freeCells().length === 0` dopo `move / applyPending / tapSpecial(laser) / malus_clutter / malus_wallAmbush` → `engine.gameOver = true` → overlay con `score/best/blocks/maxTile` + Rigioca/Menu + Condividi (`navigator.share` o clipboard) (`src/App.svelte:794`). Su `gameOver` → `pushScore(score, maxTile)` in leaderboard (`src/App.svelte:210`, `src/services/leaderboard.ts`).

### Undo limitato
Solo **ultima mossa** (`pushHistory` sovrascrive). `undo` ripristina anche `combo` dal `comboHistory` dedicato (`src/lib/game.svelte.ts:118,293`).

### Persistenza
- Chiave `tilemama-save-v3` (lettura legacy `v2/v1`), validazione **zod** (`src/services/persistence.ts:58`), migrate:
  - `pendingMultiplier → pendingMode`, drop pending obsoleti (`div2/virus/safeX5`), remap speciali obsoleti (`div2→x2`, `magnet→shuffle`, `virus→clone`, `safeX5/star→clone/drop`), sanitizza `wall.hp`, `activeMalus`, scarta malus scaduti (`src/services/persistence.ts:104`, `src/lib/engine.ts:656`).
  - Salvataggio debounced **50 ms** via `setTimeout` (`src/lib/game.svelte.ts:121`), flush immediato su `purchaseShopItem/setShopActive` (`persistNow`).
  - `QuotaExceededError` silenziato.
- Alla ripresa (`initGame` → `loadPersisted`): `engine.fromJSON` + `achievementManager.restore` + `shopOwned/Active`; se `activeMissions` vuoto → `initRun(score)` (`src/lib/game.svelte.ts:151`).

### Scheduler pause/resume
`$effect` in `App.svelte:201`: `paused = view !== 'game' || !!pendingMode || !!gameOver || showPause || isFrozen`. `GameScheduler.stop()` su `onDestroy` e cleanup `visibilitychange` (`src/services/scheduler.ts:110`).

### Leaderboard locale
`localStorage` separato (`src/services/leaderboard.ts`), `loadLeaderboard / pushScore`, mostrato in `Leaderboard.svelte`.

### Build & PWA
Vite `base` = `BASE_PATH ?? '/tilemama/'`, `prebuild` genera sprites via `sharp` (`scripts/build-sprites.mjs`), `vite-plugin-pwa` con `includeAssets: ['favicon.svg','fonts/*.woff2','sprites/*']` (`vite.config.ts`). Deploy GitHub Pages con `404.html` fallback (`AGENTS.md`).

---

## 14. Tuning centralizzato — `GAME_CONFIG`

Tutti i numeri tuning in un unico posto (`src/core/config/gameConfig.ts`) — non hardcodare:

```ts
gridSize:8, initialBlocksPerColor:4, explosionValue:32, explosionSpawnCount:4,
bonusMinDelayMs:6500, bonusMaxDelayMs:10500,
specialDurationMs:9000, wallDurationMs:12000, wallHp:2,
virusIntervalMs:3000, cleanupIntervalMs:250, virusTickMs:1000,
malusMinDelayMs:15000, malusMaxDelayMs:25000, malusGraceMs:30000,
malusFreezeMs:3000, malusFogMs:5000, malusInvertMs:6000, malusDecayMs:8000,
malusTaxFlat:15, malusWallCount:2, malusClutterCount:3,
clutterIntervalMs:12000, clutterGraceMs:8000, clutterMin:1, clutterMax:3,
missionsPerRun:3, missionRewardScore:80, missionRewardCoins:15, missionRewardMultiplier:1.5,
missionAllBonusScore:300, missionAllBonusCoins:50,
achievementRewardCoins:30, achievementRewardScore:150
```

---

## 15. Diagramma di flusso mossa (sintesi)

```
input (drag swipe / tap freccia / tap speciale)
  → [isFrozen / pendingMode / gameOver ? blocca]
  → [isInverted ? inv(dir)]
  → engine.pushHistory() + combo.snapshot()
  → resolveMove → {wall|special|merge|slide|none}
  → branch:
     wall: hp-1 ? resta : distrutto → combo.onMerge / onMiss
     special: pending? → pendingMode | instant → applyLaser/Vortex/Shuffle+score
     merge: removeTarget → sum → gain*multiplier(→*0.5 se decay) → score+=gain → explosion? → check gameOver → combo.onMerge
     slide: posiziona → onMiss (slide vuota o muro crepato = onMiss) → check gameOver
  → track achievement/mission (+buff/+coins/+reroll)
  → sync() + persist() + bump version/specialsTick → UI tick
```

---

*Per modifiche al bilanciamento: aggiornare solo `src/core/config/gameConfig.ts` e `pickRandomBonusKind/MalusKind` weights in `src/lib/engine.ts:705,718`.*
