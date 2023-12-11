local SelectScreen1LocalPlayer = require("scenes.SelectScreen1LocalPlayer")
local sceneManager = require("scenes.sceneManager")
local class = require("class")
local MatchSetup = require("MatchSetup")
local GameModes = require("GameModes")

--@module CharacterSelectVsSelf
-- The character select screen scene
local CharacterSelectVsSelf = class(
  function (self, sceneParams)
    self:load()
  end,
  SelectScreen1LocalPlayer
)

CharacterSelectVsSelf.name = "VsSelfMenu"
sceneManager:addScene(CharacterSelectVsSelf)

function CharacterSelectVsSelf:customLoad(sceneParams)
  self.matchSetup = MatchSetup(GameModes.ONE_PLAYER_VS_SELF)
  self:designScreen()
  self:assignCallbacks()
end

function CharacterSelectVsSelf:designScreen()
  -- already defined in super class
  -- self.ui.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.ui.selectedCharacter)
  -- self.ui.grid:createElementAt(9, 2, 1, 1, "readySelection", self.ui.readyButton)
  -- self.ui.grid:createElementAt(1, 3, 9, 3, "characterSelection", self.ui.characterGrid, true)
  -- self.ui.grid:createElementAt(9, 6, 1, 1, "leaveSelection", self.ui.leaveButton)
  self.ui.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.ui.panelCarousel)
  --self.ui.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.ui.stageCarousel)
  self:loadLevels(20)
  self.ui.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.ui.levelSlider)
end

function CharacterSelectVsSelf:customUpdate()
end

local lastLinesLabelQuads = {}
local lastLinesQuads = {}
local recordLabelQuads = {}
local recordQuads = {}

function CharacterSelectVsSelf:customDraw()
  local xPosition1 = 196
  local xPosition2 = 320
  local yPosition = 24
  local lastScore = tostring(GAME.scores:lastVsScoreForLevel(self.ui.levelSlider.value))
  local record = tostring(GAME.scores:recordVsScoreForLevel(self.ui.levelSlider.value))
  draw_pixel_font("last lines", themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition, 0.5, 1.0, nil, nil, lastLinesLabelQuads)
  draw_pixel_font(lastScore,    themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition1, yPosition + 24, 0.5, 1.0, nil, nil, lastLinesQuads)
  draw_pixel_font("record",     themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition, 0.5, 1.0, nil, nil, recordLabelQuads)
  draw_pixel_font(record,       themes[config.theme].images.IMG_pixelFont_blue_atlas, xPosition2, yPosition + 24, 0.5, 1.0, nil, nil, recordQuads)
end

return CharacterSelectVsSelf