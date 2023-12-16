require("localization")
local tableUtils = require("tableUtils")

local GameModes = {}

local Styles = { CHOOSE = 0, CLASSIC = 1, MODERN = 2}
local FileSelection = { NONE = 0, TRAINING = 1, PUZZLE = 2}
local StackInteraction = { NONE = 0, VERSUS = 1, SELF = 2, ATTACK_ENGINE = 3, HEALTH_ENGINE = 4}
local WinConditions = { GAME_OVER = 1, SCORE = 2, TIME = 3, NO_MATCHABLE_PANELS = 4, NO_MATCHABLE_GARBAGE = 5 }
local GameOverConditions = { NEGATIVE_HEALTH = 1, TIME_OUT = 2, SCORE_REACHED = 3, NO_MOVES_LEFT = 4, CHAIN_DROPPED = 5 }

local OnePlayerVsSelf = {
  style = Styles.MODERN,
  selectFile = FileSelection.NONE,
  scene = "VsSelfGame",
  richPresenceLabel = loc("mm_1_vs"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteraction.SELF,
  winConditions = { },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,

  -- flags to know what other properties match needs
  needsPuzzle = false,
  needsAttackEngine = false,
  needsHealth = false,
}

local OnePlayerTimeAttack = {
  style = Styles.CHOOSE,
  selectFile = FileSelection.NONE,
  scene = "TimeAttackGame",
  richPresenceLabel = loc("mm_1_time"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteraction.NONE,
  winConditions = { },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH, GameOverConditions.TIME_OUT },
  doCountdown = true,
  timeLimit = TIME_ATTACK_TIME,

  -- flags to know what other properties match needs
  needsPuzzle = false,
  needsAttackEngine = false,
  needsHealth = false,
}

local OnePlayerEndless = {
  style = Styles.CHOOSE,
  selectFile = FileSelection.NONE,
  scene = "EndlessGame",
  richPresenceLabel = loc("mm_1_endless"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteraction.NONE,
  winConditions = { },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,

  -- flags to know what other properties match needs
  needsPuzzle = false,
  needsAttackEngine = false,
  needsHealth = false,
}

local OnePlayerTraining = {
  style = Styles.MODERN,
  selectFile = FileSelection.TRAINING,
  scene = "GameBase",
  richPresenceLabel = loc("mm_1_training"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteraction.ATTACK_ENGINE,
  winConditions = { },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,

  -- flags to know what other properties match needs
  needsPuzzle = false,
  needsAttackEngine = true,
  needsHealth = false,
}

local OnePlayerPuzzle = {
  -- flags for battleRoom to evaluate and in some cases offer UI for
  style = Styles.MODERN,
  selectFile = FileSelection.PUZZLE,
  richPresenceLabel = loc("mm_1_puzzle"),
  scene = "PuzzleGame",

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteraction.NONE,
  -- these are extended based on the loaded puzzle
  winConditions = { },
  -- these are extended based on the loaded puzzle
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = false,

  -- flags to know what other properties match needs
  needsPuzzle = true,
  needsAttackEngine = false,
  needsHealth = false,
}

local OnePlayerChallenge = {
  style = Styles.MODERN,
  selectFile = FileSelection.NONE,
  scene = "GameBase",
  richPresenceLabel = loc("mm_1_challenge_mode"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteraction.HEALTH_ENGINE,
  winConditions = { WinConditions.GAME_OVER },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,

  -- flags to know what other properties match needs
  needsPuzzle = false,
  needsAttackEngine = true,
  needsHealth = true,
}

local TwoPlayerVersus = {
  style = Styles.MODERN,
  scene = "Game2pVs",
  richPresenceLabel = loc("mm_2_vs"),

  -- already known match properties
  playerCount = 2,
  stackInteraction = StackInteraction.VERSUS,
  winConditions = { WinConditions.GAME_OVER},
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,

  -- flags to know what other properties match needs
  needsPuzzle = false,
  needsAttackEngine = false,
  needsHealth = false,
}

GameModes.Styles = Styles
GameModes.FileSelection = FileSelection
GameModes.StackInteraction = StackInteraction
GameModes.WinCondition = WinConditions
GameModes.GameOverCondition = GameOverConditions

GameModes.ONE_PLAYER_VS_SELF = OnePlayerVsSelf
GameModes.ONE_PLAYER_TIME_ATTACK = OnePlayerTimeAttack
GameModes.ONE_PLAYER_ENDLESS = OnePlayerEndless
GameModes.ONE_PLAYER_TRAINING = OnePlayerTraining
GameModes.ONE_PLAYER_PUZZLE = OnePlayerPuzzle
GameModes.ONE_PLAYER_CHALLENGE = OnePlayerChallenge
GameModes.TWO_PLAYER_VS = TwoPlayerVersus

return GameModes