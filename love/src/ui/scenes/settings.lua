local Theme = require("src.ui.theme")
local Button = require("src.ui.components.button")
local Emoji = require("src.ui.emoji")
local Modal = require("src.ui.components.modal")
local Settings = require("src.systems.settings")
local S = {}

local cardX, cardY, cardW, cardH
local volDown, volUp, partBtn, motionBtn, resetBtn

local function build(w, h)
  cardW = math.min(380, w - 32)
  cardH = 356
  cardX = (w - cardW) / 2
  cardY = (h - cardH) / 2
  local rowY = cardY + 112
  volDown = Button.new({x = cardX + 24, y = rowY, w = 52, h = 42, label = "-", variant = "secondary", id = "volDown"})
  volUp   = Button.new({x = cardX + cardW - 76, y = rowY, w = 52, h = 42, label = "+", variant = "secondary", id = "volUp"})
  partBtn = Button.new({x = cardX + 24, y = rowY + 62, w = cardW - 48, h = 44, label = "Particelle", variant = "secondary", id = "particles"})
  motionBtn = Button.new({x = cardX + 24, y = rowY + 112, w = cardW - 48, h = 44, label = "Tile animate", variant = "secondary", id = "motion"})
  resetBtn = Button.new({x = cardX + 24, y = rowY + 164, w = cardW - 48, h = 44, label = "Azzera progressi", variant = "ghost", id = "reset"})
  S._cardX, S._cardY, S._cardW, S._cardH = cardX, cardY, cardW, cardH
end

function S.resize(w, h) build(w, h) end
function S.load() build(love.graphics.getDimensions()) end

function S.draw()
  local data = Settings.data

  Modal.drawBackdrop()
  Modal.drawCard(cardX, cardY, cardW, cardH)
  Modal.drawClose(cardX, cardY, cardW)

  do
    local txt = "Impostazioni"
    local font = Theme.font(20)
    love.graphics.setFont(font)
    local tw = font:getWidth(txt)
    local iconSize = 22
    local gap = 8
    local totalW = iconSize + gap + tw
    local sx = cardX + (cardW - totalW) / 2
    Emoji.draw("package", sx + iconSize / 2, cardY + 26, iconSize, 1)
    love.graphics.setColor(Theme.text)
    love.graphics.printf(txt, sx + iconSize + gap, cardY + 16, tw, "left")
  end

  Theme.set(Theme.textTertiary)
  love.graphics.setFont(Theme.font(10))
  love.graphics.printf("Audio e resa", cardX, cardY + 44, cardW, "center")

  Theme.roundRect(cardX + cardW * 0.3, cardY + 56, cardW * 0.4, 2, {
    r = 1, top = Theme.accent, bot = Theme.accentDark,
  })

  -- Volume row
  Theme.set(Theme.textSecondary)
  love.graphics.setFont(Theme.font(11))
  love.graphics.printf("Volume", cardX + 24, cardY + 84, cardW - 48, "left")
  volDown:draw()
  volUp:draw()
  Theme.set(Theme.text)
  love.graphics.setFont(Theme.font(16))
  love.graphics.printf(math.floor(data.volume * 100 + 0.5) .. "%", cardX + 76, cardY + 122, cardW - 152, "center")

  -- Particles row
  partBtn.label = "Particelle: " .. (data.particles and "On" or "Off")
  partBtn:draw()

  -- Motion row
  motionBtn.label = "Tile animate: " .. (data.motion and "On" or "Off")
  motionBtn:draw()

  resetBtn:draw()
end

function S.hitTest(x, y)
  if Modal.hitClose(x, y, cardX, cardY, cardW) then return "close" end
  if x < cardX or x > cardX + cardW or y < cardY or y > cardY + cardH then return "outside" end
  if volDown:hitTest(x, y) then return "volDown" end
  if volUp:hitTest(x, y) then return "volUp" end
  if partBtn:hitTest(x, y) then return "particles" end
  if motionBtn:hitTest(x, y) then return "motion" end
  if resetBtn:hitTest(x, y) then return "reset" end
  return nil
end

function S.updateHover(x, y)
  volDown:setHover(volDown:hitTest(x, y))
  volUp:setHover(volUp:hitTest(x, y))
  partBtn:setHover(partBtn:hitTest(x, y))
  motionBtn:setHover(motionBtn:hitTest(x, y))
  resetBtn:setHover(resetBtn:hitTest(x, y))
end

function S.pressAt(x, y)
  if volDown:hitTest(x, y) then volDown:setPressed(true) end
  if volUp:hitTest(x, y) then volUp:setPressed(true) end
  if partBtn:hitTest(x, y) then partBtn:setPressed(true) end
  if motionBtn:hitTest(x, y) then motionBtn:setPressed(true) end
  if resetBtn:hitTest(x, y) then resetBtn:setPressed(true) end
end

function S.releasePress()
  volDown:setPressed(false)
  volUp:setPressed(false)
  partBtn:setPressed(false)
  motionBtn:setPressed(false)
  resetBtn:setPressed(false)
end

-- Applies a settings action. Returns true if audio should be reapplied.
function S.activate(id)
  local data = Settings.data
  if id == "volDown" then
    data.volume = math.max(0, data.volume - 0.1)
  elseif id == "volUp" then
    data.volume = math.min(1, data.volume + 0.1)
  elseif id == "particles" then
    data.particles = not data.particles
    return "particles"
  elseif id == "motion" then
    data.motion = not data.motion
    return "motion"
  end
  return "audio"
end

return S
