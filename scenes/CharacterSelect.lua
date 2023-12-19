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
local TextButton = require("ui.TextButton")
local GridCursor = require("ui.GridCursor")
local Focusable = require("ui.Focusable")
local ImageContainer = require("ui.ImageContainer")
local Label = require("ui.Label")

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
  self.ui = {}
  self.ui.cursors = {}
  self.ui.characterIcons = {}
  self.battleRoom = sceneParams.battleRoom
  self:customLoad(sceneParams)
  -- assign input configs
  -- ideally the local player can use all configs in menus until game start
  -- but should be ok for now
  self:playThemeMusic()
  reset_filters()
end

function CharacterSelect:createSelectedCharacterIcon(player)
  local icon
  if config.character == random_character_special_value then
    icon = themes[config.theme].images.IMG_random_character
  else
    icon = characters[config.character].images.icon
  end

  local selectedCharacterIcon = ImageContainer({
    hFill = true,
    vFill = true,
    image = icon,
    drawBorders = true,
    outlineColor = {1, 1, 1, 1}
  })

   -- character image
   selectedCharacterIcon.updateImage = function(image, characterId)
    if characterId == random_character_special_value then
      image:setImage(themes[config.theme].images.IMG_random_character)
    else
      image:setImage(characters[characterId].images.icon)
    end
  end
  player:subscribe(selectedCharacterIcon, "characterId", selectedCharacterIcon.updateImage)

  return selectedCharacterIcon
end

function CharacterSelect:createReadyButton()
  local readyButton = TextButton({width = 96, height = 96, label = Label({text = "ready"}), backgroundColor = {1, 1, 1, 0}, outlineColor = {1, 1, 1, 1}})

  -- assign player generic callback
  readyButton.onClick = function(self, inputSource)
    local player
    if inputSource.player then
      player = inputSource.player
    else
      player = GAME.localPlayer
    end
    player:setWantsReady(not player.settings.wantsReady)
  end
  readyButton.onSelect = readyButton.onClick

  return readyButton
end

function CharacterSelect:createLeaveButton()
  leaveButton = TextButton({
    width = 96,
    height = 96,
    label = Label({text = "leave"}),
    backgroundColor = {1, 1, 1, 0},
    outlineColor = {1, 1, 1, 1},
    onClick = function()
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
      self.battleRoom = nil
      sceneManager:switchToScene("MainMenu")
    end
  })
  leaveButton.onSelect = leaveButton.onClick

  return leaveButton
end

function CharacterSelect:createStageCarousel(player, width)
  local stageCarousel = StageCarousel({hAlign = "center", vAlign = "center", width = width, vFill = true})
  stageCarousel:loadCurrentStages()

  -- stage carousel
  stageCarousel.onSelectCallback = function()
    player:setStage(stageCarousel:getSelectedPassenger().id)
  end

  stageCarousel.onBackCallback = function()
    stageCarousel:setPassengerById(player.settings.stageId)
  end

  stageCarousel.onPassengerUpdateCallback = function ()
    player:setStage(stageCarousel:getSelectedPassenger().id)
  end

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:subscribe(stageCarousel, "stageId", stageCarousel.setPassengerById)

  return stageCarousel
end

function CharacterSelect:getCharacterButtons()
  local characterButtons = {}

  local randomCharacterButton = Button({hFill = true, vFill = true})
  randomCharacterButton.characterId = random_character_special_value
  randomCharacterButton.image = ImageContainer({image = themes[config.theme].images.IMG_random_character, hFill = true, vFill = true})
  randomCharacterButton:addChild(randomCharacterButton.image)
  randomCharacterButton.label = Label({text = "random", translate = true, vAlign = "bottom", hAlign = "center"})
  randomCharacterButton:addChild(randomCharacterButton.label)

  characterButtons[#characterButtons + 1] = randomCharacterButton

  for i = 1, #characters_ids_for_current_theme do
    local characterButton = Button({
      width = 96,
      height = 96,
    })
    characterButton.image = ImageContainer({image = characters[characters_ids_for_current_theme[i]].images.icon, hFill = true, vFill = true})
    characterButton:addChild(characterButton.image)
    characterButton.label = Label({text = characters[characters_ids_for_current_theme[i]].display_name, translate = false, vAlign = "bottom", hAlign = "center"})
    characterButton:addChild(characterButton.label)
    characterButton.characterId = characters_ids_for_current_theme[i]
    characterButtons[#characterButtons + 1] = characterButton
  end

  -- assign player generic callbacks
  for i = 1, #characterButtons do
    local characterButton = characterButtons[i]
    characterButton.onClick = function(self, inputSource)
      if inputSource and inputSource.player then
        player = inputSource.player
      else
        player = GAME.localPlayer
      end
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      player:setCharacter(self.characterId)
      player.cursor:updatePosition(9, 2)
    end
    characterButton.onSelect = characterButton.onClick
  end

  return characterButtons
end

function CharacterSelect:createCharacterGrid(characterButtons, grid, width, height)
  local characterGrid = PagedUniGrid({x = 0, y = 0, unitSize = grid.unitSize, gridWidth = width, gridHeight = height, unitMargin = grid.unitMargin})

  for i = 1, #characterButtons do
    characterGrid:addElement(characterButtons[i])
  end

  return characterGrid
end

function CharacterSelect:createCursor(grid, player)
  local cursor = GridCursor({
    grid = grid,
    activeArea = {x1 = 1, y1 = 2, x2 = 9, y2 = 5},
    translateSubGrids = true,
    startPosition = {x = 9, y = 2},
    player = player
  })

  player:subscribe(cursor, "wantsReady", cursor.setRapidBlinking)

  cursor.escapeCallback = function()
    if cursor.selectedGridPos.x == 9 and cursor.selectedGridPos.y == 6 then
      self:leave()
    elseif player.settings.wantsReady then
      player:setWantsReady(false)
    else
      cursor:updatePosition(9, 6)
    end
  end

  return cursor
end

function CharacterSelect:createPanelCarousel(player, height)
  local panelCarousel = PanelCarousel({hAlign = "center", vAlign = "center", hFill = true, height = height})
  panelCarousel:loadPanels()

  -- panel carousel
  panelCarousel.onSelectCallback = function()
    player:setPanels(panelCarousel:getSelectedPassenger().id)
  end

  panelCarousel.onBackCallback = function()
    self.ui.panelCarousel:setPassengerById(player.settings.panelId)
  end

  panelCarousel.onPassengerUpdateCallback = function ()
    player:setPanels(panelCarousel:getSelectedPassenger().id)
  end

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:subscribe(panelCarousel, "panelId", panelCarousel.setPassengerById)

  return panelCarousel
end

function CharacterSelect:createLevelSlider(player, imageWidth)
  local levelSlider = LevelSlider({
    tickLength = imageWidth,
    value = config.level or 5,
    onValueChange = function(s)
      play_optional_sfx(themes[config.theme].sounds.menu_move)
    end,
    hAlign = "center",
    vAlign = "center"
  })
  Focusable(levelSlider)
  levelSlider.receiveInputs = function(self, inputs)
    if inputs:isPressedWithRepeat("Left", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      levelSlider:setValue(levelSlider.value - 1)
    end

    if inputs:isPressedWithRepeat("Right", consts.KEY_DELAY, consts.KEY_REPEAT_PERIOD) then
      levelSlider:setValue(levelSlider.value + 1)
    end

    if inputs.isDown["Swap2"] then
      if levelSlider.onBackCallback then
        levelSlider.onBackCallback()
      end
      play_optional_sfx(themes[config.theme].sounds.menu_cancel)
      levelSlider:yieldFocus()
    end

    if inputs.isDown["Swap1"] or inputs.isDown["MenuEnter"] then
      if levelSlider.onSelectCallback then
        levelSlider.onSelectCallback()
      end
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      levelSlider:yieldFocus()
    end
  end

  -- level slider
  levelSlider.onSelectCallback = function ()
    player:setLevel(levelSlider.value)
  end

  levelSlider.onValueChange = function()
    -- using this makes the onBackCallback pointless
    --player:setLevel(levelSlider.value)
  end

  levelSlider.onBackCallback = function ()
    levelSlider:setValue(player.settings.level)
  end

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:subscribe(levelSlider, "level", levelSlider.setValue)

  return levelSlider
end

function CharacterSelect:update()
  for i = 1, #self.ui.cursors do
    self.ui.cursors[i]:receiveInputs(self.ui.cursors[i].player.inputConfiguration)
  end
  if self:customUpdate() then
    return
  end
end

function CharacterSelect:draw()
  self.ui.grid:draw()
  for i = 1, #self.ui.cursors do
    self.ui.cursors[i]:draw()
  end
  self:customDraw()
end

function CharacterSelect:drawBackground()
  self.backgroundImg:draw()
end

function CharacterSelect:drawForeground()

end

function CharacterSelect:unload()
  self.ui.grid:setVisibility(false)
  stop_the_music()
  if self.customUnload then
    self:customUnload()
  end
end

function CharacterSelect:leave()
  self.battleRoom:shutdown()
  play_optional_sfx(themes[config.theme].sounds.menu_cancel)
  sceneManager:switchToScene("MainMenu")
end

return CharacterSelect
