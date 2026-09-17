local config=require("src.config")
local M={}
M.__index=M

function M.new()
  local self=setmetatable({},M)
  self.missions={}
  self.achievements={}
  self.counters={totalMerges=0,totalValue16=0,totalExplosions=0,totalSpecials=0,totalWalls=0,maxComboEver=0}
  for _,a in ipairs(config.ACHIEVEMENTS) do
    self.achievements[a.id]={progress=0, completedAt=nil}
  end
  self:rollMissions(0)
  return self
end

function M:scaledTarget(mission, score)
  local countKinds={merge_color=true,merge_total=true,wall_break=true,diagonal=true,jolly_use=true,clone_use=true,grow_use=true,special_use=true}
  if not countKinds[mission.kind] then return mission.target end
  local add=0
  if score>=600 then add=2 elseif score>=300 then add=1 end
  return mission.target+add
end

function M:rollMissions(score)
  self.missions={}
  for _,pick in ipairs(config.MISSION_POOL) do
    local st=self:scaledTarget(pick, score or 0)
    table.insert(self.missions,{id=pick.id,label=pick.label,kind=pick.kind,target=pick.target,scaledTarget=st,progress=0,color=pick.color,value=pick.value,diff=pick.diff})
  end
end

function M:rerollMission(m, score)
  local diff=m.diff
  local pool={}
  for _,pm in ipairs(config.MISSION_POOL) do if pm.diff==diff then table.insert(pool,pm) end end
  local pick=pool[love.math.random(#pool)]
  local st=self:scaledTarget(pick, score)
  return {id=pick.id,label=pick.label,kind=pick.kind,target=pick.target,scaledTarget=st,progress=0,color=pick.color,value=pick.value,diff=diff}
end

function M:track(event, score, engine)
  local gainedScore=0
  local completedMissions={}
  local completedAchievements={}

  if event.type=="merge" then
    self.counters.totalMerges=self.counters.totalMerges+1
    if event.value and event.value>=16 then self.counters.totalValue16=self.counters.totalValue16+1 end
    if event.exploded then self.counters.totalExplosions=self.counters.totalExplosions+1 end
    if event.combo and event.combo>self.counters.maxComboEver then self.counters.maxComboEver=event.combo end
  elseif event.type=="wall_break" then
    self.counters.totalWalls=self.counters.totalWalls+1
  elseif event.type=="special" then
    self.counters.totalSpecials=self.counters.totalSpecials+1
  end

  for _,m in ipairs(self.missions) do
    local inc=0
    if m.kind=="merge_color" and event.type=="merge" and event.color==m.color then inc=1
    elseif m.kind=="merge_total" and event.type=="merge" then inc=1
    elseif m.kind=="wall_break" and event.type=="wall_break" then inc=1
    elseif m.kind=="value_reach" and event.type=="merge" and event.value and event.value>=m.value then inc=1
    elseif m.kind=="special_use" and event.type=="special" and (event.specialKind=="levelup" or event.specialKind=="grow") then inc=1
    elseif m.kind=="combo" and event.type=="merge" and event.combo and event.combo>=m.target then inc=m.target
    elseif m.kind=="clone_use" and event.type=="special" and event.specialKind=="clone" then inc=1
    elseif m.kind=="explosion" and event.type=="merge" and event.exploded then inc=1
    elseif m.kind=="diagonal" and event.type=="merge" and event.isDiagonal then inc=1
    elseif m.kind=="jolly_use" and event.type=="special" and event.specialKind=="jolly" then inc=1
    elseif m.kind=="grow_use" and event.type=="special" and (event.specialKind=="levelup" or event.specialKind=="grow") then inc=1
    end
    if inc>0 then
      if m.kind=="combo" then m.progress=math.max(m.progress, event.combo)
      else m.progress=math.min(m.progress+inc, m.scaledTarget) end
    end
  end

  for i,m in ipairs(self.missions) do
    if m.progress>=m.scaledTarget then
      gainedScore=gainedScore+config.GAME_CONFIG.missionRewardScore
      table.insert(completedMissions, {id=m.id, label=m.label, diff=m.diff})
      self.missions[i]=self:rerollMission(m, score)
    end
  end

  if engine and gainedScore>0 then engine.score=engine.score+gainedScore; engine:activateBuff() end

  local achScore=0
  for _,a in ipairs(config.ACHIEVEMENTS) do
    local st=self.achievements[a.id]
    if not st.completedAt then
      local cur=0
      if a.kind=="merge_total" then cur=self.counters.totalMerges
      elseif a.kind=="value_16" then cur=self.counters.totalValue16
      elseif a.kind=="explosion" then cur=self.counters.totalExplosions
      elseif a.kind=="combo" then cur=self.counters.maxComboEver>=4 and 1 or 0
      elseif a.kind=="special" then cur=self.counters.totalSpecials
      elseif a.kind=="wall_break" then cur=self.counters.totalWalls
      end
      if a.id=="combo_4" then st.progress=cur
      else st.progress=math.min(cur, a.target) end
      if st.progress>=a.target then
        st.completedAt=love.timer.getTime()
        achScore=achScore+a.rewardScore
        table.insert(completedAchievements, {id=a.id, label=a.label})
      end
    end
  end
  if achScore>0 and engine then engine.score=engine.score+achScore end
  return {gainedScore=gainedScore, achScore=achScore, completedMissions=completedMissions, completedAchievements=completedAchievements}
end

function M:permMult()
  local sum=0
  for _,a in ipairs(config.ACHIEVEMENTS) do
    if a.permMult and a.permMult>0 then
      local st=self.achievements[a.id]
      if st and st.completedAt then sum=sum+a.permMult end
    end
  end
  if sum>0.1 then sum=0.1 end
  return sum
end

function M:toTable()
  return {missions=self.missions, achievements=self.achievements, counters=self.counters}
end
function M:fromTable(t)
  if t.missions then self.missions=t.missions end
  if t.achievements then self.achievements=t.achievements end
  if t.counters then self.counters=t.counters end
end

return M
