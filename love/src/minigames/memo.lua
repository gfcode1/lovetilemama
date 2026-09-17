-- MEMO minigame ("MEMO!").
-- A 4x4 board of face-down cards. Flip two: matching sprite/value cards stay
-- revealed and score points (with a combo streak); mismatches flip back after
-- a short delay. Clear the board before the timer for a time bonus.
-- Cards reuse the shared sprite sets (see minigames.sprites).
local config = require("src.config")
local Theme = require("src.ui.theme")
local Anim = require("src.ui.animations")
local Sprites = require("src.minigames.sprites")
local MUI = require("src.minigames.ui")

local Memo = {}
Memo.__index = Memo

local GAME = "memo"
local GC = config.GAME_CONFIG
local INTRO_TIME = (GC.minigameIntroMs or 1200) / 1000
local URGENT_TIME = (GC.minigameUrgentMs or 5000) / 1000
local DURATION = (GC.minigameMemoDurationMs or GC.minigameDurationMs or 30000) / 1000
local FLIP_BACK = (GC.minigameMemoFlipBackMs or 700) / 1000
local TIME_BONUS_PER_SEC = GC.minigameMemoTimeBonusPerSec or 15
local POINTS_PER_MATCH = GC.minigameMemoPointsPerMatch or 25
local MISMATCH_PENALTY = GC.minigameMemoMismatchPenalty or 0
local FLIP_SPEED = 6.0 -- reveal units per second

local fontCache = {}
local function getFont(sz)
  if not fontCache[sz] then fontCache[sz] = love.graphics.newFont(sz) end
  return fontCache[sz]
end

local function randi(n) return love.math.random(n) end

local function clamp(v, lo, hi)
  if v < lo then return lo elseif v > hi then return hi else return v end
end

-- Keep playfield geometry in sync with the shared layout (also on resize).
-- Same header/footer band strategy used by the other minigames.
function Memo:setLayout(layout)
  self.layout = {
    offsetX = layout.offsetX,
    offsetY = layout.offsetY,
    cellSize = layout.cellSize,
    gridPixelW = layout.gridPixelW,
    gridPixelH = layout.gridPixelH,
  }

  local stage = {
    x = layout.offsetX - 8,
    y = layout.offsetY - 8,
    w = layout.gridPixelW + 16,
    h = layout.gridPixelH + 16,
  }
  self.stage = stage

  local headerH = math.max(48, math.min(96, math.floor(stage.h * 0.12), math.floor(stage.h * 0.30)))
  local footerH = math.max(34, math.min(84, math.floor(stage.h * 0.11), math.floor(stage.h * 0.26)))
  local inner = 8
  local availW = stage.w - inner * 2
  local availH = stage.h - headerH - footerH
  local cs = math.max(1, math.floor(math.min(availW / self.cols, availH / self.rows)))

  self.headerH = headerH
  self.footerH = footerH
  self.cs = cs
  self.gridPixelW = self.cols * cs
  self.gridPixelH = self.rows * cs
  self.gx = stage.x + math.floor((stage.w - self.gridPixelW) / 2)
  self.gy = stage.y + headerH + math.floor((stage.h - headerH - footerH - self.gridPixelH) / 2)
end

function Memo.new(layout)
  local self = setmetatable({}, Memo)
  self.cols = GC.minigameMemoCols or 4
  self.rows = GC.minigameMemoRows or 4
  if self.cols % 2 ~= 0 and self.rows % 2 ~= 0 then
    -- needs an even number of slots for pairs; keep at least one even axis
    self.cols = self.cols + 1
  end
  self:setLayout(layout)

  self.totalPairs = math.floor(self.cols * self.rows / 2)
  self.cards = self:buildDeck()
  self.flipped = {}          -- carte attualmente scoperte (max 2)
  self.flipBackT = 0         -- >0: attesa prima di ricoprire un mismatch
  self.elapsed = 0
  self.duration = DURATION

  self.score = 0
  self.pairs = 0
  self.caught = 0
  self.streak = 0
  self.bestStreak = 0
  self.finished = false
  self.introT = 0
  self.hoverCell = nil
  self.finishFlash = 0

  self.debugTimer = 0.45
  self.fx = MUI.newEffects()
  self.background = "campo"

  return self
end

function Memo:isFinished() return self.finished end
function Memo:getScore() return self.score end
function Memo:timeLeft() return math.max(0, self.elapsed and (self.duration - self.elapsed) or self.duration) end

function Memo:finish() self.finished = true end

-- Build a shuffled deck of pairs. Each sprite index appears twice; with 6
-- sprites and 8 pairs some indices repeat, so matching is by index (value).
function Memo:buildDeck()
  local n = Sprites.count(GAME)
  local slots = self.cols * self.rows
  local pairsNeeded = math.floor(slots / 2)
  local indices = {}
  for i = 1, pairsNeeded do
    if n > 0 then
      local idx
      if i <= n then
        idx = i
      else
        idx = randi(n)
      end
      indices[#indices + 1] = idx
    else
      indices[#indices + 1] = 1
    end
  end
  -- shuffle pair order so identical sprites are not adjacent by construction
  for i = #indices, 2, -1 do
    local j = randi(i)
    indices[i], indices[j] = indices[j], indices[i]
  end

  local cards = {}
  for _, idx in ipairs(indices) do
    local value = Sprites.value(GAME, idx)
    cards[#cards + 1] = { index = idx, value = value }
    cards[#cards + 1] = { index = idx, value = value }
  end
  for i = #cards, 2, -1 do
    local j = randi(i)
    cards[i], cards[j] = cards[j], cards[i]
  end
  for i, c in ipairs(cards) do
    local col = (i - 1) % self.cols
    local row = math.floor((i - 1) / self.cols)
    c.col, c.row = col, row
    c.faceUp, c.matched, c.reveal = false, false, 0
    c.pos = 0
  end
  return cards
end

function Memo:cardAt(col, row)
  for _, c in ipairs(self.cards) do
    if c.col == col and c.row == row then return c end
  end
  return nil
end

function Memo:cellAt(x, y)
  if x < self.gx or x > self.gx + self.gridPixelW then return nil end
  if y < self.gy or y > self.gy + self.gridPixelH then return nil end
  local col = math.floor((x - self.gx) / self.cs)
  local row = math.floor((y - self.gy) / self.cs)
  if col < 0 or col >= self.cols or row < 0 or row >= self.rows then return nil end
  return col, row
end

function Memo:cardCenter(c)
  return self.gx + (c.col + 0.5) * self.cs, self.gy + (c.row + 0.5) * self.cs
end

function Memo:flipCard(c)
  if c.matched or c.faceUp then return end
  c.faceUp = true
  self.flipped[#self.flipped + 1] = c
  if #self.flipped == 2 then
    self:evaluatePair()
  end
end

function Memo:evaluatePair()
  local a, b = self.flipped[1], self.flipped[2]
  if a.index == b.index then
    a.matched, b.matched = true, true
    self.flipped = {}
    self.pairs = self.pairs + 1
    self.caught = self.pairs
    self.streak = self.streak + 1
    if self.streak > self.bestStreak then self.bestStreak = self.streak end

    local mult = 1 + math.min(self.streak - 1, 5) * 0.1
    local gained = math.floor(POINTS_PER_MATCH * mult + 0.5)
    self.score = self.score + gained

    local ax, ay = self:cardCenter(a)
    local bx, by = self:cardCenter(b)
    local cx, cy = (ax + bx) / 2, (ay + by) / 2
    local col = Theme.accent
    Anim.addScorePop(cx, cy - self.cs * 0.3, "+" .. gained, col)
    self.fx:burst(ax, ay, col, { count = 8, speed = 140 })
    self.fx:burst(bx, by, col, { count = 8, speed = 140 })
    self.fx:burst(cx, cy, col, {
      count = 5, speed = 200, sizeMin = 3, sizeMax = 5.5,
      shape = "star", gravity = 140, drag = 0.9, lifeMin = 0.35, lifeMax = 0.6,
    })
    self.fx:ring(cx, cy, col, self.cs * 0.2, self.cs * 0.8, { dur = 0.4, lw = 2 })
    self.fx:shake(2.0 + math.min(2.5, self.streak * 0.3), 0.15)

    if self.pairs >= self.totalPairs then
      self:complete()
    end
  else
    -- mismatch: show both briefly, then flip back
    self.flipBackT = FLIP_BACK
    self.streak = 0
    if MISMATCH_PENALTY > 0 then
      self.score = math.max(0, self.score - MISMATCH_PENALTY)
    end
    local ax, ay = self:cardCenter(a)
    local bx, by = self:cardCenter(b)
    self.fx:burst(ax, ay, { 0.95, 0.4, 0.45 }, {
      count = 6, speed = 80, sizeMin = 2, sizeMax = 3.5,
      gravity = 80, drag = 0.9, lifeMin = 0.2, lifeMax = 0.4,
    })
    self.fx:burst(bx, by, { 0.95, 0.4, 0.45 }, {
      count = 6, speed = 80, sizeMin = 2, sizeMax = 3.5,
      gravity = 80, drag = 0.9, lifeMin = 0.2, lifeMax = 0.4,
    })
    self.fx:shake(1.6, 0.12)
  end
end

function Memo:complete()
  local bonus = math.floor(self:timeLeft() * TIME_BONUS_PER_SEC)
  self.score = self.score + bonus
  self.finishFlash = 1
  self.finished = true
end

function Memo:update(dt)
  if self.finished then return end

  self.elapsed = self.elapsed + dt
  self.introT = math.min(INTRO_TIME, self.introT + dt)
  if self.elapsed >= self.duration then
    self.elapsed = self.duration
    self.finished = true
    return
  end

  -- flip / unflip animation
  for _, c in ipairs(self.cards) do
    -- faceUp resta true anche durante l'attesa del mismatch: la carta torna
    -- coperta solo quando flipBackT arriva a 0 (vedi sotto).
    local target = c.faceUp and 1 or 0
    if c.reveal < target then
      c.reveal = math.min(target, c.reveal + dt * FLIP_SPEED)
    elseif c.reveal > target then
      c.reveal = math.max(target, c.reveal - dt * FLIP_SPEED)
    end
  end

  -- mismatch timeout: flip both back once animation has settled
  if self.flipBackT > 0 then
    self.flipBackT = math.max(0, self.flipBackT - dt)
    if self.flipBackT == 0 then
      for _, c in ipairs(self.flipped) do c.faceUp = false end
      self.flipped = {}
    end
  end

  -- debug auto-solve (TILEMAMA_MG screenshots)
  if self.debugAuto and self.flipBackT == 0 then
    self.debugTimer = self.debugTimer - dt
    if self.debugTimer <= 0 then
      self.debugTimer = 0.45
      local pick
      if #self.flipped == 1 then
        local want = self.flipped[1].index
        for _, c in ipairs(self.cards) do
          if not c.faceUp and not c.matched and c.index == want then pick = c break end
        end
      end
      if not pick then
        local free = {}
        for _, c in ipairs(self.cards) do
          if not c.faceUp and not c.matched then free[#free + 1] = c end
        end
        if #free > 0 then pick = free[randi(#free)] end
      end
      if pick then self:flipCard(pick) end
    end
  end

  self.finishFlash = math.max(0, self.finishFlash - dt * 1.5)
  self.fx:update(dt)
end

function Memo:pointerpressed(x, y)
  if self.finished or self.flipBackT > 0 then return end
  local col, row = self:cellAt(x, y)
  if not col then return end
  local c = self:cardAt(col, row)
  if not c or c.faceUp or c.matched then return end
  self:flipCard(c)
end

function Memo:pointermoved(x, y)
  if self.finished then return end
  local col, row = self:cellAt(x, y)
  self.hoverCell = col and (row * 100 + col) or nil
end

function Memo:keypressed(key)
  if self.finished then return end
  if key == "escape" then self:finish() end
end

-- ═══════════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════════
local function drawCardBack(x, y, cs, t, seed)
  Theme.softShadow(x, y, cs, cs, Theme.radius.card, 0.5, { 0.12, 0.08, 0.24 })
  Theme.rrGradient(x, y, cs, cs, Theme.radius.card,
    { 0.44, 0.36, 0.66 }, { 0.26, 0.20, 0.44 }, cs * 0.42)
  -- inner frame
  love.graphics.setColor(1, 1, 1, 0.14)
  love.graphics.rectangle("line", x + 4, y + 4, cs - 8, cs - 8, Theme.radius.card - 4, Theme.radius.card - 4)
  -- star (plus + rotated = 8-point sparkle)
  local tw = 0.5 + 0.5 * math.sin(t * 2.2 + seed)
  local cx, cy = x + cs / 2, y + cs / 2
  local r = cs * (0.13 + 0.04 * tw)
  MUI.drawStar(cx, cy, r, 0, { 1, 0.95, 0.7 }, 0.55 + 0.35 * tw)
  MUI.drawStar(cx, cy, r * 0.72, math.pi / 4, { 1, 0.95, 0.7 }, 0.45 + 0.35 * tw)
  love.graphics.setColor(1, 1, 1)
end

local function drawCardFace(c, x, y, cs, matched, t)
  local entry = Sprites.get(GAME, c.index)
  Theme.softShadow(x, y, cs, cs, Theme.radius.card, 0.55, { 0.12, 0.08, 0.24 })

  if entry and entry.img then
    -- L'art e' gia' una carta completa (cornice + personaggio): la disegniamo a
    -- riempire la cella senza corpo/badge sovrapposti.
    local img = entry.img
    local iw, ih = img:getDimensions()
    local scale = math.min(cs / iw, cs / ih)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, x + cs / 2, y + cs / 2, 0, scale, scale, iw / 2, ih / 2)
  else
    Theme.rrGradient(x, y, cs, cs, Theme.radius.card,
      { 0.90, 0.95, 1 }, { 0.78, 0.88, 1 }, cs * 0.42)
    love.graphics.setColor(0.22, 0.30, 0.48, 0.9)
    love.graphics.setFont(getFont(math.max(10, math.floor(cs * 0.34))))
    love.graphics.printf(tostring(c.value or "?"), x, y + cs * 0.38, cs, "center")
  end

  if matched then
    love.graphics.setBlendMode("add")
    local pulse = 0.5 + 0.5 * math.sin(t * 4)
    love.graphics.setColor(0.5, 1, 0.6, 0.10 + 0.12 * pulse)
    love.graphics.rectangle("fill", x, y, cs, cs, Theme.radius.card, Theme.radius.card)
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(0.35, 0.90, 0.50, 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 1, y + 1, cs - 2, cs - 2, Theme.radius.card, Theme.radius.card)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
  end
end

function Memo:draw()
  local t = love.timer.getTime()
  local cs = self.cs
  local stage = self.stage

  local sdx, sdy = self.fx:shakeOffset()
  love.graphics.push()
  love.graphics.translate(sdx, sdy)

  MUI.drawStage(stage.x, stage.y, stage.w, stage.h, t)
  MUI.drawField(self.gx, self.gy, self.cols, self.rows, cs)

  -- hover highlight
  if self.hoverCell then
    local col = self.hoverCell % 100
    local row = math.floor(self.hoverCell / 100)
    local c = self:cardAt(col, row)
    if c and not c.matched then
      love.graphics.setColor(1, 1, 1, 0.08)
      love.graphics.rectangle("fill", self.gx + col * cs + 2, self.gy + row * cs + 2,
        cs - 4, cs - 4, Theme.radius.cell, Theme.radius.cell)
    end
  end

  for _, c in ipairs(self.cards) do
    local x = self.gx + c.col * cs
    local y = self.gy + c.row * cs
    local pad = math.max(2, cs * 0.03)
    local sx = x + pad
    local sy = y + pad
    local size = cs - pad * 2

    local reveal = clamp(c.reveal or 0, 0, 1)
    local sxScale = math.abs(math.cos(reveal * math.pi))
    if c.matched then sxScale = math.max(0.85, sxScale) end
    if sxScale < 0.02 then sxScale = 0.02 end

    love.graphics.push()
    love.graphics.translate(sx + size / 2, sy + size / 2)
    love.graphics.scale(sxScale, 1)
    love.graphics.translate(-(sx + size / 2), -(sy + size / 2))
    if reveal < 0.5 then
      drawCardBack(sx, sy, size, t, (c.col + c.row) * 1.7)
    else
      drawCardFace(c, sx, sy, size, c.matched, t)
    end
    love.graphics.pop()
  end

  self.fx:draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.pop()

  -- urgency tint on the last seconds
  if self:timeLeft() <= URGENT_TIME and not self.finishFlash then
    local pulse = 0.5 + 0.5 * math.sin(t * 6)
    love.graphics.setColor(1, 0.2, 0.25, 0.05 + 0.05 * pulse)
    love.graphics.rectangle("fill", stage.x, stage.y, stage.w, stage.h, Theme.radius.card, Theme.radius.card)
    love.graphics.setColor(1, 1, 1)
  end
end

-- ═══════════════════════════════════════════
-- HUD
-- ═══════════════════════════════════════════
function Memo:drawHUD(layout)
  local t = love.timer.getTime()
  local stage = self.stage
  local w = stage.w

  local pillH = 30
  local padX = 14
  local py = stage.y + 8
  MUI.drawStatPill(stage.x + padX, py, w * 0.44 - padX, pillH, "star", self.score, "punti",
    { valueCol = { 1, 0.92, 0.5 } })
  MUI.drawStatPill(stage.x + w * 0.56, py, w * 0.44 - padX, pillH, "candy",
    self.pairs .. "/" .. self.totalPairs, "coppie", { valueCol = { 0.75, 1, 0.8 } })

  local tw = w - padX * 2
  local ty = py + pillH + 8
  local urgency = self:timeLeft() <= URGENT_TIME
  MUI.drawTimerBar(stage.x + padX, ty, tw, 8, self:timeLeft() / self.duration, urgency, t)

  -- footer
  local fy = stage.y + stage.h - self.footerH + self.footerH * 0.28
  if self.streak >= 2 then
    local col = self.streak >= 5 and { 1, 0.75, 0.25 } or { 1, 0.55, 0.75 }
    love.graphics.setFont(Theme.font(Theme.fontSize.h3))
    Theme.set(col)
    love.graphics.printf("STREAK x" .. self.streak, stage.x, fy, w, "center")
  else
    love.graphics.setFont(Theme.font(Theme.fontSize.small))
    love.graphics.setColor(0.82, 0.78, 0.92, 0.85)
    love.graphics.printf("Trova le coppie uguali!", stage.x, fy, w, "center")
  end

  -- intro banner
  if self.introT < INTRO_TIME then
    local a = 1 - self.introT / INTRO_TIME
    local cy = self.gy + self.gridPixelH * 0.34
    MUI.drawHeader(stage.x + w / 2, cy - 30, w, "MEMO!", "star", a,
      { size = Theme.fontSize.hero, fill = { 1, 0.6, 0.75 } })
    love.graphics.setFont(Theme.font(Theme.fontSize.body))
    love.graphics.setColor(1, 1, 1, a * 0.9)
    love.graphics.printf("Gira due carte e trova le coppie!", stage.x, cy + 12, w, "center")
  end

  love.graphics.setColor(1, 1, 1)
end

return Memo
