local R={}
R.__index=R

local Anim=require("src.ui.animations")

local stack={"menu"}

-- Apply a stack mutation, wrapped in a fade transition when idle.
-- If a transition is already running, mutate immediately to avoid nesting.
local function apply(fn)
  if Anim.isTransitioning and Anim.isTransitioning() then
    fn()
  else
    Anim.startTransition(fn, 0.28)
  end
end

function R.current() return stack[#stack] end
function R.base() return stack[1] end
function R.isGame() return R.current()=="game" end
function R.isMenu() return R.current()=="menu" end
function R.isOverlay()
  local c=R.current()
  return c=="pause" or c=="leaderboard" or c=="achievements" or c=="help" or c=="gameover"
end

function R.push(state)
  apply(function() table.insert(stack, state) end)
end

function R.pop()
  if #stack<=1 then return end
  apply(function() table.remove(stack) end)
end

function R.replace(state)
  apply(function() stack[#stack]=state end)
end

function R.goMenu()
  apply(function() stack={"menu"} end)
end

function R.goGame()
  apply(function() stack={"game"} end)
end

function R.reset()
  stack={"menu"}
end

-- helper: can scheduler run?
function R.canTick(engine)
  if R.current()~="game" then return false end
  if engine and (engine.gameOver or engine.pendingMode or engine:isFrozen()) then return false end
  return true
end

return R
