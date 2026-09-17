# Piano — Nuovo minigioco "MEMO" (Memory Match)

## 1. Concept proposti

| # | Nome | Meccanica in una riga | Perché | Costo |
|---|------|-----------------------|--------|-------|
| A | **MEMO** (consigliato) | Griglia di carte coperte: gira due carte, se hanno lo stesso sprite/value restano scoperte e fai punti | Ritmo riflessivo, si distingue nettamente da CATCH (reazione) e TALPA (click rapido). Riutilizza gli sprite esistenti, zero asset obbligatori | Basso |
| B | **TORRE** | Una tile oscilla in orizzontale in cima; tap per farla cadere e impilarla: più sei preciso, più punti; errori accumulano instabilità | Timing/precisione, sensazione "arcade" | Medio (fisica/stacking) |
| C | **SMISTA** | Sprite cadono dal alto; trascinali (o toccali) nel cesto del valore giusto prima che tocchino terra | Categorizzazione sotto pressione | Medio-alto (drag + 3-4 bin + collisioni) |

Il resto del documento dettaglia **MEMO (A)**. Se preferisci B o C dimmelo e riscrivo il piano sulla meccanica scelta (l'ossatura tecnica — registry, config, HUD, FX — resta identica).

## 2. MEMO — Regole di gioco

- Campo **4×5** (20 carte) centrato nello stage, carte coperte all'avvio.
- **10 coppie** costruite dai **10 simboli** disponibili: ogni simbolo appare esattamente due volte. Due carte sono "match" se hanno lo **stesso index**.
- Tap su una carta la gira. Alla seconda carta:
  - **match** → restano scoperte, `+ minigameMemoPointsPerMatch` (25) con moltiplicatore streak, `streak++`.
  - **mismatch** → restano visibili `flipBackMs` (700 ms) poi si ricoprono; `streak = 0`, penalità default 0.
- Nessun badge numerico sulle carte: il match è per immagine, il punteggio è a punti fissi.
- Timer: `minigameMemoDurationMs` (45 s). Allo scadere il gioco finisce e si incassa lo score.
- Se finisci tutte le coppie prima del tempo: **time bonus** = `timeLeft * minigameMemoTimeBonus` e fine anticipata.
- `getScore()` = punti partita; `caught` = coppie risolte (per il toast "+N tile" di `finishMinigame`).

## 3. Perché NON rompe nulla

Il flusso in `love/main.lua` è già generico:
- `startMinigame(name)` → `Minigames.start(name, layout)` → il modulo deve solo rispettare l'interfaccia.
- `activeMinigame.background` viene usato dal drawer; `:drawHUD()` viene chiamato se presente.
- Lo scheduler è in pausa durante il minigioco, `finishMinigame()` fa `engine:award(raw)` e mostra il toast.
- La barra di avanzamento/timer comune è già gestita da `drawMinigameHUD` (il ramo di default è usato solo se il modulo non espone `drawHUD`).

Quindi l'integrazione è: **1 file config**, **1 nuovo modulo**, **1 registro**, **1 def sprite**, **1 eventuale icona**.

## 4. Contratto modulo (`src/minigames/memo.lua`)

Interfaccia richiesta (vedi `whack.lua`/`falling.lua`):

```lua
M.new(layout)            -- costruisce lo stato, chiama setLayout
M:setLayout(layout)      -- ricalcola stage/cs/gx/gy (riusare il blocco di whack)
M:update(dt)
M:draw()
M:drawHUD(layout)        -- opzionale ma consigliato (HUD dedicato)
M:pointerpressed(x, y)
M:pointermoved(x, y)     -- opzionale (hover)
M:keypressed(key)        -- escape = finish
M:isFinished() -> bool
M:getScore() -> number
M.background             -- stringa: "campo" (o nuovo sfondo)
M.debugAuto              -- flag settato da main; auto-risolvi per screenshot
```

Stato suggerito:

```lua
self.cols, self.rows = GC.minigameMemoCols, GC.minigameMemoRows  -- 4,4
self.cards = {}          -- {col,row,index,value,faceUp,matched,flipT}
self.first, self.second  -- carte attualmente girate
self.flipBackT           -- countdown per ricoprire i mismatch
self.score, self.pairs, self.streak, self.bestStreak
self.elapsed, self.duration, self.finished, self.introT
self.fx = MUI.newEffects()
```

Punti d'attenzione:
- **Generazione coppie**: estrarre 8 indici da `Sprites.count(GAME)` con ripetizione permessa, duplicarli, mescolare le 16 posizioni con Fisher-Yates (`love.math.random`).
- **Input lock**: ignora tap su carta già scoperta/match o mentre `flipBackT > 0`.
- **Resize**: `setLayout` ricentra tutto; `refreshLayout()` in main chiama già `activeMinigame:setLayout(layout)`.
- **debugAuto**: ogni ~0.4 s gira una coppia libera (per gli screenshot `TILEMAMA_MG=memo`).

## 5. Config da aggiungere (`love/src/config.lua`)

In `M.GAME_CONFIG`:

```lua
-- minigame memo
minigameMemoCols = 4,
minigameMemoRows = 5,              -- 20 carte = 10 coppie
minigameMemoDurationMs = 45000,
minigameMemoFlipBackMs = 700,
minigameMemoTimeBonusPerSec = 15,
minigameMemoPointsPerMatch = 25,
minigameMemoMismatchPenalty = 0, -- 0 = nessuna penalità
```

Registrazione gioco (in fondo al file):

```lua
M.MINIGAME_KINDS = {"falling", "whack", "memo"}
M.MINIGAME_WEIGHTS = { falling = 0.45, whack = 0.30, memo = 0.25 }
```

## 6. Registro (`src/minigames/init.lua`)

```lua
local modules = {
  falling = "src.minigames.falling",
  whack = "src.minigames.whack",
  memo = "src.minigames.memo",
}
```

## 7. Sprite (`src/minigames/sprites.lua`)

Set dedicato con arte definitiva (10 carte):

```lua
local defs = {
  whack = { dir = "assets/minigiochi/whack", prefix = "mole_", count = 6 },
  falling = { dir = "assets/minigiochi/falling", prefix = "leaf_", count = 6 },
  memo = { dir = "assets/minigiochi/memo", prefix = "card_", count = 10 },
}
```

Gli asset stanno in `love/assets/minigiochi/memo/card_1..10.png` (+ `icon.png`).
`S.VALUES` è esteso a 10 tier (`1..512`) per dare un valore coerente a ogni indice
(whack/falling usano solo i primi 6; memo non mostra badge).

## 8. Icona dello speciale (`src/ui/grid.lua`)

Oggi `grid.lua` ha un'icona dedicata per `whack` e `memo`.

```lua
-- in loadImages()
if love.filesystem.getInfo("assets/minigiochi/memo/icon.png") then
  local ok, img = pcall(love.graphics.newImage, "assets/minigiochi/memo/icon.png")
  if ok then specialImages["minigame_memo"] = img end
end
-- nel loop speciali
if kind == "minigame" and sp.game == "memo" then
  img = specialImages["minigame_memo"] or img
end
```

Senza icona dedicata resta l'icona generica `minigame` già presente.

## 9. Asset opzionali (in ordine di priorità)

1. `assets/minigiochi/memo/icon.png` — icona speciale sulla board.
2. `assets/minigiochi/memo/card_1..6.png` — volti delle carte (altrimenti sprite riusati).
3. (Facoltativo) dorso carta: può essere disegnato via `Theme` senza PNG.
4. (Facoltativo) nuovo sfondo `assets/sfondi/memo.jpg` + entry in `Background` con scrim.

## 10. Verifica

- Syntax: `luac -p love/src/config.lua love/src/minigames/memo.lua love/src/minigames/init.lua` (Lua 5.1 compatibile con LÖVE/LuaJIT).
- Avvio: da root repo `love love`.
- Test mirato: `TILEMAMA_MG=memo love love` (avvia subito il minigioco; con `debugAuto` si compila un run).
- Screenshot: `TILEMAMA_MG=memo TILEMAMA_SHOTS=/tmp/opencode/shots_memo love love` → controlla `shot_mg.png` / `shot_mg2.png`.
- Bilanciamento: ritocca i soli valori in `config.lua` (nessuna modifica al codice).

## 11. Checklist implementativa

- [x] Aggiungere chiavi memo in `M.GAME_CONFIG` e registrare `memo` in `MINIGAME_KINDS`/`MINIGAME_WEIGHTS`
- [x] Creare `love/src/minigames/memo.lua` con l'interfaccia della §4
- [x] Aggiungere `memo` al registro in `love/src/minigames/init.lua`
- [x] Aggiungere la def `memo` in `sprites.lua` (riuso falling)
- [x] (Opz.) icona speciale in `grid.lua`
- [x] (Opz.) asset dedicati (icona + 10 carte in `love/assets/minigiochi/memo/`)
- [x] Verificare con `TILEMAMA_MG=memo` + screenshot e tarare `config.lua`
- [x] Aggiornare `minigames.md` con la descrizione di MEMO

> Stato: **implementato con asset definitivi**. Board 4×5 (10 coppie, usa tutti e 10 i simboli), nessun badge numerico, punteggio a punti fissi + streak, durata 45s. Arte in `love/assets/minigiochi/memo/card_1..10.png`, icona speciale `icon.png` (verificata sulla board). Verificato con `TILEMAMA_MG=memo` e `TILEMAMA_SPECIALS=1`.
