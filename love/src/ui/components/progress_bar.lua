local Theme = require("src.ui.theme")
local PB = {}

function PB.draw(x, y, w, h, pct, fillCol)
  pct = math.max(0, math.min(1, pct or 0))
  local r = math.min(Theme.radius.pill, w / 2, h / 2)

  -- Track
  Theme.set({0.95, 0.93, 0.95})
  love.graphics.rectangle("fill", x, y, w, h, r, r)

  -- Fill
  if pct > 0 then
    local fillW = math.max(h, w * pct)
    Theme.set(fillCol or Theme.accent)
    love.graphics.rectangle("fill", x, y, fillW, h, r, r)

    -- Gloss: full-radius rect clipped to top band (straight bottom edge)
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
      Theme.set({1, 1, 1, 0.25})
      love.graphics.rectangle("fill", x + 2, y + 1, fillW - 4, gh, r, r)
      if prevGX then
        love.graphics.setScissor(prevGX, prevGY, prevGW, prevGH)
      else
        love.graphics.setScissor()
      end
    end
  end
end

-- Animated version with shimmer
function PB.drawAnimated(x, y, w, h, pct, fillCol, time)
  PB.draw(x, y, w, h, pct, fillCol)

  if pct > 0.1 then
    local fillW = w * pct
    local shimmerX = (time * 80) % (fillW + 40) - 20
    local prevSX, prevSY, prevSW, prevSH = love.graphics.getScissor()
    if prevSX then
      local ix  = math.max(x, prevSX)
      local iy  = math.max(y + 1, prevSY)
      local ix2 = math.min(x + fillW, prevSX + prevSW)
      local iy2 = math.min(y + h - 1, prevSY + prevSH)
      love.graphics.setScissor(ix, iy, math.max(0, ix2 - ix), math.max(0, iy2 - iy))
    else
      love.graphics.setScissor(x, y + 1, fillW, h - 2)
    end
    Theme.set({1, 1, 1, 0.15})
    love.graphics.rectangle("fill", x + shimmerX, y + 1, 20, h - 2, 10, 10)
    if prevSX then
      love.graphics.setScissor(prevSX, prevSY, prevSW, prevSH)
    else
      love.graphics.setScissor()
    end
  end
end

return PB
