local CharacterSelect = require("scenes.CharacterSelect")

--@module vs_self_menu
local vs_self_menu = CharacterSelect(
  "vs_self_menu", 
  {
    previous_scene = "mainMenu",
    next_scene = "vs_self_game"
  })

local lastLinesLabelQuads = {}
local lastLinesQuads = {}
local recordLabelQuads = {}
local recordQuads = {}

function vs_self_menu:customDraw()
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

return vs_self_menu