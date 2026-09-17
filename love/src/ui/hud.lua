local Theme = require("src.ui.theme")
local Emoji = require("src.ui.emoji")
local H = {}

-- ═══════════════════════════════════════════
-- HUD STATE (for animations)
-- ═══════════════════════════════════════════
local prevScore = 0
local scorePopTimer = 0
local comboPulse = 0
local prevCombo = 0

function H.resetState()
  prevScore = 0
  scorePopTimer = 0
  comboPulse = 0
  prevCombo = 0
end

-- ═══════════════════════════════════════════
-- DRAW — compact single row
-- ═══════════════════════════════════════════
function H.draw(engine, combo, layout)
  local pad = layout.pad
  local winW = love.graphics.getWidth()
  local hudH = layout.hudH
  local t = love.timer.getTime()

  -- Score animation tracking
  if engine.score > prevScore then
    scorePopTimer = 0.6
  end
  if scorePopTimer > 0 then scorePopTimer = scorePopTimer - love.timer.getDelta() end
  prevScore = engine.score

  -- Combo pulse animation
  if combo.combo > prevCombo and combo.combo > 1 then
    comboPulse = 1.0
  end
  if comboPulse > 0 then comboPulse = comboPulse - love.timer.getDelta() * 2 end
  prevCombo = combo.combo

  -- ── Top bar card ──
  local cardY = 4
  local cardH = hudH - 4
  Theme.softShadow(pad, cardY, winW - pad * 2, cardH, Theme.radius.card, 0.8)
  Theme.roundRect(pad, cardY, winW - pad * 2, cardH, {
    r = Theme.radius.card,
    top = {1, 1, 1, 0.95},
    bot = {0.995, 0.99, 0.995, 0.95},
    gloss = {1, 1, 1, 0.15},
    gh = cardH * 0.3,
  })

  -- ── Score pill (left) ──
  local leftX = pad + 10
  local scoreW = 96
  local scoreH = 26
  local scoreY = cardY + math.floor((cardH - scoreH) / 2)

  local scoreScale = 1
  if scorePopTimer > 0 then
    scoreScale = 1 + 0.08 * math.sin(scorePopTimer * 20)
  end

  love.graphics.push()
  local scoreCX = leftX + scoreW / 2
  local scoreCY = scoreY + scoreH / 2
  love.graphics.translate(scoreCX, scoreCY)
  love.graphics.scale(scoreScale, scoreScale)
  love.graphics.translate(-scoreCX, -scoreCY)

  Theme.drawPill(leftX, scoreY, scoreW, scoreH, Theme.accent, nil, {
    top = Theme.accent,
    bot = Theme.accentDark,
  })

  Theme.set(Theme.textInverse)
  love.graphics.setFont(Theme.font(12))
  love.graphics.printf("Score " .. engine.score, leftX, scoreY + 6, scoreW, "center")
  love.graphics.pop()

  -- ── Combo badge (center-left) ──
  local comboW = 72
  local comboX = leftX + scoreW + 10
  local comboY = cardY + math.floor((cardH - 22) / 2)

  if combo.combo > 1 then
    local pulse = 1 + 0.06 * math.sin(t * 6) * comboPulse
    love.graphics.push()
    local ccx = comboX + comboW / 2
    local ccy = comboY + 11
    love.graphics.translate(ccx, ccy)
    love.graphics.scale(pulse, pulse)
    love.graphics.translate(-ccx, -ccy)
    Theme.drawPill(comboX, comboY, comboW, 22, {1, 0.75, 0.82}, nil, {
      top = {1, 0.78, 0.84},
      bot = {0.98, 0.62, 0.72},
    })
    love.graphics.pop()
  else
    Theme.drawPill(comboX, comboY, comboW, 22, {1, 0.96, 0.94})
  end

  if combo.combo > 1 then
    Theme.set(Theme.accentDark)
  else
    Theme.set(Theme.textSecondary)
  end
  love.graphics.setFont(Theme.font(10))
  love.graphics.printf("Combo x" .. combo.combo, comboX, comboY + 5, comboW, "center")

  -- ── Undo button (compact icon, right of pause) ──
  local iconBtnW = 32
  local iconBtnH = 26
  local iconBtnY = cardY + math.floor((cardH - iconBtnH) / 2)
  local rightX = winW - pad - 10

  -- Pause button (rightmost)
  local pauseX = rightX - iconBtnW
  Theme.roundRect(pauseX, iconBtnY, iconBtnW, iconBtnH, {
    r = iconBtnH / 2,
    top = {1, 1, 1},
    bot = {0.96, 0.94, 0.96},
    border = Theme.borderLight,
    bw = 1,
    gloss = {1, 1, 1, 0.2},
    gh = iconBtnH * 0.4,
  })
  Emoji.draw("pause", pauseX + 16, iconBtnY + 13, 18, 1)
  H._btnPause = {x = pauseX, y = iconBtnY, w = iconBtnW, h = iconBtnH}

  -- Undo button (left of pause)
  local undoX = pauseX - 6 - iconBtnW
  local canUndo = engine:canUndo()
  if canUndo then
    Theme.roundRect(undoX, iconBtnY, iconBtnW, iconBtnH, {
      r = iconBtnH / 2,
      top = {0.88, 0.94, 1},
      bot = {0.80, 0.88, 0.98},
      border = {0.40, 0.74, 1, 0.30},
      bw = 1,
      gloss = {1, 1, 1, 0.2},
      gh = iconBtnH * 0.4,
    })
  else
    Theme.rrSolid(undoX, iconBtnY, iconBtnW, iconBtnH, iconBtnH / 2, Theme.button.disabledBg)
  end
  Emoji.draw("undo", undoX + 16, iconBtnY + 13, 18, canUndo and 1 or 0.35)
  H._btnUndo = {x = undoX, y = iconBtnY, w = iconBtnW, h = iconBtnH}

  -- ── Add Tiles button (+3, left of undo) ──
  local addX = undoX - 6 - iconBtnW
  local canAdd = not engine.gameOver and not engine.pendingMode and not engine:isFrozen() and #engine:freeCells() >= 3
  if canAdd then
    Theme.roundRect(addX, iconBtnY, iconBtnW, iconBtnH, {
      r = iconBtnH / 2,
      top = {0.92, 0.98, 0.90},
      bot = {0.82, 0.94, 0.80},
      border = {0.40, 0.82, 0.30, 0.30},
      bw = 1,
      gloss = {1, 1, 1, 0.2},
      gh = iconBtnH * 0.4,
    })
  else
    Theme.rrSolid(addX, iconBtnY, iconBtnW, iconBtnH, iconBtnH / 2, Theme.button.disabledBg)
  end
  Theme.set(canAdd and Theme.text or Theme.button.disabledText)
  love.graphics.setFont(Theme.font(12))
  love.graphics.printf("+3", addX, iconBtnY + 5, iconBtnW, "center")
  H._btnAdd = {x = addX, y = iconBtnY, w = iconBtnW, h = iconBtnH}

  -- ── Buff badge (between combo and undo, only when active and room) ──
  if engine:isBuffActive() then
    local buffW = 72
    local buffH = 20
    local buffY = cardY + math.floor((cardH - buffH) / 2)
    local buffX = comboX + comboW + 8
    if buffX + buffW <= addX - 6 then
      Theme.drawPill(buffX, buffY, buffW, buffH, Theme.success, nil, {
        top = Theme.success,
        bot = Theme.successDark,
      })
      Theme.set(Theme.textInverse)
      love.graphics.setFont(Theme.font(9))
      love.graphics.printf("BUFF x1.5", buffX, buffY + 4, buffW, "center")
    end
  end

  -- ── GAME OVER hint ──
  if engine.gameOver then
    Theme.set(Theme.danger)
    love.graphics.setFont(Theme.font(10))
    love.graphics.printf("GAME OVER — R rigioca", pad, hudH - 14, winW - pad * 2, "center")
  end

  -- ── Decorative accent line ──
  Theme.roundRect(pad + 4, hudH, winW - pad * 2 - 8, 2, {
    r = 1,
    top = Theme.accent,
    bot = Theme.accentDark,
  })
  Theme.roundRect(pad + 4, hudH + 2, winW - pad * 2 - 8, 1, {
    r = 1,
    top = Theme.accentLight,
    bot = Theme.withAlpha(Theme.accentLight, 0.3),
  })
end

function H.hitTest(x, y)
  local function inside(b, pad)
    pad = pad or 3
    return b and x >= b.x - pad and x <= b.x + b.w + pad
      and y >= b.y - pad and y <= b.y + b.h + pad
  end
  if inside(H._btnPause) then return "pause" end
  if inside(H._btnUndo) then return "undo" end
  if inside(H._btnAdd) then return "addTiles" end
  return nil
end

return H
