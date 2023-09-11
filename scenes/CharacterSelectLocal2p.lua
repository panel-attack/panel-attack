local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local CharacterSelect = require("scenes.CharacterSelect")
local class = require("class")

--@module CharacterSelectLocal2p
-- 
local CharacterSelectLocal2p = class(
  function (self, sceneParams)
    self.players = {{}, {}}
    self.independentControls = true
    self:load(sceneParams)
  end,
  CharacterSelect
)

CharacterSelectLocal2p.name = "CharacterSelectLocal2p"
sceneManager:addScene(CharacterSelectLocal2p)

function CharacterSelectLocal2p:start2pLocalMatch()
  local P1 = GAME.match.P1 
  local P2 = GAME.match.P2
  GAME.match = Match("vs", GAME.battleRoom)
  P1 = Stack{which = 1, match = GAME.match, is_local = true, panels_dir = self.players[self.my_player_number].panels_dir, level = self.players[self.my_player_number].level, inputMethod = config.inputMethod, character = self.players[self.my_player_number].character, player_number = 1}
  GAME.match.P1 = P1
  P2 = Stack{which = 2, match = GAME.match, is_local = true, panels_dir = self.players[self.op_player_number].panels_dir, level = self.players[self.op_player_number].level, inputMethod = "controller", character = self.players[self.op_player_number].character, player_number = 2}
  --note: local P2 not currently allowed to use "touch" input method
  GAME.match.P2 = P2
  P1:setOpponent(P2)
  P1:setGarbageTarget(P2)
  P2:setOpponent(P1)
  P2:setGarbageTarget(P1)
  current_stage = self.players[math.random(1, #self.players)].stage
  stage_loader_load(current_stage)
  stage_loader_wait()
  P2:moveForPlayerNumber(2)

  P1:starting_state()
  P2:starting_state()
  return main_dumb_transition, {main_local_vs, "", 0, 0}
end

function CharacterSelectLocal2p:customLoad(sceneParams)
  self:setUpOpponentPlayer()
end

function CharacterSelectLocal2p:customUpdate()
  --local playerNumberWaiting = GAME.input.playerNumberWaitingForInputConfiguration()
  --if playerNumberWaiting then
  --  gprintf(loc("player_press_key", playerNumberWaiting), 0, 30, canvas_width, "center")
  --end
  
  self:refreshLoadingState(self.op_player_number)
  
  if self.players[self.my_player_number].ready and self.players[self.op_player_number].ready then
    return self:start2pLocalMatch()
  end
end

return CharacterSelectLocal2p