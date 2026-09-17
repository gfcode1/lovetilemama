local Theme = require("src.ui.theme")
local Button = require("src.ui.components.button")
local Modal = require("src.ui.components.modal")
local Confirm = {}

local active = false
local opts = nil
local buttons = {}
local cardX, cardY, cardW, cardH

local function build()
  local w, h = love.graphics.getDimensions()
  cardW = math.min(340, w - 40)
  cardH = 200
  cardX = (w - cardW) / 2
  cardY = (h - cardH) / 2
  local bw = math.floor((cardW - 36) / 2)
  local by = cardY + cardH - 60
  buttons = {
    Button.new({x = cardX + 12, y = by, w = bw, h = 44,
      label = (opts and opts.cancelLabel) or "Annulla", variant = "secondary", id = "cancel"}),
    Button.new({x = cardX + 24 + bw, y = by, w = bw, h = 44,
      label = (opts and opts.confirmLabel) or "Conferma", variant = "primary", id = "confirm"}),
  }
end

function Confirm.open(o)
  opts = o or {}
  active = true
  build()
end

function Confirm.close()
  active = false
  opts = nil
  for _, b in ipairs(buttons) do b:setPressed(false) end
end

function Confirm.isOpen() return active end

function Confirm.resize()
  if active then build() end
end

function Confirm.draw()
  if not active then return end
  Modal.drawBackdrop()
  Theme.softShadow(cardX, cardY, cardW, cardH, Theme.radius.card, 1.0, {0.72, 0.52, 0.62})
  Theme.roundRect(cardX, cardY, cardW, cardH, {
    r = Theme.radius.card,
    top = {1, 1, 1},
    bot = {0.995, 0.985, 0.99},
    border = {1, 0.86, 0.90, 0.8},
    bw = 1.5,
    gloss = {1, 1, 1, 0.10},
    gh = cardH * 0.28,
  })

  Theme.chunkyText((opts and opts.title) or "Sei sicuro?", cardX, cardY + 26, 20, {
    fill = Theme.text,
    outline = Theme.shadow.dark,
    width = cardW,
    align = "center",
  })

  Theme.set(Theme.textSecondary)
  love.graphics.setFont(Theme.font(12))
  love.graphics.printf((opts and opts.message) or "", cardX + 20, cardY + 64, cardW - 40, "center")

  for _, b in ipairs(buttons) do b:draw() end
end

function Confirm.hitTest(x, y)
  if not active then return nil end
  for _, b in ipairs(buttons) do
    if b:hitTest(x, y) then return b.id end
  end
  return "block"
end

function Confirm.updateHover(x, y)
  if not active then return end
  for _, b in ipairs(buttons) do b:setHover(b:hitTest(x, y)) end
end

function Confirm.pressAt(x, y)
  if not active then return end
  for _, b in ipairs(buttons) do if b:hitTest(x, y) then b:setPressed(true) end end
end

function Confirm.releasePress()
  for _, b in ipairs(buttons) do b:setPressed(false) end
end

function Confirm.activate(id)
  if not active then return end
  if id == "confirm" then
    local cb = opts and opts.onConfirm
    Confirm.close()
    if cb then cb() end
  elseif id == "cancel" then
    local cb = opts and opts.onCancel
    Confirm.close()
    if cb then cb() end
  end
end

return Confirm
