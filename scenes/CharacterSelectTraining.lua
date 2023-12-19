local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local CharacterSelect = require("scenes.CharacterSelect")
local class = require("class")
local GameModes = require("GameModes")

--@module CharacterSelectTraining
-- 
local CharacterSelectTraining = class(
  function (self, sceneParams)
    print(dump(sceneParams))
    self.players = {{}, {}}
    self:load(sceneParams)
  end,
  CharacterSelect
)

CharacterSelectTraining.name = "CharacterSelectTraining"
sceneManager:addScene(CharacterSelectTraining)

return CharacterSelectTraining