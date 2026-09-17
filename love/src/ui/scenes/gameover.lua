local Theme = require("src.ui.theme")
local Button = require("src.ui.components.button")
local Emoji = require("src.ui.emoji")
local GO = {}
local buttons = {}
local cardX, cardY, cardW, cardH
local entranceTimer = 0

local function build(w, h)
  cardW = math.min(380, w - 24)
  cardH = 400
  cardX = (w - cardW) / 2
  cardY = (h - cardH) / 2
  local bw = cardW - 32
  local bh = 44
  local startY = cardY + 160
  local gap = 10
  local defs = {
    {id = "retry",       label = "Rigioca",    icon = "refresh",  variant = "primary"},
    {id = "leaderboard", label = "Classifica",  icon = "trophy",   variant = "secondary"},
    {id = "menu",        label = "Menu",        icon = "home",     variant = "secondary"},
  }
  buttons = {}
  for i, d in ipairs(defs) do
    local y = startY + (i - 1) * (bh + gap)
    table.insert(buttons, Button.new({x = cardX + 16, y = y, w = bw, h = bh, label = d.label, icon = d.icon, variant = d.variant, id = d.id}))
  end
end

function GO.resize(w, h) build(w, h) end
function GO.load() build(love.graphics.getDimensions()); entranceTimer = 0 end

function GO.draw(engine)
  local w, h = love.graphics.getDimensions()
  local t = love.timer.getTime()
  entranceTimer = entranceTimer + love.timer.getDelta()

  -- Card with soft shadow
  Theme.softShadow(cardX, cardY, cardW, cardH, Theme.radius.card, 1.0, {0.72, 0.52, 0.62})
  Theme.roundRect(cardX, cardY, cardW, cardH, {
    r = Theme.radius.card,
    top = {1, 1, 1},
    bot = {0.995, 0.985, 0.99},
    border = {1, 0.86, 0.90, 0.8},
    bw = 1.5,
    gloss = {1, 1, 1, 0.10},
    gh = cardH * 0.28,
    shade = {0.92, 0.82, 0.90, 0.10},
  })

  -- Game Over label (danger color)
  Theme.set(Theme.danger)
  love.graphics.setFont(Theme.font(11))
  love.graphics.printf("GAME OVER", cardX, cardY + 14, cardW, "center")

  -- Score (chunky text with animation)
  local scoreScale = math.min(1, entranceTimer * 4)
  love.graphics.push()
  local scx = cardX + cardW / 2
  local scy = cardY + 42
  love.graphics.translate(scx, scy)
  love.graphics.scale(scoreScale, scoreScale)
  love.graphics.translate(-scx, -scy)
  Theme.chunkyText("Punteggio " .. (engine and engine.score or 0), cardX, cardY + 28, 24, {
    fill = Theme.text,
    outline = Theme.shadow.dark,
    width = cardW,
    align = "center",
  })
  love.graphics.pop()

  -- Best + Max row
  Theme.set(Theme.textSecondary)
  love.graphics.setFont(Theme.font(11))
  local best = engine and engine.best or 0
  local maxT = engine and engine.maxTile or 1
  love.graphics.printf("Best " .. best .. "  •  Max " .. maxT, cardX, cardY + 60, cardW, "center")

  -- Stats cards (2 columns, gradient)
  local sw = (cardW - 48) / 2

  -- Left: Max tile
  Theme.softShadow(cardX + 16, cardY + 84, sw, 56, Theme.radius.round, 0.4)
  Theme.roundRect(cardX + 16, cardY + 84, sw, 56, {
    r = Theme.radius.round,
    top = Theme.candy.yellowBg,
    bot = Theme.candy.yellow,
    gloss = {1, 1, 1, 0.2},
    gh = 20,
  })
  Theme.set(Theme.textSecondary)
  love.graphics.setFont(Theme.font(10))
  love.graphics.printf("Blocco max", cardX + 16, cardY + 92, sw, "center")
  Theme.set(Theme.text)
  love.graphics.setFont(Theme.font(18))
  love.graphics.printf(tostring(maxT), cardX + 16, cardY + 108, sw, "center")

  -- Right: Score
  Theme.softShadow(cardX + 16 + sw + 16, cardY + 84, sw, 56, Theme.radius.round, 0.4)
  Theme.roundRect(cardX + 16 + sw + 16, cardY + 84, sw, 56, {
    r = Theme.radius.round,
    top = Theme.candy.blueBg,
    bot = Theme.candy.blue,
    gloss = {1, 1, 1, 0.2},
    gh = 20,
  })
  Theme.set(Theme.textSecondary)
  love.graphics.setFont(Theme.font(10))
  love.graphics.printf("Punteggio", cardX + 16 + sw + 16, cardY + 92, sw, "center")
  Theme.set(Theme.text)
  love.graphics.setFont(Theme.font(18))
  love.graphics.printf(tostring(engine and engine.score or 0), cardX + 16 + sw + 16, cardY + 108, sw, "center")

  -- Buttons
  for _, b in ipairs(buttons) do b:draw() end
  GO._cardX, GO._cardY, GO._cardW, GO._cardH = cardX, cardY, cardW, cardH

  -- Footer hint
  Theme.set(Theme.textTertiary)
  love.graphics.setFont(Theme.font(9))
  love.graphics.printf("Premi R per rigiocare  •  Esc menu", cardX, cardY + cardH - 16, cardW, "center")
end

function GO.hitTest(x, y)
  for _, b in ipairs(buttons) do if b:hitTest(x, y) then return b.id end end
  return nil
end

function GO.updateHover(x, y)
  for _, b in ipairs(buttons) do b:setHover(b:hitTest(x, y)) end
end

function GO.pressAt(x, y)
  for _, b in ipairs(buttons) do if b:hitTest(x, y) then b:setPressed(true) end end
end

function GO.releasePress()
  for _, b in ipairs(buttons) do b:setPressed(false) end
end

return GO
