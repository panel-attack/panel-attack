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

function CharacterSelectLocal2p:loadUserInterface()
  
end

function CharacterSelectLocal2p:customLoad(sceneParams)
  self:setUpOpponentPlayer()
end

function CharacterSelectLocal2p:customUpdate()

end

return CharacterSelectLocal2p