local config = require("src.config")
local MoveResolver = require("src.engine.move_resolver")
local Engine = {}
Engine.__index = Engine
local function newGrid()
  local g = {}
  for y=1,config.GRID_H do
    g[y] = {}
    for x=1,config.GRID_W do g[y][x]=nil end
  end
  return g
end
function Engine.new()
  local self=setmetatable({},Engine)
  self.grid=newGrid()
  self.blocks={}
  self.specials={}
  self.walls={}
  self.nextId=1
  self.score=0
  self.gameOver=false
  self.pendingMode=nil
  self.history=nil
  self.best=0
  self.maxTile=1
  self.activeMalus=nil
  self.buffEndsAt=nil
  self.permMult=0
  return self
end
function Engine:freeCells()
  local out={}
  for y=0,config.GRID_H-1 do for x=0,config.GRID_W-1 do if self.grid[y+1][x+1]==nil then table.insert(out,{x=x,y=y}) end end end
  return out
end
function Engine:placeBlock(b) self.grid[b.y+1][b.x+1]=b; self.blocks[b.id]=b; if b.value>self.maxTile then self.maxTile=b.value end end
function Engine:removeBlock(b) if self.grid[b.y+1][b.x+1]==b then self.grid[b.y+1][b.x+1]=nil end; self.blocks[b.id]=nil end
function Engine:placeSpecial(s) self.grid[s.y+1][s.x+1]=s; self.specials[s.id]=s end
function Engine:removeSpecial(s) if self.grid[s.y+1][s.x+1]==s then self.grid[s.y+1][s.x+1]=nil end; self.specials[s.id]=nil end
function Engine:placeWall(w) self.grid[w.y+1][w.x+1]=w; self.walls[w.id]=w end
function Engine:removeWall(w) if self.grid[w.y+1][w.x+1]==w then self.grid[w.y+1][w.x+1]=nil end; self.walls[w.id]=nil end
function Engine:spawnInitial()
  self.grid=newGrid(); self.blocks={}; self.specials={}; self.walls={}; self.score=0; self.gameOver=false; self.pendingMode=nil; self.history=nil; self.maxTile=1; self.activeMalus=nil
  for _,c in ipairs(config.COLORS) do for i=1,config.GAME_CONFIG.initialBlocksPerColor do
    local free=self:freeCells(); if #free==0 then break end
    local cell=free[love.math.random(#free)]
    local b={id=self.nextId,x=cell.x,y=cell.y,color=c,value=1,jolly=false}
    self.nextId=self.nextId+1; self:placeBlock(b)
  end end
end
function Engine:getBlockAt(x,y)
  local cell=self.grid[y+1][x+1]
  if cell and not cell.isSpecial and not cell.isWall then return cell end
  return nil
end
function Engine:getSpecialAt(x,y)
  local cell=self.grid[y+1][x+1]
  if cell and cell.isSpecial then return cell end
  return nil
end
function Engine:getWallAt(x,y)
  local cell=self.grid[y+1][x+1]
  if cell and cell.isWall then return cell end
  return nil
end
function Engine:pushHistory(comboSnap)
  local snap=self:toTable()
  snap.comboSnap=comboSnap and {combo=comboSnap.combo,lastAt=comboSnap.lastAt,chainDepth=comboSnap.chainDepth} or nil
  self.history=snap
end
function Engine:canUndo() return self.history~=nil and self.pendingMode==nil and not self.gameOver and not self:isFrozen() end
function Engine:undo()
  if not self:canUndo() then return nil end
  local s=self.history
  self:fromTable(s)
  local cs=s.comboSnap
  self.history=nil
  return cs
end
function Engine:toTable()
  local blocks={}; for _,b in pairs(self.blocks) do table.insert(blocks,{id=b.id,x=b.x,y=b.y,color=b.color,value=b.value,jolly=b.jolly}) end
  local specials={}; for _,sp in pairs(self.specials) do
    local sk=sp.specialKind or sp.kindOrig or sp.kind
    table.insert(specials,{id=sp.id,x=sp.x,y=sp.y,kind=sk,pointsLevel=sp.pointsLevel,expiresAt=sp.expiresAt,game=sp.game})
  end
  local walls={}; for _,w in pairs(self.walls) do table.insert(walls,{id=w.id,x=w.x,y=w.y,hp=w.hp,expiresAt=w.expiresAt}) end
  return {blocks=blocks,specials=specials,walls=walls,score=self.score,gameOver=self.gameOver,pendingMode=self.pendingMode,nextId=self.nextId,maxTile=self.maxTile,best=self.best,activeMalus=self.activeMalus,buffEndsAt=self.buffEndsAt,permMult=self.permMult}
end
function Engine:fromTable(t)
  self.grid=newGrid(); self.blocks={}; self.specials={}; self.walls={}
  self.score=t.score or 0; self.gameOver=t.gameOver or false; self.pendingMode=t.pendingMode; self.nextId=t.nextId or 1; self.maxTile=t.maxTile or 1; self.best=t.best or self.best
  self.activeMalus=t.activeMalus; self.buffEndsAt=t.buffEndsAt; self.permMult=t.permMult or 0
  if t.blocks then for _,b in ipairs(t.blocks) do
    if b.x >= 0 and b.x < config.GRID_W and b.y >= 0 and b.y < config.GRID_H then
      local nb={id=b.id,x=b.x,y=b.y,color=b.color,value=b.value,jolly=b.jolly or false}; self:placeBlock(nb)
    end
  end end
  if t.specials then for _,s in ipairs(t.specials) do
    if s.x >= 0 and s.x < config.GRID_W and s.y >= 0 and s.y < config.GRID_H then
      local ns={id=s.id,x=s.x,y=s.y,expiresAt=s.expiresAt,isSpecial=true,specialKind=s.kind,pointsLevel=s.pointsLevel,game=s.game,kind="special"}; self.grid[ns.y+1][ns.x+1]=ns; self.specials[ns.id]=ns
    end
  end end
  if t.walls then for _,w in ipairs(t.walls) do
    if w.x >= 0 and w.x < config.GRID_W and w.y >= 0 and w.y < config.GRID_H then
      local nw={id=w.id,x=w.x,y=w.y,hp=w.hp or 2,expiresAt=w.expiresAt,isWall=true,kind="wall"}; self.grid[nw.y+1][nw.x+1]=nw; self.walls[nw.id]=nw
    end
  end end
end
function Engine:spawnSpecial(kind)
  local free=self:freeCells(); if #free==0 then return nil end
  local cell=free[love.math.random(#free)]
  return self:spawnSpecialAt(cell.x,cell.y,kind)
end
function Engine:spawnSpecialAt(x,y,kind)
  if kind=="wall" then return self:spawnWallAt(x,y) end
  local now=love.timer.getTime()
  local durMs=(kind=="minigame") and (config.GAME_CONFIG.minigameSpecialDurationMs or config.GAME_CONFIG.specialDurationMs) or config.GAME_CONFIG.specialDurationMs
  local s={id=self.nextId,x=x,y=y,isSpecial=true,kind="special",specialKind=kind,kindOrig=kind,expiresAt=now+durMs/1000}
  if kind=="points" then s.pointsLevel=love.math.random(#config.POINTS_VALUES) end
  if kind=="minigame" then s.game=self:pickRandomMinigameKind() end
  s.specialKindOrig=kind; self.nextId=self.nextId+1; self.grid[y+1][x+1]=s; self.specials[s.id]=s; return s
end
function Engine:spawnWallAt(x,y)
  local now=love.timer.getTime()
  local w={id=self.nextId,x=x,y=y,isWall=true,kind="wall",hp=config.GAME_CONFIG.wallHp,expiresAt=now+config.GAME_CONFIG.wallDurationMs/1000}
  self.nextId=self.nextId+1; self.grid[y+1][x+1]=w; self.walls[w.id]=w; return w
end
function Engine:pickRandomSpecialKind()
  local r=love.math.random()
  local cum=0
  for _,k in ipairs(config.SPECIAL_KINDS) do
    cum=cum+(config.SPECIAL_WEIGHTS[k] or 0)
    if r<=cum then return k end
  end
  return "laser"
end
function Engine:pickRandomMinigameKind()
  local r=love.math.random()
  local cum=0
  local kinds=config.MINIGAME_KINDS or {"falling"}
  for _,k in ipairs(kinds) do
    cum=cum+((config.MINIGAME_WEIGHTS and config.MINIGAME_WEIGHTS[k]) or 0)
    if r<=cum then return k end
  end
  return kinds[1] or "falling"
end
function Engine:pickRandomMalusKind()
  local r=love.math.random()
  local cum=0
  local order={"leveldown","freeze","scramble","invert","rain","tax"}
  for _,k in ipairs(order) do
    cum=cum+(config.MALUS_WEIGHTS[k] or 0)
    if r<=cum then return k end
  end
  return "tax"
end
local function malusActive(m, kind)
  return m and m.kind==kind and (not m.endsAt or love.timer.getTime()<m.endsAt)
end
function Engine:isFrozen() return malusActive(self.activeMalus,"freeze") end
function Engine:isInverted() return malusActive(self.activeMalus,"invert") end
function Engine:hasTax() return malusActive(self.activeMalus,"tax") end
function Engine:canApplyMalus() return not self.gameOver and not self.pendingMode and not self:isFrozen() end
function Engine:applyMalus(kind)
  if not self:canApplyMalus() then return {kind="blocked"} end
  if os.getenv and os.getenv("TILEMAMA_DEBUG") then print("[DEBUG] applyMalus:", kind) end
  local now=love.timer.getTime()
  local dur = (config.MALUS_DURATION_MS[kind] or 0)/1000
  if dur>0 then self.activeMalus={kind=kind, endsAt=now+dur}
  else self.activeMalus={kind=kind, endsAt=now+1.2} end
  if kind=="scramble" then self:doShuffle()
  elseif kind=="leveldown" then
    if os.getenv and os.getenv("TILEMAMA_DEBUG") then
      local n=0 for _ in pairs(self.blocks) do n=n+1 end
      print("[DEBUG] leveldown - tile:", n)
    end
    for _,b in pairs(self.blocks) do b.value=math.max(1, math.floor(b.value/2)) end
    if self.maxTile>1 then self.maxTile=math.max(1, math.floor(self.maxTile/2)) end
  elseif kind=="rain" then
    local n=love.math.random(config.GAME_CONFIG.rainMin, config.GAME_CONFIG.rainMax)
    for i=1,n do
      local free=self:freeCells(); if #free==0 then self.gameOver=true; break end
      local cell=free[love.math.random(#free)]
      local col=config.COLORS[love.math.random(#config.COLORS)]
      local nb={id=self.nextId,x=cell.x,y=cell.y,color=col,value=1,jolly=false}
      self.nextId=self.nextId+1; self:placeBlock(nb)
    end
    self:checkGameOver()
  end
  return {kind=kind}
end
function Engine:tickMalus()
  if not self.activeMalus then return end
  if love.timer.getTime() >= self.activeMalus.endsAt then self.activeMalus=nil end
  self:cleanupExpired()
end
function Engine:cleanupExpired()
  local now=love.timer.getTime()
  local toR={}
  for _,s in pairs(self.specials) do if s.expiresAt and now>s.expiresAt then table.insert(toR,s) end end
  for _,s in ipairs(toR) do self:removeSpecial(s) end
  local toW={}
  for _,w in pairs(self.walls) do if w.expiresAt and now>w.expiresAt then table.insert(toW,w) end end
  for _,w in ipairs(toW) do self:removeWall(w) end
  if self.buffEndsAt and now>self.buffEndsAt then self.buffEndsAt=nil end
end
function Engine:checkGameOver() if #self:freeCells()==0 then self.gameOver=true; if self.score>self.best then self.best=self.score end end end
function Engine:doShuffle()
  local blocks={}
  for _,b in pairs(self.blocks) do table.insert(blocks,b) end
  local positions={}
  for _,b in ipairs(blocks) do table.insert(positions,{x=b.x,y=b.y}) end
  for i=#positions,2,-1 do local j=love.math.random(i); positions[i],positions[j]=positions[j],positions[i] end
  for _,b in ipairs(blocks) do self.grid[b.y+1][b.x+1]=nil end
  for i,b in ipairs(blocks) do b.x=positions[i].x; b.y=positions[i].y; self.grid[b.y+1][b.x+1]=b end
end
function Engine:doLevelUpAll()
  local levelups=0; local explosions=0; local gain=0
  local ids={}
  for id in pairs(self.blocks) do table.insert(ids,id) end
  if os.getenv and os.getenv("TILEMAMA_DEBUG") then
    local vals={}
    for _,id in ipairs(ids) do vals[#vals+1]=self.blocks[id].value end
    print("[DEBUG] levelup - tile:", #ids, "valori:", table.concat(vals,","))
  end
  for _,id in ipairs(ids) do
    local b=self.blocks[id]
    if b then
      local newVal=b.value*2
      local g=newVal; if self:hasTax() then g=math.floor(g*0.5) end
      gain=gain+g
      if newVal>=config.GAME_CONFIG.explosionValue then
        explosions=explosions+1
        if newVal>self.maxTile then self.maxTile=newVal end
        self.grid[b.y+1][b.x+1]=nil
        self.blocks[id]=nil
        local free=self:freeCells()
        if #free==0 then self.gameOver=true
        else
          local cell=free[love.math.random(#free)]
          local col=config.COLORS[love.math.random(#config.COLORS)]
          local nb={id=self.nextId,x=cell.x,y=cell.y,color=col,value=1,jolly=false}
          self.nextId=self.nextId+1; self:placeBlock(nb)
        end
      else
        b.value=newVal
        if newVal>self.maxTile then self.maxTile=newVal end
        levelups=levelups+1
      end
    end
  end
  self.score=self.score+gain; if self.score>self.best then self.best=self.score end
  self:checkGameOver()
  return {levelups=levelups, explosions=explosions, gain=gain}
end
function Engine:addTiles(n)
  if self.gameOver or self.pendingMode or self:isFrozen() then return {kind="blocked"} end
  local free=self:freeCells()
  if #free < n then return {kind="blocked"} end
  local spawned={}
  for i=1,n do
    local free=self:freeCells()
    local cell=free[love.math.random(#free)]
    local col=config.COLORS[love.math.random(#config.COLORS)]
    local nb={id=self.nextId,x=cell.x,y=cell.y,color=col,value=1,jolly=false}
    self.nextId=self.nextId+1; self:placeBlock(nb)
    table.insert(spawned, nb)
  end
  local gain=n*config.GAME_CONFIG.addTilesRewardPerTile
  self.score=self.score+gain
  if self.score>self.best then self.best=self.score end
  self:checkGameOver()
  return {kind="addTiles", blocks=spawned, gain=gain}
end
function Engine:move(blockId, dirName, peekMult)
  if self.gameOver or self.pendingMode or self:isFrozen() then return {kind="blocked"} end
  if self:isInverted() then
    local inv={N="S",S="N",E="W",W="E",NE="SW",NW="SE",SE="NW",SW="NE"}
    dirName=inv[dirName] or dirName
  end
  local block=self.blocks[blockId]
  if not block then return {kind="blocked"} end
  local res=MoveResolver.resolve(block, dirName, self.grid)
  if res.kind=="none" or res.kind=="blocked" then return {kind="none", res=res} end
  if res.kind=="wall" then
    local wall=res.target
    wall.hp=wall.hp-1
    if wall.hp<=0 then
      self:removeWall(wall)
      self.grid[block.y+1][block.x+1]=nil; block.x=res.finalX; block.y=res.finalY; self.grid[res.finalY+1][res.finalX+1]=block
      local rw=config.GAME_CONFIG.wallBreakReward or 0; if self:hasTax() then rw=math.floor(rw*0.5) end
      self.score=self.score+rw; if self.score>self.best then self.best=self.score end
      self:checkGameOver()
      return {kind="wallDestroyed", wall=wall, res=res, scoreGain=rw}
    else
      self.grid[block.y+1][block.x+1]=nil; block.x=res.beforeX; block.y=res.beforeY; self.grid[res.beforeY+1][res.beforeX+1]=block
      return {kind="wallHit", wall=wall, res=res}
    end
  elseif res.kind=="special" then
    local special=res.target
    local skind=special.specialKind or special.specialKindOrig or special.kindOrig or "laser"
    self:removeSpecial(special)
    if skind=="laser" then
      local fx,fy=res.finalX,res.finalY
      self.grid[block.y+1][block.x+1]=nil; block.x=fx; block.y=fy; self.grid[fy+1][fx+1]=block
      local cleared=0
      for x=0,config.GRID_W-1 do if x~=fx then local c=self.grid[fy+1][x+1]; if c and not c.isSpecial and not c.isWall then self:removeBlock(c); cleared=cleared+1 end end end
      for y=0,config.GRID_H-1 do if y~=fy then local c=self.grid[y+1][fx+1]; if c and not c.isSpecial and not c.isWall then self:removeBlock(c); cleared=cleared+1 end end end
      local gain=cleared*2; if self:hasTax() then gain=math.floor(gain*0.5) end
      self.score=self.score+gain; if self.score>self.best then self.best=self.score end
      self:checkGameOver()
      return {kind="laser", cleared=cleared, res=res, scoreGain=gain}
    elseif skind=="levelup" then
      self.grid[block.y+1][block.x+1]=nil; block.x=res.finalX; block.y=res.finalY; self.grid[res.finalY+1][res.finalX+1]=block
      local res2=self:doLevelUpAll()
      return {kind="levelup", res=res, levelups=res2.levelups, explosions=res2.explosions, gain=res2.gain}
    elseif skind=="points" then
      local lvl=special.pointsLevel or 1
      local gain=config.POINTS_VALUES[lvl] or config.POINTS_VALUES[1]
      if self:hasTax() then gain=math.floor(gain*0.5) end
      self.grid[block.y+1][block.x+1]=nil; block.x=res.finalX; block.y=res.finalY; self.grid[res.finalY+1][res.finalX+1]=block
      self.score=self.score+gain; if self.score>self.best then self.best=self.score end
      return {kind="points", gain=gain, level=lvl, res=res}
    elseif skind=="minigame" then
      self.grid[block.y+1][block.x+1]=nil; block.x=res.finalX; block.y=res.finalY; self.grid[res.finalY+1][res.finalX+1]=block
      return {kind="minigame", game=special.game or "falling", res=res}
    elseif skind=="grow" or skind=="jolly" or skind=="clone" then
      self.grid[block.y+1][block.x+1]=nil; block.x=res.finalX; block.y=res.finalY; self.grid[res.finalY+1][res.finalX+1]=block
      self.pendingMode={kind=skind, specialId=special.id, blockId=block.id}
      return {kind="pending", pending=skind, res=res}
    else
      return {kind="none", res=res}
    end
  elseif res.kind=="merge" then
    local target=res.target
    local sum=block.value+target.value
    local gain=math.floor(sum*(peekMult or 1)+0.5)
    if self:hasTax() then gain=math.floor(gain*0.5) end
    self.grid[block.y+1][block.x+1]=nil; self.grid[target.y+1][target.x+1]=nil; self.blocks[block.id]=nil; self.blocks[target.id]=nil
    local exploded=false
    if sum>=config.GAME_CONFIG.explosionValue then
      exploded=true; if sum>self.maxTile then self.maxTile=sum end
      for _,c in ipairs(config.COLORS) do local free=self:freeCells(); if #free>0 then local cell=free[love.math.random(#free)]; local nb={id=self.nextId,x=cell.x,y=cell.y,color=c,value=1,jolly=false}; self.nextId=self.nextId+1; self:placeBlock(nb) end end
    else
      local nb={id=self.nextId,x=res.finalX,y=res.finalY,color=target.color,value=sum,jolly=false}
      self.nextId=self.nextId+1; self:placeBlock(nb)
    end
    self.score=self.score+gain; if self.score>self.best then self.best=self.score end
    self:checkGameOver()
    return {kind="merge", sum=sum, gain=gain, exploded=exploded, res=res, dir=dirName}
  elseif res.kind=="slide" then
    self.grid[block.y+1][block.x+1]=nil; block.x=res.finalX; block.y=res.finalY; self.grid[res.finalY+1][res.finalX+1]=block; self:checkGameOver(); return {kind="slide", res=res}
  end
  return {kind="none", res=res}
end
function Engine:tapSpecial(specialId)
  if self.gameOver or self.pendingMode or self:isFrozen() then return {kind="blocked"} end
  local sp=self.specials[specialId]
  local w=self.walls[specialId]
  if w then
    w.hp=w.hp-1
    if w.hp<=0 then
      self:removeWall(w)
      local rw=config.GAME_CONFIG.wallBreakReward or 0; if self:hasTax() then rw=math.floor(rw*0.5) end
      self.score=self.score+rw; if self.score>self.best then self.best=self.score end
      return {kind="wallDestroyed", wall=w, scoreGain=rw}
    else return {kind="wallHit", wall=w} end
  end
  if not sp then return {kind="blocked"} end
  local skind=sp.specialKind or sp.specialKindOrig or sp.kindOrig or "laser"
  self:removeSpecial(sp)
  if skind=="laser" then
    local fx,fy=sp.x,sp.y
    local cleared=0
    for x=0,config.GRID_W-1 do local c=self.grid[fy+1][x+1]; if c and not c.isSpecial and not c.isWall then self:removeBlock(c); cleared=cleared+1 end end
    for y=0,config.GRID_H-1 do if y~=fy then local c=self.grid[y+1][fx+1]; if c and not c.isSpecial and not c.isWall then self:removeBlock(c); cleared=cleared+1 end end end
    local gain=cleared*2; if self:hasTax() then gain=math.floor(gain*0.5) end
    self.score=self.score+gain; if self.score>self.best then self.best=self.score end; self:checkGameOver(); return {kind="laser", cleared=cleared, scoreGain=gain}
  elseif skind=="levelup" then
    local res2=self:doLevelUpAll()
    return {kind="levelup", levelups=res2.levelups, explosions=res2.explosions, gain=res2.gain}
  elseif skind=="points" then
    local lvl=sp.pointsLevel or 1
    local gain=config.POINTS_VALUES[lvl] or config.POINTS_VALUES[1]
    if self:hasTax() then gain=math.floor(gain*0.5) end
    self.score=self.score+gain; if self.score>self.best then self.best=self.score end
    return {kind="points", gain=gain, level=lvl}
  elseif skind=="wall" then return {kind="none"} end
  if skind=="minigame" then
    return {kind="minigame", game=sp.game or "falling"}
  end
  if skind=="grow" or skind=="jolly" or skind=="clone" then
    self.pendingMode={kind=skind, specialId=sp.id}
    return {kind="pending", pending=skind}
  end
  return {kind="none"}
end
function Engine:applyPending(blockId)
  if not self.pendingMode then return {kind="blocked"} end
  local kind=self.pendingMode.kind
  local block=self.blocks[blockId]
  if not block then return {kind="blocked"} end
  self.pendingMode=nil
  if kind=="grow" then
    local newVal=block.value*2
    if newVal>=config.GAME_CONFIG.explosionValue then
      if newVal>self.maxTile then self.maxTile=newVal end
      self:removeBlock(block)
      for _,c in ipairs(config.COLORS) do local free=self:freeCells(); if #free>0 then local cell=free[love.math.random(#free)]; local nb={id=self.nextId,x=cell.x,y=cell.y,color=c,value=1,jolly=false}; self.nextId=self.nextId+1; self:placeBlock(nb) end end
      local gain=newVal; if self:hasTax() then gain=math.floor(gain*0.5) end
      self.score=self.score+gain; if self.score>self.best then self.best=self.score end; self:checkGameOver()
      return {kind="grow_explode", gain=gain}
    else
      block.value=newVal; if newVal>self.maxTile then self.maxTile=newVal end
      local gain=newVal; if self:hasTax() then gain=math.floor(gain*0.5) end
      self.score=self.score+gain; if self.score>self.best then self.best=self.score end
      return {kind="grow", gain=gain, block=block}
    end
  elseif kind=="jolly" then block.jolly=true; return {kind="jolly", block=block}
  elseif kind=="clone" then
    local free=self:freeCells(); if #free==0 then self.gameOver=true; return {kind="clone", cloned=false} end
    local cell=free[love.math.random(#free)]
    local nb={id=self.nextId,x=cell.x,y=cell.y,color=block.color,value=block.value,jolly=block.jolly}
    self.nextId=self.nextId+1; self:placeBlock(nb); self:checkGameOver(); return {kind="clone", cloned=true, block=nb}
  end
  return {kind="none"}
end
function Engine:cancelPending() if not self.pendingMode then return end; self.pendingMode=nil end
function Engine:activateBuff() self.buffEndsAt=love.timer.getTime()+config.GAME_CONFIG.missionBuffMs/1000 end
function Engine:isBuffActive() return self.buffEndsAt and love.timer.getTime()<self.buffEndsAt end
function Engine:award(amount)
  amount=math.floor((amount or 0)+0.5)
  if self:hasTax() then amount=math.floor(amount*0.5) end
  if amount<=0 then return 0 end
  self.score=self.score+amount
  if self.score>self.best then self.best=self.score end
  return amount
end
return Engine
