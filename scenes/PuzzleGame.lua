local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local class = require("class")

--@module puzzleGame
-- Scene for a puzzle mode instance of the game
local PuzzleGame = class(
  function (self, sceneParams)
    self.nextScene = nil -- set in customGameOverSetup
    self.puzzleIndex = 1
    
    self:load(sceneParams)
  end,
  GameBase
)

PuzzleGame.name = "PuzzleGame"
sceneManager:addScene(PuzzleGame)

function PuzzleGame:customLoad(sceneParams)
  if sceneParams.puzzleIndex then
    self.puzzleIndex = sceneParams.puzzleIndex
  end
  self.puzzleSet = self.match.players[1].settings.puzzleSet
  local puzzle = self.puzzleSet.puzzles[self.puzzleIndex]
  local isValid, validationError = puzzle:validate()
  if isValid then
    self.match.players[1].stack:set_puzzle_state(puzzle)
  else
    validationError = "Validation error in puzzle set " .. self.puzzleSet.setName .. "\n"
                      .. validationError
    sceneManager:switchToScene(sceneManager:createScene("PuzzleMenu"))
  end
end

function PuzzleGame:customRun()
  -- reset level
  if (input.isDown["TauntUp"] or input.isDown["TauntDown"]) and not self.match.isPaused then 
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    -- The character and stage and music and background should all state the same until you complete the whole puzzle set
    sceneManager:switchToScene(sceneManager:createScene("PuzzleGame", {puzzleSet = self.puzzleSet, puzzleIndex = self.puzzleIndex, character = self.match.players[1].stack.character, loadStageAndMusic = false}))
  end
end

function PuzzleGame:customGameOverSetup()
  if self.match.P1:puzzle_done() then -- writes successful puzzle replay and ends game
    self.text = loc("pl_you_win")
    if self.puzzleIndex == #self.puzzleSet.puzzles then
      self.keepMusic = false
      self.nextScene = "PuzzleMenu"
      self.nextSceneParams = nil
    else
      self.keepMusic = true
      self.nextScene = "PuzzleGame"
      local match = GAME.battleRoom:createMatch()
      match:start()
      -- The character and stage and music and background should all state the same until you complete the whole puzzle set
      self.nextSceneParams = {puzzleSet = self.puzzleSet, puzzleIndex = self.puzzleIndex + 1, character = self.match.players[1].stack.character, loadStageAndMusic = false, match = match}
    end
  elseif self.match.players[1].stack:puzzle_failed() then
    SFX_GameOver_Play = 1
    self.text = loc("pl_you_lose")
    self.keepMusic = true
    self.nextScene = "PuzzleGame"
    local match = GAME.battleRoom:createMatch()
    match:start()
    self.nextSceneParams = {puzzleSet = self.puzzleSet, puzzleIndex = self.puzzleIndex, character = self.match.players[1].stack.character, loadStageAndMusic = false, match = match}
  end
end

return PuzzleGame