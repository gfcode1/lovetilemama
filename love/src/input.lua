local config = require("src.config")

local I = {}

function I.angleToDir8(dx, dy)
  local ang = math.atan2(dy, dx) -- -pi..pi, 0 = E
  local deg = math.deg(ang)
  -- 8 sectors centered on dirs: E 0, NE -45, N -90, NW -135, W 180, SW 135, S 90, SE 45
  if deg >= -22.5 and deg < 22.5 then return "E"
  elseif deg >= 22.5 and deg < 67.5 then return "SE"
  elseif deg >= 67.5 and deg < 112.5 then return "S"
  elseif deg >= 112.5 and deg < 157.5 then return "SW"
  elseif deg >= 157.5 or deg < -157.5 then return "W"
  elseif deg >= -157.5 and deg < -112.5 then return "NW"
  elseif deg >= -112.5 and deg < -67.5 then return "N"
  else return "NE" end
end

function I.dirFromArrowTap(blockX, blockY, tapX, tapY, layout)
  local cs = layout.cellSize
  local cx = layout.offsetX + blockX*cs + cs/2
  local cy = layout.offsetY + blockY*cs + cs/2
  local dx = tapX - cx
  local dy = tapY - cy
  local dist = math.sqrt(dx*dx+dy*dy)
  if dist < cs*0.35 or dist > cs*1.2 then return nil end
  return I.angleToDir8(dx, dy)
end

return I
