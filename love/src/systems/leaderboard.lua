local LB={}
LB.__index=LB
function LB.new()
  return setmetatable({entries={}}, LB)
end
function LB:push(score, maxTile)
  table.insert(self.entries, {score=score, maxTile=maxTile, at=os.time()})
  table.sort(self.entries, function(a,b) return a.score>b.score end)
  while #self.entries>10 do table.remove(self.entries) end
end
function LB:toTable() return self.entries end
function LB:fromTable(t) if type(t)=="table" then self.entries=t end end
return LB
