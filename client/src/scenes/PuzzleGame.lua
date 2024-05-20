local GameBase = require("client.src.scenes.GameBase")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local MessageTransition = require("client.src.scenes.Transitions.MessageTransition")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local consts = require("common.engine.consts")

--@module puzzleGame
-- Scene for a puzzle mode instance of the game
local PuzzleGame = class(
  function (self, sceneParams)
    -- we cache the player's input configuration here
    self.inputConfiguration = nil

    self:load(sceneParams)
  end,
  GameBase
)

PuzzleGame.name = "PuzzleGame"

function PuzzleGame:customLoad(sceneParams)
  self.inputConfiguration = self.match.players[1].inputConfiguration
  self.puzzleSet = self.match.players[1].settings.puzzleSet
  self.puzzleIndex = self.match.players[1].settings.puzzleIndex
  local puzzle = self.puzzleSet.puzzles[self.puzzleIndex]
  local isValid, validationError = puzzle:validate()
  if isValid then
    self.match.players[1].stack:set_puzzle_state(puzzle)
    self.match:setCountdown(puzzle.doCountdown)
  else
    validationError = "Validation error in puzzle set " .. self.puzzleSet.setName .. "\n"
                    .. validationError
    local transition = MessageTransition(GAME.timer, 5, validationError)
    GAME.navigationStack:pop(transition)
  end
end

function PuzzleGame:customRun()
  -- reset level
  if (self.inputConfiguration and self.inputConfiguration.isDown["TauntUp"]) and not self.match.isPaused then
    GAME.theme:playValidationSfx()
    -- basically resetting the stack and match
    local puzzle = self.puzzleSet.puzzles[self.puzzleIndex]
    local stack = self.match.stacks[1]
    stack:set_puzzle_state(puzzle)
    stack.confirmedInput = {}
    stack.input_buffer = {}
    stack.clock = 0
    stack.game_stopwatch = 0
    stack.game_stopwatch_running = false

    self.match.clock = 0
    self.match:setCountdown(puzzle.doCountdown)
    self.match.players[1]:incrementWinCount()
  end
end

function PuzzleGame:runGameOver()
  GraphicsUtil.print(self.text, (consts.CANVAS_WIDTH - GraphicsUtil.getGlobalFont():getWidth(self.text)) / 2, 10)

  self.match:run()

  -- if a key of the used inputconfig is used, set the player to want ready again
  local keyPressed = tableUtils.trueForAny(self.inputConfiguration.isDown, function(key) return key end)

  if (keyPressed) then
    GAME.theme:playValidationSfx()
    SFX_GameOver_Play = 0
    if self.match.players[1].settings.puzzleIndex <= #self.match.players[1].settings.puzzleSet.puzzles then
      self.match.players[1]:setWantsReady(true)
    else
      GAME.navigationStack:pop()
    end
  end
end

function PuzzleGame:customGameOverSetup()
  -- currently puzzle game bypasses the match start mechanism of BattleRoom by not returning to a real ready screen
  -- as the player releases their inputConfiguration on puzzle end, we need to reassign it asap
  -- otherwise the next puzzle match will crash due to the player not having an input configuration assigned

  if self.match.stacks[1].game_over_clock <= 0 and not self.match.aborted then -- puzzle has been solved successfully
    self.text = loc("pl_you_win")
    self.match.players[1]:setPuzzleIndex(self.puzzleIndex + 1)
  else -- puzzle failed or manually reset
    SFX_GameOver_Play = 1
    self.text = loc("pl_you_lose")
  end
end

return PuzzleGame