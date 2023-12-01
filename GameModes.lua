require("localization")

local GameModes = {}

local Styles = { CHOOSE = 0, CLASSIC = 1, MODERN = 2}
local FileSelection = { NONE = 0, TRAINING = 1, PUZZLE = 2}
local StackInteraction = { NONE = 0, VERSUS = 1, SELF = 2, ATTACK_ENGINE = 3, HEALTH_ENGINE = 4}
local WinConditions = { GAME_OVER = 1, SCORE = 2, TIME = 3 }

local OnePlayerVsSelf = {
  playerCount = 1,
  style = Styles.MODERN,
  selectFile = FileSelection.NONE,
  stackInteraction = StackInteraction.SELF,
  scene = "VsSelfGame",
  richPresenceLabel = loc("mm_1_vs"),
  winConditions = { },
  doCountdown = true,
}

local OnePlayerTimeAttack = {
  playerCount = 1,
  style = Styles.CHOOSE,
  selectFile = FileSelection.NONE,
  stackInteraction = StackInteraction.NONE,
  scene = "TimeAttackGame",
  richPresenceLabel = loc("mm_1_time"),
  winConditions = { }, -- for 2p vs Time Attack: { WinConditions.SCORE }
  doCountdown = true,
  timeLimit = TIME_ATTACK_TIME,
}

local OnePlayerEndless = {
  playerCount = 1,
  style = Styles.CHOOSE,
  selectFile = FileSelection.NONE,
  stackInteraction = StackInteraction.NONE,
  scene = "EndlessGame",
  richPresenceLabel = loc("mm_1_endless"),
  winConditions = { }, -- for 2p vs endless: { WinConditions.SCORE, WinConditions.TIME }
  doCountdown = true,
}

local OnePlayerTraining = {
  playerCount = 1,
  style = Styles.MODERN,
  selectFile = FileSelection.TRAINING,
  stackInteraction = StackInteraction.ATTACK_ENGINE,
  scene = "GameBase",
  richPresenceLabel = loc("mm_1_training"),
  winConditions = { }, -- for 2p vs training: { WinConditions.TIME } 
  doCountdown = true,
}

local OnePlayerPuzzle = {
  playerCount = 1,
  style = Styles.MODERN,
  selectFile = FileSelection.PUZZLE,
  stackInteraction = StackInteraction.NONE,
  scene = "PuzzleGame",
  richPresenceLabel = loc("mm_1_puzzle"),
  winConditions = { },
  doCountdown = false,
}

local OnePlayerChallenge = {
  playerCount = 1,
  style = Styles.MODERN,
  selectFile = FileSelection.NONE,
  stackInteraction = StackInteraction.HEALTH_ENGINE,
  scene = "GameBase",
  richPresenceLabel = loc("mm_1_challenge_mode"),
  winConditions = { WinConditions.GAME_OVER }, -- for 2p vs challenge: { WinConditions.TIME }
  doCountdown = true,
}

local TwoPlayerVersus = {
  playerCount = 2,
  style = Styles.MODERN,
  selectFile = FileSelection.NONE,
  stackInteraction = StackInteraction.VERSUS,
  scene = "OnlineVsGame",
  richPresenceLabel = loc("mm_2_vs"),
  winConditions = { WinConditions.GAME_OVER},
  doCountdown = true,
}

GameModes.Styles = Styles
GameModes.FileSelection = FileSelection
GameModes.StackInteraction = StackInteraction
GameModes.WinCondition = WinConditions

GameModes.ONE_PLAYER_VS_SELF = OnePlayerVsSelf
GameModes.ONE_PLAYER_TIME_ATTACK = OnePlayerTimeAttack
GameModes.ONE_PLAYER_ENDLESS = OnePlayerEndless
GameModes.ONE_PLAYER_TRAINING = OnePlayerTraining
GameModes.ONE_PLAYER_PUZZLE = OnePlayerPuzzle
GameModes.ONE_PLAYER_CHALLENGE = OnePlayerChallenge
GameModes.TWO_PLAYER_VS = TwoPlayerVersus

return GameModes