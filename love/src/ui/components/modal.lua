local Theme = require("src.ui.theme")
local Modal = {}

function Modal.drawBackdrop()
  local w, h = love.graphics.getDimensions()
  love.graphics.setColor(Theme.overlay.backdrop)
  love.graphics.rectangle("fill", 0, 0, w, h)
end

function Modal.drawCard(x, y, w, h)
  Theme.softShadow(x, y, w, h, Theme.radius.card, 1.0, {0.72, 0.52, 0.62})
  Theme.roundRect(x, y, w, h, {
    r = Theme.radius.card,
    top = {1, 1, 1},
    bot = {0.995, 0.985, 0.99},
    border = {1, 0.86, 0.90, 0.8},
    bw = 1.5,
    gloss = {1, 1, 1, 0.10},
    gh = h * 0.28,
    shade = {0.92, 0.82, 0.90, 0.10},
  })
end

-- Centered modal rect with padding
function Modal.centeredRect(padW, padH)
  local w, h = love.graphics.getDimensions()
  local pw = w - (padW or 40)
  local ph = h - (padH or 40)
  local x = (w - pw) / 2
  local y = (h - ph) / 2
  return x, y, pw, ph
end

-- Close button hit test (larger, more accessible)
function Modal.hitClose(px, py, cardX, cardY, cardW)
  local cx = cardX + cardW - 40
  local cy = cardY + 8
  -- Visual button is 32x32; hit area inflated to 44x44 for touch
  return px >= cx - 6 and px <= cx + 38 and py >= cy - 6 and py <= cy + 38
end

-- Close button (circular, more visible)
function Modal.drawClose(cardX, cardY, cardW)
  local cx = cardX + cardW - 40
  local cy = cardY + 8
  local size = 32
  -- Soft shadow circle
  Theme.softShadow(cx, cy, size, size, size / 2, 0.3)
  Theme.roundRect(cx, cy, size, size, {
    r = size / 2,
    top = {0.96, 0.94, 0.96},
    bot = {0.90, 0.88, 0.92},
    gloss = {1, 1, 1, 0.2},
    gh = size * 0.4,
  })
  -- X icon
  love.graphics.setColor(Theme.textSecondary[1], Theme.textSecondary[2], Theme.textSecondary[3], 0.8)
  love.graphics.setFont(Theme.font(14))
  love.graphics.printf("✕", cx, cy + 8, size, "center")
end

return Modal
