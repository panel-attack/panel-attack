local GameModes = {}

local Styles = { Choose = 0, Classic = 1, Modern = 2}
local FileSelection = { None = 0, Training = 1, Puzzle = 2}
local StackInteraction = { None = 0, Versus = 1, Self = 2, AttackEngine = 3, HealthEngine = 4}

local OnePlayerVsSelf = {
  playerCount = 1,
  selectCharacter = true,
  selectLevel = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Modern,
  selectFile = FileSelection.None,
  selectColorRandomization = false,
  stackInteraction = StackInteraction.Self
}
local OnePlayerTimeAttack = {
  playerCount = 1,
  selectCharacter = true,
  selectLevel = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Choose,
  selectFile = FileSelection.None,
  selectColorRandomization = false,
  stackInteraction = StackInteraction.None,
  scene = "TimeAttackGame",
  matchMode = "time"
}

local OnePlayerEndless = {
  playerCount = 1,
  selectCharacter = true,
  selectLevel = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Choose,
  selectFile = FileSelection.None,
  selectColorRandomization = false,
  stackInteraction = StackInteraction.None,
  scene = "EndlessGame",
  matchMode = "endless"
}

local OnePlayerTraining = {
  playerCount = 1,
  selectCharacter = true,
  selectLevel = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Modern,
  selectFile = FileSelection.Training,
  selectColorRandomization = false,
  stackInteraction = StackInteraction.AttackEngine
}

local OnePlayerPuzzle = {
  playerCount = 1,
  selectCharacter = true,
  selectLevel = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Modern,
  selectFile = FileSelection.Puzzle,
  selectColorRandomization = true,
  stackInteraction = StackInteraction.None,
  scene = "PuzzleGame",
  matchMode = "puzzle"
}

local OnePlayerChallenge = {
  playerCount = 1,
  selectCharacter = true,
  selectLevel = false,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Modern,
  selectFile = FileSelection.None,
  selectColorRandomization = false,
  stackInteraction = StackInteraction.HealthEngine
}

local TwoPlayerVersus = {
  playerCount = 2,
  selectCharacter = true,
  selectLevel = true,
  selectStage = true,
  selectPanels = true,
  -- this has to be rechecked with the online flag
  selectRanked = true,
  style = Styles.Modern,
  selectFile = FileSelection.None,
  selectColorRandomization = false,
  stackInteraction = StackInteraction.Versus,
  scene = "OnlineVsGame"
}

GameModes.OnePlayerVsSelf = OnePlayerVsSelf
GameModes.OnePlayerTimeAttack = OnePlayerTimeAttack
GameModes.OnePlayerEndless = OnePlayerEndless
GameModes.OnePlayerTraining = OnePlayerTraining
GameModes.OnePlayerPuzzle = OnePlayerPuzzle
GameModes.OnePlayerChallenge = OnePlayerChallenge
GameModes.TwoPlayerVersus = TwoPlayerVersus
GameModes.Styles = Styles
GameModes.FileSelection = FileSelection
GameModes.StackInteraction = StackInteraction


return GameModes