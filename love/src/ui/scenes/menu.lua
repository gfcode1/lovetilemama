local Theme = require("src.ui.theme")
local Button = require("src.ui.components.button")
local Emoji = require("src.ui.emoji")
local Menu = {}

local buttons = {}
local titleBounce = 0
local entranceTimer = 0
local logoImg = nil
local logoW, logoH = 179, 256

local function buildButtons(w, h, hasSave)
  buttons = {}
  local bw = math.min(300, w - 40)
  local bh = 48
  local cx = (w - bw) / 2
  local startY = h * 0.40
  local gap = 12

  local labels = {
    {id = "continue",  label = "Continua",     icon = "play",     variant = "primary",   disabled = not hasSave},
    {id = "new",       label = "Nuova Partita", icon = "sparkles", variant = "primary"},
    {id = "leaderboard", label = "Classifica",  icon = "trophy",   variant = "secondary"},
    {id = "achievements", label = "Traguardi",  icon = "target",   variant = "secondary"},
    {id = "help",      label = "Come si gioca", icon = "question", variant = "secondary"},
    {id = "settings",  label = "Impostazioni",  icon = "package",  variant = "secondary"},
  }

  local os = love.system and love.system.getOS and love.system.getOS() or "Linux"
  if os ~= "Android" and os ~= "iOS" then
    table.insert(labels, {id = "quit", label = "Esci", icon = nil, variant = "ghost"})
  end

  for i, info in ipairs(labels) do
    local y = startY + (i - 1) * (bh + gap)
    local b = Button.new({x = cx, y = y, w = bw, h = bh, label = info.label, icon = info.icon, variant = info.variant, disabled = info.disabled, id = info.id})
    -- stagger entrance
    b._animDelay = i * 0.08
    b._animAlpha = 0
    b._animOffY = 20
    table.insert(buttons, b)
  end
  Menu._bw = bw
  Menu._bh = bh
end

function Menu.load(hasSave)
  local w, h = love.graphics.getDimensions()
  buildButtons(w, h, hasSave)
  titleBounce = 0
  entranceTimer = 0
  if not logoImg then
    local path = "assets/tilemama_cropped.png"
    if love.filesystem.getInfo(path) then
      local ok, img = pcall(love.graphics.newImage, path)
      if ok then logoImg = img end
    end
  end
end

function Menu.resize(w, h, hasSave)
  buildButtons(w, h, hasSave)
end

function Menu.draw(engine)
  local w, h = love.graphics.getDimensions()
  local t = love.timer.getTime()
  entranceTimer = entranceTimer + love.timer.getDelta()

  -- Title animation
  titleBounce = titleBounce + love.timer.getDelta()
  local bounce = math.sin(t * 1.5) * 3

  -- ── Logo area ──
  local logoImgH = math.max(180, math.floor(h * 0.30))
  local logoImgW = math.floor(logoImgH * logoW / logoH)
  local titleY = h * 0.06 + bounce

  if logoImg then
    local logoScale = logoImgH / logoH
    local pulse = 1 + 0.03 * math.sin(t * 2)
    local logoCX = w / 2
    local logoCY = titleY + logoImgH / 2
    love.graphics.push()
    love.graphics.translate(logoCX, logoCY)
    love.graphics.scale(pulse, pulse)
    love.graphics.translate(-logoCX, -logoCY)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(logoImg, logoCX - logoImgW / 2, titleY, 0, logoScale, logoScale)
    love.graphics.pop()
  else
    Theme.chunkyText("TileMama", 0, titleY, 36, {
      fill = Theme.accent,
      outline = Theme.accentDark,
      width = w,
      align = "center",
    })
  end

  -- ── Button container card ──
  local bw = Menu._bw or 300
  local totalH = #buttons * (48 + 12) - 12
  local cx = (w - bw) / 2
  local bgY = h * 0.40 - 16
  local cardH = totalH + 32

  -- Soft shadow + gradient card
  Theme.softShadow(cx - 14, bgY, bw + 28, cardH, Theme.radius.card, 0.8)
  Theme.roundRect(cx - 14, bgY, bw + 28, cardH, {
    r = Theme.radius.card,
    top = {1, 1, 1, 0.92},
    bot = {0.995, 0.99, 0.995, 0.92},
    gloss = {1, 1, 1, 0.10},
    gh = cardH * 0.15,
  })

  -- ── Buttons (staggered entrance) ──
  for _, b in ipairs(buttons) do
    local delay = b._animDelay or 0
    local progress = math.max(0, math.min(1, (entranceTimer - delay) / 0.3))
    -- ease out back
    local s = 1.70158
    local t2 = progress - 1
    local eased = t2 * t2 * ((s + 1) * t2 + s) + 1
    b._animAlpha = progress
    b._animOffY = (1 - eased) * 20
    -- apply offset for entrance
    local origY = b.y
    b.y = b.y + b._animOffY
    love.graphics.push()
    love.graphics.setColor(1, 1, 1, b._animAlpha)
    b:draw()
    love.graphics.pop()
    b.y = origY
  end

  -- ── Footer ──
  if engine and engine.best and engine.best > 0 then
    Theme.set(Theme.textSecondary)
    love.graphics.setFont(Theme.font(10))
    love.graphics.printf("Best: " .. engine.best, 0, h - 32, w, "center")
    Emoji.draw("star", w / 2 - Theme.font(10):getWidth("Best: " .. engine.best) / 2 - 16, h - 28, 16, 0.7)
  end

  -- Controls hint
  Theme.set(Theme.textTertiary)
  love.graphics.setFont(Theme.font(9))
  love.graphics.printf("Drag / Tap / Frecce  •  Esc pausa", 0, h - 16, w, "center")
end

function Menu.hitTest(x, y)
  for _, b in ipairs(buttons) do
    if b:hitTest(x, y) then return b.id end
  end
  return nil
end

function Menu.updateHover(x, y)
  for _, b in ipairs(buttons) do b:setHover(b:hitTest(x, y)) end
end

function Menu.pressAt(x, y)
  for _, b in ipairs(buttons) do if b:hitTest(x, y) then b:setPressed(true) end end
end

function Menu.releasePress()
  for _, b in ipairs(buttons) do b:setPressed(false) end
end

return Menu
