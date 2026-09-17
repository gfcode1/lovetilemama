local config=require("src.config")
local Engine=require("src.engine.engine")
local Combo=require("src.engine.combo")
local Scheduler=require("src.systems.scheduler")
local Persistence=require("src.systems.persistence")
local Layout=require("src.ui.layout")
local GridUI=require("src.ui.grid")
local HUD=require("src.ui.hud")
local Input=require("src.input")
local MoveResolver=require("src.engine.move_resolver")
local Ach=require("src.systems.achievements")
local LB=require("src.systems.leaderboard")
local Theme=require("src.ui.theme")
local Emoji=require("src.ui.emoji")
local Background=require("src.ui.background")
local Minigames=require("src.minigames")
local MinigameSprites=require("src.minigames.sprites")

local Router=require("src.ui.router")
local MenuScene=require("src.ui.scenes.menu")
local PauseScene=require("src.ui.scenes.pause")
local GameOverScene=require("src.ui.scenes.gameover")
local LBScene=require("src.ui.scenes.leaderboard")
local AchScene=require("src.ui.scenes.achievements")
local HelpScene=require("src.ui.scenes.help")
local SettingsScene=require("src.ui.scenes.settings")
local Settings=require("src.systems.settings")
local Anim=require("src.ui.animations")
local FX=require("src.ui.fx")
local Confirm=require("src.ui.components.confirm")

local engine,combo,scheduler,ach,lb
local layout
local selectedId=nil
local drag=nil
local ghost=nil
local lastSave=0
local pendingFont=nil
local hasSave=false
local activeMinigame=nil

local function hexColor(hex)
  return {tonumber(hex:sub(1,2),16)/255, tonumber(hex:sub(3,4),16)/255, tonumber(hex:sub(5,6),16)/255}
end
local colorMap={green=hexColor("6bd14d"),red=hexColor("fa617f"),yellow=hexColor("ffd133"),blue=hexColor("66bdff")}

local function refreshLayout()
  local w,h=love.graphics.getDimensions()
  layout=Layout.compute(w,h)
  Background.invalidate()
  MenuScene.resize(w,h,hasSave)
  PauseScene.resize(w,h)
  GameOverScene.resize(w,h)
  LBScene.resize(w,h)
  AchScene.resize(w,h)
  HelpScene.resize(w,h)
  SettingsScene.resize(w,h)
  Confirm.resize(w,h)
  if activeMinigame and activeMinigame.setLayout then activeMinigame:setLayout(layout) end
end

local function persistDebounced(force)
  local now=love.timer.getTime()
  if force or (now-lastSave)>0.05 then
    local state=engine:toTable()
    state.best=engine.best
    state.comboSnap=combo:snapshot()
    state.achData=ach:toTable()
    state.lbData=lb:toTable()
    Persistence.save(state)
    lastSave=now
  end
end

local function getPeek()
  local base=combo:peekMultiplier(love.timer.getTime())
  if engine:isBuffActive() then return base*1.5
  else return base + ach:permMult() end
end

local function trackMission(event)
  local res=ach:track(event, engine.score, engine)
  for _,m in ipairs(res.completedMissions or {}) do
    Anim.showToast("Missione: "..m.label.." ✓ +80","target",Theme.success,2.5)
  end
  for _,a in ipairs(res.completedAchievements or {}) do
    Anim.showToast("Traguardo: "..a.label.." ✓ +150","trophy",Theme.accent,3)
  end
  return res
end

local function startMinigame(name)
  if activeMinigame then return end
  local inst=Minigames.start(name, layout)
  if not inst then return end
  activeMinigame=inst
  scheduler:setPaused(true)
  selectedId=nil; drag=nil; ghost=nil
  FX.drag(nil)
end

local function finishMinigame()
  if not activeMinigame then return end
  local raw=activeMinigame:getScore() or 0
  local gained=activeMinigame.caught or 0
  activeMinigame=nil
  scheduler:setPaused(false)
  local gain=engine:award(raw)
  if gain>0 then
    Anim.showToast("Minigioco: +"..gain.." ("..gained.." tile)","target",Theme.accent,2.5)
  else
    Anim.showToast("Minigioco: nessun punto","target",Theme.textTertiary,2.0)
  end
  persistDebounced(true)
end

local function newGame()
  engine:spawnInitial()
  combo=Combo.new()
  scheduler:reset()
  activeMinigame=nil
  scheduler:setPaused(false)
  selectedId=nil; drag=nil; ghost=nil
  FX.reset()
  hasSave=true
  local w,h=love.graphics.getDimensions()
  MenuScene.resize(w,h,hasSave)
  persistDebounced(true)
  Router.goGame()
end

local function goMenu()
  MenuScene.load(hasSave)
  Router.goMenu()
end

local function resetProgress()
  Persistence.clear()
  engine=Engine.new()
  combo=Combo.new()
  scheduler=Scheduler.new(engine)
  ach=Ach.new()
  lb=LB.new()
  engine:spawnInitial()
  hasSave=false
  activeMinigame=nil
  selectedId=nil; drag=nil; ghost=nil
  FX.reset()
  local w,h=love.graphics.getDimensions()
  MenuScene.resize(w,h,hasSave)
  goMenu()
end

local function tryMove(blockId, dir)
  if engine.gameOver or engine.pendingMode or engine:isFrozen() then return end
  local peek=getPeek()
  local blk=engine.blocks[blockId]
  local fromX,fromY = blk and blk.x or 0, blk and blk.y or 0
  local cs=layout.cellSize
  engine:pushHistory(combo:snapshot())
  local res=engine:move(blockId, dir, peek)
  if res.kind=="merge" then
    combo:onMerge(love.timer.getTime())
    local fx,fy=res.res.finalX,res.res.finalY
    local nb=engine.grid[fy+1][fx+1]
    local col = nb and nb.color or nil
    local px=layout.offsetX+fx*cs+cs/2
    local py=layout.offsetY+fy*cs+cs/2
    if res.exploded then
      -- esplosione: il blocco risultante può non esistere (il motore crea N tile nuove),
      -- quindi esplodi comunque sul punto di merge usando il colore del target
      local target = res.res and res.res.target
      local boomCol = (target and target.color) or col or "green"
      FX.onExplosion(px,py,boomCol)
      Anim.addScorePop(px,py-12,"+"..res.gain,colorMap[boomCol] or nil)
      trackMission({type="merge", color=col, value=res.sum, exploded=true, combo=combo.combo, isDiagonal=dir=="NE" or dir=="NW" or dir=="SE" or dir=="SW"})
    elseif col then
      FX.onMerge(px,py,col,combo.combo, nb and nb.id)
      Anim.addScorePop(px,py-12,"+"..res.gain,colorMap[col] or nil)
      trackMission({type="merge", color=col, value=res.sum, exploded=false, combo=combo.combo, isDiagonal=dir=="NE" or dir=="NW" or dir=="SE" or dir=="SW"})
    else
      trackMission({type="merge", color=nil, value=res.sum, exploded=res.exploded, combo=combo.combo, isDiagonal=dir=="NE" or dir=="NW" or dir=="SE" or dir=="SW"})
    end
    persistDebounced(true)
  elseif res.kind=="slide" then
    combo:onMiss()
    FX.onSlide(blockId,fromX,fromY,res.res.finalX,res.res.finalY,cs)
    persistDebounced(true)
  elseif res.kind=="laser" then
    combo:onMerge(love.timer.getTime())
    local cx=layout.offsetX+res.res.finalX*cs+cs/2
    local cy=layout.offsetY+res.res.finalY*cs+cs/2
    FX.onLaser(cx,cy,cs,config.GRID_W,config.GRID_H)
    if res.scoreGain then Anim.addScorePop(cx,cy-12,"+"..res.scoreGain) end
    trackMission({type="special", specialKind="laser"})
    persistDebounced(true)
  elseif res.kind=="levelup" then
    combo:onMerge(love.timer.getTime())
    local cx,cy=(blk and layout.offsetX+blk.x*cs+cs/2 or layout.offsetX+layout.gridPixelW/2), (blk and layout.offsetY+blk.y*cs+cs/2 or layout.offsetY+layout.gridPixelH/2)
    trackMission({type="special", specialKind="levelup"}); trackMission({type="grow_use"})
    if res.explosions and res.explosions>0 then FX.onExplosion(cx,cy,"green") end
    if res.gain and res.gain>0 then Anim.addScorePop(cx,cy-12,"+"..res.gain) end
    FX.wiggleAll(engine)
    Anim.showToast("LEVEL UP!"..(res.levelups and (" x"..res.levelups.." tile") or ""),"levelup",Theme.accent,1.6)
    if res.explosions and res.explosions>0 then Anim.showToast("+"..res.explosions.." esplosioni!","boom",Theme.danger,1.6) end
    persistDebounced(true)
  elseif res.kind=="points" then
    combo:onMerge(love.timer.getTime())
    local cx,cy=(blk and layout.offsetX+blk.x*cs+cs/2 or layout.offsetX+layout.gridPixelW/2), (blk and layout.offsetY+blk.y*cs+cs/2 or layout.offsetY+layout.gridPixelH/2)
    trackMission({type="special", specialKind="points"})
    if res.gain then Anim.addScorePop(cx,cy-12,"+"..res.gain) end
    persistDebounced(true)
  elseif res.kind=="wallDestroyed" then
    combo:onMerge(love.timer.getTime())
    local w=res.wall
    if w then FX.onWallBreak(layout.offsetX+w.x*cs+cs/2,layout.offsetY+w.y*cs+cs/2) end
    trackMission({type="wall_break"})
    if res.scoreGain then Anim.addScorePop((blk and layout.offsetX+blk.x*cs+cs/2 or layout.offsetX), (blk and layout.offsetY+blk.y*cs+cs/2 or layout.offsetY)-12, "+"..res.scoreGain) end
    persistDebounced(true)
  elseif res.kind=="wallHit" then
    combo:onMiss()
    if blk then FX.onBlockShake(blockId) end
    local w=res.wall
    if w then FX.onWallHit(layout.offsetX+w.x*cs+cs/2,layout.offsetY+w.y*cs+cs/2) end
    persistDebounced(true)
  elseif res.kind=="pending" then
    persistDebounced(true)
  elseif res.kind=="minigame" then
    combo:onMerge(love.timer.getTime())
    trackMission({type="special", specialKind="minigame"})
    Anim.showToast("MINIGIOCO!","minigame",Theme.accent,1.4)
    startMinigame(res.game)
    persistDebounced(true)
  elseif res.kind=="none" then
    engine.history=nil
    if blk then FX.onWiggle(blockId) end
  end
  -- combo toast
  if res.kind=="merge" and combo.combo>=3 and (combo.combo==3 or combo.combo%5==0) then
    Anim.showToast("COMBO x"..combo.combo,"sparkles",Theme.accent,1.4)
  end
  selectedId=nil; ghost=nil
end

local function handlePointerDown(x,y)
  if Anim.isTransitioning() then return true end
  if activeMinigame then activeMinigame:pointerpressed(x,y); return true end
  local cur=Router.current()
  -- Menu
  if cur=="menu" then
    local hit=MenuScene.hitTest(x,y)
    if hit=="continue" then Router.goGame(); return true
    elseif hit=="new" then
      if hasSave then
        Confirm.open({title="Nuova partita?", message="Il salvataggio attuale verrà sovrascritto.", confirmLabel="Sì, ricomincia", onConfirm=newGame})
      else newGame() end
      return true
    elseif hit=="leaderboard" then Router.push("leaderboard"); return true
    elseif hit=="achievements" then Router.push("achievements"); return true
    elseif hit=="help" then Router.push("help"); return true
    elseif hit=="settings" then Router.push("settings"); return true
    elseif hit=="quit" then love.event.quit(); return true
    end
    return true
  elseif cur=="pause" then
    local hit=PauseScene.hitTest(x,y)
    if hit=="close" or hit=="outside" or hit=="resume" then Router.pop(); return true
    elseif hit=="restart" then
      Confirm.open({title="Ricomincia?", message="La partita attuale verrà persa.", confirmLabel="Sì, ricomincia", onConfirm=newGame})
      return true
    elseif hit=="leaderboard" then Router.replace("leaderboard"); return true
    elseif hit=="achievements" then Router.replace("achievements"); return true
    elseif hit=="help" then Router.replace("help"); return true
    elseif hit=="settings" then Router.replace("settings"); return true
    elseif hit=="menu" then goMenu(); return true
    end
    return true
  elseif cur=="settings" then
    local hit=SettingsScene.hitTest(x,y)
    if hit=="close" or hit=="outside" then Router.pop(); return true
    elseif hit=="reset" then
      Confirm.open({title="Azzerare tutto?", message="Punteggi, traguardi e partita verranno cancellati.", confirmLabel="Azzera", onConfirm=resetProgress})
      return true
    elseif hit=="volDown" or hit=="volUp" or hit=="particles" or hit=="motion" then
      local res=SettingsScene.activate(hit)
      Settings.apply(); Settings.save()
      if res=="particles" then Background.setEnabled(Settings.data.particles) end
      if res=="motion" then FX.setMotion(Settings.data.motion) end
      return true
    end
    return true
  elseif cur=="leaderboard" then
    local hit=LBScene.hitTest(x,y)
    if hit=="close" or hit=="outside" then Router.pop(); return true end
    return true
  elseif cur=="achievements" then
    local hit=AchScene.hitTest(x,y)
    if hit=="close" or hit=="outside" then Router.pop(); return true end
    AchScene.beginScroll(y)
    return true
  elseif cur=="help" then
    local hit=HelpScene.hitTest(x,y)
    if hit=="close" or hit=="outside" then Router.pop(); return true
    elseif hit=="next" then HelpScene.nextPage(); return true
    elseif hit=="prev" then HelpScene.prevPage(); return true
    end
    return true
  elseif cur=="gameover" then
    local hit=GameOverScene.hitTest(x,y)
    if hit=="retry" then newGame(); return true
    elseif hit=="leaderboard" then Router.replace("leaderboard"); return true
    elseif hit=="menu" then goMenu(); return true
    end
    return true
  end

  -- Game state below
  -- HUD hit (Undo) + Pause button
  local hit=HUD.hitTest(x,y)
  if hit=="undo" then
    local snap=engine:undo()
    if snap then combo:restore(snap) end
    selectedId=nil; ghost=nil
    persistDebounced(true)
    return true
  end
  if hit=="pause" then Router.push("pause"); return true end
  if hit=="addTiles" then
    local cs=layout.cellSize
    engine:pushHistory(combo:snapshot())
    local res=engine:addTiles(config.GAME_CONFIG.addTilesCount)
    if res.kind=="addTiles" then
      combo:onMerge(love.timer.getTime())
      local lastB=res.blocks[#res.blocks]
      local px=layout.offsetX+lastB.x*cs+cs/2
      local py=layout.offsetY+lastB.y*cs+cs/2
      for _,b in ipairs(res.blocks) do
        local bx=layout.offsetX+b.x*cs+cs/2
        local by=layout.offsetY+b.y*cs+cs/2
        FX.onMerge(bx,by,b.color,1)
        FX.onWiggle(b.id)
      end
      Anim.addScorePop(px,py-12,"+"..res.gain,Theme.candy.green)
      persistDebounced(true)
    else engine.history=nil end
    return true
  end

  if engine.gameOver then
    -- fallback: tap anywhere in gameover triggers scene (already handled) else newGame
    return true
  end
  if engine.pendingMode then
    local cx,cy=Layout.cellAt(layout,x,y)
    if cx then
      local b=engine:getBlockAt(cx,cy)
      if b then
        local cs=layout.cellSize
        local px=layout.offsetX+b.x*cs+cs/2
        local py=layout.offsetY+b.y*cs+cs/2
        local res=engine:applyPending(b.id)
        if res.kind~="blocked" then
          if res.kind=="jolly" then trackMission({type="special", specialKind="jolly"}); FX.onMerge(px,py,"green",combo.combo,b.id)
          elseif res.kind=="clone" then trackMission({type="special", specialKind="clone"})
          elseif res.kind=="grow" then FX.onMerge(px,py,b.color,combo.combo,b.id); trackMission({type="special", specialKind="grow"}); trackMission({type="grow_use"}); if res.gain then Anim.addScorePop(px,py-12,"+"..res.gain,colorMap[b.color] or nil) end
          elseif res.kind=="grow_explode" then FX.onExplosion(px,py,b.color or "red",b.id); trackMission({type="special", specialKind="grow"}); trackMission({type="grow_use"}); if res.gain then Anim.addScorePop(px,py-12,"+"..res.gain) end; trackMission({type="merge", value=32, exploded=true, combo=combo.combo})
          end
          if res.gain then combo:onMerge(love.timer.getTime())
          elseif res.kind=="jolly" or res.kind=="clone" then combo:onMerge(love.timer.getTime()) end
          persistDebounced(true)
        end
        ghost=nil
        return true
      end
    end
    return true
  end
  local cx,cy=Layout.cellAt(layout,x,y)
  if cx then
    local wall=engine:getWallAt(cx,cy)
    if wall then
      local cs=layout.cellSize
      local wpx=layout.offsetX+wall.x*cs+cs/2
      local wpy=layout.offsetY+wall.y*cs+cs/2
      engine:pushHistory(combo:snapshot())
      local res=engine:tapSpecial(wall.id)
      if res.kind=="wallDestroyed" then combo:onMerge(love.timer.getTime()); FX.onWallBreak(wpx,wpy); trackMission({type="wall_break"}); if res.scoreGain then Anim.addScorePop(wpx,wpy-12,"+"..res.scoreGain) end
      else combo:onMiss(); FX.onWallHit(wpx,wpy) end
      persistDebounced(true)
      selectedId=nil
      return true
    end
    local sp=engine:getSpecialAt(cx,cy)
    if sp then
      local cs=layout.cellSize
      local spx=layout.offsetX+sp.x*cs+cs/2
      local spy=layout.offsetY+sp.y*cs+cs/2
      engine:pushHistory(combo:snapshot())
      local res=engine:tapSpecial(sp.id)
      if res.kind=="pending" then
      elseif res.kind=="laser" then
        combo:onMerge(love.timer.getTime())
        FX.onLaser(spx,spy,cs,config.GRID_W,config.GRID_H)
        if res.scoreGain then Anim.addScorePop(spx,spy-12,"+"..res.scoreGain) end
        trackMission({type="special", specialKind="laser"})
      elseif res.kind=="levelup" then
        combo:onMerge(love.timer.getTime())
        trackMission({type="special", specialKind="levelup"}); trackMission({type="grow_use"})
        if res.explosions and res.explosions>0 then FX.onExplosion(spx,spy,"green") end
        if res.gain and res.gain>0 then Anim.addScorePop(spx,spy-12,"+"..res.gain) end
        FX.wiggleAll(engine)
        Anim.showToast("LEVEL UP!"..(res.levelups and (" x"..res.levelups.." tile") or ""),"levelup",Theme.accent,1.6)
        if res.explosions and res.explosions>0 then Anim.showToast("+"..res.explosions.." esplosioni!","boom",Theme.danger,1.6) end
      elseif res.kind=="points" then
        combo:onMerge(love.timer.getTime())
        trackMission({type="special", specialKind="points"})
        if res.gain then Anim.addScorePop(spx,spy-12,"+"..res.gain) end
      elseif res.kind=="minigame" then
        combo:onMerge(love.timer.getTime())
        trackMission({type="special", specialKind="minigame"})
        Anim.showToast("MINIGIOCO!","minigame",Theme.accent,1.4)
        startMinigame(res.game)
      else engine.history=nil end
      persistDebounced(true)
      selectedId=nil
      return true
    end
  end
  if selectedId then
    local blk=engine.blocks[selectedId]
    if blk then
      local dir=Input.dirFromArrowTap(blk.x,blk.y,x,y,layout)
      if dir then tryMove(selectedId, dir); return true end
    end
  end
  if cx then
    local b=engine:getBlockAt(cx,cy)
    if b then
      drag={startX=x,startY=y,curX=x,curY=y,blockId=b.id,cx=cx,cy=cy}
      return true
    else selectedId=nil; ghost=nil end
  end
  return false
end

function love.load()
  love.math.setRandomSeed(os.time())
  pendingFont=love.graphics.newFont(13)
  Emoji.load()
  GridUI.loadImages()
  MinigameSprites.loadAll()
  Settings.load()
  Settings.apply()
  FX.setMotion(Settings.data.motion)
  Background.setEnabled(Settings.data.particles)
  engine=Engine.new()
  combo=Combo.new()
  scheduler=Scheduler.new(engine)
  ach=Ach.new()
  lb=LB.new()
  local saved=Persistence.load()
  if saved and saved.blocks and #saved.blocks>0 then
    engine:fromTable(saved)
    engine.best=saved.best or engine.best
    if saved.comboSnap then combo:restore(saved.comboSnap) end
    if saved.achData then ach:fromTable(saved.achData) end
    if #ach.missions ~= #config.MISSION_POOL then ach:rollMissions(engine.score) end
    if saved.lbData then lb:fromTable(saved.lbData) end
    engine.permMult=ach:permMult()
    FX.preseed(engine)
    hasSave=true
  else
    engine:spawnInitial()
    hasSave=false
  end
  scheduler:reset()
  refreshLayout()
  Router.reset()
  -- if hasSave, start at menu; else menu as well (player chooses)
  MenuScene.load(hasSave)
  PauseScene.load()
  GameOverScene.load()
  LBScene.load()
  AchScene.load()
  HelpScene.load()
  SettingsScene.load()
end

function love.resize(w,h) refreshLayout() end

-- debug screenshot harness: TILEMAMA_SHOTS=<dir> captures menu+game then quits
local shotMode = os.getenv("TILEMAMA_SHOTS")
local shotTimer = 0
local shotStep = 0
-- debug: TILEMAMA_MG=<name> force-starts a minigame once we are in game
local debugMg = os.getenv("TILEMAMA_MG")
local debugMgStarted = false
-- debug: TILEMAMA_SPECIALS=1 force-spawns one of each special once in game
local debugSpecials = os.getenv("TILEMAMA_SPECIALS")
local debugSpecialsDone = false

function love.update(dt)
  -- animations
  Anim.update(dt)
  Anim.updateAll(dt)
  FX.update(dt)

  -- screenshot harness
  if shotMode and shotMode ~= "" then
    shotTimer = shotTimer + dt
    local shoot = {0.5, 1.2, 2.0, 3.8, 6.0}
    if shotStep < #shoot and shotTimer >= shoot[shotStep + 1] then
      shotStep = shotStep + 1
      if shotStep == 2 then Router.goGame() end
      local name = ({"shot_menu.png", "shot_game.png", "shot_game2.png", "shot_mg.png", "shot_mg2.png"})[shotStep]
      local path = shotMode .. "/" .. name
      love.graphics.captureScreenshot(function(imgdata)
        local fdata = imgdata:encode("png")
        local f = io.open(path, "wb")
        if f then f:write(fdata:getString()) f:close() end
      end)
    end
    if shotStep >= #shoot and shotTimer >= 6.4 then love.event.quit() return
    end
  end

  if debugMg and debugMg ~= "" and not debugMgStarted and Router.current() == "game" then
    debugMgStarted = true
    startMinigame(debugMg)
    if activeMinigame then activeMinigame.debugAuto = true end
  end

  if debugSpecials and debugSpecials ~= "" and not debugSpecialsDone and Router.current() == "game" then
    debugSpecialsDone = true
    for _, k in ipairs(config.SPECIAL_KINDS) do engine:spawnSpecial(k) end
    engine:spawnSpecial("minigame")
  end

  -- minigame overlay: owns update, freezes the board
  if activeMinigame then
    activeMinigame:update(dt)
    if activeMinigame:isFinished() then finishMinigame() end
    engine.permMult=ach:permMult()
    return
  end

  -- scheduler only when in game
  if Router.current()=="game" and not engine.gameOver and not engine.pendingMode then
    scheduler:update()
  end
  if engine.gameOver and not engine._lbPushed and Router.current()=="game" then
    lb:push(engine.score, engine.maxTile); engine._lbPushed=true; persistDebounced(true)
    Router.push("gameover")
  elseif not engine.gameOver then engine._lbPushed=nil end

  if drag then
    local dx=drag.curX-drag.startX
    local dy=drag.curY-drag.startY
    local dpi=love.window.getDPIScale and love.window.getDPIScale() or 1
    local thresh=28*dpi
    if math.sqrt(dx*dx+dy*dy)>thresh then
      local dir=Input.angleToDir8(dx,dy)
      if engine:isInverted() then
        local inv={N="S",S="N",E="W",W="E",NE="SW",NW="SE",SE="NW",SW="NE"}
        dir=inv[dir] or dir
      end
      local blk=engine.blocks[drag.blockId]
      if blk then
        local res=MoveResolver.resolve(blk,dir,engine.grid)
        ghost={kind=res.kind,finalX=res.finalX,finalY=res.finalY,path=res.path}
        FX.drag(drag.blockId, dx / (math.abs(dx)+math.abs(dy)+0.01), dy / (math.abs(dx)+math.abs(dy)+0.01))
      end
    else ghost=nil; FX.drag(nil) end
  else FX.drag(nil) end
  engine.permMult=ach:permMult()
  if love.timer.getTime()-lastSave>1 and Router.current()=="game" then persistDebounced(false) end
end

local function drawGame()
  HUD.draw(engine, combo, layout)
  GridUI.draw(engine, layout, selectedId, ghost, engine.pendingMode)

  local w=love.graphics.getDimensions()
  -- malus banner (above grid)
  if engine.activeMalus then
    local remain=engine.activeMalus.endsAt - love.timer.getTime()
    if remain>0 then
      local kind=engine.activeMalus.kind
      local iconMap={freeze="snow", invert="invert", scramble="shuffle", tax="money", leveldown="leveldown", rain="rain"}
      local label=({freeze="GHIACCIATO!", invert="CONTROLLI INVERTITI!", tax="TASSA -50%!", scramble="SCRAMBLE!", leveldown="LEVEL DOWN!", rain="PIOGGIA!"})[kind] or kind
      local ename=iconMap[kind] or "candy"
      local bannerY=layout.offsetY+6
      local txt
      if remain>1.2 and (kind=="freeze" or kind=="invert" or kind=="tax") then txt=label.." "..string.format("%.1fs",remain) else txt=label end
      local font=pendingFont
      love.graphics.setFont(font)
      local tw=font:getWidth(txt)
      local iconSize=20
      local gap=8
      local totalW=iconSize+gap+tw
      local bw=math.min(w-16, totalW+34)
      local bx=w/2-bw/2
      Theme.set({1,0.42,0.54,0.92})
      if kind=="tax" then Theme.set({0.94,0.72,0.24,0.92}) end
      if kind=="freeze" then Theme.set({0.62,0.82,1,0.92}) end
      if kind=="invert" then Theme.set({1,0.85,0.24,0.92}) end
      if kind=="rain" then Theme.set({0.52,0.72,1,0.92}) end
      love.graphics.rectangle("fill", bx, bannerY, bw, 26, 13, 13)
      love.graphics.setColor(0,0,0,0.10)
      love.graphics.rectangle("line", bx, bannerY, bw, 26, 13, 13)
      local sx=bx+(bw-totalW)/2
      Emoji.draw(ename, sx+iconSize/2, bannerY+13, iconSize, 1)
      Theme.set(Theme.textInverse)
      love.graphics.printf(txt, sx+iconSize+gap, bannerY+6, tw, "left")
    end
  end
  if engine.pendingMode then
    local bannerY=layout.offsetY+6
    local pendingLabels={grow="grow (raddoppia)", jolly="jolly (fonde con tutti)", clone="clone (duplica)"}
    local txt="Tocca un blocco per "..(pendingLabels[engine.pendingMode.kind] or engine.pendingMode.kind).." — Esc annulla"
    local font=pendingFont
    love.graphics.setFont(font)
    local tw=font:getWidth(txt)
    local iconSize=20
    local gap=8
    local totalW=iconSize+gap+tw
    local bw=math.min(w-16, totalW+34)
    local bx=w/2-bw/2
    Theme.set(Theme.success)
    love.graphics.rectangle("fill", bx, bannerY, bw, 26, 13, 13)
    local sx=bx+(bw-totalW)/2
    Emoji.draw("candy", sx+iconSize/2, bannerY+13, iconSize, 1)
    Theme.set(Theme.textInverse)
    love.graphics.printf(txt, sx+iconSize+gap, bannerY+6, tw, "left")
  end
  if engine:hasTax() then
    love.graphics.setColor(0.94,0.72,0.24,0.12)
    love.graphics.rectangle("fill", layout.offsetX, layout.offsetY, layout.gridPixelW, layout.gridPixelH, Theme.radius.card, Theme.radius.card)
  end
  if engine:isFrozen() then
    love.graphics.setColor(0.72,0.88,1,0.18)
    love.graphics.rectangle("fill", layout.offsetX, layout.offsetY, layout.gridPixelW, layout.gridPixelH, Theme.radius.card, Theme.radius.card)
    do
      local txt="GHIACCIATO!"
      local font=Theme.font(18)
      love.graphics.setFont(font)
      local tw=font:getWidth(txt)
      local iconSize=26
      local gap=8
      local totalW=iconSize*2+gap*2+tw
      local sx=layout.offsetX + (layout.gridPixelW-totalW)/2
      local cy=layout.offsetY+layout.gridPixelH/2
      Emoji.draw("snow", sx+iconSize/2, cy, iconSize, 1)
      Theme.set(Theme.textInverse)
      love.graphics.printf(txt, sx+iconSize+gap, cy-10, tw, "center")
      Emoji.draw("snow", sx+iconSize+gap+tw+gap+iconSize/2, cy, iconSize, 1)
    end
  end
end

local function drawMinigameHUD()
  local mg=activeMinigame
  if not mg then return end
  if mg.drawHUD then mg:drawHUD(layout); return end
  local barW=math.min(layout.gridPixelW, 360)
  local bx=layout.offsetX + (layout.gridPixelW-barW)/2
  local by=layout.offsetY + layout.gridPixelH + 20
  local dur=(config.GAME_CONFIG.minigameDurationMs or 30000)/1000
  local pct=math.max(0, math.min(1, mg:timeLeft()/dur))
  Theme.set({0,0,0,0.35})
  love.graphics.rectangle("fill",bx,by,barW,10,5,5)
  Theme.set(pct>0.25 and Theme.accent or Theme.danger)
  love.graphics.rectangle("fill",bx,by,barW*pct,10,5,5)
  love.graphics.setFont(pendingFont)
  Theme.set(Theme.text)
  love.graphics.printf("Catch — "..(mg.caught or 0).." tile", bx, by+16, barW/2, "left")
  love.graphics.printf("+"..(mg.score or 0), bx+barW/2, by+16, barW/2, "right")
end

function love.draw()
  local cur=Router.current()
  if cur=="menu" then
    Background.draw("menu")
    Background.drawParticles(love.timer.getDelta())
    MenuScene.draw(engine)
    if Confirm.isOpen() then Confirm.draw() end
    Anim.drawTransition()
    return
  end

  -- minigame owns the screen: its declared backdrop instead of the board
  if activeMinigame then
    Background.draw(activeMinigame.background or "falling")
    Background.drawParticles(love.timer.getDelta())
    local w,h=love.graphics.getDimensions()
    local band=math.floor(h*0.26)
    Theme.verticalFade(0,0,w,band,{0,0,0,0.35},{0,0,0,0},10)
    Theme.verticalFade(0,h-band,w,band,{0,0,0,0},{0,0,0,0.45},10)
    activeMinigame:draw()
    drawMinigameHUD()
  else
    -- menu-originated overlays keep the menu backdrop
    Background.draw(Router.base()=="menu" and "menu" or "game")
    Background.drawParticles(love.timer.getDelta())
    drawGame()
  end

  if cur=="pause" then
    PauseScene.draw()
  elseif cur=="leaderboard" then
    LBScene.draw(lb)
  elseif cur=="achievements" then
    AchScene.draw(ach)
  elseif cur=="help" then
    HelpScene.draw()
  elseif cur=="settings" then
    SettingsScene.draw()
  elseif cur=="gameover" then
    GameOverScene.draw(engine)
  end

  if Confirm.isOpen() then Confirm.draw() end

  -- animation overlays (on top of everything)
  Anim.drawScorePops(pendingFont)
  Anim.drawToasts(Emoji, love.graphics.getDimensions())
  Anim.drawTransition()
end

local function buttonScene()
  local c=Router.current()
  if c=="menu" then return MenuScene end
  if c=="pause" then return PauseScene end
  if c=="gameover" then return GameOverScene end
  if c=="help" then return HelpScene end
  if c=="settings" then return SettingsScene end
  return nil
end

function love.mousepressed(x,y,button)
  if button~=1 then return end
  if Confirm.isOpen() then Confirm.pressAt(x,y); return end
  local sc=buttonScene()
  if sc and sc.pressAt then sc.pressAt(x,y) end
  handlePointerDown(x,y)
end

function love.mousemoved(x,y)
  if activeMinigame then
    -- only steer while dragging: plain hover must not move the bucket
    if love.mouse.isDown(1) then activeMinigame:pointermoved(x,y) end
    return
  end
  if Confirm.isOpen() then Confirm.updateHover(x,y); return end
  local sc=buttonScene()
  if sc and sc.updateHover then sc.updateHover(x,y) end
  if Router.current()=="achievements" then AchScene.moveScroll(y) end
  if drag then drag.curX, drag.curY = x,y end
end

function love.mousereleased(x,y,button)
  if button~=1 then return end
  if Confirm.isOpen() then
    local sc=buttonScene()
    if sc and sc.releasePress then sc.releasePress() end
    local hit=Confirm.hitTest(x,y)
    Confirm.releasePress()
    if hit then Confirm.activate(hit) end
    return
  end
  local sc=buttonScene()
  if sc and sc.releasePress then sc.releasePress() end
  if Router.current()=="achievements" then AchScene.endScroll() end
  if not drag then return end
  -- if in menu/overlay, already handled on press; ignore drag release
  if Router.current()~="game" then drag=nil; ghost=nil; return end
  local dx = x - drag.startX
  local dy = y - drag.startY
  local dpi = love.window.getDPIScale and love.window.getDPIScale() or 1
  local thresh = 28*dpi
  local dist = math.sqrt(dx*dx+dy*dy)
  if dist < thresh then
    local b = engine.blocks[drag.blockId]
    if b then if selectedId==b.id then selectedId=nil else selectedId=b.id end end
    ghost=nil
  else
    local dir = Input.angleToDir8(dx, dy)
    tryMove(drag.blockId, dir)
  end
  drag=nil
end

function love.touchpressed(id,x,y)
  if Confirm.isOpen() then Confirm.pressAt(x,y); return end
  local sc=buttonScene()
  if sc and sc.pressAt then sc.pressAt(x,y) end
  handlePointerDown(x,y)
end

function love.touchmoved(id,x,y)
  if activeMinigame then activeMinigame:pointermoved(x,y); return end
  if Confirm.isOpen() then Confirm.updateHover(x,y); return end
  if Router.current()=="achievements" then AchScene.moveScroll(y) end
  if drag then drag.curX, drag.curY=x,y end
end

function love.touchreleased(id,x,y)
  if Confirm.isOpen() then
    local sc=buttonScene()
    if sc and sc.releasePress then sc.releasePress() end
    local hit=Confirm.hitTest(x,y)
    Confirm.releasePress()
    if hit then Confirm.activate(hit) end
    return
  end
  local sc=buttonScene()
  if sc and sc.releasePress then sc.releasePress() end
  if Router.current()=="achievements" then AchScene.endScroll() end
  if not drag then return end
  if Router.current()~="game" then drag=nil; ghost=nil; return end
  local dx=x - drag.startX
  local dy=y - drag.startY
  local dpi=love.window.getDPIScale and love.window.getDPIScale() or 1
  if math.sqrt(dx*dx+dy*dy) < 28*dpi then
    local b=engine.blocks[drag.blockId]
    if b then selectedId = (selectedId==b.id and nil or b.id) end
  else tryMove(drag.blockId, Input.angleToDir8(dx,dy)) end
  drag=nil; ghost=nil
end

function love.wheelmoved(x,y)
  if Router.current()=="achievements" then AchScene.wheel(y) end
  if Router.current()=="help" then
    if y>0 then HelpScene.prevPage() else HelpScene.nextPage() end
  end
end

function love.keypressed(key)
  if activeMinigame then activeMinigame:keypressed(key); return end
  local cur=Router.current()
  if Confirm.isOpen() then
    if key=="escape" then Confirm.activate("cancel")
    elseif key=="return" or key=="kpenter" then Confirm.activate("confirm") end
    return
  end
  if key=="escape" then
    if cur=="help" or cur=="achievements" or cur=="leaderboard" or cur=="settings" then Router.pop(); return
    elseif cur=="pause" then Router.pop(); return
    elseif cur=="gameover" then goMenu(); return
    elseif cur=="game" then
      if engine.pendingMode then engine:cancelPending(); return end
      Router.push("pause"); return
    elseif cur=="menu" then
      -- on menu, Esc does nothing (or quit on desktop)
      return
    end
  elseif key=="n" and cur=="game" then
    if engine.gameOver then newGame()
    else Confirm.open({title="Nuova partita?", message="La partita attuale verrà persa.", confirmLabel="Sì, ricomincia", onConfirm=newGame}) end
  elseif key=="r" and (cur=="gameover" or cur=="game") then
    if engine.gameOver or cur=="gameover" then newGame() end
  elseif key=="p" and cur=="game" then Router.push("pause")
  elseif key=="g" and cur=="game" then
    engine:spawnSpecial("minigame")
    Anim.showToast("MINIGIOCO (test)!","minigame",Theme.accent,1.4)
  elseif key=="z" and cur=="game" then
    local snap=engine:undo()
    if snap then combo:restore(snap) end
    persistDebounced(true)
  elseif key=="a" and cur=="game" then
    local cs=layout.cellSize
    engine:pushHistory(combo:snapshot())
    local res=engine:addTiles(config.GAME_CONFIG.addTilesCount)
    if res.kind=="addTiles" then
      combo:onMerge(love.timer.getTime())
      local lastB=res.blocks[#res.blocks]
      local px=layout.offsetX+lastB.x*cs+cs/2
      local py=layout.offsetY+lastB.y*cs+cs/2
      for _,b in ipairs(res.blocks) do
        local bx=layout.offsetX+b.x*cs+cs/2
        local by=layout.offsetY+b.y*cs+cs/2
        FX.onMerge(bx,by,b.color,1)
        FX.onWiggle(b.id)
      end
      Anim.addScorePop(px,py-12,"+"..res.gain,Theme.candy.green)
      persistDebounced(true)
    else engine.history=nil end
  end
  -- help navigation
  if cur=="help" then
    if key=="left" or key=="a" then HelpScene.prevPage() end
    if key=="right" or key=="d" then HelpScene.nextPage() end
  end
end

function love.quit() if hasSave then persistDebounced(true) end end
