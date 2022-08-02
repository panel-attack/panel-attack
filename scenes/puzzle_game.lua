local GameBase = require("scenes.GameBase")
local scene_manager = require("scenes.scene_manager")
local input = require("inputManager")

--@module puzzle_game
local puzzle_game = GameBase("puzzle_game", {})

function puzzle_game:customLoad(scene_params)
  GAME.match = Match("puzzle")
  GAME.match.P1 = Stack{which=1, match=GAME.match, is_local=true, level=config.puzzle_level, character=nil}
  GAME.match.P1:wait_for_random_character()
  GAME.match.P1.do_countdown = config.ready_countdown_1P or false
  GAME.match.P2 = nil
  
  self.puzzle_set = scene_params.puzzle_set
  self.puzzle_index = scene_params.puzzle_index

  local puzzle = self.puzzle_set.puzzles[self.puzzle_index]
  local isValid, validationError = puzzle:validate()
  if isValid then
    GAME.match.P1:set_puzzle_state(puzzle)
  else
    validationError = "Validation error in puzzle set " .. self.puzzleSet.setName .. "\n"
                      .. validationError
    scene_manager:switchScene("puzzle_menu")
  end
end

function puzzle_game:customRun()
  -- reset level
  if input.isDown["TauntUp"] or input.isDown["TauntDown"] then 
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    scene_manager:switchScene("puzzle_game", {puzzle_set = self.puzzle_set, puzzle_index = self.puzzle_index})
  end
end

function puzzle_game:abortGame()
  scene_manager:switchScene("puzzle_menu")
end

function puzzle_game:customGameOverSetup()
  if GAME.match.P1:puzzle_done() then -- writes successful puzzle replay and ends game
    self.text = loc("pl_you_win")
    self.winner_SFX = GAME.match.P1:pick_win_sfx()
    if self.puzzle_index == #self.puzzle_set.puzzles then
      self.keep_music = false
      self.next_scene = "puzzle_menu"
      self.next_scene_params = nil
    else
      self.keep_music = true
      self.next_scene = "puzzle_game"
      self.next_scene_params = {puzzle_set = self.puzzle_set, puzzle_index = self.puzzle_index + 1}
    end
  elseif GAME.match.P1:puzzle_failed() then -- writes failed puzzle replay and returns to menu
    SFX_GameOver_Play = 1
    self.text = loc("pl_you_lose")
    self.keep_music = true
    self.next_scene = "puzzle_game"
    self.next_scene_params = {puzzle_set = self.puzzle_set, puzzle_index = self.puzzle_index}
  end
end

return puzzle_game