-- ═══════════════════════════════════════════
-- ANIMATIONS — Lightweight tween engine
-- ═══════════════════════════════════════════
local Theme = require("src.ui.theme")
local Anim = {}

-- Active tweens
local tweens = {}
-- Active particles
local particles = {}
-- Scene transition state
local transition = {active = false, alpha = 0, phase = "none", callback = nil, duration = 0}

-- ═══════════════════════════════════════════
-- EASING FUNCTIONS
-- ═══════════════════════════════════════════
local Ease = {
  linear = function(t) return t end,

  inQuad  = function(t) return t * t end,
  outQuad = function(t) return t * (2 - t) end,
  inOutQuad = function(t)
    if t < 0.5 then return 2 * t * t end
    return -1 + (4 - 2 * t) * t
  end,

  outBack = function(t)
    local s = 1.70158
    t = t - 1
    return t * t * ((s + 1) * t + s) + 1
  end,

  outElastic = function(t)
    if t == 0 or t == 1 then return t end
    return math.pow(2, -10 * t) * math.sin((t - 0.1) * 5 * math.pi) + 1
  end,

  outBounce = function(t)
    if t < 1 / 2.75 then
      return 7.5625 * t * t
    elseif t < 2 / 2.75 then
      t = t - 1.5 / 2.75
      return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then
      t = t - 2.25 / 2.75
      return 7.5625 * t * t + 0.9375
    else
      t = t - 2.625 / 2.75
      return 7.5625 * t * t + 0.984375
    end
  end,

  inOutBack = function(t)
    local s = 1.70158 * 1.525
    t = t * 2
    if t < 1 then
      return 0.5 * (t * t * ((s + 1) * t - s))
    end
    t = t - 2
    return 0.5 * (t * t * ((s + 1) * t + s) + 2)
  end,
}

Anim.Ease = Ease

-- ═══════════════════════════════════════════
-- TWEEN SYSTEM
-- ═══════════════════════════════════════════

--- Create a new tween
-- @param target table to animate
-- @param props {property = endValue} e.g. {x = 100, alpha = 0}
-- @param duration seconds
-- @param opts {ease, delay, onComplete, tag}
function Anim.tween(target, props, duration, opts)
  opts = opts or {}
  local t = {
    target = target,
    start = {},
    props = {},
    duration = duration,
    elapsed = -(opts.delay or 0),
    ease = Ease[opts.ease] or Ease.outQuad,
    onComplete = opts.onComplete,
    tag = opts.tag,
    done = false,
  }
  for k, v in pairs(props) do
    t.start[k] = target[k] or 0
    t.props[k] = v
  end
  table.insert(tweens, t)
  return t
end

--- Cancel tweens by tag
function Anim.cancel(tag)
  for i = #tweens, 1, -1 do
    if tweens[i].tag == tag then
      table.remove(tweens, i)
    end
  end
end

--- Cancel all tweens
function Anim.cancelAll()
  tweens = {}
end

--- Update all tweens
function Anim.update(dt)
  for i = #tweens, 1, -1 do
    local t = tweens[i]
    t.elapsed = t.elapsed + dt
    if t.elapsed >= 0 then
      local progress = math.min(1, t.elapsed / t.duration)
      local eased = t.ease(progress)
      for k, targetVal in pairs(t.props) do
        local startVal = t.start[k]
        t.target[k] = startVal + (targetVal - startVal) * eased
      end
      if progress >= 1 then
        t.done = true
        if t.onComplete then t.onComplete() end
        table.remove(tweens, i)
      end
    end
  end
end

--- Check if a tag has active tweens
function Anim.isActive(tag)
  for _, t in ipairs(tweens) do
    if not tag or t.tag == tag then return true end
  end
  return false
end

-- ═══════════════════════════════════════════
-- SCORE POP — floating "+N" text
-- ═══════════════════════════════════════════
local scorePops = {}

function Anim.addScorePop(x, y, text, col)
  table.insert(scorePops, {
    x = x, y = y,
    text = tostring(text),
    col = col or {1, 0.48, 0.62},
    elapsed = 0,
    duration = 1.2,
    vy = -60,
  })
end

function Anim.updateScorePops(dt)
  for i = #scorePops, 1, -1 do
    local p = scorePops[i]
    p.elapsed = p.elapsed + dt
    p.y = p.y + p.vy * dt
    p.vy = p.vy * 0.97 -- slow down
    if p.elapsed >= p.duration then
      table.remove(scorePops, i)
    end
  end
end

function Anim.drawScorePops(font)
  for _, p in ipairs(scorePops) do
    local alpha = 1 - (p.elapsed / p.duration)
    local scale = 1 + 0.3 * math.sin(p.elapsed * 8) * alpha
    love.graphics.push()
    love.graphics.translate(p.x, p.y)
    love.graphics.scale(scale, scale)
    love.graphics.setFont(font)
    -- outline
    love.graphics.setColor(1, 1, 1, alpha * 0.8)
    love.graphics.printf(p.text, -1, -1, 200, "center")
    love.graphics.printf(p.text, 1, -1, 200, "center")
    love.graphics.printf(p.text, -1, 1, 200, "center")
    love.graphics.printf(p.text, 1, 1, 200, "center")
    -- text
    love.graphics.setColor(p.col[1], p.col[2], p.col[3], alpha)
    love.graphics.printf(p.text, 0, 0, 200, "center")
    love.graphics.pop()
  end
end

-- ═══════════════════════════════════════════
-- TOAST — transient notifications
-- ═══════════════════════════════════════════
local toasts = {}

function Anim.showToast(text, icon, col, duration)
  table.insert(toasts, {
    text = text or "",
    icon = icon,
    col = col or {0.42, 0.82, 0.30},
    elapsed = 0,
    duration = duration or 2.5,
    y = 0, -- computed during draw
  })
end

function Anim.updateToasts(dt)
  for i = #toasts, 1, -1 do
    toasts[i].elapsed = toasts[i].elapsed + dt
    if toasts[i].elapsed >= toasts[i].duration then
      table.remove(toasts, i)
    end
  end
end

function Anim.drawToasts(emoji, winW, winH)
  local toastH = 36
  local gap = 8
  local totalH = #toasts * (toastH + gap)
  local startY = winH - totalH - 20

  for i, t in ipairs(toasts) do
    local progress = t.elapsed / t.duration
    local alpha
    if progress < 0.15 then
      alpha = progress / 0.15 -- fade in
    elseif progress > 0.8 then
      alpha = (1 - progress) / 0.2 -- fade out
    else
      alpha = 1
    end

    local tw = math.min(320, winW - 40)
    local tx = (winW - tw) / 2
    local ty = startY + (i - 1) * (toastH + gap)
    local slideY = ty + (1 - alpha) * 20

    -- pill background
    love.graphics.setColor(t.col[1], t.col[2], t.col[3], alpha * 0.92)
    love.graphics.rectangle("fill", tx, slideY, tw, toastH, toastH / 2, toastH / 2)
    -- border
    love.graphics.setColor(1, 1, 1, alpha * 0.2)
    love.graphics.rectangle("line", tx, slideY, tw, toastH, toastH / 2, toastH / 2)

    -- icon
    local textX = tx + 16
    if t.icon and emoji then
      emoji.draw(t.icon, tx + 24, slideY + toastH / 2, 18, alpha)
      textX = tx + 38
    end

    -- text
    love.graphics.setColor(1, 1, 1, alpha)
    love.graphics.setFont(Theme.font(12))
    love.graphics.printf(t.text, textX, slideY + 10, tw - (textX - tx) - 12, "left")
  end
end

-- ═══════════════════════════════════════════
-- SCENE TRANSITIONS
-- ═══════════════════════════════════════════

function Anim.startTransition(callback, duration)
  transition.active = true
  transition.alpha = 0
  transition.phase = "fadeOut"
  transition.callback = callback
  transition.duration = duration or 0.35
  transition.elapsed = 0
end

function Anim.updateTransition(dt)
  if not transition.active then return end
  transition.elapsed = transition.elapsed + dt
  local progress = math.min(1, transition.elapsed / (transition.duration / 2))

  if transition.phase == "fadeOut" then
    transition.alpha = progress
    if progress >= 1 then
      transition.phase = "fadeIn"
      transition.elapsed = 0
      if transition.callback then transition.callback() end
    end
  elseif transition.phase == "fadeIn" then
    transition.alpha = 1 - progress
    if progress >= 1 then
      transition.active = false
      transition.phase = "none"
      transition.alpha = 0
    end
  end
end

function Anim.drawTransition()
  if not transition.active or transition.alpha <= 0 then return end
  love.graphics.setColor(0.15, 0.12, 0.16, transition.alpha * 0.7)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
end

function Anim.isTransitioning()
  return transition.active
end

-- ═══════════════════════════════════════════
-- MASTER UPDATE / DRAW
-- ═══════════════════════════════════════════

function Anim.updateAll(dt)
  Anim.updateScorePops(dt)
  Anim.updateToasts(dt)
  Anim.updateTransition(dt)
end

return Anim
