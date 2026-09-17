-- MINIGAME UI — shared stage, HUD widgets and a LOCAL effect layer.
--
-- Minigames render on top of a full-screen dim (see main.love.draw); the
-- global FX layer of the board is drawn underneath that dim, so minigames
-- must own their own particles/rings/shake here to stay crisp.
local Theme = require("src.ui.theme")
local Emoji = require("src.ui.emoji")
local FX = require("src.ui.fx")

local Settings
do
  local ok, mod = pcall(require, "src.systems.settings")
  if ok then Settings = mod end
end

local MUI = {}

local function motionOn()
  return FX.motion
end

-- Exposed so minigames can gate their own idle/shake animation.
function MUI.motion() return motionOn() end

local function particlesOn()
  if Settings and Settings.data and Settings.data.particles ~= nil then
    return Settings.data.particles and true or false
  end
  return true
end

local function easeOutQuad(t) return t * (2 - t) end

local function drawStar(x, y, r, rot, col, alpha)
  love.graphics.setColor(col[1], col[2], col[3], alpha)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.rotate(rot)
  local t = r * 0.30
  love.graphics.rectangle("fill", -r, -t, r * 2, t * 2, t)
  love.graphics.rectangle("fill", -t, -r, t * 2, r * 2, t)
  love.graphics.pop()
end
MUI.drawStar = drawStar

-- ═══════════════════════════════════════════
-- LOCAL EFFECT LAYER
-- ═══════════════════════════════════════════
local Effects = {}
Effects.__index = Effects

function MUI.newEffects()
  return setmetatable({
    particles = {},
    rings = {},
    _shake = { mag = 0, rot = 0, t = 0, dur = 0 },
  }, Effects)
end

function Effects:burst(cx, cy, col, opts)
  opts = opts or {}
  if not motionOn() or not particlesOn() then return end
  local count = opts.count or 12
  local speed = opts.speed or 150
  local lifeMin, lifeMax = opts.lifeMin or 0.35, opts.lifeMax or 0.7
  local sizeMin, sizeMax = opts.sizeMin or 2.5, opts.sizeMax or 5
  local cols = opts.colors or { col or { 1, 1, 1 }, { 1, 1, 1 } }
  local grav = opts.gravity or 340
  local drag = opts.drag or 0.98
  local shape = opts.shape or "circle"
  for _ = 1, count do
    local ang = math.random() * math.pi * 2
    local spd = speed * (0.5 + math.random() * 0.6)
    local c = cols[math.random(#cols)]
    self.particles[#self.particles + 1] = {
      x = cx, y = cy,
      vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
      g = grav, drag = drag,
      life = lifeMin + math.random() * (lifeMax - lifeMin),
      age = 0,
      col = c,
      size = sizeMin + math.random() * (sizeMax - sizeMin),
      shape = shape,
      rot = math.random() * math.pi * 2,
      spin = (math.random() - 0.5) * 7,
    }
  end
end

function Effects:ring(cx, cy, col, r0, r1, opts)
  opts = opts or {}
  if not motionOn() then return end
  self.rings[#self.rings + 1] = {
    x = cx, y = cy,
    r0 = r0 or 4, r1 = r1 or 40,
    col = col or { 1, 1, 1 },
    dur = opts.dur or 0.4,
    lw = opts.lw or 2,
    age = 0,
  }
end

function Effects:shake(mag, dur)
  if not motionOn() then return end
  local s = self._shake
  if s.t <= 0 then s.mag, s.dur = 0, 0 end
  s.mag = math.max(s.mag, mag)
  s.dur = math.max(s.dur, dur or 0.2)
  s.t = s.dur
end

function Effects:shakeOffset()
  local s = self._shake
  if s.t <= 0 then return 0, 0 end
  local p = s.t / s.dur
  local decay = p * p * (3 - 2 * p)
  local dx = math.sin(s.t * 62) * s.mag * decay
  local dy = math.cos(s.t * 47) * s.mag * 0.6 * decay
  return dx, dy
end

function Effects:reset()
  self.particles = {}
  self.rings = {}
  self._shake = { mag = 0, rot = 0, t = 0, dur = 0 }
end

function Effects:update(dt)
  for i = #self.particles, 1, -1 do
    local p = self.particles[i]
    p.age = p.age + dt
    if p.age >= p.life then
      table.remove(self.particles, i)
    else
      p.vy = p.vy + p.g * dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.vx = p.vx * p.drag
      p.rot = p.rot + p.spin * dt
    end
  end
  for i = #self.rings, 1, -1 do
    self.rings[i].age = self.rings[i].age + dt
    if self.rings[i].age >= self.rings[i].dur then
      table.remove(self.rings, i)
    end
  end
  if self._shake.t > 0 then self._shake.t = self._shake.t - dt end
end

function Effects:draw()
  for _, p in ipairs(self.particles) do
    local alpha = math.max(0, 1 - p.age / p.life)
    local sz = p.size * (1 + p.age * 0.3)
    if p.shape == "star" then
      drawStar(p.x, p.y, sz * 1.3, p.rot, p.col, alpha * 0.95)
    else
      love.graphics.setColor(p.col[1], p.col[2], p.col[3], alpha * 0.9)
      love.graphics.circle("fill", p.x, p.y, sz)
      love.graphics.setColor(1, 1, 1, alpha * 0.4)
      love.graphics.circle("fill", p.x, p.y, sz * 0.6)
    end
  end
  for _, r in ipairs(self.rings) do
    local p = r.age / r.dur
    local rad = r.r0 + (r.r1 - r.r0) * easeOutQuad(p)
    local alpha = (1 - p) * 0.55
    love.graphics.setLineWidth(r.lw)
    love.graphics.setColor(r.col[1], r.col[2], r.col[3], alpha * 0.5)
    love.graphics.circle("line", r.x, r.y, rad + 3)
    love.graphics.setColor(r.col[1], r.col[2], r.col[3], alpha)
    love.graphics.circle("line", r.x, r.y, rad)
    love.graphics.setLineWidth(1)
  end
  love.graphics.setColor(1, 1, 1)
end

-- ═══════════════════════════════════════════
-- STAGE
-- ═══════════════════════════════════════════
function MUI.drawStage(gx, gy, gw, gh, t, opts)
  opts = opts or {}
  local r = opts.radius or Theme.radius.card
  local st = Theme.stageMinigame

  Theme.softShadow(gx, gy, gw, gh, r, 1.0, { 0.10, 0.06, 0.22 })

  -- smooth rounded gradient (stencilled so the corners stay rounded)
  love.graphics.setColor(1, 1, 1)
  love.graphics.stencil(function()
    love.graphics.rectangle("fill", gx, gy, gw, gh, r, r)
  end, "replace", 1)
  love.graphics.setStencilTest("greater", 0)
  Theme.verticalFade(gx, gy, gw, gh, st.top, st.bot, 24)

  -- arena top light (additive, fades out smoothly — no hard scissor edge)
  local glowA = motionOn() and (0.12 + 0.05 * math.sin(t * 1.4)) or 0.14
  love.graphics.setBlendMode("add")
  Theme.verticalFade(gx, gy, gw, gh * 0.38,
    { st.glow[1], st.glow[2], st.glow[3], glowA },
    { st.glow[1], st.glow[2], st.glow[3], 0 }, 12)
  love.graphics.setBlendMode("alpha")

  -- bottom depth
  Theme.verticalFade(gx, gy + gh * 0.76, gw, gh * 0.24, { 0, 0, 0, 0 }, { 0, 0, 0, 0.30 }, 10)
  love.graphics.setStencilTest()

  -- border
  love.graphics.setColor(st.edge[1], st.edge[2], st.edge[3], st.edge[4])
  love.graphics.setLineWidth(1.5)
  love.graphics.rectangle("line", gx, gy, gw, gh, r, r)
  love.graphics.setLineWidth(1)

  -- corner sparkles
  if motionOn() then
    local s = 3.2
    local pts = {
      { gx + 16, gy + 16, 0.0 },
      { gx + gw - 16, gy + 16, 1.7 },
      { gx + 16, gy + gh - 16, 3.1 },
      { gx + gw - 16, gy + gh - 16, 4.6 },
    }
    for _, p in ipairs(pts) do
      local tw = 0.5 + 0.5 * math.sin(t * 2.4 + p[3])
      drawStar(p[1], p[2], s * (0.7 + 0.5 * tw), t * 0.6 + p[3], st.star, 0.35 * tw)
    end
  end
  love.graphics.setColor(1, 1, 1)
end

-- Playfield background: checker cells + faint grid, drawn inside the stage.
function MUI.drawField(gx, gy, cols, rows, cs, floorRow)
  local st = Theme.stageMinigame
  for y = 0, rows - 1 do
    for x = 0, cols - 1 do
      local rx, ry = gx + x * cs, gy + y * cs
      local c = ((x + y) % 2 == 0) and st.cell or st.cellAlt
      Theme.set(c)
      love.graphics.rectangle("fill", rx + 1, ry + 1, cs - 2, cs - 2, Theme.radius.cell, Theme.radius.cell)
      Theme.set(st.gridLine)
      love.graphics.rectangle("line", rx + 1, ry + 1, cs - 2, cs - 2, Theme.radius.cell, Theme.radius.cell)
    end
  end
  if floorRow then
    local fy = gy + floorRow * cs
    Theme.set(st.floor)
    love.graphics.rectangle("fill", gx, fy + cs * 0.72, cols * cs, cs * 0.28,
      Theme.radius.cell, Theme.radius.cell)
  end
end

-- Vertical guidance beam for the bucket column.
function MUI.drawLane(gx, gy, cols, rows, cs, colX, color, t)
  color = color or Theme.stage.lane
  local lx = gx + colX * cs
  local ly = gy
  local lh = rows * cs

  -- beam gradient: transparent top -> soft color at floor
  local steps = math.max(14, math.min(48, math.floor(lh / 20)))
  Theme.verticalFade(lx + cs * 0.16, ly, cs * 0.68, lh,
    { color[1], color[2], color[3], 0.0 },
    { color[1], color[2], color[3], 0.22 }, steps)

  -- floor pool
  local poolPulse = motionOn() and (0.06 * math.sin(t * 3)) or 0
  love.graphics.setBlendMode("add")
  love.graphics.setColor(color[1], color[2], color[3], 0.20 + poolPulse)
  love.graphics.ellipse("fill", lx + cs / 2, ly + lh - cs * 0.18, cs * 0.62, cs * 0.22)
  love.graphics.setBlendMode("alpha")

  -- top chevron marker
  local mx = lx + cs / 2
  local my = ly + cs * 0.30
  local bob = motionOn() and (math.sin(t * 4) * 2) or 0
  love.graphics.setColor(color[1], color[2], color[3], 0.55)
  love.graphics.polygon("fill",
    mx - cs * 0.20, my - cs * 0.16 + bob,
    mx + cs * 0.20, my - cs * 0.16 + bob,
    mx, my + cs * 0.10 + bob)
end

-- ═══════════════════════════════════════════
-- HUD WIDGETS
-- ═══════════════════════════════════════════
function MUI.drawHeader(cx, y, width, title, icon, alpha, opts)
  opts = opts or {}
  alpha = alpha or 1
  if alpha <= 0.01 then return end
  local size = opts.size or Theme.fontSize.h2
  Theme.chunkyText(title, cx - width / 2, y, size, {
    width = width,
    align = "center",
    fill = opts.fill or { 1, 1, 1 },
    outline = opts.outline or { 0.26, 0.16, 0.40 },
    a = alpha,
  })
  if icon then
    local iw = size * 0.95
    Emoji.draw(icon, cx - width / 2 - iw * 0.7, y + size * 0.42, iw, alpha)
    Emoji.draw(icon, cx + width / 2 + iw * 0.7, y + size * 0.42, iw, alpha)
  end
end

function MUI.drawTimerBar(x, y, w, h, pct, urgency, t)
  pct = math.max(0, math.min(1, pct))
  -- track
  Theme.rrGradient(x, y, w, h, h / 2, { 0.09, 0.07, 0.14 }, { 0.05, 0.04, 0.10 }, h * 0.5)
  love.graphics.setColor(1, 1, 1, 0.08)
  love.graphics.rectangle("line", x, y, w, h, h / 2, h / 2)

  if pct > 0.002 then
    local top = urgency and { 1, 0.36, 0.42 } or { 0.98, 0.62, 0.78 }
    local bot = urgency and { 0.86, 0.16, 0.24 } or Theme.accent
    Theme.rrGradient(x, y, w * pct, h, h / 2, top, bot, h * 0.5)

    if urgency then
      local pulse = 0.5 + 0.5 * math.sin(t * 8)
      love.graphics.setBlendMode("add")
      love.graphics.setColor(1, 0.4, 0.45, 0.18 + 0.22 * pulse)
      love.graphics.rectangle("fill", x - 2, y - 2, w * pct + 4, h + 4, (h + 4) / 2, (h + 4) / 2)
      love.graphics.setBlendMode("alpha")
    end
  end
  love.graphics.setColor(1, 1, 1)
end

function MUI.drawStatPill(x, y, w, h, icon, value, label, opts)
  opts = opts or {}
  Theme.softShadow(x, y, w, h, h / 2, 0.5, { 0.10, 0.06, 0.22 })
  Theme.rrGradient(x, y, w, h, h / 2,
    opts.top or { 0.24, 0.19, 0.36 },
    opts.bot or { 0.15, 0.12, 0.24 }, h * 0.45)
  love.graphics.setColor(1, 1, 1, 0.10)
  love.graphics.rectangle("line", x, y, w, h, h / 2, h / 2)

  local tx = x + 10
  if icon then
    Emoji.draw(icon, x + h * 0.5, y + h * 0.5, h * 0.52, 1)
    tx = x + h * 0.95
  end
  love.graphics.setFont(Theme.font(Theme.fontSize.h3))
  love.graphics.setColor(opts.valueCol or { 1, 1, 1 })
  love.graphics.print(tostring(value or 0), tx, y + h * 0.5 - Theme.fontSize.h3 * 0.58)
  if label then
    love.graphics.setFont(Theme.font(Theme.fontSize.tiny))
    love.graphics.setColor(0.80, 0.75, 0.90, 0.9)
    local vw = Theme.font(Theme.fontSize.h3):getWidth(tostring(value or 0))
    love.graphics.print(label, tx + vw + 5, y + h * 0.5 - Theme.fontSize.tiny * 0.55)
  end
  love.graphics.setColor(1, 1, 1)
end

return MUI
