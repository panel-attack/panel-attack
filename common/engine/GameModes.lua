local TIME_ATTACK_TIME = 120

local GameModes = {}

-- longterm we want to abandon the concept of "style" on the engine and room setup level
-- the engine only cares about levelData, style is a menu-only concept
-- there is no technical reason why someone on level 10 shouldn't be able to play against someone on Hard
-- meaning the props which scene uses which style should live on the scenes, not here
local Styles = { CHOOSE = 0, CLASSIC = 1, MODERN = 2}
local StackInteractions = { NONE = 0, VERSUS = 1, SELF = 2, ATTACK_ENGINE = 3 }

-- these are competitive win conditions to determine a winner across multiple stacks
local MatchWinConditions = { LAST_ALIVE = 1, SCORE = 2, TIME = 3 }
-- these are game winning objectives on the stack level, the stack stops running without going game over
local GameWinConditions = { NO_MATCHABLE_PANELS = 1, NO_MATCHABLE_GARBAGE = 2}
-- these are game losing objectives on the stack level, the stack goes game over or is forced to stop running in another way
local GameOverConditions = { NEGATIVE_HEALTH = 1, TIME_OUT = 2, NO_MOVES_LEFT = 3, CHAIN_DROPPED = 4 }

local OnePlayerVsSelf = {
  style = Styles.MODERN,
  gameScene = "VsSelfGame",
  setupScene = "CharacterSelectVsSelf",
  richPresenceLabel = "1p vs self", -- loc("mm_1_vs"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.SELF,
  winConditions = { },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,
}

local OnePlayerTimeAttack = {
  style = Styles.CHOOSE,
  gameScene = "TimeAttackGame",
  setupScene = "TimeAttackMenu",
  richPresenceLabel = "Time Attack", -- loc("mm_1_time"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.NONE,
  winConditions = { },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH, GameOverConditions.TIME_OUT },
  doCountdown = true,
  timeLimit = TIME_ATTACK_TIME,
}

local OnePlayerEndless = {
  style = Styles.CHOOSE,
  gameScene = "EndlessGame",
  setupScene = "EndlessMenu",
  richPresenceLabel = "Endless", -- loc("mm_1_endless"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.NONE,
  winConditions = { },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,
}

local OnePlayerTraining = {
  style = Styles.MODERN,
  gameScene = "Game1pTraining",
  setupScene = "CharacterSelectVsSelf",
  richPresenceLabel = "Training", -- loc("mm_1_training"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.ATTACK_ENGINE,
  winConditions = { MatchWinConditions.LAST_ALIVE },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,
}

local OnePlayerPuzzle = {
  -- flags for battleRoom to evaluate and in some cases offer UI for
  style = Styles.MODERN,
  richPresenceLabel = "Puzzle", -- loc("mm_1_puzzle"),
  gameScene = "PuzzleGame",
  setupScene = "PuzzleMenu",

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.NONE,
  -- these are extended based on the loaded puzzle
  winConditions = { },
  -- these are extended based on the loaded puzzle
  gameOverConditions = {  },
  doCountdown = false,
}

local OnePlayerChallenge = {
  style = Styles.MODERN,
  gameScene = "Game1pChallenge",
  setupScene = "CharacterSelectChallenge",
  richPresenceLabel = "Challenge Mode", -- loc("mm_1_challenge_mode"),

  -- already known match properties
  playerCount = 1,
  stackInteraction = StackInteractions.VERSUS,
  winConditions = { MatchWinConditions.LAST_ALIVE },
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,
}

local TwoPlayerVersus = {
  style = Styles.MODERN,
  gameScene = "Game2pVs",
  setupScene = "CharacterSelect2p",
  richPresenceLabel = "2p versus", -- loc("mm_2_vs"),

  -- already known match properties
  playerCount = 2,
  stackInteraction = StackInteractions.VERSUS,
  winConditions = { MatchWinConditions.LAST_ALIVE},
  gameOverConditions = { GameOverConditions.NEGATIVE_HEALTH },
  doCountdown = true,
}

GameModes.Styles = Styles
GameModes.StackInteractions = StackInteractions
GameModes.WinConditions = MatchWinConditions
GameModes.GameWinConditions = GameWinConditions
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