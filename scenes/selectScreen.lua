local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local logger = require("logger")
local Carousel = require("ui.Carousel")
local CarouselPassenger = require("ui.CarouselPassenger")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local directsFocus = require("ui.FocusDirector")
require("tableUtils")

local stageCarousel = Carousel({
  x = 100,
  y = 100,
  width = 84,
  height = 84
})

--local players = {}
local stage = config.stage

local function loadStages()
  for i = 1, #stages_ids_for_current_theme do
    local stage = stages[stages_ids_for_current_theme[i]]
    local passenger = CarouselPassenger(stage.id, stage.images.thumbnail, stage.display_name)
    stageCarousel:addPassenger(passenger)
  end
  -- offer up the random stage for selection
  local randomStage = CarouselPassenger(random_stage_special_value, themes[config.theme].images.IMG_random_stage, loc("random"))
  stageCarousel:addPassenger(randomStage)

  -- set the config stage as initial selection
  stageCarousel:setPassenger(stage)

  -- overwrite the default behaviour: set the stage on selection
  stageCarousel.onSelect = function()
    stage = stageCarousel:getSelectedPassenger().id
    stageCarousel.yieldFocus()
  end
  -- overwrite the default behaviour: move back to the previously selected stage
  stageCarousel.onBack = function()
    stageCarousel:setPassenger(stage)
    stageCarousel.yieldFocus()
  end
end

local selectScreen = Scene("selectScreen")
directsFocus(selectScreen)

function selectScreen:init()
  sceneManager:addScene(self)
end

function selectScreen:load()
  loadStages()
end


function selectScreen:drawBackground()
  themes[config.theme].images.bg_select_screen:draw()
end

function selectScreen:update()
  stageCarousel:draw()

  if self.focused then
    self.focused:receiveInputs()
  else
    if input.isDown["Swap1"] or input.isDown["Start"] then
      play_optional_sfx(themes[config.theme].sounds.menu_enter)
      self:setFocus(stageCarousel)
    elseif input:isPressedWithRepeat("Swap2", 10, 10) then
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
      sceneManager:switchToScene("mainMenu")
    end
  end
end

return selectScreen