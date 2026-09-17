local Theme = require("src.ui.theme")
local B = {}

-- Scene backgrounds (cover-fit photos + a scrim to keep the UI legible).
local SCENES = {
  menu    = { path = "assets/sfondi/strada.jpg",  scrim = 0.12 },
  game    = { path = "assets/sfondi/cucina.jpg",  scrim = 0.15 },
  falling = { path = "assets/sfondi/foresta.jpg", scrim = 0.18 },
  campo   = { path = "assets/sfondi/campo.jpg",   scrim = 0.18 },
}

local images = {}   -- sceneId -> Image|false (false = missing, don't retry)

local function sceneImage(id)
  if images[id] == nil then
    local def = SCENES[id]
    local img = false
    if def and love.filesystem.getInfo(def.path) then
      local ok, loaded = pcall(love.graphics.newImage, def.path)
      if ok then img = loaded end
    end
    images[id] = img
  end
  return images[id]
end

-- Floating candy particles
local particles = {}
local particlesInit = false
local enabled = true

function B.setEnabled(v)
  enabled = v and true or false
  if not enabled then particlesInit = false end
end

local function initParticles(w, h)
  particles = {}
  for i = 1, 16 do
    particles[i] = {
      x = math.random() * w,
      y = math.random() * h,
      r = 3 + math.random() * 5,
      speed = 8 + math.random() * 16,
      drift = (math.random() - 0.5) * 12,
      alpha = 0.04 + math.random() * 0.06,
      colorIdx = math.random(4),
      rot = math.random() * math.pi * 2,
      rotSpeed = (math.random() - 0.5) * 2,
      shape = math.random(3),
    }
  end
  particlesInit = true
end

local candyColors = {
  {0.98, 0.48, 0.62},
  {0.42, 0.82, 0.30},
  {1, 0.82, 0.20},
  {0.40, 0.74, 1},
}

-- ═══════════════════════════════════════════
-- DRAW — scene photo (cover) or flat fallback
-- ═══════════════════════════════════════════
function B.draw(sceneId)
  local w, h = love.graphics.getDimensions()
  local img = sceneId and sceneImage(sceneId) or nil

  if img then
    local iw, ih = img:getDimensions()
    local s = math.max(w / iw, h / ih)          -- cover: fill, center-crop
    local dw, dh = iw * s, ih * s
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(img, (w - dw) / 2, (h - dh) / 2, 0, s, s)

    local scrim = SCENES[sceneId].scrim or 0
    if scrim > 0 then
      love.graphics.setColor(0, 0, 0, scrim)
      love.graphics.rectangle("fill", 0, 0, w, h)
    end
  else
    Theme.set(Theme.bgFlat)
    love.graphics.rectangle("fill", 0, 0, w, h)
  end
end

function B.drawParticles(dt)
  if not enabled then return end
  local w, h = love.graphics.getDimensions()
  if not particlesInit then initParticles(w, h) end

  for _, p in ipairs(particles) do
    p.y = p.y - p.speed * dt
    p.x = p.x + p.drift * dt
    p.rot = p.rot + p.rotSpeed * dt
    if p.y < -p.r * 2 then
      p.y = h + p.r * 2
      p.x = math.random() * w
    end
    if p.x < -p.r * 2 then p.x = w + p.r * 2 end
    if p.x > w + p.r * 2 then p.x = -p.r * 2 end

    local col = candyColors[p.colorIdx]
    love.graphics.push()
    love.graphics.translate(p.x, p.y)
    love.graphics.rotate(p.rot)
    love.graphics.setColor(col[1], col[2], col[3], p.alpha)
    if p.shape == 1 then
      love.graphics.circle("fill", 0, 0, p.r)
      love.graphics.setColor(1, 1, 1, p.alpha * 0.5)
      love.graphics.circle("fill", 0, 0, p.r * 0.4)
    elseif p.shape == 2 then
      local rr = p.r * 0.8
      love.graphics.rectangle("fill", -rr, -rr, rr * 2, rr * 2, rr * 0.4, rr * 0.4)
      love.graphics.setColor(1, 1, 1, p.alpha * 0.4)
      love.graphics.rectangle("fill", -rr * 0.4, -rr * 0.6, rr * 0.8, rr * 0.4, rr * 0.2, rr * 0.2)
    else
      love.graphics.polygon("fill", 0, -p.r, p.r * 0.6, 0, 0, p.r, -p.r * 0.6, 0)
      love.graphics.setColor(1, 1, 1, p.alpha * 0.4)
      love.graphics.polygon("fill", 0, -p.r * 0.5, p.r * 0.3, 0, 0, p.r * 0.3, -p.r * 0.3, 0)
    end
    love.graphics.pop()
  end
end

function B.invalidate()
  particlesInit = false
end

return B
