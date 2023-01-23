local GameModes = {}

local Styles = { Choose = 0, Classic = 1, Modern = 2}
local FileSelection = { None = 0, Training = 1, Puzzle = 2}

local OnePlayerVsSelf = {
  playerCount = 1,
  selectCharacter = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Modern,
  selectFile = FileSelection.None,
  selectColorRandomization = false
}
local OnePlayerTimeAttack = {
  playerCount = 1,
  selectCharacter = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Choose,
  selectFile = FileSelection.None,
  selectColorRandomization = false
}

local OnePlayerEndless = {
  playerCount = 1,
  selectCharacter = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Choose,
  selectFile = FileSelection.None,
  selectColorRandomization = false
}

local OnePlayerTraining = {
  playerCount = 1,
  selectCharacter = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Modern,
  selectFile = FileSelection.Training,
  selectColorRandomization = false
}

local OnePlayerPuzzle = {
  playerCount = 1,
  selectCharacter = true,
  selectStage = true,
  selectPanels = true,
  selectRanked = false,
  style = Styles.Modern,
  selectFile = FileSelection.Puzzle,
  selectColorRandomization = true
}

local TwoPlayerVersus = {
  playerCount = 2,
  selectCharacter = true,
  selectStage = true,
  selectPanels = true,
  -- this will be rechecked with the online flag
  selectRanked = true,
  style = Styles.Modern,
  selectFile = FileSelection.None,
  selectColorRandomization = false
}

GameModes.OnePlayerVsSelf = OnePlayerVsSelf
GameModes.OnePlayerTimeAttack = OnePlayerTimeAttack
GameModes.OnePlayerEndless = OnePlayerEndless
GameModes.OnePlayerTraining = OnePlayerTraining
GameModes.OnePlayerPuzzle = OnePlayerPuzzle
GameModes.TwoPlayerVersus = TwoPlayerVersus
GameModes.Styles = Styles
GameModes.FileSelection = FileSelection


return GameModes