-- Whack-a-Tile minigame ("TALPA!").
-- A target tile {color,value} is shown in the HUD; tiles pop up on the board
-- and only the ones matching the target must be tapped. Wrong taps cost points.
local config = require("src.config")
local Theme = require("src.ui.theme")
local Anim = require("src.ui.animations")
local GridUI = require("src.ui.grid")
local MUI = require("src.minigames.ui")

local Whack = {}
Whack.__index = Whack

local COLOR_LIST = config.COLORS
local VALUE_LIST = config.MINIGAME_TILE_VALUES or { 1, 1, 2, 2, 4, 8 }
local POINTS_PER_VALUE = config.MINIGAME_POINTS_PER_VALUE or 5
local GC = config.GAME_CONFIG
local INTRO_TIME = (GC.minigameIntroMs or 1200) / 1000
local URGENT_TIME = (GC.minigameUrgentMs or 5000) / 1000
local UP_BASE = (GC.minigameWhackUpBaseMs or 1000) / 1000
local UP_MIN = (GC.minigameWhackUpMinMs or 520) / 1000
local SPAWN_BASE = (GC.minigameWhackSpawnMs or 620) / 1000
local SPAWN_MIN = (GC.minigameWhackSpawnMinMs or 320) / 1000
local MAX_MOLES = GC.minigameWhackMaxMoles or 3
local TARGET_EVERY = (GC.minigameWhackTargetEveryMs or 4000) / 1000
local PENALTY = GC.minigameWhackPenalty or 1
local RISE_TIME = 0.14
local SINK_TIME = 0.16
local DEBUG_HIT_DELAY = 0.25

local fontCache = {}
local function getFont(sz)
  if not fontCache[sz] then fontCache[sz] = love.graphics.newFont(sz) end
  return fontCache[sz]
end

local function randi(n) return love.math.random(n) end

local function easeOutBack(t)
  local s = 1.70158
  t = t - 1
  return t * t * ((s + 1) * t + s) + 1
end

local function candyOf(color)
  return Theme.candy[color] or Theme.candy.green
end

local function candySkin(color)
  local c = Theme.candy
  if color == "red" then return c.redBg, c.red, c.redDark end
  if color == "yellow" then return c.yellowBg, c.yellow, c.yellowDark end
  if color == "blue" then return c.blueBg, c.blue, c.blueDark end
  return c.greenBg, c.green, c.greenDark
end

function Whack:setLayout(layout)
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

function Whack.new(layout)
  local self = setmetatable({}, Whack)
  self.cols = config.GRID_W
  self.rows = config.GRID_H
  self:setLayout(layout)

  self.moles = {}
  self.spawnTimer = 0.25
  self.targetTimer = TARGET_EVERY
  self.elapsed = 0
  self.duration = (GC.minigameDurationMs or 30000) / 1000

  self.score = 0
  self.caught = 0
  self.streak = 0
  self.bestStreak = 0
  self.finished = false

  self.target = { color = COLOR_LIST[randi(#COLOR_LIST)], value = VALUE_LIST[randi(#VALUE_LIST)] }
  self.targetFlash = 0
  self.introT = 0
  self.hitFlash = {}
  self.missedFlash = {}
  self.hoverCell = nil

  self.debugTimer = DEBUG_HIT_DELAY
  self.fx = MUI.newEffects()
  self.background = "campo"

  return self
end

function Whack:isFinished() return self.finished end
function Whack:getScore() return self.score end
function Whack:timeLeft() return math.max(0, self.duration - self.elapsed) end

function Whack:finish() self.finished = true end

local function cellKey(col, row) return row * 100 + col end

function Whack:rotateTarget()
  local nc, nv = self.target.color, self.target.value
  for _ = 1, 8 do
    nc = COLOR_LIST[randi(#COLOR_LIST)]
    nv = VALUE_LIST[randi(#VALUE_LIST)]
    if nc ~= self.target.color or nv ~= self.target.value then break end
  end
  self.target.color, self.target.value = nc, nv
  self.targetTimer = TARGET_EVERY
  self.targetFlash = 1
end

function Whack:pickCell()
  local occupied = {}
  for _, m in ipairs(self.moles) do
    occupied[cellKey(m.col, m.row)] = true
  end
  local free = {}
  for row = 0, self.rows - 1 do
    for col = 0, self.cols - 1 do
      if not occupied[cellKey(col, row)] then free[#free + 1] = { col, row } end
    end
  end
  if #free == 0 then return nil end
  local c = free[randi(#free)]
  return c[1], c[2]
end

function Whack:spawnMole()
  local col, row = self:pickCell()
  if not col then return end
  local isTarget = love.math.random() < 0.45
  local color, value
  if isTarget then
    color, value = self.target.color, self.target.value
  else
    if randi(2) == 1 then
      color = self.target.color
      for _ = 1, 8 do
        value = VALUE_LIST[randi(#VALUE_LIST)]
        if value ~= self.target.value then break end
      end
      if value == self.target.value then value = self.target.value * 2 end
    else
      value = self.target.value
      for _ = 1, 8 do
        color = COLOR_LIST[randi(#COLOR_LIST)]
        if color ~= self.target.color then break end
      end
      if color == self.target.color then color = (self.target.color == "red") and "blue" or "red" end
    end
  end
  table.insert(self.moles, {
    col = col, row = row,
    color = color, value = value,
    isTarget = isTarget,
    phase = "rise", t = 0,
    upTime = UP_BASE + (UP_MIN - UP_BASE) * (self.elapsed / self.duration),
    wobble = love.math.random() * math.pi * 2,
    spin = (love.math.random() - 0.5) * 1.2,
  })
end

function Whack:removeMole(mole)
  for i = #self.moles, 1, -1 do
    if self.moles[i] == mole then table.remove(self.moles, i) return end
  end
end

function Whack:cellCenter(col, row)
  return self.gx + (col + 0.5) * self.cs, self.gy + (row + 0.5) * self.cs
end

function Whack:hitMole(mole)
  local cx, cy = self:cellCenter(mole.col, mole.row)
  local key = cellKey(mole.col, mole.row)
  local match = (mole.color == self.target.color and mole.value == self.target.value)

  if match then
    self.streak = self.streak + 1
    if self.streak > self.bestStreak then self.bestStreak = self.streak end
    local mult = 1 + math.min(self.streak, 5) * 0.1
    local gained = math.floor(mole.value * POINTS_PER_VALUE * mult + 0.5)
    self.score = self.score + gained
    self.caught = self.caught + 1
    self.hitFlash[key] = 1

    local col = candyOf(mole.color)
    Anim.addScorePop(cx, cy - self.cs * 0.4, "+" .. gained, col)
    self.fx:burst(cx, cy, col, { count = 12, speed = 165 })
    self.fx:burst(cx, cy, col, {
      count = 5, speed = 210, sizeMin = 3, sizeMax = 5.5,
      shape = "star", gravity = 140, drag = 0.9, lifeMin = 0.35, lifeMax = 0.6,
    })
    self.fx:ring(cx, cy, col, self.cs * 0.18, self.cs * 0.75, { dur = 0.38, lw = 2 })
    self.fx:shake(2.2 + math.min(2.5, self.streak * 0.35), 0.16)
  else
    self.score = math.max(0, self.score - PENALTY * POINTS_PER_VALUE)
    self.streak = 0
    self.missedFlash[key] = 1
    Anim.addScorePop(cx, cy - self.cs * 0.4, "-" .. (PENALTY * POINTS_PER_VALUE), { 0.95, 0.35, 0.4 })
    self.fx:burst(cx, cy, { 0.95, 0.35, 0.4 }, {
      count = 8, speed = 110, sizeMin = 2, sizeMax = 4,
      gravity = 160, drag = 0.92, lifeMin = 0.25, lifeMax = 0.45,
      colors = { { 0.95, 0.35, 0.4 }, { 0.80, 0.22, 0.28 } },
    })
    self.fx:shake(2.0, 0.12)
  end

  self:removeMole(mole)
end

function Whack:missTarget(mole)
  self.streak = 0
  self.missedFlash[cellKey(mole.col, mole.row)] = 1
  local cx, cy = self:cellCenter(mole.col, mole.row)
  self.fx:burst(cx, cy, { 0.86, 0.82, 0.90 }, {
    count = 6, speed = 80, sizeMin = 2, sizeMax = 3.5,
    gravity = 60, drag = 0.9, lifeMin = 0.25, lifeMax = 0.45,
    colors = { { 0.86, 0.82, 0.90 }, { 0.72, 0.66, 0.82 } },
  })
end

function Whack:update(dt)
  if self.finished then return end

  self.elapsed = self.elapsed + dt
  self.introT = math.min(INTRO_TIME, self.introT + dt)
  self.targetFlash = math.max(0, self.targetFlash - dt * 2.5)
  if self.elapsed >= self.duration then
    self.elapsed = self.duration
    self.finished = true
    return
  end

  local t = self.elapsed / self.duration

  -- target rotation
  self.targetTimer = self.targetTimer - dt
  if self.targetTimer <= 0 then self:rotateTarget() end

  -- debug auto-hit (TILEMAMA_MG screenshots): tap the first ready target
  if self.debugAuto then
    self.debugTimer = self.debugTimer - dt
    if self.debugTimer <= 0 then
      local pick
      for _, m in ipairs(self.moles) do
        if m.isTarget and m.phase == "up" then pick = m break end
      end
      if pick then
        self.debugTimer = DEBUG_HIT_DELAY
        self:hitMole(pick)
      end
    end
  end

  -- spawn
  local spawnEvery = SPAWN_BASE + (SPAWN_MIN - SPAWN_BASE) * t
  local maxMoles = MAX_MOLES + math.floor(t * 2 + 0.5)
  self.spawnTimer = self.spawnTimer + dt
  while self.spawnTimer >= spawnEvery do
    self.spawnTimer = self.spawnTimer - spawnEvery
    if #self.moles < maxMoles then self:spawnMole() end
  end

  -- mole lifecycle
  for i = #self.moles, 1, -1 do
    local m = self.moles[i]
    m.t = m.t + dt
    if m.phase == "rise" then
      if m.t >= RISE_TIME then m.phase = "up" m.t = 0 end
    elseif m.phase == "up" then
      if m.t >= m.upTime then
        if m.isTarget then self:missTarget(m) end
        m.phase = "sink" m.t = 0
      end
    elseif m.t >= SINK_TIME then
      table.remove(self.moles, i)
    end
  end

  for key, v in pairs(self.hitFlash) do
    local nv = v - dt * 3
    if nv <= 0 then self.hitFlash[key] = nil else self.hitFlash[key] = nv end
  end
  for key, v in pairs(self.missedFlash) do
    local nv = v - dt * 2.6
    if nv <= 0 then self.missedFlash[key] = nil else self.missedFlash[key] = nv end
  end

  self.fx:update(dt)
end

function Whack:cellAt(x, y)
  if x < self.gx or x > self.gx + self.gridPixelW then return nil end
  if y < self.gy or y > self.gy + self.gridPixelH then return nil end
  local col = math.floor((x - self.gx) / self.cs)
  local row = math.floor((y - self.gy) / self.cs)
  if col < 0 or col >= self.cols or row < 0 or row >= self.rows then return nil end
  return col, row
end

function Whack:pointerpressed(x, y)
  if self.finished then return end
  local col, row = self:cellAt(x, y)
  if not col then return end
  for _, m in ipairs(self.moles) do
    if m.col == col and m.row == row and m.phase ~= "sink" then
      self:hitMole(m)
      return
    end
  end
end

function Whack:pointermoved(x, y)
  if self.finished then return end
  local col, row = self:cellAt(x, y)
  self.hoverCell = col and cellKey(col, row) or nil
end

function Whack:keypressed(key)
  if self.finished then return end
  if key == "escape" then self:finish() end
end

-- ═══════════════════════════════════════════
-- DRAW
-- ═══════════════════════════════════════════
function Whack:drawTile(color, value, px, py, cs, scale, alpha, rot)
  local topBg, botCol = candySkin(color)
  local bw, bh = cs * 0.92 * scale, cs * 0.92 * scale

  love.graphics.setColor(0, 0, 0, 0.20 * alpha)
  love.graphics.ellipse("fill", px, py + cs * 0.46, cs * 0.32 * scale, cs * 0.12 * scale)

  love.graphics.push()
  love.graphics.translate(px, py)
  love.graphics.rotate(rot or 0)
  love.graphics.scale(scale, scale)

  Theme.softShadow(-bw / 2, -bh / 2 + cs * 0.06, bw, bh, Theme.radius.block, 0.5)
  love.graphics.setColor(topBg[1], topBg[2], topBg[3], alpha)
  love.graphics.rectangle("fill", -bw / 2, -bh / 2, bw, bh, Theme.radius.block, Theme.radius.block)

  local img = GridUI.tileImage(color, value)
  if img then
    local iw, ih = img:getDimensions()
    local s = math.min((cs + 4) / iw, (cs + 4) / ih)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.draw(img, 0, 0, 0, s, s, iw / 2, ih / 2)
  else
    love.graphics.setColor(botCol[1], botCol[2], botCol[3], alpha)
    love.graphics.rectangle("fill", -cs * 0.4, -cs * 0.4, cs * 0.8, cs * 0.8, Theme.radius.block, Theme.radius.block)
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(getFont(math.max(10, math.floor(cs * 0.34))))
    love.graphics.printf(tostring(value), -cs / 2, -cs * 0.18, cs, "center")
  end
  love.graphics.pop()
  love.graphics.setColor(1, 1, 1)
end

function Whack:drawMole(m, t)
  local cs = self.cs
  local px, py = self:cellCenter(m.col, m.row)
  local scale, alpha = 1, 1
  if m.phase == "rise" then
    local p = math.min(1, m.t / RISE_TIME)
    scale, alpha = 0.2 + 0.8 * easeOutBack(p), p
  elseif m.phase == "sink" then
    local p = math.min(1, m.t / SINK_TIME)
    scale, alpha = 1 - 0.6 * p, 1 - p
  end
  local rot = 0
  if MUI.motion() then
    rot = math.sin(t * 3 + m.wobble) * 0.06 + m.spin * 0.04
  end
  self:drawTile(m.color, m.value, px, py, cs, scale, alpha, rot)
end

function Whack:draw()
  local t = love.timer.getTime()
  local gx, gy, cs = self.gx, self.gy, self.cs
  local stage = self.stage

  local sdx, sdy = self.fx:shakeOffset()
  love.graphics.push()
  love.graphics.translate(sdx, sdy)

  MUI.drawStage(stage.x, stage.y, stage.w, stage.h, t)
  MUI.drawField(gx, gy, self.cols, self.rows, cs)

  -- hover highlight
  if self.hoverCell then
    local col = self.hoverCell % 100
    local row = math.floor(self.hoverCell / 100)
    love.graphics.setColor(1, 1, 1, 0.10)
    love.graphics.rectangle("fill", gx + col * cs + 2, gy + row * cs + 2,
      cs - 4, cs - 4, Theme.radius.cell, Theme.radius.cell)
  end

  -- hit / miss flashes
  for key, v in pairs(self.hitFlash) do
    local col, row = key % 100, math.floor(key / 100)
    love.graphics.setColor(0.55, 1, 0.65, 0.45 * v)
    love.graphics.rectangle("fill", gx + col * cs + 2, gy + row * cs + 2,
      cs - 4, cs - 4, Theme.radius.cell, Theme.radius.cell)
  end
  for key, v in pairs(self.missedFlash) do
    local col, row = key % 100, math.floor(key / 100)
    love.graphics.setColor(1, 0.30, 0.36, 0.40 * v)
    love.graphics.rectangle("fill", gx + col * cs + 2, gy + row * cs + 2,
      cs - 4, cs - 4, Theme.radius.cell, Theme.radius.cell)
  end

  for _, m in ipairs(self.moles) do
    self:drawMole(m, t)
  end

  self.fx:draw()
  love.graphics.setColor(1, 1, 1)
  love.graphics.pop()

  if self:timeLeft() <= URGENT_TIME then
    local pulse = 0.5 + 0.5 * math.sin(t * 6)
    love.graphics.setColor(1, 0.2, 0.25, 0.05 + 0.05 * pulse)
    love.graphics.rectangle("fill", stage.x, stage.y, stage.w, stage.h, Theme.radius.card, Theme.radius.card)
    love.graphics.setColor(1, 1, 1)
  end
end

-- ═══════════════════════════════════════════
-- HUD
-- ═══════════════════════════════════════════
local function drawTargetPanel(x, y, w, h, target, flash, t)
  Theme.softShadow(x, y, w, h, h / 2, 0.5, { 0.10, 0.06, 0.22 })
  Theme.rrGradient(x, y, w, h, h / 2, { 0.30, 0.22, 0.42 }, { 0.18, 0.14, 0.28 }, h * 0.45)
  love.graphics.setColor(1, 1, 1, 0.10)
  love.graphics.rectangle("line", x, y, w, h, h / 2, h / 2)

  if flash > 0.02 then
    local pulse = 0.5 + 0.5 * math.sin(t * 10)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 0.6, 0.8, 0.20 * flash + 0.12 * pulse * flash)
    love.graphics.rectangle("fill", x - 2, y - 2, w + 4, h + 4, h / 2 + 2, h / 2 + 2)
    love.graphics.setBlendMode("alpha")
  end

  love.graphics.setFont(Theme.font(Theme.fontSize.tiny))
  love.graphics.setColor(0.86, 0.80, 0.95, 0.9)
  love.graphics.print("COLPOISCI", x + h * 0.95, y + h / 2 - Theme.fontSize.tiny * 0.9)

  local img = GridUI.tileImage(target.color, target.value)
  local ts = h * 0.68
  if img then
    local iw, ih = img:getDimensions()
    local s = ts / math.max(iw, ih)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(img, x + w - h * 0.6, y + h / 2, 0, s, s, iw / 2, ih / 2)
  else
    local col = candyOf(target.color)
    love.graphics.setColor(col[1], col[2], col[3])
    love.graphics.circle("fill", x + w - h * 0.6, y + h / 2, ts * 0.4)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Theme.font(Theme.fontSize.h3))
    love.graphics.printf(tostring(target.value), x + w - h * 0.6 - ts / 2, y + h / 2 - Theme.fontSize.h3 * 0.55, ts, "center")
  end
  love.graphics.setColor(1, 1, 1)
end

function Whack:drawHUD()
  local t = love.timer.getTime()
  local stage = self.stage
  local w = stage.w
  local pillH = 30
  local padX = 14
  local py = stage.y + 8

  local targetW = w * 0.40 - padX
  drawTargetPanel(stage.x + padX, py, targetW, pillH, self.target, self.targetFlash, t)

  local restX = stage.x + w * 0.40
  local restW = w - w * 0.40 - padX
  local halfW = (restW - 6) / 2
  MUI.drawStatPill(restX, py, halfW, pillH, "star", self.score, "punti",
    { valueCol = { 1, 0.92, 0.5 } })
  MUI.drawStatPill(restX + halfW + 6, py, halfW, pillH, "target", self.caught, "centri",
    { valueCol = { 0.75, 1, 0.8 } })

  local tw = w - padX * 2
  local ty = py + pillH + 8
  local urgency = self:timeLeft() <= URGENT_TIME
  MUI.drawTimerBar(stage.x + padX, ty, tw, 8, self:timeLeft() / self.duration, urgency, t)

  local fy = stage.y + stage.h - self.footerH + self.footerH * 0.24
  if self.streak >= 2 then
    local col = self.streak >= 5 and { 1, 0.75, 0.25 } or { 1, 0.55, 0.75 }
    love.graphics.setFont(Theme.font(Theme.fontSize.h3))
    Theme.set(col)
    love.graphics.printf("STREAK x" .. self.streak, stage.x, fy, w, "center")
  else
    love.graphics.setFont(Theme.font(Theme.fontSize.small))
    love.graphics.setColor(0.82, 0.78, 0.92, 0.85)
    love.graphics.printf("Tocca solo le tile che combaciano col bersaglio!", stage.x, fy, w, "center")
  end

  if self.introT < INTRO_TIME then
    local a = 1 - self.introT / INTRO_TIME
    local cy = self.gy + self.gridPixelH * 0.34
    MUI.drawHeader(stage.x + w / 2, cy - 30, w, "TALPA!", "target", a,
      { size = Theme.fontSize.hero, fill = { 1, 0.6, 0.75 } })
    love.graphics.setFont(Theme.font(Theme.fontSize.body))
    love.graphics.setColor(1, 1, 1, a * 0.9)
    love.graphics.printf("Colpisci la tile bersaglio, evita le esche!", stage.x, cy + 12, w, "center")
  end

  love.graphics.setColor(1, 1, 1)
end

return Whack
