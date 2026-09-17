local config = require("src.config")

local M = {}

-- grid is 2D [y][x] 0-indexed logical, stored as grid[y+1][x+1] in lua
-- block: {x,y,color,value,jolly}
-- returns {kind, finalX, finalY, beforeX, beforeY, target, path}
-- kinds: "wall" (hit edge treated as wall), "special", "merge", "slide", "none"
function M.resolve(block, dirName, grid)
  local dir = config.DIRS[dirName]
  if not dir then return {kind="none", finalX=block.x, finalY=block.y, beforeX=block.x, beforeY=block.y, path={}} end
  local dx, dy = dir.dx, dir.dy
  local cx, cy = block.x, block.y
  local path = {}
  local lastEmptyX, lastEmptyY = cx, cy
  local moved = false

  while true do
    local nx, ny = cx + dx, cy + dy
    -- out of bounds -> slide to edge (last empty)
    if nx < 0 or nx >= config.GRID_W or ny < 0 or ny >= config.GRID_H then
      if not moved then
        return {kind="none", finalX=cx, finalY=cy, beforeX=cx, beforeY=cy, path=path}
      else
        return {kind="slide", finalX=lastEmptyX, finalY=lastEmptyY, beforeX=lastEmptyX, beforeY=lastEmptyY, path=path}
      end
    end
    local cell = grid[ny+1][nx+1]
    if cell == nil then
      -- empty, continue
      cx, cy = nx, ny
      lastEmptyX, lastEmptyY = cx, cy
      moved = true
      table.insert(path, {x=cx, y=cy})
    else
      if cell.kind == "special" or cell.isSpecial then
        -- land on special
        -- path includes special cell
        table.insert(path, {x=nx, y=ny})
        return {kind="special", finalX=nx, finalY=ny, beforeX=cx, beforeY=cy, target=cell, path=path}
      elseif cell.kind == "wall" or cell.isWall then
        return {kind="wall", finalX=nx, finalY=ny, beforeX=lastEmptyX, beforeY=lastEmptyY, target=cell, path=path}
      else
        -- block
        local canMerge = false
        if cell.value == block.value then
          if cell.color == block.color or block.jolly or cell.jolly then
            canMerge = true
          end
        end
        if canMerge then
          table.insert(path, {x=nx, y=ny})
          return {kind="merge", finalX=nx, finalY=ny, beforeX=cx, beforeY=cy, target=cell, path=path}
        else
          if not moved then
            return {kind="none", finalX=block.x, finalY=block.y, beforeX=block.x, beforeY=block.y, path=path}
          else
            return {kind="slide", finalX=lastEmptyX, finalY=lastEmptyY, beforeX=lastEmptyX, beforeY=lastEmptyY, path=path}
          end
        end
      end
    end
  end
end

return M
