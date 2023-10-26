local CharacterSelect = require("scenes.CharacterSelect")
local sceneManager = require("scenes.sceneManager")
local class = require("class")

--@module CharacterSelectVsSelf
-- The character select screen scene
local CharacterSelectVsSelf = class(
  function (self, sceneParams)
    self.my_player_number = 1
    self:load(sceneParams)
  end,
  CharacterSelect
)

CharacterSelectVsSelf.name = "CharacterSelectVsSelf"
sceneManager:addScene(CharacterSelectVsSelf)

-- Updates the ready state for all players
function CharacterSelectVsSelf:refreshReadyStates()
  self.players[1].ready = self.players[1].wants_ready and self.players[1].loaded
end

function CharacterSelectVsSelf:customLoad(sceneParams)
  self:refreshBasedOnOwnMods(self.players[1])
  self:refreshLoadingState(1)
end

function CharacterSelectVsSelf:customUpdate()
  if self.players[self.my_player_number].ready then
    return self:start1pLocalMatch()
  end
end

local lastLinesLabelQuads = {}
local lastLinesQuads = {}
local recordLabelQuads = {}
local recordQuads = {}

function CharacterSelectVsSelf:customDraw()
  local xPosition1 = 196
  local xPosition2 = 320
  local yPosition = 24
  local lastScore = tostring(GAME.scores:lastVsScoreForLevel(self.level_slider.value))
  local record = tostring(GAME.scores:recordVsScoreForLevel(self.level_slider.value))
  draw_pixel_font("last lines", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition, 0.5, 1.0, nil, nil, lastLinesLabelQuads)
  draw_pixel_font(lastScore,    themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition + 24, 0.5, 1.0, nil, nil, lastLinesQuads)
  draw_pixel_font("record",     themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition, 0.5, 1.0, nil, nil, recordLabelQuads)
  draw_pixel_font(record,       themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition + 24, 0.5, 1.0, nil, nil, recordQuads)
end

return CharacterSelectVsSelf