local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local logger = require("logger")
local Carousel = require("ui.Carousel")
local CarouselPassenger = require("ui.CarouselPassenger")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
require("table_utils")

local stageCarousel = Carousel({
  x = 100,
  y = 100,
  width = 84,
  height = 84
})

local function loadStages()
  for i = 1, #stages_ids_for_current_theme do
    local stage = stages[stages_ids_for_current_theme[i]]
    local passenger = CarouselPassenger(stage.id, stage.images.thumbnail, stage.display_name)
    stageCarousel:addPassenger(passenger)
  end
  -- offer up the random stage for selection
  stageCarousel:addPassenger(random_stage_special_value, themes[config.theme].images.IMG_random_stage, loc("random"))
end

local selectScreen = Scene("selectScreen")

function selectScreen:init()
  sceneManager:add(self)
end

function selectScreen:load()
  loadStages()
  stageCarousel.hasFocus = true
end

function selectScreen.drawBackground()
  themes[config.theme].images.bg_select_screen:draw()
end

function selectScreen:update()
  stageCarousel:draw()

  if self.focused then
    -- forward input
    if input:isPressedWithRepeat("Left") then
      stageCarousel:moveToNextPassenger(-1)
    elseif input:isPressedWithRepeat("Right") then
      stageCarousel:moveToNextPassenger(1)
    else
      self:setFocus()
    end
  else
    if input:isPressedWithRepeat("Left") then
      stageCarousel:moveToNextPassenger(-1)
    elseif input:isPressedWithRepeat("Right") then
      stageCarousel:moveToNextPassenger(1)
    elseif input:isPressedWithRepeat("Raise1") then
      self:setFocus(stageCarousel)
    elseif input:isPressedWithRepeat("Raise2") then
      self:setFocus(stageCarousel)
    elseif input:isPressedWithRepeat("Swap2") then
      sceneManager:switchScene("main_menu")
    end
  end
end

function selectScreen:setFocus(child)
  self.focused.hasFocus = false
  self.focused = child
  if child then
    child.hasFocus = true
  end
end