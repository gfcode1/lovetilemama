local E={}
local cache={}
local loaded=false

local files={
  star="star.png",
  pause="pause.png",
  sparkles="sparkles.png",
  undo="undo.png",
  boom="boom.png",
  wall="wall.png",
  rainbow="rainbow.png",
  heart="heart.png",
  play="play.png",
  trophy="trophy.png",
  target="target.png",
  question="question.png",
  refresh="refresh.png",
  home="home.png",
  hand="hand.png",
  candy="candy.png",
  snow="snow.png",
  fog="fog.png",
  microbe="microbe.png",
  shuffle="shuffle.png",
  money="money.png",
  scissors="scissors.png",
  package="package.png",
  arrow_up="arrow_up.png",
  arrow_down="arrow_down.png",
  arrow_left="arrow_left.png",
  arrow_right="arrow_right.png",
  arrow_ne="arrow_ne.png",
  arrow_nw="arrow_nw.png",
  arrow_se="arrow_se.png",
  arrow_sw="arrow_sw.png",
  levelup="star.png",
  leveldown="arrow_down.png",
  rain="package.png",
  invert="hand.png",
}

function E.load()
  if loaded then return end
  for name, fn in pairs(files) do
    local path="assets/emoji/"..fn
    if love.filesystem.getInfo(path) then
      local ok,img=pcall(love.graphics.newImage, path)
      if ok and img then
        img:setFilter("linear","linear")
        cache[name]=img
      end
    end
  end
  loaded=true
end

function E.get(name) return cache[name] end

-- Register an already-loaded image under an emoji name (e.g. sprites montate
-- dalla board riusate in toast/banner). Overrides the file-based entry.
function E.register(name, img)
  if not name or not img then return false end
  img:setFilter("linear", "linear")
  cache[name] = img
  return true
end

-- draw centered at (cx,cy) with size (pixel height), optional alpha
function E.draw(name, cx, cy, size, alpha)
  local img=cache[name]
  if not img then return false end
  size=size or 16
  local iw,ih=img:getDimensions()
  local scale=size / math.max(iw,ih)
  love.graphics.setColor(1,1,1, alpha or 1)
  love.graphics.draw(img, cx, cy, 0, scale, scale, iw/2, ih/2)
  return true
end

-- draw inside a rect with padding, returns width used
function E.drawInRect(name, x, y, h, alpha)
  local size = math.floor(h * 0.72)
  local cx = x + size/2 + 2
  local cy = y + h/2
  return E.draw(name, cx, cy, size, alpha)
end

function E.isLoaded() return loaded end

return E
