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