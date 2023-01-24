local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local logger = require("logger")
local Carousel = require("ui.Carousel")
local sceneManager = require("scenes.sceneManager")
local input = require("inputManager")
local directsFocus = require("ui.FocusDirector")
local LevelSlider = require("ui.LevelSlider")
local GameModes = require("GameModes")
local MatchSetup = require("MatchSetup")
require("tableUtils")


--local players = {}

local selectScreen = Scene("selectScreen")
directsFocus(selectScreen)

function selectScreen:init()
  sceneManager:addScene(self)
end

-- I kind of dislike how PA silently dies without even crashing if there's an error inside of load
function selectScreen:load(args)
  if args and args.matchSetupNetwork then
    self.matchSetupNetwork = args.matchSetupNetwork
    self.matchSetup = self.matchSetupNetwork.matchSetup
  else
    self.matchSetup = MatchSetup(GameModes.OnePlayerVsSelf, false)
  end
  for i = 1, #self.matchSetup.players do
    self:loadStages(i)
    self.levelSlider = LevelSlider({x = 400, y = 300})
  end
end

function selectScreen:loadStages(owner)
  local stageCarousel = Carousel({
    x = 200,
    y = 100,
    width = 134,
    height = 134
  })
  stageCarousel.owner = owner
  for i = 1, #stages_ids_for_current_theme do
    local stage = stages[stages_ids_for_current_theme[i]]
    local passenger = Carousel.createPassenger(stage.id, stage.images.thumbnail, stage.display_name)
    stageCarousel:addPassenger(passenger)
  end
  -- offer up the random stage for selection
  local randomStage = Carousel.createPassenger(random_stage_special_value, themes[config.theme].images.IMG_random_stage, loc("random"))
  stageCarousel:addPassenger(randomStage)

  -- set the config stage as initial selection
  stageCarousel:setPassenger(self.matchSetup.players[owner].stageId)

  -- overwrite the default behaviour: set the stage on selection
  stageCarousel.onSelect = function()
    self.matchSetup:setStage(owner, stageCarousel:getSelectedPassenger().id)
    stageCarousel.yieldFocus()
  end
  -- overwrite the default behaviour: move back to the previously selected stage
  stageCarousel.onBack = function()
    stageCarousel:setPassenger(self.matchSetup.players[owner].stageId)
    stageCarousel.yieldFocus()
  end

  self.stageCarousel = stageCarousel
end

function selectScreen:drawBackground()
  themes[config.theme].images.bg_select_screen:draw()
end

function selectScreen:update()
  self.stageCarousel:draw()
  self.levelSlider:draw()

  if self.focused then
    self.focused:receiveInputs()
  else
    if input.isDown["Swap1"] or input.isDown["Start"] then
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      self:setFocus(self.stageCarousel)
    elseif input:isPressedWithRepeat("Swap2", 10, 10) then
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
      sceneManager:switchToScene("mainMenu")
    end
  end
end

return selectScreen