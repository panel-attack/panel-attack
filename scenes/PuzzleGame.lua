local GameBase = require("scenes.GameBase")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local class = require("class")

--@module puzzleGame
-- Scene for a puzzle mode instance of the game
local PuzzleGame = class(
  function (self, sceneParams)
    self:init()
    self:load(sceneParams)
  end,
  GameBase
)

PuzzleGame.name = "PuzzleGame"
sceneManager:addScene(PuzzleGame)

function PuzzleGame:customLoad(sceneParams)
  GAME.match = Match("puzzle")
  GAME.match.P1 = Stack{which=1, match=GAME.match, is_local=true, level=config.puzzle_level, character=sceneParams.character}
  GAME.match.P1:wait_for_random_character()
  GAME.match.P1.do_countdown = config.ready_countdown_1P or false
  GAME.match.P2 = nil
  
  self.puzzleSet = sceneParams.puzzleSet
  self.puzzleIndex = sceneParams.puzzleIndex

  local puzzle = self.puzzleSet.puzzles[self.puzzleIndex]
  local isValid, validationError = puzzle:validate()
  if isValid then
    GAME.match.P1:set_puzzle_state(puzzle)
  else
    validationError = "Validation error in puzzle set " .. self.puzzleSet.setName .. "\n"
                      .. validationError
    sceneManager:switchToScene("PuzzleMenu")
  end
end

function PuzzleGame:customRun()
  -- reset level
  if (input.isDown["TauntUp"] or input.isDown["TauntDown"]) and not GAME.gameIsPaused then 
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    -- The character and stage and music and background should all state the same until you complete the whole puzzle set
    sceneManager:switchToScene("PuzzleGame", {puzzleSet = self.puzzleSet, puzzleIndex = self.puzzleIndex, character = GAME.match.P1.character, loadStageAndMusic = false})
  end
end

function PuzzleGame:abortGame()
  sceneManager:switchToScene("PuzzleMenu")
end

function PuzzleGame:customGameOverSetup()
  if GAME.match.P1:puzzle_done() then -- writes successful puzzle replay and ends game
    self.text = loc("pl_you_win")
    self.winnerSFX = GAME.match.P1:pick_win_sfx()
    if self.puzzleIndex == #self.puzzleSet.puzzles then
      self.keepMusic = false
      self.nextScene = "PuzzleMenu"
      self.nextSceneParams = nil
    else
      self.keepMusic = true
      self.nextScene = "PuzzleGame"
      -- The character and stage and music and background should all state the same until you complete the whole puzzle set
      self.nextSceneParams = {puzzleSet = self.puzzleSet, puzzleIndex = self.puzzleIndex + 1, character = GAME.match.P1.character, loadStageAndMusic = false}
    end
  elseif GAME.match.P1:puzzle_failed() then
    SFX_GameOver_Play = 1
    self.text = loc("pl_you_lose")
    self.keepMusic = true
    self.nextScene = "PuzzleGame"
    self.nextSceneParams = {puzzleSet = self.puzzleSet, puzzleIndex = self.puzzleIndex, character = GAME.match.P1.character, loadStageAndMusic = false}
  end
  
end

return PuzzleGame