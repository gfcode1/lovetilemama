-- Shared sprite sets for the minigames.
-- Each game has 6 character sprites; every sprite is bound to one tile value.
-- The minigames pick a random sprite instead of drawing the board candy tiles,
-- so colour is not used inside them: matching is by sprite/value.
local S = {}

-- One value per sprite (sprite index 1..N).
-- The board game tops out at 32; higher tiers exist only for sprite sets that
-- declare more than 6 images (e.g. memo's 10 cards).
S.VALUES = { 1, 2, 4, 8, 16, 32, 64, 128, 256, 512 }

local defs = {
  whack = { dir = "assets/minigiochi/whack", prefix = "mole_", count = 6 },
  falling = { dir = "assets/minigiochi/falling", prefix = "leaf_", count = 6 },
  memo = { dir = "assets/minigiochi/memo", prefix = "card_", count = 10 },
}

local cache = {}

local function loadSet(game)
  local def = defs[game]
  if not def then return {} end
  local set = {}
  for i = 1, def.count do
    local path = def.dir .. "/" .. def.prefix .. i .. ".png"
    if love.filesystem.getInfo(path) then
      local ok, img = pcall(love.graphics.newImage, path)
      if ok and img then
        img:setFilter("linear", "linear")
        set[i] = { img = img, value = S.VALUES[i] or S.VALUES[#S.VALUES] }
      end
    end
  end
  return set
end

function S.load(game)
  if not cache[game] then cache[game] = loadSet(game) end
  return cache[game]
end

function S.loadAll()
  for game in pairs(defs) do S.load(game) end
end

-- Returns the {img, value} entry for a game/index, or nil.
function S.get(game, index)
  local set = S.load(game)
  return set[index]
end

function S.count(game)
  return #S.load(game)
end

function S.randomIndex(game)
  local n = S.count(game)
  if n == 0 then return nil end
  return love.math.random(n)
end

function S.value(game, index)
  local e = S.get(game, index)
  return e and e.value or 1
end

return S
