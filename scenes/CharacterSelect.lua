local Scene = require("scenes.Scene")
local sceneManager = require("scenes.sceneManager")
local consts = require("consts")
local input = require("inputManager")
local class = require("class")
local Grid = require("ui.Grid")
local StageCarousel = require("ui.StageCarousel")
local LevelSlider = require("ui.LevelSlider")
local PanelCarousel = require("ui.PanelCarousel")
local PagedUniGrid = require("ui.PagedUniGrid")
local Button = require("ui.Button")
local GridCursor = require("ui.GridCursor")
local Focusable = require("ui.Focusable")
local ImageContainer = require("ui.ImageContainer")

-- @module CharacterSelect
-- The character select screen scene
local CharacterSelect = class(function(self, sceneParams)
  self.backgroundImg = themes[config.theme].images.bg_select_screen
end, Scene)

-- begin abstract functions

-- Initalization specific to the child scene
function CharacterSelect:customLoad(sceneParams)
  error("The function customLoad needs to be implemented on the scene")
end

-- updates specific to the child scene
function CharacterSelect:customUpdate(sceneParams)
  -- error("The function customUpdate needs to be implemented on the scene")
end

function CharacterSelect:customDraw()

end

-- end abstract functions

function CharacterSelect:playThemeMusic()
  if themes[config.theme].musics.select_screen then
    stop_the_music()
    find_and_add_music(themes[config.theme].musics, "select_screen")
  elseif themes[config.theme].musics.main then
    find_and_add_music(themes[config.theme].musics, "main")
  end
end

function CharacterSelect:load(sceneParams)
  self:loadUserInterface()
  -- "2p_net_vs", msg
  -- "2p_local_vs"
  -- "2p_local_computer_vs"
  -- "1p_vs_yourself"
  self:customLoad(sceneParams)
  -- we need to refresh the position once so it fetches the current element after all grid elements were loaded in customLoad
  self.ui.cursor:updatePosition(self.ui.cursor.selectedGridPos.x, self.ui.cursor.selectedGridPos.y)
  self:playThemeMusic()
  reset_filters()
end

function CharacterSelect:loadUserInterface()
  self.ui = {}
  self:loadGrid()
  self:loadPanels()
  self:loadStandardButtons()
  self:loadStages()
  self:loadCharacters()

  self.ui.grid:createElementAt(1, 1, 1, 1, "selectedCharacter", self.ui.selectedCharacter)
  self.ui.grid:createElementAt(9, 2, 1, 1, "readyButton", self.ui.readyButton)
  self.ui.grid:createElementAt(1, 3, 9, 3, "characterSelection", self.ui.characterGrid, true)
  self.ui.grid:createElementAt(9, 6, 1, 1, "leaveButton", self.ui.leaveButton)
end

function CharacterSelect:loadStandardButtons()
  local icon
  if config.character == random_character_special_value then
    icon = themes[config.theme].images.IMG_random_character
  else
    icon = characters[config.character].images.icon
  end

  self.ui.selectedCharacter = ImageContainer({
    width = 96,
    height = 96,
    image = icon,
    drawBorders = true,
    outlineColor = {1, 1, 1, 1}
  })

  self.ui.readyButton = Button({width = 96, height = 96, label = "ready", backgroundColor = {1, 1, 1, 0}, outlineColor = {1, 1, 1, 1}})
  self.ui.readyButton.onSelect = function()
    self.ui.readyButton.onClick()
  end

  self.ui.leaveButton = Button({
    width = 96,
    height = 96,
    label = "leave",
    backgroundColor = {1, 1, 1, 0},
    outlineColor = {1, 1, 1, 1},
    onClick = function()
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
      sceneManager:switchToScene("MainMenu")
    end
  })
  self.ui.leaveButton.onSelect = self.ui.leaveButton.onClick
end

function CharacterSelect:loadStages()
  self.ui.stageCarousel = StageCarousel({})
  self.ui.stageCarousel:loadCurrentStages()
end

function CharacterSelect:loadCharacters()
  self.ui.characterGrid = PagedUniGrid({x = 0, y = 0, unitSize = 102, gridWidth = 9, gridHeight = 3, unitPadding = 6})

  local randomCharacterButton = Button({image = themes[config.theme].images.IMG_random_character, width = 96, height = 96})
  randomCharacterButton.characterId = random_character_special_value
  self.ui.characterGrid:addElement(randomCharacterButton)

  for i = 1, #characters_ids_for_current_theme do
    local characterButton = Button({
      image = characters[characters_ids_for_current_theme[i]].images.icon,
      width = 96,
      height = 96,
      valign = "bottom",
      label = characters[characters_ids_for_current_theme[i]].display_name,
      translate = false
    })
    characterButton.characterId = characters_ids_for_current_theme[i]
    self.ui.characterGrid:addElement(characterButton)
  end
end

function CharacterSelect:loadGrid()
  self.ui.grid = Grid({x = 180, y = 60, unitSize = 102, gridWidth = 9, gridHeight = 6, unitPadding = 6})
  self.ui.cursor = GridCursor({
    grid = self.ui.grid,
    activeArea = {x1 = 1, y1 = 2, x2 = 9, y2 = 5},
    translateSubGrids = true,
    startPosition = {x = 9, y = 2},
    playerNumber = 1
  })
  self.ui.cursor.escapeCallback = function()
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    sceneManager:switchToScene("MainMenu")
  end
end

function CharacterSelect:loadPanels()
  self.ui.panelCarousel = PanelCarousel({})
  self.ui.panelCarousel:loadPanels()
end

function CharacterSelect:loadLevels(unitWidth)
  local gridElementWidth = self.ui.grid.unitSize * unitWidth - self.ui.grid.unitPadding * 2
  local tickLength = 20
  self.ui.levelSlider = LevelSlider({
    tickLength = tickLength,
    x = (gridElementWidth - tickLength * #level_to_pop) / 2,
    -- 10 is tickLength / 2, level images are forced into squares
    y = (self.ui.grid.unitSize) / 2 - tickLength / 2 - self.ui.grid.unitPadding,
    value = config.level or 5,
    onValueChange = function(s)
      play_optional_sfx(themes[config.theme].sounds.menu_move)
    end
  })
  Focusable(self.ui.levelSlider)
  self.ui.levelSlider.receiveInputs = function()
    if input:isPressedWithRepeat("MenuLeft", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      self.ui.levelSlider:setValue(self.ui.levelSlider.value - 1)
    end

    if input:isPressedWithRepeat("MenuRight", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      self.ui.levelSlider:setValue(self.ui.levelSlider.value + 1)
    end

    if input.isDown["MenuEsc"] then
      if self.ui.levelSlider.onBackCallback then
        self.ui.levelSlider.onBackCallback()
      end
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
      self.ui.levelSlider:yieldFocus()
    end

    if input.isDown["Swap1"] or input.isDown["MenuEnter"] then
      if self.ui.levelSlider.onSelectCallback then
        self.ui.levelSlider.onSelectCallback()
      end
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      self.ui.levelSlider:yieldFocus()
    end
  end
  self.ui.levelSlider.drawInternal = self.ui.levelSlider.draw
  self.ui.levelSlider.draw = function(self)
    local x, y = self.parent:getScreenPos()
    grectangle("line", x, y, self.width, self.height)
    self:drawInternal()
  end
end

function CharacterSelect:update()
  self.matchSetup:update()
  self.ui.cursor:receiveInputs()
  GAME.gfx_q:push({self.ui.grid.draw, {self.ui.grid}})
  GAME.gfx_q:push({self.ui.cursor.draw, {self.ui.cursor}})
  self:customDraw()
  if self:customUpdate() then
    return
  end
end

function CharacterSelect:drawBackground()
  self.backgroundImg:draw()
end

function CharacterSelect:drawForeground()

end

function CharacterSelect:unload()
  self.ui.grid:setVisibility(false)
  stop_the_music()
end

return CharacterSelect
