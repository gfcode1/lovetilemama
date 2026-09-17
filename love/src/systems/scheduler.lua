local config=require("src.config")
local okAnim, Anim=pcall(require,"src.ui.animations")
local S={}
S.__index=S
function S.new(engine)
  local now=love.timer.getTime()
  local self=setmetatable({engine=engine, nextBonus=now+3, nextMalus=now+config.GAME_CONFIG.malusGraceMs/1000, nextRain=now+config.GAME_CONFIG.rainGraceMs/1000, nextMinigame=now+(config.GAME_CONFIG.minigameGraceMs or 20000)/1000, paused=false},S)
  self.hasMinigame=(config.MINIGAME_KINDS and #config.MINIGAME_KINDS>0) or false
  return self
end
function S:reset()
  local now=love.timer.getTime()
  local d=(config.GAME_CONFIG.bonusMinDelayMs + love.math.random(config.GAME_CONFIG.bonusMaxDelayMs-config.GAME_CONFIG.bonusMinDelayMs))/1000
  self.nextBonus=now+d
  local dm=(config.GAME_CONFIG.malusMinDelayMs + love.math.random(config.GAME_CONFIG.malusMaxDelayMs-config.GAME_CONFIG.malusMinDelayMs))/1000
  self.nextMalus=now+dm
  local dr=(config.GAME_CONFIG.rainIntervalMs-2000 + love.math.random(4000))/1000
  self.nextRain=now+dr
  local dg=(config.GAME_CONFIG.minigameGraceMs or 20000)/1000
  self.nextMinigame=now+dg
end
function S:update()
  if self.paused then return end
  local eng=self.engine
  if eng.gameOver or eng.pendingMode then return end
  local now=love.timer.getTime()
  if now>=self.nextBonus then
    eng:spawnSpecial(eng:pickRandomSpecialKind())
    local d=(config.GAME_CONFIG.bonusMinDelayMs + love.math.random(config.GAME_CONFIG.bonusMaxDelayMs-config.GAME_CONFIG.bonusMinDelayMs))/1000
    self.nextBonus=now+d
  end
  if now>=self.nextMalus then
    if eng:canApplyMalus() then
      local kind=eng:pickRandomMalusKind()
      eng:applyMalus(kind)
      if okAnim and Anim and kind=="leveldown" then
        Anim.showToast("LEVEL DOWN! -1 livello","arrow_down",{1,0.42,0.54},1.6)
      end
      local dm=(config.GAME_CONFIG.malusMinDelayMs + love.math.random(config.GAME_CONFIG.malusMaxDelayMs-config.GAME_CONFIG.malusMinDelayMs))/1000
      self.nextMalus=now+dm
    end
  end
  if now>=self.nextRain then
    if eng:canApplyMalus() then
      eng:applyMalus("rain")
    end
    local dr=(config.GAME_CONFIG.rainIntervalMs-2000 + love.math.random(4000))/1000
    self.nextRain=now+dr
  end
  if self.hasMinigame and now>=self.nextMinigame then
    if eng:canApplyMalus() then
      local free=eng:freeCells()
      if #free>0 then
        local cell=free[love.math.random(#free)]
        eng:spawnSpecialAt(cell.x,cell.y,"minigame")
        if okAnim and Anim then Anim.showToast("MINIGIOCO!","target",{0.55,0.4,0.95},2.0) end
      end
    end
    local dg=(config.GAME_CONFIG.minigameMinDelayMs + love.math.random(config.GAME_CONFIG.minigameMaxDelayMs-config.GAME_CONFIG.minigameMinDelayMs))/1000
    self.nextMinigame=now+dg
  end
  eng:cleanupExpired()
  eng:tickMalus()
end
function S:setPaused(p) self.paused=p end
return S
