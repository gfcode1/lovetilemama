-- Minigame registry. Each minigame module implements:
--   new(layout) -> instance
--   :update(dt)
--   :draw()
--   :pointerpressed(x, y)
--   :pointermoved(x, y)          (optional)
--   :keypressed(key)
--   :isFinished() -> bool
--   :getScore() -> number
local M = {}

local modules = {
  falling = "src.minigames.falling",
  whack = "src.minigames.whack",
}

function M.list()
  local out = {}
  for name in pairs(modules) do table.insert(out, name) end
  return out
end

function M.start(name, layout)
  local path = modules[name]
  if not path then return nil end
  local ok, mod = pcall(require, path)
  if not ok or type(mod) ~= "table" or not mod.new then return nil end
  return mod.new(layout)
end

return M
