local Theme = require("src.ui.theme")
local Emoji = require("src.ui.emoji")
local Btn = {}
Btn.__index = Btn

function Btn.new(opts)
  opts = opts or {}
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 120,
    h = opts.h or 44,
    label = opts.label or "",
    variant = opts.variant or "primary",
    disabled = opts.disabled or false,
    icon = opts.icon,
    id = opts.id,
    -- interaction state
    _hover = false,
    _pressed = false,
    -- animation state
    _animScale = 1,
    _animAlpha = 1,
  }, Btn)
end

function Btn:setBounds(x, y, w, h)
  self.x, self.y, self.w, self.h = x, y, w, h
end

function Btn:hitTest(px, py)
  if self.disabled then return false end
  return px >= self.x and px <= self.x + self.w and py >= self.y and py <= self.y + self.h
end

function Btn:setHover(hover) self._hover = hover end
function Btn:setPressed(pressed) self._pressed = pressed end

function Btn:draw()
  local r = Theme.radius.pill
  local bx, by, bw, bh = self.x, self.y, self.w, self.h

  -- Pressed offset
  if self._pressed and not self.disabled then
    by = by + 2
  end

  -- Hover scale
  local scale = 1
  if self._hover and not self.disabled and not self._pressed then
    scale = 1.02
  end

  love.graphics.push()
  if scale ~= 1 then
    love.graphics.translate(bx + bw / 2, by + bh / 2)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-(bx + bw / 2), -(by + bh / 2))
  end

  -- Shadow + gradient body
  if not self.disabled and self.variant ~= "ghost" then
    Theme.softShadow(bx, by, bw, bh, r, 0.4)
  end

  if self.disabled then
    Theme.rrSolid(bx, by, bw, bh, r, Theme.button.disabledBg)
  elseif self.variant == "primary" then
    local top = self._pressed and Theme.button.primaryPressed
      or self._hover and Theme.button.primaryHover
      or Theme.button.primaryBg
    local bot = Theme.button.primaryPressed
    Theme.roundRect(bx, by, bw, bh, {
      r = r, top = top, bot = bot,
      gloss = {1, 1, 1, 0.18}, gh = bh * 0.4,
    })
  elseif self.variant == "secondary" then
    local top = self._pressed and Theme.button.secondaryPressed
      or self._hover and Theme.button.secondaryHover
      or Theme.button.secondaryBg
    local bot = Theme.button.secondaryPressed
    Theme.roundRect(bx, by, bw, bh, {
      r = r, top = top, bot = bot,
      border = Theme.button.secondaryBorder, bw = 1.2,
      gloss = {1, 1, 1, 0.15}, gh = bh * 0.38,
    })
  elseif self.variant == "ghost" then
    local bg = self._hover and Theme.button.ghostHover or Theme.button.ghostBg
    Theme.rrSolid(bx, by, bw, bh, r, bg)
  else
    Theme.rrSolid(bx, by, bw, bh, r, Theme.card)
  end

  -- Icon + label layout
  local textCol
  if self.disabled then textCol = Theme.button.disabledText
  elseif self.variant == "primary" then textCol = Theme.button.primaryText
  elseif self.variant == "secondary" then textCol = Theme.button.secondaryText
  else textCol = Theme.button.ghostText end

  local hasEmoji = self.icon and Emoji.get(self.icon)
  if hasEmoji then
    local fontSize = self.w > 180 and 13 or 11
    local font = Theme.font(fontSize)
    love.graphics.setFont(font)
    local textW = font:getWidth(self.label)
    local iconSize = self.w > 180 and 22 or 20
    local gap = 6
    local totalW = textW + iconSize + gap
    local startX = bx + (bw - totalW) / 2
    local alpha = self.disabled and 0.4 or 1
    Emoji.draw(self.icon, startX + iconSize / 2, by + bh / 2, iconSize, alpha)
    love.graphics.setColor(textCol[1], textCol[2], textCol[3], textCol[4] or 1)
    love.graphics.printf(self.label, startX + iconSize + gap, by + bh / 2 - 7, textW, "left")
  else
    love.graphics.setColor(textCol[1], textCol[2], textCol[3], textCol[4] or 1)
    local fontSize = self.w > 180 and 13 or 11
    love.graphics.setFont(Theme.font(fontSize))
    local txt = self.icon and (self.icon .. " " .. self.label) or self.label
    love.graphics.printf(txt, bx, by + bh / 2 - 7, bw, "center")
  end

  love.graphics.pop()
end

return Btn
