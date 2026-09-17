local Theme = require("src.ui.theme")
local Emoji = require("src.ui.emoji")
local Modal = require("src.ui.components.modal")
local LBScene = {}
local cardX, cardY, cardW, cardH

local function build(w, h)
  cardW = math.min(420, w - 24)
  cardH = math.min(560, h - 24)
  cardX = (w - cardW) / 2
  cardY = (h - cardH) / 2
end

function LBScene.resize(w, h) build(w, h) end
function LBScene.load() build(love.graphics.getDimensions()) end

function LBScene.draw(lb)
  Modal.drawBackdrop()
  Modal.drawCard(cardX, cardY, cardW, cardH)
  Modal.drawClose(cardX, cardY, cardW)

  -- Title with icon
  do
    local txt = "Classifica"
    local font = Theme.font(20)
    love.graphics.setFont(font)
    local tw = font:getWidth(txt)
    local iconSize = 22
    local gap = 8
    local totalW = iconSize + gap + tw
    local sx = cardX + (cardW - totalW) / 2
    Emoji.draw("trophy", sx + iconSize / 2, cardY + 26, iconSize, 1)
    love.graphics.setColor(Theme.text)
    love.graphics.printf(txt, sx + iconSize + gap, cardY + 16, tw, "left")
  end

  -- Subtitle
  Theme.set(Theme.textTertiary)
  love.graphics.setFont(Theme.font(10))
  love.graphics.printf("Top 10 partite", cardX, cardY + 44, cardW, "center")

  -- Accent line
  Theme.roundRect(cardX + cardW * 0.3, cardY + 56, cardW * 0.4, 2, {
    r = 1, top = Theme.accent, bot = Theme.accentDark,
  })

  -- Header (aligned columns)
  local y = cardY + 68
  Theme.set(Theme.textTertiary)
  love.graphics.setFont(Theme.font(9))
  love.graphics.printf("#", cardX + 16, y, 24, "left")
  love.graphics.printf("Punteggio", cardX + 44, y, 110, "left")
  love.graphics.printf("Max", cardX + 158, y, 80, "left")
  love.graphics.printf("Data", cardX + 16, y, cardW - 32, "right")
  y = y + 14
  Theme.set(Theme.borderLight)
  love.graphics.line(cardX + 16, y, cardX + cardW - 16, y)
  y = y + 10

  local entries = lb and lb.entries or {}
  if #entries == 0 then
    Theme.set(Theme.textSecondary)
    love.graphics.setFont(Theme.font(13))
    love.graphics.printf("Nessun punteggio — gioca!", cardX, y + 40, cardW, "center")
    love.graphics.setFont(Theme.font(10))
    love.graphics.printf("I tuoi migliori risultati appariranno qui.", cardX, y + 64, cardW, "center")
  else
    for i, e in ipairs(entries) do
      if y + 20 > cardY + cardH - 16 then break end

      -- Row background (gradient for top 3)
      if i <= 3 then
        local medalBgs = {
          {{1, 0.98, 0.90}, {1, 0.95, 0.82}},
          {{0.96, 0.97, 0.99}, {0.92, 0.94, 0.97}},
          {{1, 0.96, 0.92}, {1, 0.92, 0.86}},
        }
        Theme.roundRect(cardX + 12, y - 4, cardW - 24, 24, {
          r = 6, top = medalBgs[i][1], bot = medalBgs[i][2],
        })
      elseif i % 2 == 1 then
        Theme.rrSolid(cardX + 12, y - 4, cardW - 24, 24, 6, Theme.surfaceAlt)
      end

      local col = i <= 3 and Theme.text or Theme.textSecondary
      love.graphics.setColor(col[1], col[2], col[3], col[4] or 1)
      love.graphics.setFont(Theme.font(11))
      local dateStr = ""
      if e.at then dateStr = os.date("%d/%m", e.at) end
      love.graphics.printf(string.format("%2d", i), cardX + 16, y, 24, "left")
      love.graphics.printf(tostring(e.score or 0), cardX + 44, y, 110, "left")
      love.graphics.printf(tostring(e.maxTile or 1), cardX + 158, y, 80, "left")
      love.graphics.printf(dateStr, cardX + 16, y, cardW - 32, "right")
      y = y + 24
    end
  end

  LBScene._cardX, LBScene._cardY, LBScene._cardW, LBScene._cardH = cardX, cardY, cardW, cardH
end

function LBScene.hitTest(x, y)
  if Modal.hitClose(x, y, cardX, cardY, cardW) then return "close" end
  if x < cardX or x > cardX + cardW or y < cardY or y > cardY + cardH then return "outside" end
  return nil
end

return LBScene
