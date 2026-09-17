local S = {}
local FILE = "tilemama.settings"

S.data = {
  volume = 1,
  particles = true,
  motion = true,
}

function S.load()
  if not love.filesystem.getInfo(FILE) then return end
  local content = love.filesystem.read(FILE)
  if not content then return end
  for k, v in content:gmatch("([%w_]+)=([%w%.%-]+)") do
    if k == "volume" then
      local n = tonumber(v)
      if n then S.data.volume = math.max(0, math.min(1, n)) end
    elseif k == "particles" then
      S.data.particles = (v == "true")
    elseif k == "motion" then
      S.data.motion = (v == "true")
    end
  end
end

function S.save()
  local out = string.format("volume=%s\nparticles=%s\nmotion=%s\n",
    tostring(S.data.volume), tostring(S.data.particles), tostring(S.data.motion))
  love.filesystem.write(FILE, out)
end

function S.apply()
  love.audio.setVolume(S.data.volume)
end

return S
