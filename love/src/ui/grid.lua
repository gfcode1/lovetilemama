local config = require("src.config")
local Theme = require("src.ui.theme")
local Emoji = require("src.ui.emoji")
local FX = require("src.ui.fx")
local G = {}
local images = {}
local specialImages = {}

local fontCache = {}
local function getFont(sz)
  if not fontCache[sz] then fontCache[sz] = love.graphics.newFont(sz) end
  return fontCache[sz]
end

function G.loadImages()
  for _, c in ipairs(config.COLORS) do
    images[c] = {}
    local dir = config.COLOR_TO_DIR[c]
    for _, v in ipairs({1, 2, 4, 8, 16, 32}) do
      local path = dir .. "/" .. v .. ".png"
      if love.filesystem.getInfo(path) then
        local ok, img = pcall(love.graphics.newImage, path)
        if ok then images[c][v] = img end
      end
    end
    if not images[c][32] and images[c][16] then images[c][32] = images[c][16] end
  end
  local map = {
    grow = "x2_nobg_cropped.png",
    laser = "laser_nobg_cropped.png", jolly = "rainbow_nobg_cropped.png",
    clone = "clone_nobg_cropped.png", wall = "wall_nobg_cropped.png",
    levelup = "levelup_nobg_cropped.png", leveldown = "leveldown_nobg_cropped.png",
    rain = "rain_nobg_cropped.png", invert = "invert_nobg_cropped.png",
    minigame = "minigame_nobg_cropped.png",
    points = "points_nobg_cropped.png",
    points_1 = "points_100_nobg_cropped.png",
    points_2 = "points_200_nobg_cropped.png",
    points_3 = "points_300_nobg_cropped.png",
  }
  for k, fn in pairs(map) do
    local p = "assets/speciali/" .. fn
    if love.filesystem.getInfo(p) then
      local ok, img = pcall(love.graphics.newImage, p)
      if ok then specialImages[k] = img end
    end
  end
  if love.filesystem.getInfo("assets/speciali/crackedwall_nobg_cropped.png") then
    local ok, img = pcall(love.graphics.newImage, "assets/speciali/crackedwall_nobg_cropped.png")
    if ok then specialImages["wall_cracked"] = img end
  end
  -- Icona dedicata allo speciale "minigame" quando il gioco estratto e whack.
  if love.filesystem.getInfo("assets/minigiochi/whack/icon.png") then
    local ok, img = pcall(love.graphics.newImage, "assets/minigiochi/whack/icon.png")
    if ok then specialImages["minigame_whack"] = img end
  end
  -- Icona dedicata allo speciale "minigame" quando il gioco estratto e memo.
  if love.filesystem.getInfo("assets/minigiochi/memo/icon.png") then
    local ok, img = pcall(love.graphics.newImage, "assets/minigiochi/memo/icon.png")
    if ok then specialImages["minigame_memo"] = img end
  end
  -- Riusa le sprite della board in toast/banner (Emoji.draw).
  for _, name in ipairs({ "levelup", "minigame", "minigame_whack", "minigame_memo", "points", "points_1", "points_2", "points_3" }) do
    if specialImages[name] then Emoji.register(name, specialImages[name]) end
  end
end

local SPECIAL_BG = {
  laser     = {{1, 0.97, 0.82}, {1, 0.93, 0.70}},
  grow      = {{0.86, 0.95, 1},  {0.78, 0.90, 1}},
  jolly     = {{0.94, 0.90, 1},  {0.88, 0.84, 1}},
  clone     = {{0.86, 1, 0.90},  {0.78, 0.95, 0.84}},
  levelup   = {{1, 0.96, 0.80},  {1, 0.88, 0.66}},
  points    = {{1, 0.92, 0.72},  {1, 0.84, 0.58}},
  minigame  = {{0.90, 0.86, 1},  {0.80, 0.74, 1}},
}

-- Tinta delle stelline: identifica il tipo di bonus e distingue le tile speciali
-- dalle tile normali (che hanno solo alone/riflesso).
local SPARKLE_COL = {
  laser     = {1, 0.95, 0.55},
  grow      = {0.62, 0.90, 1},
  jolly     = {0.85, 0.75, 1},
  clone     = {0.60, 1, 0.78},
  levelup   = {1, 0.90, 0.50},
  points    = {1, 0.86, 0.45},
  minigame  = {0.78, 0.68, 1},
}
local SPARKLE_GOLD = {1, 0.92, 0.45}

-- ═══════════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════════
function G.draw(engine, layout, selectedId, ghost, pendingMode)
  local cs = layout.cellSize
  local t = love.timer.getTime()
  FX.observe(engine)

  -- ── Grid container: pannello "vetro" traslucido ──
  local gx, gy = layout.offsetX - 8, layout.offsetY - 8
  local gw, gh = layout.gridPixelW + 16, layout.gridPixelH + 16
  local st = Theme.stageMain
  Theme.softShadow(gx, gy, gw, gh, Theme.radius.card, 0.7, {0.10, 0.06, 0.22})

  -- gradiente traslucido + luce arena + profondità, mascherati agli angoli
  love.graphics.stencil(function()
    love.graphics.rectangle("fill", gx, gy, gw, gh, Theme.radius.card, Theme.radius.card)
  end, "replace", 1)
  love.graphics.setStencilTest("greater", 0)
  Theme.verticalFade(gx, gy, gw, gh, st.top, st.bot, 24)
  local glowA = FX.motion and (0.10 + 0.04 * math.sin(t * 1.4)) or 0.12
  love.graphics.setBlendMode("add")
  Theme.verticalFade(gx, gy, gw, gh * 0.36,
    {st.glow[1], st.glow[2], st.glow[3], glowA},
    {st.glow[1], st.glow[2], st.glow[3], 0}, 12)
  love.graphics.setBlendMode("alpha")
  Theme.verticalFade(gx, gy + gh * 0.78, gw, gh * 0.22, {0, 0, 0, 0}, {0, 0, 0, 0.28}, 10)
  love.graphics.setStencilTest()

  -- bordo
  love.graphics.setColor(st.edge[1], st.edge[2], st.edge[3], st.edge[4])
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", gx, gy, gw, gh, Theme.radius.card, Theme.radius.card)
  love.graphics.setLineWidth(1)

  -- ── Cells, content, blocks, FX ──
  love.graphics.push()
  local sdx, sdy, srot = FX.shakeOffset()
  if srot and srot ~= 0 then
    local gcx = layout.offsetX + layout.gridPixelW / 2
    local gcy = layout.offsetY + layout.gridPixelH / 2
    love.graphics.translate(gcx + sdx, gcy + sdy)
    love.graphics.rotate(srot)
    love.graphics.translate(-gcx, -gcy)
  else
    love.graphics.translate(sdx, sdy)
  end

  -- ── Cells (scacchiera scura, come il field dei minigame) ──
  for y = 0, config.GRID_H - 1 do
    for x = 0, config.GRID_W - 1 do
      local rx, ry = layout.offsetX + x * cs, layout.offsetY + y * cs
      local c = ((x + y) % 2 == 0) and st.cell or st.cellAlt
      Theme.rrSolid(rx + 1, ry + 1, cs - 2, cs - 2, Theme.radius.cell, c)
      Theme.set(st.gridLine)
      love.graphics.rectangle("line", rx + 1, ry + 1, cs - 2, cs - 2, Theme.radius.cell, Theme.radius.cell)
    end
  end

  -- ── Ghost preview ──
  if ghost and ghost.path then
    local dashOffset = t * 40
    local ghostCol = Theme.withAlpha(Theme.accent, 0.3)
    for i, p in ipairs(ghost.path) do
      local rx, ry = layout.offsetX + p.x * cs, layout.offsetY + p.y * cs
      Theme.rrSolid(rx + 2, ry + 2, cs - 4, cs - 4, 10, Theme.withAlpha(Theme.accent, 0.12))
      Theme.drawDashedLine(rx + 2, ry + 2, rx + cs - 2, ry + 2, 6, 4, dashOffset, ghostCol, 2)
      Theme.drawDashedLine(rx + 2, ry + 2, rx + 2, ry + cs - 2, 6, 4, dashOffset, ghostCol, 2)
      Theme.drawDashedLine(rx + cs - 2, ry + 2, rx + cs - 2, ry + cs - 2, 6, 4, dashOffset, ghostCol, 2)
      Theme.drawDashedLine(rx + 2, ry + cs - 2, rx + cs - 2, ry + cs - 2, 6, 4, dashOffset, ghostCol, 2)
    end
    -- Final cell badge
    if ghost.kind and ghost.kind ~= "none" then
      local fx, fy = ghost.finalX, ghost.finalY
      if fx and fy then
        local rx, ry = layout.offsetX + fx * cs, layout.offsetY + fy * cs
        local badgeR = cs * 0.36
        Theme.drawGlowRing(rx + cs / 2, ry + cs / 2, badgeR, Theme.accent, t)
        Theme.rrSolid(rx + cs / 2 - badgeR, ry + cs / 2 - badgeR,
          badgeR * 2, badgeR * 2, badgeR, {1, 1, 1, 0.92})
        Theme.set(Theme.borderAccent)
        love.graphics.circle("line", rx + cs / 2, ry + cs / 2, badgeR)
        local map = {merge = "boom", special = "star", wall = "wall"}
        local ename = map[ghost.kind]
        if ename then
          Emoji.draw(ename, rx + cs / 2, ry + cs / 2, math.min(26, cs * 0.55), 1)
        elseif ghost.kind == "slide" then
          Theme.set(Theme.accent)
          love.graphics.setFont(getFont(14))
          love.graphics.printf("→", rx, ry + cs / 2 - 8, cs, "center")
        end
      end
    end
  end

  -- ── Specials ──
  for _, sp in pairs(engine.specials) do
    local rx, ry = layout.offsetX + sp.x * cs, layout.offsetY + sp.y * cs
    local kind = sp.specialKind or "laser"
    local bgPair = SPECIAL_BG[kind] or {{1, 1, 1}, {0.98, 0.98, 0.98}}
    local cx, cy = rx + 2, ry + 2
    local cw, ch = cs - 4, cs - 4

    Theme.softShadow(cx, cy, cw, ch, Theme.radius.round, 0.6)
    Theme.roundRect(cx, cy, cw, ch, {
      r = Theme.radius.round,
      top = bgPair[1], bot = bgPair[2],
      border = Theme.borderLight, gh = ch * 0.35,
    })

    -- Idle "vivo": galleggiamento + micro-rotazione + alone pulsante
    local seed = (sp.id or 0) * 3 + 1
    local _, _, _, ioy, irot = FX.idleOffset(seed, t, 0.6)
    local pulse = 1 + 0.025 * math.sin(t * 2.6 + seed)
    local icx, icy = rx + cs / 2, ry + cs / 2

    love.graphics.setBlendMode("add")
    love.graphics.setColor(bgPair[1][1], bgPair[1][2], bgPair[1][3],
      0.14 + 0.08 * math.sin(t * 2.3 + seed))
    love.graphics.circle("fill", icx, icy, cs * 0.46)
    love.graphics.setBlendMode("alpha")

    -- Icon
    local img = specialImages[kind]
    if kind == "minigame" and sp.game == "whack" then
      img = specialImages["minigame_whack"] or img
    elseif kind == "minigame" and sp.game == "memo" then
      img = specialImages["minigame_memo"] or img
    end
    if kind == "points" then
      local lvl = sp.pointsLevel or 1
      img = specialImages["points_" .. lvl] or specialImages["points"] or img
    end
    if img then
      local iw, ih = img:getDimensions()
      local scale = math.min((cs + 4) / iw, (cs + 4) / ih)
      love.graphics.setColor(1, 1, 1)
      love.graphics.push()
      love.graphics.translate(icx, icy + ioy)
      love.graphics.rotate(irot * 1.6)
      love.graphics.scale(pulse, pulse)
      love.graphics.draw(img, 0, 0, 0, scale, scale, iw / 2, ih / 2)
      love.graphics.pop()
    elseif kind == "points" then
      local lvl = sp.pointsLevel or 1
      local val = config.POINTS_VALUES[lvl] or 100
      Theme.set(Theme.text)
      love.graphics.setFont(getFont(math.max(10, math.floor(cs * 0.30))))
      love.graphics.printf("+" .. val, rx, ry + cs / 2 - cs * 0.18 + ioy, cs, "center")
    else
      Theme.set(Theme.text)
      love.graphics.setFont(getFont(10))
      love.graphics.printf(kind, rx, ry + cs / 2 - 6 + ioy, cs, "center")
    end

    -- Stelline: rendono i bonus riconoscibili a colpo d'occhio
    FX.drawSparkles(icx, icy + ioy, cs * 0.5, seed, t,
      SPARKLE_COL[kind] or SPARKLE_GOLD, 1)

    -- Timer ring
    if sp.expiresAt then
      local remain = sp.expiresAt - love.timer.getTime()
      local durMs = (kind == "minigame")
        and (config.GAME_CONFIG.minigameSpecialDurationMs or config.GAME_CONFIG.specialDurationMs)
        or config.GAME_CONFIG.specialDurationMs
      local pct = math.max(0, remain / (durMs / 1000))
      Theme.drawRingProgress(rx + cs / 2, ry + cs / 2, cs * 0.44, pct, Theme.accent, nil, 3)
    end
  end

  -- ── Walls ──
  for _, w in pairs(engine.walls) do
    local rx, ry = layout.offsetX + w.x * cs, layout.offsetY + w.y * cs
    local cx, cy = rx + 2, ry + 2
    local cw, ch = cs - 4, cs - 4

    Theme.softShadow(cx, cy, cw, ch, Theme.radius.round, 0.8)
    Theme.roundRect(cx, cy, cw, ch, {
      r = Theme.radius.round,
      top = {1, 0.98, 0.96}, bot = {0.96, 0.92, 0.88},
      border = {0.82, 0.62, 0.45, 0.3},
    })

    local img = w.hp == 1 and specialImages["wall_cracked"] or specialImages["wall"]
    if img then
      local iw, ih = img:getDimensions()
      local scale = math.min((cs + 4) / iw, (cs + 4) / ih)
      -- idle sottile; il muro crepato (hp 1) vibra leggermente
      local wseed = (w.id or 0) * 5 + 2
      local _, _, _, ioy, irot = FX.idleOffset(wseed, t, 0.5)
      local jx = 0
      if w.hp == 1 then
        jx = math.sin(t * 30 + wseed) * 0.8
        irot = irot + math.sin(t * 26 + wseed) * 0.02
      end
      love.graphics.setColor(1, 1, 1)
      love.graphics.push()
      love.graphics.translate(rx + cs / 2 + jx, ry + cs / 2 + ioy)
      love.graphics.rotate(irot)
      love.graphics.draw(img, 0, 0, 0, scale, scale, iw / 2, ih / 2)
      love.graphics.pop()
    end

    -- Timer ring
    if w.expiresAt then
      local remain = w.expiresAt - love.timer.getTime()
      local dur = config.GAME_CONFIG.wallDurationMs / 1000
      local pct = math.max(0, remain / dur)
      Theme.drawRingProgress(rx + cs / 2, ry + cs / 2, cs * 0.44, pct, {0.82, 0.62, 0.45}, nil, 3)
    end
  end

  -- ── Blocks (candy shell, full cell) ──
  for _, b in pairs(engine.blocks) do
    local rx, ry = layout.offsetX + b.x * cs, layout.offsetY + b.y * cs
    local isSel = (b.id == selectedId)
    local cx, cy = rx + cs / 2, ry + cs / 2

    -- FX per-block transform (value/color guidano l'idle "vivo")
    local fx = FX.get(b.id, cs, t, b.value, b.color)

    local top, bot, dark = Theme.candy.greenBg, Theme.candy.green, Theme.candy.greenDark
    if b.color == "red" then
      top, bot, dark = Theme.candy.redBg, Theme.candy.red, Theme.candy.redDark
    elseif b.color == "yellow" then
      top, bot, dark = Theme.candy.yellowBg, Theme.candy.yellow, Theme.candy.yellowDark
    elseif b.color == "blue" then
      top, bot, dark = Theme.candy.blueBg, Theme.candy.blue, Theme.candy.blueDark
    end

    local bx, by = rx + 3, ry + 3
    local bw, bh = cs - 6, cs - 6

    -- ── Scia di movimento (ghost copies dietro al blocco che slitta) ──
    if fx.trail and #fx.trail > 0 then
      for _, g in ipairs(fx.trail) do
        Theme.rrSolid(bx + g.ox, by + g.oy, bw, bh, Theme.radius.block,
          {bot[1], bot[2], bot[3], g.alpha})
      end
    end

    -- ── Alone di apparizione ──
    if fx.spawnGlow and fx.spawnGlow > 0.05 then
      local a = fx.spawnGlow
      Theme.set({1, 1, 1, 0.35 * a})
      love.graphics.setLineWidth(2 + 2 * a)
      love.graphics.circle("line", cx, cy, cs * 0.5 + (1 - a) * cs * 0.45)
      love.graphics.setLineWidth(1)
    end

    -- ── Trasformazione blocco (include respiro selezione) ──
    local breath = isSel and (math.sin(t * 4.2) * FX.CFG.selBreath) or 0
    local sx = fx.sx + breath
    local sy = fx.sy - breath * 0.5
    local lift = (fx.lift or 0) + (isSel and 3 or 0)

    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(fx.rot)
    love.graphics.scale(sx, sy)
    love.graphics.translate(-cx + fx.ox, -cy + fx.oy - lift)

    -- alone pulsante per i tile di valore alto (dietro il corpo)
    if fx.aura and fx.aura > 0.01 then
      local a = fx.aura
      love.graphics.setBlendMode("add")
      for gi = 3, 1, -1 do
        love.graphics.setColor(bot[1], bot[2], bot[3], a * (0.05 + 0.03 * gi))
        love.graphics.circle("fill", cx, cy, cs * (0.38 + 0.06 * gi))
      end
      love.graphics.setBlendMode("alpha")
      love.graphics.setColor(1, 1, 1)
    end

    if isSel then
      Theme.drawGlowRing(rx + cs / 2, ry + cs / 2, cs / 2, Theme.accent, t)
    end

    if pendingMode then
      Theme.rrSolid(rx + 1, ry + 1, cs - 2, cs - 2, Theme.radius.block, Theme.withAlpha(Theme.candy.green, 0.15))
    end

    -- 3D shadow (più ampia e distanziata durante il drag)
    if fx.dragging then
      Theme.softShadow(bx + 4, by + 9, bw, bh, Theme.radius.block, 0.55)
    else
      Theme.softShadow(bx, by, bw, bh, Theme.radius.block, 0.5)
    end
    -- Gradient candy body
    Theme.rrGradient(bx, by, bw, bh, Theme.radius.block, top, bot, bh * 0.38)
    -- Bottom edge (darker for weight)
    Theme.set(dark, 0.15)
    love.graphics.rectangle("fill", bx + 3, by + bh - 4, bw - 6, 3, 2, 2)

    -- PNG image (più grande, con micro-vita idle)
    local img = images[b.color] and images[b.color][b.value]
    if img then
      local iw, ih = img:getDimensions()
      local scale = math.min((cs + 22) / iw, (cs + 22) / ih)
      local bob, srot, spulse = 0, 0, 1
      if FX.motion then
        local ph = (b.id or 0) * 0.7
        bob = math.sin(t * 2.1 + ph) * 1.7
        srot = math.sin(t * 1.6 + ph) * 0.05
        spulse = 1 + math.sin(t * 2.6 + ph) * 0.045
      end
      love.graphics.setColor(1, 1, 1)
      love.graphics.push()
      love.graphics.translate(rx + cs / 2, ry + cs / 2 - 1 + bob)
      love.graphics.rotate(srot)
      love.graphics.scale(spulse, spulse)
      love.graphics.draw(img, 0, 0, 0, scale, scale, iw / 2, ih / 2)
      love.graphics.pop()
    end

    -- Jolly indicator (bigger, con leggero galleggiamento)
    if b.jolly then
      local jbob = math.sin(t * 3 + b.id) * 1.3
      Emoji.draw("rainbow", rx + cs / 2, ry + 12 + jbob, math.floor(cs * 0.5), 1)
    end

    -- ── Sheen diagonale (riflesso vivo) mascherato al corpo del tile ──
    if fx.sheen and fx.sheen >= 0 then
      local sp = (fx.sheen + t * FX.CFG.sheenSpeed) % 1
      local bandW = math.max(6, bh * 0.45)
      local shx = bx - bandW + sp * (bw + 2 * bandW)
      love.graphics.stencil(function()
        love.graphics.rectangle("fill", bx, by, bw, bh, Theme.radius.block, Theme.radius.block)
      end, "replace", 1)
      love.graphics.setStencilTest("greater", 0)
      love.graphics.setBlendMode("add")
      love.graphics.push()
      love.graphics.translate(shx, cy)
      love.graphics.rotate(0.5)
      love.graphics.setColor(1, 1, 1, 0.14)
      love.graphics.rectangle("fill", -bandW / 2, -cs, bandW, cs * 2)
      love.graphics.pop()
      love.graphics.setBlendMode("alpha")
      love.graphics.setStencilTest()
      love.graphics.setColor(1, 1, 1)
    end

    -- ── Flash (bianco al merge, rosso alla mossa invalida) ──
    if fx.flash and fx.flash > 0.01 then
      local fc = fx.flashCol or {1, 1, 1}
      Theme.rrSolid(bx, by, bw, bh, Theme.radius.block,
        {fc[1], fc[2], fc[3], math.min(1, fx.flash) * 0.65})
    end

    love.graphics.pop()
  end

  -- ── FX particles + shockwaves + laser flashes ──
  FX.drawClip(gx, gy, gw, gh, t)

  -- ── Directional arrows (bigger) ──
  if selectedId and not pendingMode then
    local blk = engine.blocks[selectedId]
    if blk then
      local cx = layout.offsetX + blk.x * cs + cs / 2
      local cy = layout.offsetY + blk.y * cs + cs / 2
      local dirs = {N = {0, -1}, S = {0, 1}, E = {1, 0}, W = {-1, 0},
                    NE = {1, -1}, NW = {-1, -1}, SE = {1, 1}, SW = {-1, 1}}
      local arrowR = math.max(14, math.floor(cs * 0.22))
      local arrowMap = {N = "arrow_up", S = "arrow_down", E = "arrow_right", W = "arrow_left",
                        NE = "arrow_ne", NW = "arrow_nw", SE = "arrow_se", SW = "arrow_sw"}

      for _, dname in ipairs(config.DIR_LIST) do
        local v = dirs[dname]
        local ax = cx + v[1] * (cs * 0.72)
        local ay = cy + v[2] * (cs * 0.72)

        -- Shadow + pill
        Theme.softShadow(ax - arrowR, ay - arrowR, arrowR * 2, arrowR * 2, arrowR, 0.4)
        Theme.rrGradient(ax - arrowR, ay - arrowR, arrowR * 2, arrowR * 2, arrowR,
          {1, 1, 1, 0.97}, {0.96, 0.94, 0.96, 0.97}, arrowR * 0.8)
        -- Border
        Theme.set(Theme.borderAccent)
        love.graphics.circle("line", ax, ay, arrowR)
        -- Arrow icon (bigger)
        local ename = arrowMap[dname]
        if ename then
          Emoji.draw(ename, ax, ay, math.floor(cs * 0.34), 1)
        end
      end
    end
  end

  love.graphics.pop() -- shake offset
end

-- Accessor used by minigames to reuse the tile sprites.
function G.tileImage(color, value)
  local set = images[color]
  if not set then return nil end
  return set[value] or set[16] or set[8] or set[4] or set[2] or set[1]
end

return G
