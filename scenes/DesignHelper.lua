local class = require("class")
local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local Grid = require("ui.Grid")
local GridElement = require("ui.GridElement")
local StageCarousel = require("ui.StageCarousel")
local LevelSlider = require("ui.LevelSlider")
local input = require("inputManager")
local PanelCarousel = require("ui.PanelCarousel")
local PagedUniGrid = require("ui.PagedUniGrid")
local Button = require("ui.Button")
local GridCursor = require("ui.GridCursor")
local Focusable = require("ui.Focusable")
local consts = require("consts")
local GameModes = require("GameModes")
local MatchSetup = require("MatchSetup")

local DesignHelper = class(function(self, sceneParams)
  self:load(sceneParams)
end, Scene)

DesignHelper.name = "DesignHelper"
sceneManager:addScene(DesignHelper)

function DesignHelper:load()
  self.matchSetup = MatchSetup(GameModes.OnePlayerTimeAttack, false)
  self.backgroundImg = themes[config.theme].images.bg_main
  self.grid = Grid({x = 180, y = 60, unitSize = 102, gridWidth = 9, gridHeight = 6, unitPadding = 6})
  -- this is just for demo purposes, current character should always bind to the underlying matchsetup
  self.selectedCharacter = Button({
    width = 96,
    height = 96,
    image = characters[config.character].images.icon,
    backgroundColor = {1, 1, 1, 0},
    outlineColor = {1, 1, 1, 1}
  })
  self.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.selectedCharacter)
  self:loadPanels()
  self.grid:createElementAt(1, 2, 2, 1, "panelSelection", self.panelCarousel)
  self:loadStages()
  self.grid:createElementAt(3, 2, 3, 1, "stageSelection", self.stageCarousel)
  self:loadLevels()
  self.grid:createElementAt(6, 2, 3, 1, "levelSelection", self.levelSlider)
  self.readyButton = Button({
    width = 96,
    height = 96,
    label = "ready",
    backgroundColor = {1, 1, 1, 0},
    outlineColor = {1, 1, 1, 1},
    onClick = function()
      self.matchSetup:startMatch()
    end
  })
  self.readyButton.onSelect = self.readyButton.onClick
  self.grid:createElementAt(9, 2, 1, 1, "readySelection", self.readyButton)
  self:loadCharacters()
  self.grid:createElementAt(1, 3, 9, 3, "characterSelection", self.characterGrid, true)
  -- the character grid has its own padding so override the padding of the enveloping grid
  self.characterGrid.x = 0
  self.characterGrid.y = 0
  self.leaveButton = Button({
    width = 96,
    height = 96,
    label = "leave",
    backgroundColor = {1, 1, 1, 0},
    outlineColor = {1, 1, 1, 1}
  })
  self.grid:createElementAt(9, 6, 1, 1, "leaveSelection", self.leaveButton)
  self.cursor = GridCursor({
    grid = self.grid,
    activeArea = {x1 = 1, y1 = 2, x2 = 9, y2 = 5},
    translateSubGrids = true,
    startPosition = {x = 1, y = 2},
    playerNumber = 1
  })
  self.cursor.escapeCallback = function()
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    sceneManager:switchToScene("MainMenu")
  end
end

function DesignHelper:loadPanels()
  self.panelCarousel = PanelCarousel({})
  self.panelCarousel:loadPanels()
end

function DesignHelper:loadStages()
  self.stageCarousel = StageCarousel({})
  self.stageCarousel:loadCurrentStages()
end

function DesignHelper:loadLevels()
  self.levelSlider = LevelSlider({
    tickLength = 20,
    -- (gridElement width - tickLength * #levels) / 2
    x = 37,
    -- 10 is tickLength / 2, level images are forced into squares
    y = (self.grid.unitSize) / 2 - 10 - self.grid.unitPadding,
    value = config.level or 5,
    onValueChange = function(s)
      play_optional_sfx(themes[config.theme].sounds.menu_move)
    end
  })
  Focusable(self.levelSlider)
  self.levelSlider.receiveInputs = function()
    if input:isPressedWithRepeat("MenuLeft", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      self.levelSlider:setValue(self.levelSlider.value - 1)
    end

    if input:isPressedWithRepeat("MenuRight", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      self.levelSlider:setValue(self.levelSlider.value + 1)
    end

    if input.isDown["MenuEsc"] then
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
      self.levelSlider:yieldFocus()
    end
  end
  self.levelSlider.drawInternal = self.levelSlider.draw
  self.levelSlider.draw = function(self)
    local x, y = self.parent:getScreenPos()
    grectangle("line", x, y, self.width, self.height)
    self:drawInternal()
  end
end

local function goToReady(gridCursor)
  gridCursor:updatePosition(9, 2)
end

function DesignHelper:loadCharacters()
  self.characterGrid = PagedUniGrid({x = 0, y = 0, unitSize = 102, gridWidth = 9, gridHeight = 3, unitPadding = 6})
  for i = 1, #characters_ids_for_current_theme do
    local characterButton = Button({image = characters[characters_ids_for_current_theme[i]].images.icon, width = 96, height = 96})
    characterButton.onClick = function(button)
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      -- don't do it like this
      self.selectedCharacter.image = characterButton.image
      goToReady(self.cursor)
    end
    characterButton.onSelect = characterButton.onClick
    self.characterGrid:addElement(characterButton)
  end
end

function DesignHelper:drawBackground()
  self.backgroundImg:draw()
  GAME.gfx_q:push({self.grid.draw, {self.grid}})
  GAME.gfx_q:push({self.cursor.draw, {self.cursor}})
end

function DesignHelper:update()
  self.cursor:receiveInputs()
end

return DesignHelper
