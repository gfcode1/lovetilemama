local Combo = {}
Combo.__index = Combo

function Combo.new()
  return setmetatable({combo=0, lastAt=nil, chainDepth=0}, Combo)
end

function Combo:peekMultiplier(now)
  local chain = 1 + math.min(self.combo * 0.5, 3)
  local timeBonus = 1
  if self.lastAt and (now - self.lastAt) < 2.5 then
    timeBonus = 1.5
  end
  return chain * timeBonus
end

function Combo:onMerge(now)
  self.chainDepth = self.combo
  self.combo = self.combo + 1
  self.lastAt = now
end

function Combo:onMiss()
  self.combo = 0
  self.chainDepth = 0
end

function Combo:snapshot()
  return {combo=self.combo, lastAt=self.lastAt, chainDepth=self.chainDepth}
end

function Combo:restore(s)
  self.combo = s.combo or 0
  self.lastAt = s.lastAt
  self.chainDepth = s.chainDepth or 0
end

return Combo
