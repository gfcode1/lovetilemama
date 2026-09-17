local config = require("src.config")
local L = {}

-- ═══════════════════════════════════════════
-- RESPONSIVE BREAKPOINTS
-- ═══════════════════════════════════════════
-- phone:  < 400px wide
-- tablet: 400-700px wide
-- desktop: > 700px wide

function L.compute(winW, winH)
  local dpr = 1
  if love.window.getDPIScale then
    dpr = love.window.getDPIScale() or 1
  end

  local breakpoint = "phone"
  if winW >= 700 then breakpoint = "desktop"
  elseif winW >= 400 then breakpoint = "tablet" end

  local isTall = winH / winW > 2

  -- Spacing (percentage of smallest dimension, 2-4%)
  local pad = math.max(8, math.floor(math.min(winW, winH) * 0.03))

  -- HUD sizing (responsive, ~4.5% of window height)
  local hudH = math.max(42, math.floor(winH * 0.045))
  if isTall then hudH = hudH + 2 end

  local totalTop = hudH + pad

  -- Grid sizing
  local availW = winW - pad * 2
  local availH = winH - totalTop - pad * 2
  local csW = math.floor(availW / config.GRID_W)
  local csH = math.floor(availH / config.GRID_H)
  local cellSize = math.max(28, math.min(csW, csH))

  local gridPixelW = config.GRID_W * cellSize
  local gridPixelH = config.GRID_H * cellSize

  -- Center grid
  local offsetX = math.floor((winW - gridPixelW) / 2)
  local offsetY = totalTop + math.floor((availH - gridPixelH) / 2)

  return {
    cellSize    = cellSize,
    gridPixelW  = gridPixelW,
    gridPixelH  = gridPixelH,
    offsetX     = offsetX,
    offsetY     = offsetY,
    hudH        = hudH,
    totalTop    = totalTop,
    pad         = pad,
    dpr         = dpr,
    breakpoint  = breakpoint,
    winW        = winW,
    winH        = winH,
  }
end

function L.cellAt(layout, px, py)
  if px < layout.offsetX or py < layout.offsetY then return nil end
  if px >= layout.offsetX + layout.gridPixelW then return nil end
  if py >= layout.offsetY + layout.gridPixelH then return nil end
  local x = math.floor((px - layout.offsetX) / layout.cellSize)
  local y = math.floor((py - layout.offsetY) / layout.cellSize)
  if x < 0 or x >= config.GRID_W or y < 0 or y >= config.GRID_H then return nil end
  return x, y
end

function L.cellRect(layout, x, y)
  return layout.offsetX + x * layout.cellSize,
         layout.offsetY + y * layout.cellSize,
         layout.cellSize, layout.cellSize
end

-- Center a rect within the screen
function L.centerRect(layout, w, h, yOffset)
  yOffset = yOffset or 0
  return (layout.winW - w) / 2, (layout.winH - h) / 2 + yOffset, w, h
end

return L
