local Theme = require("src.ui.theme")
local Button = require("src.ui.components.button")
local Emoji = require("src.ui.emoji")
local Modal = require("src.ui.components.modal")
local Pause = {}
local buttons = {}
local cardX, cardY, cardW, cardH

local function build(w, h)
  cardW = math.min(360, w - 32)
  cardH = 400
  cardX = (w - cardW) / 2
  cardY = (h - cardH) / 2
  local bw = cardW - 32
  local bh = 44
  local startY = cardY + 76
  local gap = 10
  local defs = {
    {id = "resume",       label = "Riprendi",        icon = "play",     variant = "primary"},
    {id = "restart",      label = "Ricomincia",      icon = "refresh",  variant = "secondary"},
    {id = "leaderboard",  label = "Classifica",      icon = "trophy",   variant = "secondary"},
    {id = "achievements", label = "Traguardi",       icon = "target",   variant = "secondary"},
    {id = "help",         label = "Come si gioca",   icon = "question", variant = "secondary"},
    {id = "settings",     label = "Impostazioni",    icon = "package",  variant = "secondary"},
    {id = "menu",         label = "Menu Principale", icon = "home",     variant = "ghost"},
  }
  buttons = {}
  for i, d in ipairs(defs) do
    local y = startY + (i - 1) * (bh + gap)
    table.insert(buttons, Button.new({x = cardX + 16, y = y, w = bw, h = bh, label = d.label, icon = d.icon, variant = d.variant, id = d.id}))
  end
end

function Pause.resize(w, h) build(w, h) end
function Pause.load() build(love.graphics.getDimensions()) end

function Pause.draw()
  Modal.drawBackdrop()
  Modal.drawCard(cardX, cardY, cardW, cardH)
  Modal.drawClose(cardX, cardY, cardW)

  -- Title with chunky text
  Theme.chunkyText("Pausa", cardX, cardY + 14, 22, {
    fill = Theme.text,
    outline = Theme.shadow.dark,
    width = cardW,
    align = "center",
  })

  -- Subtitle
  Theme.set(Theme.textTertiary)
  love.graphics.setFont(Theme.font(10))
  love.graphics.printf("Esc per riprendere", cardX, cardY + 44, cardW, "center")

  -- Accent line under title
  Theme.roundRect(cardX + cardW * 0.3, cardY + 58, cardW * 0.4, 2, {
    r = 1,
    top = Theme.accent,
    bot = Theme.accentDark,
  })

  for _, b in ipairs(buttons) do b:draw() end

  Pause._cardX, Pause._cardY, Pause._cardW, Pause._cardH = cardX, cardY, cardW, cardH
end

function Pause.hitTest(x, y)
  if Modal.hitClose(x, y, cardX, cardY, cardW) then return "close" end
  for _, b in ipairs(buttons) do if b:hitTest(x, y) then return b.id end end
  if x < cardX or x > cardX + cardW or y < cardY or y > cardY + cardH then return "outside" end
  return nil
end

function Pause.updateHover(x, y)
  for _, b in ipairs(buttons) do b:setHover(b:hitTest(x, y)) end
end

function Pause.pressAt(x, y)
  for _, b in ipairs(buttons) do if b:hitTest(x, y) then b:setPressed(true) end end
end

function Pause.releasePress()
  for _, b in ipairs(buttons) do b:setPressed(false) end
end

return Pause
