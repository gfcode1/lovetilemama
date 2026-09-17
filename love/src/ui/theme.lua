local T = {}

-- ═══════════════════════════════════════════
-- CANDY PALETTE — refreshed with depth
-- ═══════════════════════════════════════════
T.bgTop     = {1, 0.965, 0.91}
T.bgMid     = {1, 0.93, 0.94}
T.bgBottom  = {1, 0.89, 0.94}
T.bgFlat    = {1, 0.93, 0.94}

T.card       = {1, 1, 1}
T.cardShadow = {0.92, 0.85, 0.88}
T.surface    = {1, 0.98, 0.96}
T.surfaceAlt = {1, 0.96, 0.93}

T.text       = {0.23, 0.18, 0.23}
T.textSecondary = {0.45, 0.38, 0.42}
T.textTertiary  = {0.62, 0.56, 0.59}
T.textInverse   = {1, 1, 1}

T.candy = {
  green     = {0.42, 0.82, 0.30},
  greenBg   = {0.90, 0.97, 0.88},
  greenDark = {0.30, 0.62, 0.22},
  red       = {0.98, 0.38, 0.50},
  redBg     = {1, 0.92, 0.94},
  redDark   = {0.78, 0.26, 0.38},
  yellow    = {1, 0.82, 0.20},
  yellowBg  = {1, 0.97, 0.86},
  yellowDark= {0.82, 0.66, 0.14},
  blue      = {0.40, 0.74, 1},
  blueBg    = {0.86, 0.93, 1},
  blueDark  = {0.28, 0.56, 0.82},
}

T.accent     = {0.98, 0.48, 0.62}
T.accentDark = {0.88, 0.32, 0.48}
T.accentLight= {1, 0.72, 0.80}
T.success    = {0.42, 0.82, 0.30}
T.successDark= {0.30, 0.65, 0.22}
T.warn       = {1, 0.68, 0.12}
T.warnDark   = {0.82, 0.54, 0.08}
T.danger     = {0.95, 0.28, 0.28}
T.dangerDark = {0.75, 0.18, 0.18}
T.info       = {0.40, 0.74, 1}
T.infoDark   = {0.28, 0.56, 0.82}

T.gridBg     = {1, 0.97, 0.94}
T.cellEmpty  = {1, 0.96, 0.93}
T.cellHover  = {1, 0.93, 0.90}
T.cellStroke = {1, 0.88, 0.85, 0.5}

T.shadow = {
  light  = {0.92, 0.85, 0.88, 0.3},
  medium = {0.88, 0.80, 0.84, 0.4},
  dark   = {0.78, 0.68, 0.74, 0.5},
  glow   = {1, 0.72, 0.80, 0.3},
  inset  = {0.88, 0.82, 0.86, 0.2},
}

T.border      = {1, 0.84, 0.88, 0.9}
T.borderLight = {1, 0.88, 0.90, 0.5}
T.borderAccent= {0.98, 0.48, 0.62, 0.3}

T.radius = {
  sm    = 8, card  = 18, cell  = 14, block = 16,
  pill  = 999, lg    = 24, round = 12,
}

T.space = {xs = 6, s = 10, m = 14, l = 20, xl = 28, xxl = 40}

T.fontSize = {
  hero    = 36, h1 = 24, h2 = 18, h3 = 15,
  body    = 13, caption = 11, small = 10, tiny = 9, pill = 11,
}

T.overlay = {
  backdrop     = {0.15, 0.12, 0.16, 0.55},
  backdropSoft = {0.15, 0.12, 0.16, 0.30},
}

-- ═══════════════════════════════════════════
-- MINIGAME STAGE — twilight arcade, candy accents
-- ═══════════════════════════════════════════
T.stage = {
  top      = {0.16, 0.13, 0.24, 0.28},
  mid      = {0.11, 0.09, 0.18, 0.34},
  bot      = {0.07, 0.06, 0.13, 0.42},
  edge     = {0.62, 0.50, 0.92, 0.40},
  glow     = {0.72, 0.55, 1},
  lane     = {0.72, 0.55, 1},
  laneAlt  = {0.45, 0.38, 0.72},
  grid     = {1, 1, 1, 0.045},
  gridLine = {1, 1, 1, 0.12},
  cell     = {0.10, 0.08, 0.16, 0.18},
  cellAlt  = {0.06, 0.05, 0.12, 0.26},
  star     = {1, 0.98, 0.94},
  floor    = {0.30, 0.24, 0.46, 0.35},
}

local function stageVariant(scale)
  local function sc(c) return { c[1], c[2], c[3], (c[4] or 1) * scale } end
  local s = T.stage
  return {
    top = sc(s.top), mid = sc(s.mid), bot = sc(s.bot),
    edge = s.edge, glow = s.glow, star = s.star,
    grid = sc(s.grid), gridLine = sc(s.gridLine),
    cell = sc(s.cell), cellAlt = sc(s.cellAlt), floor = sc(s.floor),
  }
end
T.stageMain     = stageVariant(0.85)
T.stageMinigame = stageVariant(0.40)

T.button = {
  primaryBg     = {0.98, 0.48, 0.62},
  primaryHover  = {1, 0.58, 0.70},
  primaryPressed= {0.88, 0.38, 0.52},
  primaryText   = {1, 1, 1},
  secondaryBg     = {1, 1, 1},
  secondaryHover  = {1, 0.97, 0.96},
  secondaryPressed= {0.95, 0.93, 0.92},
  secondaryBorder = {0.98, 0.48, 0.62, 0.20},
  secondaryText   = {0.23, 0.18, 0.23},
  ghostBg     = {1, 1, 1, 0},
  ghostHover  = {1, 0.96, 0.94, 0.6},
  ghostText   = {0.45, 0.38, 0.42},
  disabledBg  = {0.94, 0.92, 0.94},
  disabledText= {0.70, 0.66, 0.70},
}

-- ═══════════════════════════════════════════
-- COLOR HELPERS
-- ═══════════════════════════════════════════
function T.withAlpha(c, a)
  return {c[1], c[2], c[3], a}
end
function T.lerpCol(a, b, t)
  return { a[1]+(b[1]-a[1])*t, a[2]+(b[2]-a[2])*t, a[3]+(b[3]-a[3])*t, (a[4] or 1)+((b[4] or 1)-(a[4] or 1))*t }
end
function T.brighten(c, t) return T.lerpCol(c, {1,1,1}, t or 0.25) end
function T.darken(c, t)   return T.lerpCol(c, {0,0,0}, t or 0.2) end

-- ═══════════════════════════════════════════
-- FONT SYSTEM with caching
-- ═══════════════════════════════════════════
local fontCache = {}
function T.font(sz)
  if not fontCache[sz] then fontCache[sz] = love.graphics.newFont(sz) end
  return fontCache[sz]
end
function T.fontResponsive(base, winW)
  local scale = 1
  if winW < 380 then scale = 0.85
  elseif winW > 600 then scale = 1.1 end
  return T.font(math.floor(base * scale))
end

-- ═══════════════════════════════════════════
-- DRAWING HELPERS (pure LÖVE, no shaders)
-- ═══════════════════════════════════════════
function T.set(c, a)
  love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

-- Rounded rect: solid fill (clamped to true pill)
function T.rrSolid(x, y, w, h, r, col, a)
  r = math.min(r or 0, w / 2, h / 2)
  T.set(col, a)
  love.graphics.rectangle("fill", x, y, w, h, r, r)
end

-- Rounded rect: vertical 2-stop gradient (top → bot) with scissor-clipped halves
function T.rrGradient(x, y, w, h, r, top, bot, gloss)
  r = math.min(r or 0, w / 2, h / 2)
  -- bottom: full rounded rect
  T.set(bot)
  love.graphics.rectangle("fill", x, y, w, h, r, r)
  -- top: full rounded rect clipped to upper half (no seam)
  local mid = math.floor(y + h / 2)
  local prevSX, prevSY, prevSW, prevSH = love.graphics.getScissor()
  if prevSX then
    local ix  = math.max(0, prevSX)
    local iy  = math.max(y, prevSY)
    local ix2 = math.min(love.graphics.getWidth(), prevSX + prevSW)
    local iy2 = math.min(mid, prevSY + prevSH)
    love.graphics.setScissor(ix, iy, math.max(0, ix2 - ix), math.max(0, iy2 - iy))
  else
    love.graphics.setScissor(0, y, love.graphics.getWidth(), mid - y)
  end
  T.set(top)
  love.graphics.rectangle("fill", x, y, w, h, r, r)
  if prevSX then
    love.graphics.setScissor(prevSX, prevSY, prevSW, prevSH)
  else
    love.graphics.setScissor()
  end
  -- gloss highlight: full-radius rect clipped to top band (straight bottom edge)
  if gloss then
    local gh = math.floor(type(gloss) == "number" and math.min(gloss, h * 0.45) or h * 0.35)
    if gh > 1 then
      local prevGX, prevGY, prevGW, prevGH = love.graphics.getScissor()
      if prevGX then
        local ix  = math.max(0, prevGX)
        local iy  = math.max(y, prevGY)
        local ix2 = math.min(love.graphics.getWidth(), prevGX + prevGW)
        local iy2 = math.min(y + gh, prevGY + prevGH)
        love.graphics.setScissor(ix, iy, math.max(0, ix2 - ix), math.max(0, iy2 - iy))
      else
        love.graphics.setScissor(0, y, love.graphics.getWidth(), gh)
      end
      T.set({1, 1, 1, 0.22})
      love.graphics.rectangle("fill", x + 2, y + 1, w - 4, gh, r, r)
      if prevGX then
        love.graphics.setScissor(prevGX, prevGY, prevGW, prevGH)
      else
        love.graphics.setScissor()
      end
    end
  end
end

-- True vertical gradient (color + alpha), drawn as horizontal strips.
-- Use this instead of rrGradient when either stop is translucent: rrGradient's
-- 2-stop scissor trick cannot fade to alpha 0 and would produce hard bands.
function T.verticalFade(x, y, w, h, topCol, botCol, steps)
  steps = math.max(1, steps or 16)
  local y0 = math.floor(y)
  local y1 = math.floor(y + h)
  local span = y1 - y0
  if span <= 0 then return end
  local prev = y0
  for i = 1, steps do
    local edge = y0 + math.floor(i * span / steps)
    if edge > prev then
      local c = T.lerpCol(topCol, botCol, (i - 0.5) / steps)
      T.set(c)
      love.graphics.rectangle("fill", x, prev, w, edge - prev)
      prev = edge
    end
  end
end

-- Generic rounded rect (back-compat wrapper)
function T.roundRect(x, y, w, h, opts)
  opts = opts or {}
  local r = math.min(opts.r or 0, w / 2, h / 2)
  local top = opts.top or opts.col or {1, 1, 1}
  local bot = opts.bot or top
  T.rrGradient(x, y, w, h, r, top, bot, opts.gh)
  if opts.border then
    local bc = opts.border
    love.graphics.setColor(bc[1], bc[2], bc[3], bc[4] or 1)
    love.graphics.rectangle("line", x, y, w, h, r, r)
  end
end

-- Vertical gradient rect (back-compat)
function T.gradientRect(x, y, w, h, topCol, botCol, r)
  T.rrGradient(x, y, w, h, r or 0, topCol, botCol)
end

-- Soft drop shadow (layered offset rects)
function T.softShadow(x, y, w, h, r, strength, color)
  strength = strength or 1
  color = color or {0.62, 0.44, 0.52}
  r = math.min(r or 0, w / 2, h / 2)
  local layers = {
    {dx = 0, dy = 5, gr = 6, a = 0.10 * strength},
    {dx = 0, dy = 4, gr = 4, a = 0.12 * strength},
    {dx = 0, dy = 3, gr = 2, a = 0.14 * strength},
  }
  for _, l in ipairs(layers) do
    local sr = math.min(r + l.gr, (w + l.gr * 2) / 2, (h + l.gr * 2) / 2)
    T.set(color, (color[4] or 1) * l.a)
    love.graphics.rectangle("fill", x + l.dx - l.gr, y + l.dy - l.gr, w + l.gr * 2, h + l.gr * 2, sr, sr)
  end
end

-- Card with soft shadow
function T.drawCardShadow(x, y, w, h, shadowOffset)
  shadowOffset = shadowOffset or 5
  T.softShadow(x, y, w, h, T.radius.card, 1.0, {0.72, 0.52, 0.62})
  T.roundRect(x, y, w, h, {
    r = T.radius.card,
    top = {1, 1, 1},
    bot = {0.995, 0.985, 0.99},
    border = {1, 0.86, 0.90, 0.8},
    gh = h * 0.28,
  })
end

function T.drawCard(x, y, w, h)
  T.roundRect(x, y, w, h, {
    r = T.radius.card,
    top = {1, 1, 1},
    bot = {0.995, 0.985, 0.99},
    border = T.borderLight,
    gh = h * 0.25,
  })
end

-- Pill / capsule
function T.drawPill(x, y, w, h, bg, border, opts)
  opts = opts or {}
  local top = opts.top or bg
  local bot = opts.bot or T.darken(bg, 0.08)
  T.rrGradient(x, y, w, h, h / 2, top, bot)
  -- gloss: clipped to top band (straight bottom edge)
  local gh = math.floor(h * 0.42)
  if gh > 1 then
    local prevGX, prevGY, prevGW, prevGH = love.graphics.getScissor()
    if prevGX then
      local ix  = math.max(0, prevGX)
      local iy  = math.max(y, prevGY)
      local ix2 = math.min(love.graphics.getWidth(), prevGX + prevGW)
      local iy2 = math.min(y + gh, prevGY + prevGH)
      love.graphics.setScissor(ix, iy, math.max(0, ix2 - ix), math.max(0, iy2 - iy))
    else
      love.graphics.setScissor(0, y, love.graphics.getWidth(), gh)
    end
    T.set({1, 1, 1, opts.glossAlpha or 0.22})
    love.graphics.rectangle("fill", x + 2, y + 1, w - 4, gh, h / 2, h / 2)
    if prevGX then
      love.graphics.setScissor(prevGX, prevGY, prevGW, prevGH)
    else
      love.graphics.setScissor()
    end
  end
  if border then
    love.graphics.setColor(border[1], border[2], border[3], border[4] or 1)
    love.graphics.rectangle("line", x, y, w, h, h / 2, h / 2)
  end
end

-- Candy block body (3D effect)
function T.drawBlockShadow(x, y, w, h, r, shadowCol)
  T.softShadow(x, y, w, h, r, 0.7, shadowCol or {0.55, 0.40, 0.48})
end

-- Inset cell (flat, no nested boxes)
function T.drawInsetCell(x, y, w, h, r)
  T.set(T.cellEmpty)
  love.graphics.rectangle("fill", x, y, w, h, r, r)
  love.graphics.setColor(T.cellStroke[1], T.cellStroke[2], T.cellStroke[3], T.cellStroke[4] or 1)
  love.graphics.rectangle("line", x, y, w, h, r, r)
end

-- Glow ring
function T.drawGlowRing(cx, cy, radius, col, pulse)
  pulse = pulse or 0
  local alpha = 0.15 + 0.1 * math.sin(pulse * 4)
  local r = radius + 4 + 2 * math.sin(pulse * 3)
  T.set({col[1], col[2], col[3], alpha * 0.5})
  love.graphics.circle("fill", cx, cy, r + 8)
  T.set({col[1], col[2], col[3], alpha})
  love.graphics.circle("fill", cx, cy, r + 4)
  T.set({col[1], col[2], col[3], alpha + 0.15})
  love.graphics.circle("line", cx, cy, r)
end

-- Circular progress ring
function T.drawRingProgress(cx, cy, radius, pct, col, bg, lw)
  lw = lw or 3
  pct = math.max(0, math.min(1, pct))
  T.set(T.withAlpha({0.55, 0.48, 0.55}, 0.18))
  love.graphics.arc("line", "open", cx, cy, radius, -math.pi/2, math.pi * 1.5, 16)
  if pct > 0.002 then
    local c = T.brighten(col, 0.15)
    T.set(c)
    love.graphics.arc("line", "open", cx, cy, radius, -math.pi/2, -math.pi/2 + pct * math.pi * 2, 24)
  end
end

-- Animated dashed line
function T.drawDashedLine(x1, y1, x2, y2, dashLen, gapLen, offset, col, lineWidth)
  local dx = x2 - x1
  local dy = y2 - y1
  local dist = math.sqrt(dx * dx + dy * dy)
  if dist < 1 then return end
  local nx = dx / dist
  local ny = dy / dist
  local pos = -(offset % (dashLen + gapLen))
  T.set(col)
  love.graphics.setLineWidth(lineWidth or 2)
  while pos < dist do
    local sx = x1 + nx * math.max(0, pos)
    local sy = y1 + ny * math.max(0, pos)
    local ex = x1 + nx * math.min(dist, pos + dashLen)
    local ey = y1 + ny * math.min(dist, pos + dashLen)
    love.graphics.line(sx, sy, ex, ey)
    pos = pos + dashLen + gapLen
  end
  love.graphics.setLineWidth(1)
end

-- ═══════════════════════════════════════════
-- CHUNKY TEXT — candy style multi-pass text
-- ═══════════════════════════════════════════
function T.chunkyText(str, x, y, size, opts)
  opts = opts or {}
  local font = T.font(size)
  love.graphics.setFont(font)
  local fill = opts.fill or T.text
  local outline = opts.outline or T.darken(fill, 0.55)
  local o = math.max(1, math.floor(size * 0.09))
  local drop = math.max(2, size * 0.10)
  local align = opts.align or "center"
  local hasWidth = opts.width ~= nil

  local function drawPass(col, ox, oy)
    love.graphics.setColor(col[1], col[2], col[3], (col[4] or 1) * (opts.a or 1))
    if hasWidth then
      love.graphics.printf(str, x + ox, y + oy, opts.width, align)
    else
      love.graphics.print(str, x + ox, y + oy)
    end
  end

  -- drop shadow
  if opts.shadow ~= false then
    drawPass(T.withAlpha(outline, 0.25), o, drop)
  end
  -- outline (8 directions)
  for i = 0, 7 do
    local ang = i * math.pi / 4
    drawPass(outline, math.cos(ang) * o, math.sin(ang) * o)
  end
  -- main fill
  drawPass(fill, 0, 0)
  -- top-half highlight (scissored)
  if opts.top ~= false then
    local prevX, prevY, prevW, prevH = love.graphics.getScissor()
    local sx, sy, sw, sh
    if hasWidth then
      sx, sy, sw, sh = x, y, opts.width, size * 0.52
    else
      local tw = font:getWidth(str)
      sx, sy, sw, sh = x, y, tw, size * 0.52
    end
    if prevX then
      local ix  = math.max(sx, prevX)
      local iy  = math.max(sy, prevY)
      local ix2 = math.min(sx + sw, prevX + prevW)
      local iy2 = math.min(sy + sh, prevY + prevH)
      love.graphics.setScissor(ix, iy, math.max(0, ix2 - ix), math.max(0, iy2 - iy))
    else
      love.graphics.setScissor(sx, sy, sw, sh)
    end
    drawPass(T.brighten(fill, 0.5), 0, 0)
    love.graphics.setScissor(prevX, prevY, prevW, prevH)
    if prevX == nil then love.graphics.setScissor() end
  end
end

function T.centerText(str, cx, cy, size, col, alpha)
  love.graphics.setFont(T.font(size))
  love.graphics.setColor(col[1], col[2], col[3], alpha or 1)
  love.graphics.printf(str, cx - 400, cy - size / 2, 800, "center")
end

return T
