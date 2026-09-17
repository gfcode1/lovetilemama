-- Falling Tiles minigame ("Catch").
-- Empty arena; a bucket sits on the floor and slides left/right on tap/drag/keys.
-- Character sprites fall from the top: catch them with the bucket to score.
-- Each sprite maps to a fixed value (see minigames.sprites).
local config = require("src.config")
local Theme = require("src.ui.theme")
local Anim = require("src.ui.animations")
local Sprites = require("src.minigames.sprites")
local MUI = require("src.minigames.ui")

local Falling = {}
Falling.__index = Falling

local GAME = "falling"
local POINTS_PER_VALUE = config.MINIGAME_POINTS_PER_VALUE or 5
local GC = config.GAME_CONFIG
local STREAK_WINDOW = (GC.minigameStreakWindowMs or 1100) / 1000
local INTRO_TIME = (GC.minigameIntroMs or 1200) / 1000
local URGENT_TIME = (GC.minigameUrgentMs or 5000) / 1000
local SPAWN_DUR = 0.28

local fontCache = {}
local function getFont(sz)
  if not fontCache[sz] then fontCache[sz] = love.graphics.newFont(sz) end
  return fontCache[sz]
end

local function easeOutBack(t)
  local s = 1.70158
  t = t - 1
  return t * t * ((s + 1) * t + s) + 1
end

-- Keep playfield geometry in sync with the shared layout (also on resize).
-- Reserves a header band (score + timer) and a footer band (streak/hint)
-- inside a dedicated stage card.
function Falling:setLayout(layout)
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

  -- Bands are capped to a fraction of the stage so they never eat the whole
  -- playfield on very short windows.
  local headerH = math.max(48, math.min(96, math.floor(stage.h * 0.12), math.floor(stage.h * 0.30)))
  local footerH = math.max(34, math.min(84, math.floor(stage.h * 0.11), math.floor(stage.h * 0.26)))
  local inner = 8
  local availW = stage.w - inner * 2
  local availH = stage.h - headerH - footerH
  -- Fit to the available box (no upward clamp: clamping could overflow the stage).
  local cs = math.max(1, math.floor(math.min(availW / self.cols, availH / self.rows)))

  self.headerH = headerH
  self.footerH = footerH
  self.cs = cs
  self.gridPixelW = self.cols * cs
  self.gridPixelH = self.rows * cs
  self.gx = stage.x + math.floor((stage.w - self.gridPixelW) / 2)
  self.gy = stage.y + headerH + math.floor((stage.h - headerH - footerH - self.gridPixelH) / 2)
end

function Falling.new(layout)
  local self = setmetatable({}, Falling)
  self.cols = config.GRID_W
  self.rows = config.GRID_H
  self:setLayout(layout)

  self.bucketCol = math.floor(self.cols / 2)
  self.bucketDisplay = self.bucketCol
  self.bucketVel = 0
  self.pieces = {}
  self.spawnTimer = 0.35
  self.elapsed = 0
  self.duration = (GC.minigameDurationMs or 30000) / 1000
  self.baseSpeed = GC.minigameFallSpeed or 3.5
  self.baseSpawn = (GC.minigameSpawnMs or 650) / 1000

  self.score = 0
  self.caught = 0
  self.streak = 0
  self.streakTimer = 0
  self.bestStreak = 0
  self.finished = false

  self.bucketFlash = 0
  self.catchShake = 0
  self.missedFlash = 0
  self.introT = 0
  self.floorFlashes = {}

  self.fx = MUI.newEffects()

  return self
end

function Falling:isFinished() return self.finished end
function Falling:getScore() return self.score end
function Falling:timeLeft() return math.max(0, self.duration - self.elapsed) end

function Falling:finish() self.finished = true end

local function randi(n) return love.math.random(n) end

function Falling:spawnPiece()
  local col = randi(self.cols) - 1
  local index = Sprites.randomIndex(GAME) or 1
  table.insert(self.pieces, {
    x = col,
    y = -1,
    index = index,
    value = Sprites.value(GAME, index),
    wobble = love.math.random() * math.pi * 2,
    spawn = 0,
    spin = (love.math.random() - 0.5) * 2,
  })
end

function Falling:catchPiece(p)
  local gained = p.value * POINTS_PER_VALUE
  self.score = self.score + gained
  self.caught = self.caught + 1
  self.bucketFlash = 1
  self.catchShake = 1

  if self.streakTimer > 0 then
    self.streak = self.streak + 1
  else
    self.streak = 1
  end
  self.streakTimer = STREAK_WINDOW
  if self.streak > self.bestStreak then self.bestStreak = self.streak end

  local cx = self.gx + (p.x + 0.5) * self.cs
  local cy = self.gy + (self.rows - 0.5) * self.cs
  local col = Theme.accent

  Anim.addScorePop(cx, cy - self.cs * 0.4, "+" .. gained, col)
  self.fx:burst(cx, cy - self.cs * 0.15, col, { count = 12, speed = 165 })
  self.fx:burst(cx, cy - self.cs * 0.10, col, {
    count = 5, speed = 210, sizeMin = 3, sizeMax = 5.5,
    shape = "star", gravity = 140, drag = 0.9, lifeMin = 0.35, lifeMax = 0.6,
  })
  self.fx:ring(cx, cy, col, self.cs * 0.18, self.cs * 0.75, { dur = 0.38, lw = 2 })
  self.fx:shake(2.2 + math.min(2.5, self.streak * 0.35), 0.18)
end

function Falling:missPiece(p)
  local col = math.floor(p.x + 0.5)
  local cx = self.gx + (col + 0.5) * self.cs
  local cy = self.gy + (self.rows - 0.15) * self.cs

  self.missedFlash = 1
  self.streak = 0
  self.streakTimer = 0
  self.floorFlashes[col] = 1

  self.fx:burst(cx, cy, { 0.86, 0.82, 0.90 }, {
    count = 7, speed = 90, sizeMin = 2, sizeMax = 3.5,
    gravity = 60, drag = 0.9, lifeMin = 0.25, lifeMax = 0.45,
    colors = { { 0.86, 0.82, 0.90 }, { 0.72, 0.66, 0.82 } },
  })
end

function Falling:update(dt)
  if self.finished then return end

  self.elapsed = self.elapsed + dt
  self.introT = math.min(INTRO_TIME, self.introT + dt)
  if self.elapsed >= self.duration then
    self.elapsed = self.duration
    self.finished = true
    return
  end

  -- debug auto-aim (TILEMAMA_MG screenshots): chase the lowest tile
  if self.debugAuto then
    local low, ly
    for _, p in ipairs(self.pieces) do
      if not ly or p.y > ly then low, ly = p, p.y end
    end
    if low then self.bucketCol = math.max(0, math.min(self.cols - 1, math.floor(low.x + 0.5))) end
  end

  -- difficulty ramp
  local t = self.elapsed / self.duration
  local speed = self.baseSpeed * (1 + t * 0.6)
  local spawnEvery = math.max(0.28, self.baseSpawn - t * 0.25)

  -- bucket easing toward target column (track velocity for lean)
  local prevDisplay = self.bucketDisplay
  self.bucketDisplay = self.bucketDisplay + (self.bucketCol - self.bucketDisplay) * math.min(1, dt * 14)
  if dt > 0 then
    self.bucketVel = (self.bucketDisplay - prevDisplay) / dt
  end

  -- spawn
  self.spawnTimer = self.spawnTimer + dt
  while self.spawnTimer >= spawnEvery do
    self.spawnTimer = self.spawnTimer - spawnEvery
    self:spawnPiece()
  end

  -- fall + collision
  local bucketRow = self.rows - 1
  local bucketCol = math.floor(self.bucketDisplay + 0.5)
  local keep = {}
  for _, p in ipairs(self.pieces) do
    p.y = p.y + speed * dt
    p.spawn = math.min(SPAWN_DUR, p.spawn + dt)
    local col = math.floor(p.x + 0.5)
    if p.y >= bucketRow - 0.35 and p.y <= bucketRow + 0.6 and col == bucketCol then
      self:catchPiece(p)
    elseif p.y > self.rows + 0.5 then
      self:missPiece(p)
    else
      table.insert(keep, p)
    end
  end
  self.pieces = keep

  -- decay feedback timers
  self.bucketFlash = math.max(0, self.bucketFlash - dt * 3)
  self.catchShake = math.max(0, self.catchShake - dt * 4)
  self.missedFlash = math.max(0, self.missedFlash - dt * 3)
  self.streakTimer = math.max(0, self.streakTimer - dt)
  if self.streakTimer == 0 then self.streak = 0 end
  for col, v in pairs(self.floorFlashes) do
    local nv = v - dt * 2.4
    if nv <= 0 then self.floorFlashes[col] = nil else self.floorFlashes[col] = nv end
  end

  self.fx:update(dt)
end

function Falling:pointerpressed(x, y)
  if self.finished then return end
  if x < self.gx or x > self.gx + self.gridPixelW then return end
  local centerX = self.gx + (self.bucketCol + 0.5) * self.cs
  if x < centerX then
    self.bucketCol = math.max(0, self.bucketCol - 1)
  else
    self.bucketCol = math.min(self.cols - 1, self.bucketCol + 1)
  end
end

function Falling:pointermoved(x, y)
  if self.finished then return end
  if x < self.gx or x > self.gx + self.gridPixelW then return end
  local col = math.floor((x - self.gx) / self.cs)
  self.bucketCol = math.max(0, math.min(self.cols - 1, col))
end

function Falling:keypressed(key)
  if self.finished then return end
  if key == "left" or key == "a" then
    self.bucketCol = math.max(0, self.bucketCol - 1)
  elseif key == "right" or key == "d" then
    self.bucketCol = math.min(self.cols - 1, self.bucketCol + 1)
  elseif key == "escape" then
    self:finish()
  end
end

-- ═══════════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════════
local function drawValueBadge(px, py, cs, value, alpha)
  local r = math.max(9, cs * 0.20)
  local tw = math.max(Theme.fontSize.tiny, math.floor(cs * 0.26))
  Theme.softShadow(px - r, py - r, r * 2, r * 2, r, 0.45, { 0.10, 0.06, 0.22 })
  love.graphics.setColor(0.16, 0.12, 0.28, 0.88 * alpha)
  love.graphics.circle("fill", px, py, r)
  love.graphics.setColor(1, 1, 1, 0.18 * alpha)
  love.graphics.circle("line", px, py, r)
  love.graphics.setFont(getFont(tw))
  love.graphics.setColor(1, 0.98, 0.9, alpha)
  love.graphics.printf(tostring(value), px - r, py - tw * 0.58, r * 2, "center")
end

function Falling:drawPiece(p, t)
  local cs = self.cs
  local px = self.gx + (p.x + 0.5) * cs
  local py = self.gy + (p.y + 0.5) * cs
  local entry = Sprites.get(GAME, p.index)
  local col = Theme.accent

  -- spawn pop-in (rotation only when motion is allowed)
  local sp = math.min(1, p.spawn / SPAWN_DUR)
  local sc = 0.2 + 0.8 * easeOutBack(sp)
  local rot = 0
  if MUI.motion() then
    rot = math.sin(t * 3 + p.wobble) * 0.08 + p.spin * 0.05
  end

  -- soft shadow (denser the closer the piece is to the floor)
  local depth = math.max(0, math.min(1, p.y / (self.rows - 1)))
  local shOff = cs * (0.10 + 0.10 * (1 - depth))
  love.graphics.setColor(0, 0, 0, 0.16 + 0.14 * depth)
  love.graphics.ellipse("fill", px, py + cs * 0.46 + shOff, cs * 0.32 * sc, cs * 0.12 * sc)

  -- soft aura for high values (behind the sprite)
  if p.value >= 4 then
    local aura = math.min(1, (math.log(p.value) / math.log(2) - 2) / 3)
    love.graphics.setBlendMode("add")
    for gi = 2, 1, -1 do
      love.graphics.setColor(col[1], col[2], col[3], (0.03 + 0.02 * gi) * (0.5 + aura))
      love.graphics.circle("fill", px, py, cs * (0.44 + 0.04 * gi) * sc)
    end
    love.graphics.setBlendMode("alpha")
  end

  love.graphics.push()
  love.graphics.translate(px, py)
  love.graphics.rotate(rot)
  love.graphics.scale(sc, sc)

  if entry and entry.img then
    local img = entry.img
    local iw, ih = img:getDimensions()
    local scale = math.min((cs + 6) / iw, (cs + 6) / ih)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, 0, 0, 0, scale, scale, iw / 2, ih / 2)
  else
    Theme.rrSolid(-cs * 0.4, -cs * 0.4, cs * 0.8, cs * 0.8, Theme.radius.block, Theme.candy.green)
    Theme.set(Theme.textInverse)
    love.graphics.setFont(getFont(math.max(10, math.floor(cs * 0.34))))
    love.graphics.printf(tostring(p.value), -cs / 2, -cs * 0.18, cs, "center")
  end
  love.graphics.pop()

  if entry then
    drawValueBadge(px, py + cs * 0.36 * sc, cs, entry.value, 1)
  end
  love.graphics.setColor(1, 1, 1)
end

function Falling:drawBucket(t)
  local cs = self.cs
  local bx = self.gx + (self.bucketDisplay + 0.5) * cs
  local by = self.gy + (self.rows - 0.5) * cs

  local motion = MUI.motion()
  local flash = self.bucketFlash
  if motion then
    bx = bx + self.catchShake * math.sin(t * 60) * cs * 0.05
    by = by + math.sin(t * 3.4) * cs * 0.015
  end

  local lean = motion and math.max(-0.22, math.min(0.22, self.bucketVel * 0.5)) or 0
  local bw = cs * 0.98
  local bh = cs * 0.82
  local squash = motion and self.catchShake or 0
  local sx = 1 + squash * 0.14
  local sy = 1 - squash * 0.10

  local accent = Theme.accent
  local bodyTop = { 1, 0.70, 0.80 }
  local bodyBot = { 0.86, 0.34, 0.50 }
  local rim = { 1, 0.88, 0.92 }

  if flash > 0.02 then
    love.graphics.setBlendMode("add")
    love.graphics.setColor(accent[1], accent[2], accent[3], 0.28 * flash)
    love.graphics.ellipse("fill", bx, by - bh * 0.38, bw * 0.62, bh * 0.34)
    love.graphics.setBlendMode("alpha")
  end

  Theme.softShadow(bx - bw / 2, by - bh / 2 + 5, bw, bh, Theme.radius.block, 0.55, { 0.32, 0.16, 0.30 })

  love.graphics.push()
  love.graphics.translate(bx, by)
  love.graphics.rotate(lean)
  love.graphics.scale(sx, sy)

  -- body
  Theme.rrGradient(-bw / 2, -bh / 2, bw, bh, Theme.radius.block, bodyTop, bodyBot, bh * 0.5)

  -- inner cavity (open mouth)
  love.graphics.setColor(0.30, 0.12, 0.22, 0.85)
  love.graphics.ellipse("fill", 0, -bh / 2 + 5, bw * 0.40, bh * 0.12)

  -- glossy highlight
  love.graphics.setColor(1, 1, 1, 0.20)
  love.graphics.polygon("fill",
    -bw * 0.34, -bh * 0.16, -bw * 0.20, -bh * 0.16,
    -bw * 0.26, bh * 0.42, -bw * 0.38, bh * 0.42)

  -- front lip
  Theme.rrGradient(-bw / 2 - 2, -bh / 2 - 5, bw + 4, 10, 5, rim, accent, 5)

  love.graphics.pop()
  love.graphics.setColor(1, 1, 1)
end

function Falling:draw()
  local t = love.timer.getTime()
  local gx, gy, cs = self.gx, self.gy, self.cs
  local stage = self.stage
  local cols, rows = self.cols, self.rows

  local sdx, sdy = self.fx:shakeOffset()
  love.graphics.push()
  love.graphics.translate(sdx, sdy)

  MUI.drawStage(stage.x, stage.y, stage.w, stage.h, t)
  MUI.drawField(gx, gy, cols, rows, cs, rows - 1)
  MUI.drawLane(gx, gy, cols, rows, cs, self.bucketDisplay, Theme.accent, t)

  -- miss flashes on the floor
  local fy = gy + (rows - 1) * cs
  for col, v in pairs(self.floorFlashes) do
    love.graphics.setColor(1, 0.30, 0.36, 0.35 * v)
    love.graphics.rectangle("fill", gx + col * cs + 1, fy + cs * 0.6,
      cs - 2, cs * 0.4, Theme.radius.cell, Theme.radius.cell)
  end

  for _, p in ipairs(self.pieces) do
    self:drawPiece(p, t)
  end

  self:drawBucket(t)
  self.fx:draw()

  love.graphics.setColor(1, 1, 1)
  love.graphics.pop()

  -- urgency tint on the last seconds
  if self:timeLeft() <= URGENT_TIME then
    local pulse = 0.5 + 0.5 * math.sin(t * 6)
    love.graphics.setColor(1, 0.2, 0.25, 0.05 + 0.05 * pulse)
    love.graphics.rectangle("fill", stage.x, stage.y, stage.w, stage.h, Theme.radius.card, Theme.radius.card)
    love.graphics.setColor(1, 1, 1)
  end
end

-- Own HUD (called by main if present). Header: score + tiles + timer.
-- Footer: streak meter or input hint. Intro banner on start.
function Falling:drawHUD(layout)
  local t = love.timer.getTime()
  local stage = self.stage
  local w = stage.w

  local pillH = 30
  local padX = 14
  local py = stage.y + 8
  MUI.drawStatPill(stage.x + padX, py, w * 0.44 - padX, pillH, "star", self.score, "punti",
    { valueCol = { 1, 0.92, 0.5 } })
  MUI.drawStatPill(stage.x + w * 0.56, py, w * 0.44 - padX, pillH, "candy", self.caught, "tile",
    { valueCol = { 0.75, 1, 0.8 } })

  local tw = w - padX * 2
  local ty = py + pillH + 8
  local urgency = self:timeLeft() <= URGENT_TIME
  MUI.drawTimerBar(stage.x + padX, ty, tw, 8, self:timeLeft() / self.duration, urgency, t)

  -- footer
  local fy = stage.y + stage.h - self.footerH + self.footerH * 0.28
  if self.streak >= 2 and self.streakTimer > 0 then
    local col = self.streak >= 5 and { 1, 0.75, 0.25 } or { 1, 0.55, 0.75 }
    love.graphics.setFont(Theme.font(Theme.fontSize.h3))
    Theme.set(col)
    love.graphics.printf("STREAK x" .. self.streak, stage.x, fy, w, "center")
    MUI.drawTimerBar(stage.x + w * 0.30, fy + 20, w * 0.40, 4, self.streakTimer / STREAK_WINDOW, false, t)
  else
    love.graphics.setFont(Theme.font(Theme.fontSize.small))
    love.graphics.setColor(0.82, 0.78, 0.92, 0.85)
    love.graphics.printf("Tocca, trascina o usa  A / D", stage.x, fy, w, "center")
  end

  -- intro banner
  if self.introT < INTRO_TIME then
    local a = 1 - self.introT / INTRO_TIME
    local cy = self.gy + self.gridPixelH * 0.34
    MUI.drawHeader(stage.x + w / 2, cy - 30, w, "CATCH!", "heart", a,
      { size = Theme.fontSize.hero, fill = { 1, 0.6, 0.75 } })
    love.graphics.setFont(Theme.font(Theme.fontSize.body))
    love.graphics.setColor(1, 1, 1, a * 0.9)
    love.graphics.printf("Prendi il maggior numero di tile!", stage.x, cy + 12, w, "center")
  end

  love.graphics.setColor(1, 1, 1)
end

return Falling
