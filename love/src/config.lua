local M = {}

M.GRID_W = 7
M.GRID_H = 9
M.GRID_CELLS = M.GRID_W * M.GRID_H

M.GAME_CONFIG = {
  gridW = 7,
  gridH = 9,
  initialBlocksPerColor = 4,
  explosionValue = 32,
  explosionSpawnCount = 4,
  bonusMinDelayMs = 6500,
  bonusMaxDelayMs = 10500,
  specialDurationMs = 9000,
  wallDurationMs = 12000,
  wallHp = 2,
  cleanupIntervalMs = 250,
  malusMinDelayMs = 15000,
  malusMaxDelayMs = 25000,
  malusGraceMs = 30000,
  malusFreezeMs = 3000,
  malusInvertMs = 6000,
  malusTaxMs = 8000,
  rainIntervalMs = 12000,
  rainGraceMs = 8000,
  rainMin = 2,
  rainMax = 5,
  missionsPerRun = 3,
  missionRewardScore = 80,
  missionRewardMultiplier = 1.5,
  missionBuffMs = 5000,
  achievementRewardScore = 150,
  addTilesCount = 3,
  addTilesRewardPerTile = 10,
  wallBreakReward = 20,
  -- minigames
  minigameMinDelayMs = 45000,
  minigameMaxDelayMs = 75000,
  minigameGraceMs = 20000,
  minigameSpecialDurationMs = 15000,
  minigameDurationMs = 30000,
  minigameFallSpeed = 3.5,
  minigameSpawnMs = 650,
  minigameStreakWindowMs = 1100,
  minigameIntroMs = 1200,
  minigameUrgentMs = 5000,
  minigameWhackUpBaseMs = 1000,
  minigameWhackUpMinMs = 520,
  minigameWhackSpawnMs = 620,
  minigameWhackSpawnMinMs = 320,
  minigameWhackMaxMoles = 3,
  minigameWhackTargetEveryMs = 4000,
  minigameWhackPenalty = 1,
}

M.POINTS_VALUES = {100, 200, 300}

M.COLORS = {"green", "red", "yellow", "blue"}
M.COLOR_TO_DIR = {
  green = "assets/verde",
  red = "assets/rosso",
  yellow = "assets/giallo",
  blue = "assets/blue",
}

M.VALUES = {1,2,4,8,16,32}

M.DIRS = {
  N  = {dx=0, dy=-1},
  S  = {dx=0, dy=1},
  E  = {dx=1, dy=0},
  W  = {dx=-1, dy=0},
  NE = {dx=1, dy=-1},
  NW = {dx=-1, dy=-1},
  SE = {dx=1, dy=1},
  SW = {dx=-1, dy=1},
}
M.DIR_LIST = {"N","S","E","W","NE","NW","SE","SW"}

-- bonus/malus from bonus.md
M.SPECIAL_KINDS = {"levelup", "points", "laser", "jolly", "clone", "grow", "wall"}
M.SPECIAL_WEIGHTS = {
  levelup=0.16, points=0.15, laser=0.18, jolly=0.13, clone=0.13, grow=0.14, wall=0.11
}

-- minigames (activated by a dedicated board special)
M.MINIGAME_KINDS = {"falling", "whack"}
M.MINIGAME_WEIGHTS = { falling = 0.6, whack = 0.4 }
M.MINIGAME_TILE_VALUES = {1, 1, 2, 2, 4, 8}
M.MINIGAME_POINTS_PER_VALUE = 5

M.MALUS_KINDS = {"leveldown", "freeze", "scramble", "invert", "rain", "tax"}
M.MALUS_WEIGHTS = {
  leveldown=0.18, freeze=0.17, scramble=0.17, invert=0.13, rain=0.18, tax=0.17
}
M.MALUS_DURATION_MS = {
  leveldown=0, freeze=3000, scramble=0, invert=6000, rain=0, tax=8000,
}

-- missions 12 templates
M.MISSION_POOL = {
  {id="merge_red_3", label="Fondi 3 rossi", kind="merge_color", color="red", target=3, diff="easy"},
  {id="merge_green_3", label="Fondi 3 verdi", kind="merge_color", color="green", target=3, diff="easy"},
  {id="merge_total_4", label="Fai 4 fusioni", kind="merge_total", target=4, diff="easy"},
  {id="wall_break_1", label="Rompi 1 muro", kind="wall_break", target=1, diff="easy"},
  {id="value_16", label="Crea valore 16", kind="value_reach", value=16, target=1, diff="med"},
  {id="grow_use_1", label="Usa 1 grow/levelup", kind="grow_use", target=1, diff="med"},
  {id="special_rainbow", label="Usa 1 levelup/rainbow", kind="special_use", target=1, diff="med"},
  {id="combo_3", label="Combo x3", kind="combo", target=3, diff="med"},
  {id="clone_use_1", label="Usa 1 clone", kind="clone_use", target=1, diff="med"},
  {id="explosion_32", label="Esplosione 32!", kind="explosion", target=1, diff="hard"},
  {id="diagonal_2", label="2 fusioni diagonali", kind="diagonal", target=2, diff="hard"},
  {id="jolly_use_1", label="Usa 1 jolly", kind="jolly_use", target=1, diff="hard"},
}

M.ACHIEVEMENTS = {
  {id="merge_50", label="Fonditore", desc="50 fusioni", kind="merge_total", target=50, rewardScore=150, permMult=0},
  {id="value_16_5", label="Artigiano", desc="Crea 5x valore 16", kind="value_16", target=5, rewardScore=150, permMult=0},
  {id="explosion_3", label="Demolitore", desc="3 esplosioni", kind="explosion", target=3, rewardScore=150, permMult=0.05},
  {id="combo_4", label="Catena", desc="Combo x4", kind="combo", target=1, rewardScore=150, permMult=0.05},
  {id="special_15", label="Collezionista", desc="Usa 15 speciali", kind="special", target=15, rewardScore=150, permMult=0},
  {id="wall_10", label="Muratore", desc="Rompi 10 muri", kind="wall_break", target=10, rewardScore=150, permMult=0},
}

return M
