local Theme = require("src.ui.theme")
local Emoji = require("src.ui.emoji")
local Modal = require("src.ui.components.modal")
local Button = require("src.ui.components.button")
local Help = {}
local cardX, cardY, cardW, cardH
local page = 1
local totalPages = 5
local nextBtn, prevBtn

local pages = {
  {title = "Movimento",   desc = "Trascina un blocco in 8 direzioni. Scorri fino all'ostacolo. Ghost rosa mostra l'anteprima.", icon = "hand"},
  {title = "Fusione",     desc = "Stesso colore + stesso valore = fusione. 8+8 → 16. A 32 esplode: +4 blocchi da 1.", icon = "boom"},
  {title = "Bonus", desc = "Ogni 6-10s appare un bonus da toccare o trascinare: level up (tutti i tile salgono di livello), grow (raddoppia un tile a scelta), jolly/arcobaleno (tile universale), spada/laser (elimina righe e colonne), 100/200/300 punti, clone, muro (2 vite, dà punti se distrutto).", icon = "sparkles"},
  {title = "Malus", desc = "Ogni 15-25s un malus: level down (tutti i tile perdono un livello), ghiaccio (board bloccata), scramble (mischia i pezzi), invertito (movimenti invertiti), pioggia (2-5 pezzi in più), tassa (punti dimezzati per 8s).", icon = "target"},
  {title = "Minigiochi", desc = "Ogni tanto appare un tile Minigioco: toccalo per giocare a Falling Tiles. Muovi il secchio toccando a sinistra o a destra (o trascinando) e prendi più tile che puoi in 30s. I punti presi si sommano al tuo score.", icon = "star"},
}

local function build(w, h)
  cardW = math.min(440, w - 20)
  cardH = math.min(480, h - 20)
  cardX = (w - cardW) / 2
  cardY = (h - cardH) / 2
  local bw = 90
  nextBtn = Button.new({x = cardX + cardW - 100, y = cardY + cardH - 52, w = bw, h = 36, label = "Avanti", variant = "primary", id = "next"})
  prevBtn = Button.new({x = cardX + 16, y = cardY + cardH - 52, w = bw, h = 36, label = "Indietro", variant = "secondary", id = "prev"})
end

function Help.resize(w, h) build(w, h) end
function Help.load() build(love.graphics.getDimensions()); page = 1 end
function Help.setPage(p) page = math.max(1, math.min(totalPages, p)) end
function Help.nextPage() page = math.min(totalPages, page + 1) end
function Help.prevPage() page = math.max(1, page - 1) end
function Help.getPage() return page end

function Help.draw()
  Modal.drawBackdrop()
  Theme.drawCardShadow(cardX, cardY, cardW, cardH, 5)
  Modal.drawClose(cardX, cardY, cardW)

  -- Title
  do
    local txt = "Come si gioca"
    local font = Theme.font(20)
    love.graphics.setFont(font)
    local tw = font:getWidth(txt)
    local iconSize = 22
    local gap = 8
    local totalW = iconSize + gap + tw
    local sx = cardX + (cardW - totalW) / 2
    Emoji.draw("question", sx + iconSize / 2, cardY + 26, iconSize, 1)
    love.graphics.setColor(Theme.text)
    love.graphics.printf(txt, sx + iconSize + gap, cardY + 16, tw, "left")
  end

  -- Page dots
  for i = 1, totalPages do
    local dotX = cardX + cardW / 2 - (totalPages * 14) / 2 + (i - 1) * 14
    local dotY = cardY + 44
    if i == page then
      Theme.set(Theme.accent)
      love.graphics.circle("fill", dotX + 6, dotY + 6, 5)
    else
      Theme.set(Theme.borderLight)
      love.graphics.circle("fill", dotX + 6, dotY + 6, 4)
    end
  end

  -- Page content
  local p = pages[page]
  Emoji.draw(p.icon, cardX + cardW / 2, cardY + 92, 56, 1)
  love.graphics.setColor(Theme.text)
  love.graphics.setFont(Theme.font(16))
  love.graphics.printf(p.title, cardX + 16, cardY + 130, cardW - 32, "center")
  love.graphics.setColor(Theme.textSecondary)
  love.graphics.setFont(Theme.font(12))
  do
    local descY = cardY + 160
    local descH = cardY + cardH - 60 - descY
    if descH > 0 then love.graphics.setScissor(cardX + 8, descY, cardW - 16, descH) end
    love.graphics.printf(p.desc, cardX + 20, descY, cardW - 40, "center")
    love.graphics.setScissor()
  end

  -- Navigation buttons
  if page > 1 then
    prevBtn:draw()
  else
    -- Disabled state
    Theme.rrSolid(prevBtn.x, prevBtn.y, prevBtn.w, prevBtn.h, Theme.radius.pill, Theme.button.disabledBg)
    love.graphics.setColor(Theme.button.disabledText)
    love.graphics.setFont(Theme.font(11))
    love.graphics.printf("Indietro", prevBtn.x, prevBtn.y + 11, prevBtn.w, "center")
  end

  if page < totalPages then
    nextBtn:draw()
  else
    local b = Button.new({x = nextBtn.x, y = nextBtn.y, w = nextBtn.w, h = nextBtn.h, label = "Chiudi", variant = "primary", id = "close"})
    b:draw()
    Help._closeBtn = b
  end

  Help._cardX, Help._cardY, Help._cardW, Help._cardH = cardX, cardY, cardW, cardH
end

function Help.hitTest(x, y)
  if Modal.hitClose(x, y, cardX, cardY, cardW) then return "close" end
  if x < cardX or x > cardX + cardW or y < cardY or y > cardY + cardH then return "outside" end
  if page > 1 and prevBtn:hitTest(x, y) then return "prev" end
  if page < totalPages and nextBtn:hitTest(x, y) then return "next" end
  if page == totalPages and Help._closeBtn and Help._closeBtn:hitTest(x, y) then return "close" end
  return nil
end

function Help.updateHover(x, y)
  if prevBtn then prevBtn:setHover(page > 1 and prevBtn:hitTest(x, y)) end
  if nextBtn then nextBtn:setHover(page < totalPages and nextBtn:hitTest(x, y)) end
end

function Help.pressAt(x, y)
  if page > 1 and prevBtn and prevBtn:hitTest(x, y) then prevBtn:setPressed(true) end
  if page < totalPages and nextBtn and nextBtn:hitTest(x, y) then nextBtn:setPressed(true) end
end

function Help.releasePress()
  if prevBtn then prevBtn:setPressed(false) end
  if nextBtn then nextBtn:setPressed(false) end
end

return Help
