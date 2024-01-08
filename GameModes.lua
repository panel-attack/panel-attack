require("localization")

local TIME_ATTACK_TIME = 120

local GameModes = {}

local Styles = { CHOOSE = 0, CLASSIC = 1, MODERN = 2}
local FileSelection = { NONE = 0, TRAINING = 1, PUZZLE = 2}
local StackInteractions = { NONE = 0, VERSUS = 1, SELF = 2, ATTACK_ENGINE = 3, HEALTH_ENGINE = 4}
local WinConditions = { LAST_ALIVE = 1, SCORE = 2, TIME = 3, NO_MATCHABLE_PANELS = 4, NO_MATCHABLE_GARBAGE = 5 }
local GameOverConditions = { NEGATIVE_HEALTH = 1, TIME_OUT = 2, SCORE_REACHED = 3, NO_MOVES_LEFT = 4, CHAIN_DROPPED = 5 }

local OnePlayerVsSelf = {
  style = Styles.MODERN,
  selectFile = FileSelection.NONE,
  gameScene = "VsSelfGame",
  setupScene = "CharacterSelectVsSelf",
  richPresenceLabel = loc("mm_1_vs"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.SELF,
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
  gameScene = "TimeAttackGame",
  setupScene = "TimeAttackMenu",
  richPresenceLabel = loc("mm_1_time"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.NONE,
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
  gameScene = "EndlessGame",
  setupScene = "EndlessMenu",
  richPresenceLabel = loc("mm_1_endless"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.NONE,
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
  gameScene = "Game1pTraining",
  setupScene = "CharacterSelectVsSelf",
  richPresenceLabel = loc("mm_1_training"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.ATTACK_ENGINE,
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
  gameScene = "PuzzleGame",
  setupScene = "PuzzleMenu",

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.NONE,
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
  gameScene = "Game1pChallenge",
  setupScene = "CharacterSelectChallenge",
  richPresenceLabel = loc("mm_1_challenge_mode"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.VERSUS,
  winConditions = { WinConditions.LAST_ALIVE },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,

  -- flags to know what other properties match needs
  needsPuzzle = false,
  needsAttackEngine = true,
  needsHealth = true,
}

local TwoPlayerVersus = {
  style = Styles.MODERN,
  gameScene = "Game2pVs",
  setupScene = "CharacterSelect2p",
  richPresenceLabel = loc("mm_2_vs"),

  -- already known match properties
  playerCount = 2,
  stackInteraction = StackInteractions.VERSUS,
  winConditions = { WinConditions.LAST_ALIVE},
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,

  -- flags to know what other properties match needs
  needsPuzzle = false,
  needsAttackEngine = false,
  needsHealth = false,
}

GameModes.Styles = Styles
GameModes.FileSelection = FileSelection
GameModes.StackInteractions = StackInteractions
GameModes.WinConditions = WinConditions
GameModes.GameOverConditions = GameOverConditions

local privateGameModes = {}
privateGameModes.ONE_PLAYER_VS_SELF = OnePlayerVsSelf
privateGameModes.ONE_PLAYER_TIME_ATTACK = OnePlayerTimeAttack
privateGameModes.ONE_PLAYER_ENDLESS = OnePlayerEndless
privateGameModes.ONE_PLAYER_TRAINING = OnePlayerTraining
privateGameModes.ONE_PLAYER_PUZZLE = OnePlayerPuzzle
privateGameModes.ONE_PLAYER_CHALLENGE = OnePlayerChallenge
privateGameModes.TWO_PLAYER_VS = TwoPlayerVersus

function GameModes.getPreset(mode)
  assert(privateGameModes[mode], "Trying to access non existing mode " .. mode)
  return deepcpy(privateGameModes[mode])
end

return GameModes