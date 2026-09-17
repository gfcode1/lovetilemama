local Theme = require("src.ui.theme")
local Emoji = require("src.ui.emoji")
local Modal = require("src.ui.components.modal")
local PB = require("src.ui.components.progress_bar")
local config = require("src.config")
local M = {}
local cardX, cardY, cardW, cardH
local scrollY = 0
local contentH = 0
local viewH = 0
local dragging = false
local dragLastY = 0

local function clamp()
  local maxScroll = math.max(0, contentH - viewH)
  if scrollY > 0 then scrollY = 0 end
  if scrollY < -maxScroll then scrollY = -maxScroll end
end

local function build(w, h)
  cardW = math.min(480, w - 20)
  cardH = math.min(620, h - 20)
  cardX = (w - cardW) / 2
  cardY = (h - cardH) / 2
end

function M.resize(w, h) build(w, h) end
function M.load() build(love.graphics.getDimensions()); scrollY = 0 end

local function drawMissionCard(x, y, w, h, m, t)
  local pct = math.min(1, m.progress / m.scaledTarget)
  local fillCol = m.diff == "easy" and Theme.success
    or m.diff == "med" and Theme.candy.yellow
    or Theme.accent
  local darkCol = m.diff == "easy" and Theme.successDark
    or m.diff == "med" and Theme.candy.yellowDark
    or Theme.accentDark

  Theme.roundRect(x, y, w, h, {
    r = Theme.radius.round,
    top = Theme.surface,
    bot = {0.98, 0.96, 0.97},
    border = Theme.borderLight,
    bw = 0.8,
  })

  Theme.set(Theme.text)
  love.graphics.setFont(Theme.font(11))
  love.graphics.print(m.label, x + 12, y + 8)

  Theme.set(Theme.textSecondary)
  love.graphics.setFont(Theme.font(9))
  local diffLabel = m.diff == "easy" and "facile" or m.diff == "med" and "medio" or "difficile"
  love.graphics.printf(diffLabel, x + 12, y + 24, w - 24, "right")

  local bw = w - 24
  Theme.rrSolid(x + 12, y + 38, bw, 8, 4, {0.94, 0.92, 0.94})
  if pct > 0.001 then
    local fillW = math.max(8, bw * pct)
    Theme.roundRect(x + 12, y + 38, fillW, 8, {
      r = 4, top = fillCol, bot = darkCol,
      gloss = {1, 1, 1, 0.2}, gh = 4,
    })
  end

  Theme.set(Theme.text)
  love.graphics.setFont(Theme.font(9))
  love.graphics.printf(m.progress .. "/" .. m.scaledTarget, x + 12, y + 38, bw, "right")
end

function M.draw(ach)
  local t = love.timer.getTime()

  Modal.drawBackdrop()
  Modal.drawCard(cardX, cardY, cardW, cardH)
  Modal.drawClose(cardX, cardY, cardW)

  do
    local txt = "Traguardi"
    local font = Theme.font(20)
    love.graphics.setFont(font)
    local tw = font:getWidth(txt)
    local iconSize = 22
    local gap = 8
    local totalW = iconSize + gap + tw
    local sx = cardX + (cardW - totalW) / 2
    Emoji.draw("target", sx + iconSize / 2, cardY + 26, iconSize, 1)
    love.graphics.setColor(Theme.text)
    love.graphics.printf(txt, sx + iconSize + gap, cardY + 16, tw, "left")
  end

  Theme.set(Theme.textTertiary)
  love.graphics.setFont(Theme.font(10))
  love.graphics.printf("Missioni attive e traguardi globali", cardX, cardY + 44, cardW, "center")

  Theme.roundRect(cardX + cardW * 0.3, cardY + 56, cardW * 0.4, 2, {
    r = 1, top = Theme.accent, bot = Theme.accentDark,
  })

  local y = cardY + 68
  love.graphics.setScissor(cardX, y, cardW, cardH - (y - cardY) - 12)
  y = y + scrollY

  local sectionHeaderH = 24
  local missionCardH = 56
  local missionGap = 6
  local achCardH = 72
  local achGap = 8

  local missions = ach and ach.missions or {}
  local totalMissionsH = #missions * (missionCardH + missionGap)
  local totalAchH = #config.ACHIEVEMENTS * (achCardH + achGap)
  local totalContentH = sectionHeaderH + totalMissionsH + 12 + sectionHeaderH + totalAchH

  if y >= cardY + 68 - sectionHeaderH and y <= cardY + cardH then
    Theme.set(Theme.text)
    love.graphics.setFont(Theme.font(13))
    love.graphics.print("Missioni", cardX + 16, y)
  end
  y = y + sectionHeaderH

  for _, m in ipairs(missions) do
    if y + missionCardH >= cardY + 68 and y <= cardY + cardH then
      drawMissionCard(cardX + 12, y, cardW - 24, missionCardH, m, t)
    end
    y = y + missionCardH + missionGap
  end

  y = y + 12

  if y >= cardY + 68 - sectionHeaderH and y <= cardY + cardH then
    Theme.set(Theme.text)
    love.graphics.setFont(Theme.font(13))
    love.graphics.print("Traguardi", cardX + 16, y)
  end
  y = y + sectionHeaderH

  for _, a in ipairs(config.ACHIEVEMENTS) do
    local st = ach and ach.achievements and ach.achievements[a.id]
    local prog = st and st.progress or 0
    local done = st and st.completedAt ~= nil
    local pct = math.min(1, prog / a.target)

    if y + achCardH >= cardY + 68 and y <= cardY + cardH then
      if done then
        Theme.roundRect(cardX + 12, y, cardW - 24, achCardH, {
          r = Theme.radius.round,
          top = {0.92, 0.98, 0.92},
          bot = {0.86, 0.94, 0.86},
          gloss = {1, 1, 1, 0.12},
          gh = achCardH * 0.3,
        })
        local glowAlpha = 0.08 + 0.04 * math.sin(t * 2)
        Theme.set({Theme.success[1], Theme.success[2], Theme.success[3], glowAlpha})
        love.graphics.rectangle("fill", cardX + 12, y, cardW - 24, achCardH, Theme.radius.round, Theme.radius.round)
      else
        Theme.roundRect(cardX + 12, y, cardW - 24, achCardH, {
          r = Theme.radius.round,
          top = Theme.surface,
          bot = {0.98, 0.96, 0.97},
          border = Theme.borderLight,
          bw = 0.8,
        })
      end

      love.graphics.setColor(Theme.text)
      love.graphics.setFont(Theme.font(12))
      love.graphics.print(a.label, cardX + 20, y + 10)

      love.graphics.setColor(Theme.textSecondary)
      love.graphics.setFont(Theme.font(9))
      love.graphics.print(a.desc, cardX + 20, y + 26)

      local bw = cardW - 24 - 16
      local fillCol = done and Theme.success or Theme.accent
      local darkCol = done and Theme.successDark or Theme.accentDark

      Theme.rrSolid(cardX + 20, y + 42, bw, 8, 4, {0.94, 0.92, 0.94})
      if pct > 0.001 then
        local fillW = math.max(8, bw * pct)
        Theme.roundRect(cardX + 20, y + 42, fillW, 8, {
          r = 4, top = fillCol, bot = darkCol,
          gloss = {1, 1, 1, 0.2}, gh = 4,
        })
      end

      love.graphics.setColor(Theme.text)
      love.graphics.setFont(Theme.font(9))
      local right = string.format("%d/%d", prog, a.target)
      if done then right = "✓ " .. right .. "  +150" end
      if a.permMult and a.permMult > 0 then right = right .. "  +" .. tostring(a.permMult) .. "x" end
      love.graphics.printf(right, cardX + 20, y + 42, bw, "right")
    end
    y = y + achCardH + achGap
  end
  love.graphics.setScissor()

  M._cardX, M._cardY, M._cardW, M._cardH = cardX, cardY, cardW, cardH

  contentH = totalContentH
  viewH = cardH - 80
  if totalContentH > viewH then
    Theme.set(Theme.textTertiary)
    love.graphics.setFont(Theme.font(9))
    love.graphics.printf("Trascina o usa la rotella per scorrere", cardX, cardY + cardH - 14, cardW, "center")
  end
end

function M.wheel(dy)
  scrollY = scrollY + dy * 20
  clamp()
end

function M.beginScroll(y)
  dragging = true
  dragLastY = y
end

function M.moveScroll(y)
  if not dragging then return end
  scrollY = scrollY + (y - dragLastY)
  dragLastY = y
  clamp()
end

function M.endScroll()
  dragging = false
end

function M.hitTest(x, y)
  if Modal.hitClose(x, y, cardX, cardY, cardW) then return "close" end
  if x < cardX or x > cardX + cardW or y < cardY or y > cardY + cardH then return "outside" end
  return nil
end

return M
