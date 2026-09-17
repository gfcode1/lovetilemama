-- ═══════════════════════════════════════════
-- FX — tile juice effects (purely visual)
-- ═══════════════════════════════════════════
local FX = {}

local blockFx = {}   -- [id] = {spawn, delay, pulse, pulseAmp, shake, wiggle, slide, dragX, dragY, flash, flashCol, spinDir}
local seenIds = {}
local particles = {}
local shockwaves = {}
local laserFlashes = {}
local shake = { mag = 0, rot = 0, t = 0, dur = 0 }

-- ═══════════════════════════════════════════
-- TUNING — durate e ampiezze regolabili
-- ═══════════════════════════════════════════
local CFG = {
  spawnDur     = 0.34,   -- durata pop di apparizione
  spawnStagger = 0.045,  -- ritardo per blocco (onda)
  spawnSpin    = 0.30,   -- rotazione iniziale (rad)
  spawnDrop    = 0.35,   -- discesa iniziale (frazione di cella)
  mergeDur     = 0.46,   -- durata deformazione merge
  flashDur     = 0.18,   -- durata flash bianco/rosso
  slideDur     = 0.22,   -- durata slittamento
  wiggleDur    = 0.36,   -- durata wiggle mossa invalida
  shakeDurMax  = 0.30,   -- oltre questa soglia un effetto va spento
  idleAmp      = 0.015,  -- ampiezza respiro idle
  selBreath    = 0.022,  -- respiro del pezzo selezionato
  trailCount   = 3,      -- scie dietro lo slittamento

  -- idle "vivo" scalato per valore (tile alto = più animato, sempre sottile)
  idleAmpBase  = 0.008,  -- ampiezza respiro tile base
  idleAmpPerTier = 0.012,-- incremento respiro per fascia valore
  idleBobBase  = 0.8,    -- bob verticale base (px)
  idleBobPerTier = 1.2,  -- incremento bob per fascia valore
  idleRotMax   = 0.012,  -- pendolo massimo (rad, ~0.7°)
  auraMax      = 0.30,   -- alone massimo dietro tile di valore alto
  auraSpeed    = 2.0,    -- velocità pulsazione alone
  sheenSpeed   = 0.30,   -- velocità riflesso diagonale
  activityDecay = 0.85,  -- quanto l'idle si riduce durante gli FX attivi
}
FX.CFG = CFG

-- Interruttore globale per l'idle "vivo" (rispetta reduced-motion)
FX.motion = true
function FX.setMotion(on) FX.motion = on and true or false end

-- Intensità idle 0.4..1: anche le tile base respirano, le alte di più
local function valueTier(value)
  if not value or value <= 1 then return 0.4 end
  local lv = math.log(value) / math.log(2) -- 1..5
  return math.min(1, 0.4 + 0.6 * math.max(0, (lv - 1) / 4))
end

-- Livello "prezioso" 0..1 per alone/riflesso (0 sotto il valore 4)
local function shineTier(value)
  if not value or value < 4 then return 0 end
  local lv = math.log(value) / math.log(2) -- 2..5
  return math.min(1, (lv - 2) / 3)
end

-- ═══════════════════════════════════════════
-- EASING
-- ═══════════════════════════════════════════
local function easeOutQuad(t) return t * (2 - t) end

local function easeOutBack(t)
  local s = 1.70158
  t = t - 1
  return t * t * ((s + 1) * t + s) + 1
end

-- back leggero: rimbalzo all'arrivo senza esagerare
local function easeOutBackLight(t)
  local s = 0.6
  t = t - 1
  return t * t * ((s + 1) * t + s) + 1
end

-- Deformazione merge: anticipazione (squash) → stretch → oscillazione smorzata
local function mergeDeform(p, amp)
  if p <= 0 then return 1, 1 end
  if p < 0.16 then
    local q = easeOutQuad(p / 0.16)
    return 1 + amp * 0.60 * q, 1 - amp * 0.90 * q
  end
  local q = (p - 0.16) / 0.84
  local damp = math.exp(-3.5 * q)
  local v = math.cos(q * math.pi * 3) * damp
  return 1 + amp * 0.60 * v, 1 - amp * 0.90 * v
end

-- ═══════════════════════════════════════════
-- HELPERS
-- ═══════════════════════════════════════════
local function hashId(id)
  return ((id * 2654435761) % 4294967296) / 4294967296
end

-- ═══════════════════════════════════════════
-- IDLE — respiro "vivo" condiviso (blocchi, speciali, muri)
-- ritorna sx, sy, ox, oy, rot con fasi sfasate per seed; intensity 0..1
-- ═══════════════════════════════════════════
function FX.idleOffset(seed, t, intensity)
  intensity = intensity or 0
  if not FX.motion or intensity <= 0 then return 1, 1, 0, 0, 0 end
  local ph = hashId(seed) * 6.283
  local ph2 = hashId(seed + 91) * 6.283
  local ph3 = hashId(seed + 177) * 6.283

  local amp = (CFG.idleAmpBase + CFG.idleAmpPerTier * intensity) * intensity
  local bob = (CFG.idleBobBase + CFG.idleBobPerTier * intensity) * intensity

  local wob = math.sin(t * 2.2 + ph) * amp
  local sx = 1 + wob
  local sy = 1 - wob * 0.5
  local oy = math.sin(t * 1.8 + ph2) * bob
  local rot = math.sin(t * 1.3 + ph3) * CFG.idleRotMax * intensity
  return sx, sy, 0, oy, rot
end

local function hexColor(hex)
  return {tonumber(hex:sub(1, 2), 16) / 255,
          tonumber(hex:sub(3, 4), 16) / 255,
          tonumber(hex:sub(5, 6), 16) / 255}
end

local colorMap = {
  green  = hexColor("6bd14d"), red    = hexColor("fa617f"),
  yellow = hexColor("ffd133"), blue   = hexColor("66bdff"),
}

-- scratch riutilizzato da FX.get (evita allocazioni per-frame)
local scratch = {
  sx = 1, sy = 1, ox = 0, oy = 0, rot = 0,
  flash = 0, flashCol = {1, 1, 1}, trail = {},
  lift = 0, dragging = false, spawnGlow = 0,
  aura = 0, sheen = -1,
}
local function blankFx()
  scratch.sx, scratch.sy, scratch.ox, scratch.oy, scratch.rot = 1, 1, 0, 0, 0
  scratch.flash, scratch.lift, scratch.dragging, scratch.spawnGlow = 0, 0, false, 0
  scratch.aura, scratch.sheen = 0, -1
  local fc = scratch.flashCol
  fc[1], fc[2], fc[3] = 1, 1, 1
  local tr = scratch.trail
  for i = #tr, 1, -1 do tr[i] = nil end
  return scratch
end

local function emitParticles(cx, cy, count, speed, lifeMin, lifeMax, cols, sizeMin, sizeMax, opts)
  opts = opts or {}
  local shape = opts.shape or "circle"
  local grav  = opts.gravity or 300
  local drag  = opts.drag or 0.98
  for i = 1, count do
    local ang = math.random() * math.pi * 2
    local spd = speed * (0.5 + math.random() * 0.5)
    local c = cols[math.random(#cols)]
    table.insert(particles, {
      x = cx, y = cy,
      vx = math.cos(ang) * spd, vy = math.sin(ang) * spd,
      g = grav, drag = drag,
      life = lifeMin + math.random() * (lifeMax - lifeMin),
      age = 0,
      col = c,
      size = sizeMin + math.random() * (sizeMax - sizeMin),
      shape = shape,
      rot = math.random() * math.pi * 2,
      spin = (math.random() - 0.5) * 7,
    })
  end
end

-- ═══════════════════════════════════════════
-- UPDATE
-- ═══════════════════════════════════════════
function FX.update(dt)
  -- block effects
  for _, f in pairs(blockFx) do
    if f.delay and f.delay > 0 then
      f.delay = f.delay - dt
    else
      if f.spawn  then f.spawn  = f.spawn + dt end
      if f.pulse  then f.pulse  = f.pulse + dt end
      if f.shake  then f.shake  = f.shake + dt end
      if f.wiggle then f.wiggle = f.wiggle + dt end
      if f.slide  then f.slide.age = f.slide.age + dt end
      if f.flash  then f.flash  = f.flash + dt end
    end
    -- spegni gli effetti completati (evita residui + stato stantio)
    if f.spawn  and f.spawn  >= CFG.spawnDur   then f.spawn = nil end
    if f.pulse  and f.pulse  >= CFG.mergeDur   then f.pulse = nil end
    if f.flash  and f.flash  >= CFG.flashDur   then f.flash = nil end
    if f.shake  and f.shake  >= CFG.shakeDurMax then f.shake = nil end
    if f.wiggle and f.wiggle >= CFG.wiggleDur  then f.wiggle = nil end
    if f.slide  and f.slide.age >= f.slide.dur then f.slide = nil end
  end

  -- particles
  for i = #particles, 1, -1 do
    local p = particles[i]
    p.age = p.age + dt
    if p.age >= p.life then
      table.remove(particles, i)
    else
      p.vy = p.vy + p.g * dt
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.vx = p.vx * p.drag
      p.rot = p.rot + p.spin * dt
    end
  end

  -- shockwaves
  for i = #shockwaves, 1, -1 do
    shockwaves[i].age = shockwaves[i].age + dt
    if shockwaves[i].age >= shockwaves[i].dur then
      table.remove(shockwaves, i)
    end
  end

  -- laser flashes
  for i = #laserFlashes, 1, -1 do
    laserFlashes[i].age = laserFlashes[i].age + dt
    if laserFlashes[i].age >= laserFlashes[i].dur then
      table.remove(laserFlashes, i)
    end
  end

  -- screen shake
  if shake.t > 0 then shake.t = shake.t - dt end
end

-- ═══════════════════════════════════════════
-- LIFECYCLE
-- ═══════════════════════════════════════════
function FX.reset()
  blockFx = {}
  seenIds = {}
  particles = {}
  shockwaves = {}
  laserFlashes = {}
  shake = {mag = 0, rot = 0, t = 0, dur = 0}
end

function FX.preseed(engine)
  for id in pairs(engine.blocks) do
    seenIds[id] = true
  end
end

function FX.observe(engine)
  -- raccogli SOLO gli id mai visti prima (i blocchi fusi hanno id nuovo ma non devono poppare)
  local fresh = nil
  for id in pairs(engine.blocks) do
    if not seenIds[id] then
      seenIds[id] = true
      fresh = fresh or {}
      fresh[#fresh + 1] = id
    end
  end
  if fresh then
    -- onda diagonale (x+y) per uno stagger armonioso
    table.sort(fresh, function(a, b)
      local ba, bb = engine.blocks[a], engine.blocks[b]
      if not ba or not bb then return a < b end
      return (ba.x + ba.y) * 100 + ba.x < (bb.x + bb.y) * 100 + bb.x
    end)
    local n = 0
    for _, id in ipairs(fresh) do
      local f = blockFx[id]
      if f and f.noSpawn then
        f.noSpawn = nil   -- risultato di merge/explosion: nessun pop, solo squash
      else
        if not f then f = {}; blockFx[id] = f end
        f.delay = n * CFG.spawnStagger
        f.spawn = 0
        f.spinDir = (hashId(id) < 0.5) and -1 or 1
        n = n + 1
      end
    end
  end
  -- pulizia: elimina stato di blocchi non più presenti
  for id in pairs(blockFx) do
    if not engine.blocks[id] then blockFx[id] = nil end
  end
end

-- ═══════════════════════════════════════════
-- BLOCK RENDER STATE
-- ═══════════════════════════════════════════
function FX.get(id, cs, t, value, color)
  local f = blockFx[id]
  if not f then return blankFx() end

  -- spawn in attesa: invisibile (scala 0 finché lo stagger non scade)
  if f.delay and f.delay > 0 then
    local s = blankFx()
    s.sx, s.sy = 0, 0
    return s
  end

  local s = blankFx()
  local sx, sy, ox, oy, rot = 1, 1, 0, 0, 0

  -- fattore attività: durante spawn/merge/slide/drag l'idle si spegne (no lotta con gli FX)
  local activity = 0
  if f.spawn or f.pulse or f.slide or f.flash then activity = 1 end
  if (f.dragX and f.dragX ~= 0) or (f.dragY and f.dragY ~= 0) then activity = 1 end
  if f.wiggle then activity = math.max(activity, 0.6) end
  local idleFactor = 1 - CFG.activityDecay * activity

  -- idle "vivo": tutte le tile respirano, intensità crescente per valore
  local tier = valueTier(value)
  if FX.motion and idleFactor > 0 then
    local ix, iy, _, ioy, irot = FX.idleOffset(id, t, tier)
    sx = sx * (1 + (ix - 1) * idleFactor)
    sy = sy * (1 + (iy - 1) * idleFactor)
    oy = oy + ioy * idleFactor
    rot = rot + irot * idleFactor
    -- alone pulsante (valore >= 4) e riflesso (valore >= 2)
    local shine = shineTier(value)
    if shine > 0 then
      s.aura = CFG.auraMax * shine * idleFactor
              * (0.72 + 0.28 * math.sin(t * CFG.auraSpeed + hashId(id) * 6.283))
    end
    if value and value >= 2 then s.sheen = hashId(id + 53) end
  end

  -- spawn pop (spin-in + leggera discesa + alone)
  if f.spawn then
    local p = math.min(1, f.spawn / CFG.spawnDur)
    local e = easeOutBack(p)
    sx = sx * e
    sy = sy * e
    local inv = 1 - p
    rot = rot + inv * inv * (f.spinDir or 1) * CFG.spawnSpin
    oy = oy - inv * cs * CFG.spawnDrop
    s.spawnGlow = inv
  end

  -- merge deform (squash & stretch)
  if f.pulse then
    local dSx, dSy = mergeDeform(math.min(1, f.pulse / CFG.mergeDur), f.pulseAmp or 0.24)
    sx = sx * dSx
    sy = sy * dSy
  end

  -- flash (bianco al merge, rosso alla mossa invalida)
  local flash, flashCol = 0, s.flashCol
  if f.flash then
    local fp = math.min(1, f.flash / CFG.flashDur)
    local fa = 1 - fp
    flash = fa * fa
    local fc = f.flashCol
    if fc then flashCol[1], flashCol[2], flashCol[3] = fc[1], fc[2], fc[3] end
  end

  -- wall hit shake
  if f.shake then
    local p = math.min(1, f.shake / CFG.shakeDurMax)
    local decay = 1 - p
    ox = ox + math.sin(p * math.pi * 6) * 3 * decay
  end

  -- invalid move wiggle: shake orizzontale + twist + tint rosso
  if f.wiggle then
    local p = math.min(1, f.wiggle / CFG.wiggleDur)
    local decay = 1 - p
    ox = ox + math.sin(p * math.pi * 8) * 6 * decay
    rot = rot + math.sin(p * math.pi * 10) * 0.10 * decay
    local wf = decay * 0.5
    if wf > flash then
      flash = wf
      flashCol[1], flashCol[2], flashCol[3] = 1, 0.28, 0.32
    end
  end

  -- slide + scia di movimento
  if f.slide then
    local sl = f.slide
    local p = math.min(1, sl.age / sl.dur)
    local e = easeOutBackLight(p)
    ox = ox + sl.fromOx * (1 - e)
    oy = oy + sl.fromOy * (1 - e)

    local trail = s.trail
    for k = 1, CFG.trailCount do
      local tp = p - k * 0.14
      if tp > 0 then
        local te = easeOutQuad(tp)
        local gx = sl.fromOx * (1 - te)
        local gy = sl.fromOy * (1 - te)
        if math.abs(gx) + math.abs(gy) > cs * 0.08 then
          trail[#trail + 1] = {ox = gx, oy = gy, alpha = (1 - k / (CFG.trailCount + 1)) * 0.22}
        end
      end
    end
  end

  -- drag tilt / lift
  local dX, dY = f.dragX or 0, f.dragY or 0
  if dX ~= 0 or dY ~= 0 then
    s.dragging = true
    rot = rot + dX * 0.09
    ox = ox + dX * 4
    oy = oy + dY * 4 - 3
    sx = sx * (1 + 0.05 * math.abs(dX))
    sy = sy * (1 + 0.05 * math.abs(dY))
    s.lift = 4
  end

  s.sx, s.sy, s.ox, s.oy, s.rot = sx, sy, ox, oy, rot
  s.flash = flash
  return s
end

-- ═══════════════════════════════════════════
-- SCREEN SHAKE
-- ═══════════════════════════════════════════
function FX.shake(mag, dur, rot)
  -- scossa precedente conclusa: azzera i valori accumulati (no carry-over)
  if shake.t <= 0 then shake.mag, shake.rot, shake.dur = 0, 0, 0 end
  shake.mag = math.max(shake.mag, mag)
  shake.rot = math.max(shake.rot, rot or 0)
  shake.dur = math.max(shake.dur, dur or 0.35)
  shake.t = shake.dur
end

function FX.shakeOffset()
  if shake.t <= 0 then return 0, 0, 0 end
  local p = shake.t / shake.dur
  local decay = p * p * (3 - 2 * p) -- smoothstep
  local dx = math.sin(shake.t * 60) * shake.mag * decay
  local dy = math.cos(shake.t * 45) * shake.mag * 0.6 * decay
  local dr = math.sin(shake.t * 38) * shake.rot * decay
  return dx, dy, dr
end

-- ═══════════════════════════════════════════
-- DRAW (scissored to grid area)
-- ═══════════════════════════════════════════
local function drawStar(x, y, r, rot, col, alpha)
  love.graphics.setColor(col[1], col[2], col[3], alpha)
  love.graphics.push()
  love.graphics.translate(x, y)
  love.graphics.rotate(rot)
  local t = r * 0.30
  love.graphics.rectangle("fill", -r, -t, r * 2, t * 2, t)
  love.graphics.rectangle("fill", -t, -r, t * 2, r * 2, t)
  love.graphics.pop()
end

function FX.drawClip(gx, gy, gw, gh, t)
  local prevSX, prevSY, prevSW, prevSH = love.graphics.getScissor()
  love.graphics.setScissor(gx, gy, gw, gh)

  -- particles
  for _, p in ipairs(particles) do
    local alpha = math.max(0, 1 - p.age / p.life)
    local sz = p.size * (1 + p.age * 0.3)
    if p.shape == "star" then
      drawStar(p.x, p.y, sz * 1.3, p.rot, p.col, alpha * 0.95)
    else
      love.graphics.setColor(p.col[1], p.col[2], p.col[3], alpha * 0.9)
      love.graphics.circle("fill", p.x, p.y, sz)
      love.graphics.setColor(1, 1, 1, alpha * 0.4)
      love.graphics.circle("fill", p.x, p.y, sz * 0.6)
    end
  end

  -- laser flashes (fade row and column bands)
  for _, lf in ipairs(laserFlashes) do
    local alpha = 0.55 * (1 - lf.age / lf.dur)
    local c = colorMap[lf.col]
    if c then
      love.graphics.setColor(c[1], c[2], c[3], alpha * 0.5)
    else
      love.graphics.setColor(1, 1, 1, alpha * 0.6)
    end
    love.graphics.rectangle("fill", lf.rx, lf.y - 1, lf.rw, 2)
    love.graphics.rectangle("fill", lf.x - 1, lf.ry, 2, lf.rh)
  end

  -- shockwaves (doppio anello)
  for _, sw in ipairs(shockwaves) do
    local p = sw.age / sw.dur
    local r = sw.minR + (sw.maxR - sw.minR) * easeOutQuad(p)
    local alpha = (1 - p) * 0.5
    love.graphics.setLineWidth(2)
    love.graphics.setColor(sw.col[1], sw.col[2], sw.col[3], alpha * 0.5)
    love.graphics.circle("line", sw.x, sw.y, r + 3)
    love.graphics.setColor(sw.col[1], sw.col[2], sw.col[3], alpha)
    love.graphics.circle("line", sw.x, sw.y, r)
    love.graphics.setLineWidth(1)
  end

  if prevSX then
    love.graphics.setScissor(prevSX, prevSY, prevSW, prevSH)
  else
    love.graphics.setScissor()
  end
end

-- ═══════════════════════════════════════════
-- EMITTERS
-- ═══════════════════════════════════════════
local function getFx(id)
  local f = blockFx[id]
  if not f then f = {}; blockFx[id] = f end
  return f
end

function FX.onMerge(cx, cy, col, combo, id)
  if id then
    local f = getFx(id)
    f.pulse = 0
    f.pulseAmp = math.min(0.34, 0.22 + (combo or 0) * 0.03)
    f.flash = 0
    f.flashCol = {1, 1, 1}
    f.noSpawn = true
  end
  local c = colorMap[col] or {1, 0.6, 0.7}
  local cnt = math.min(16, 8 + (combo or 0) * 2)
  emitParticles(cx, cy, cnt, 120, 0.45, 0.85, {c, {1, 1, 1}}, 3, 5.5)
  -- scintille a stella
  emitParticles(cx, cy, math.max(4, math.floor(cnt / 2)), 170, 0.40, 0.70,
    {c, {1, 1, 1}}, 3, 5, {shape = "star", gravity = 120, drag = 0.90})
  FX.shake(math.min(4, 1.5 + (combo or 0) * 0.5), 0.22,
    math.min(0.006, 0.002 + (combo or 0) * 0.0008))
end

function FX.onExplosion(cx, cy, col, id)
  if id then
    local f = getFx(id)
    f.pulse = 0
    f.pulseAmp = 0.5
    f.flash = 0
    f.flashCol = {1, 0.92, 0.6}
    f.noSpawn = true
  end
  local c = colorMap[col] or {1, 0.5, 0.5}
  emitParticles(cx, cy, 26, 220, 0.55, 1.0, {c, {1, 1, 1}, {1, 0.85, 0.2}}, 3, 7)
  emitParticles(cx, cy, 12, 260, 0.5, 0.9, {{1, 1, 1}, {1, 0.9, 0.4}}, 3, 6,
    {shape = "star", gravity = 60, drag = 0.88})
  table.insert(shockwaves, {
    x = cx, y = cy, age = 0, dur = 0.45,
    minR = 8, maxR = 60, col = c,
  })
  FX.shake(9, 0.45, 0.01)
end

function FX.onSlide(id, fromX, fromY, toX, toY, cs)
  local f = getFx(id)
  f.slide = {
    fromOx = (fromX - toX) * cs,
    fromOy = (fromY - toY) * cs,
    age = 0,
    dur = CFG.slideDur,
  }
end

function FX.onWiggle(id)
  local f = getFx(id)
  f.wiggle = 0
end

function FX.onBlockShake(id)
  local f = getFx(id)
  f.shake = 0
end

function FX.onWallHit(cx, cy)
  emitParticles(cx, cy, 6, 80, 0.3, 0.55, {{0.8, 0.65, 0.5}}, 2, 4)
  FX.shake(4, 0.25, 0.003)
end

function FX.onWallBreak(cx, cy)
  emitParticles(cx, cy, 12, 130, 0.45, 0.8, {{0.8, 0.65, 0.5}, {1, 1, 1}}, 3, 6)
  emitParticles(cx, cy, 6, 170, 0.4, 0.7, {{1, 1, 1}}, 3, 5,
    {shape = "star", gravity = 150, drag = 0.9})
  FX.shake(6, 0.35, 0.005)
end

function FX.onLaser(cx, cy, cs, gridW, gridH)
  local bx = cx - cs * gridW / 2
  local by = cy - cs * gridH / 2
  table.insert(laserFlashes, {
    x = cx, y = cy,
    rx = bx, ry = cy - 1,
    rw = cs * gridW, rh = 2,
    col = "yellow", age = 0, dur = 0.25,
  })
  FX.shake(6, 0.3, 0.006)
  emitParticles(cx, cy, 18, 160, 0.5, 0.9, {{1, 0.9, 0.3}, {1, 1, 1}}, 2, 5)
end

function FX.onVortex(cx, cy)
  emitParticles(cx, cy, 10, 100, 0.35, 0.6, {{0.85, 0.82, 1}, {0.7, 0.65, 1}}, 2, 4.5)
end

function FX.wiggleAll(engine)
  for id in pairs(engine.blocks) do
    FX.onWiggle(id)
  end
  FX.shake(2, 0.2, 0.002)
end

function FX.drag(id, dx, dy)
  for _, f in pairs(blockFx) do
    if f.dragX or f.dragY then
      f.dragX = 0
      f.dragY = 0
    end
  end
  if not id then return end
  local f = getFx(id)
  local len = math.sqrt(dx * dx + dy * dy)
  if len > 0.5 then
    f.dragX = dx / len
    f.dragY = dy / len
  end
end

return FX
