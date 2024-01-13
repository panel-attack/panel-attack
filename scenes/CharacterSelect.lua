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
local BoolSelector = require("ui.BoolSelector")

-- @module CharacterSelect
-- The character select screen scene
local CharacterSelect = class(function(self)
  self.backgroundImg = themes[config.theme].images.bg_select_screen
  self:load()
end, Scene)

-- begin abstract functions

-- Initalization specific to the child scene
function CharacterSelect:customLoad()
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

function CharacterSelect:load()
  self.ui = {}
  self.ui.cursors = {}
  self.ui.characterIcons = {}
  self:customLoad()
  -- assign input configs
  -- ideally the local player can use all configs in menus until game start
  -- but should be ok for now
  self:playThemeMusic()
end

function CharacterSelect:createSelectedCharacterIcon(player)
  local icon
  if player.settings.characterId == consts.RANDOM_CHARACTER_SPECIAL_VALUE then
    icon = themes[config.theme].images.IMG_random_character
  else
    icon = characters[player.settings.characterId].images.icon
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
    if characterId == consts.RANDOM_CHARACTER_SPECIAL_VALUE then
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
    if inputSource and inputSource.player then
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
      GAME.battleRoom:shutdown()
      sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
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

local super_select_pixelcode = [[
      uniform float percent;
      vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
      {
          vec4 c = Texel(tex, texture_coords) * color;
          if( texture_coords.x < percent )
          {
            return c;
          }
          float ret = (c.x+c.y+c.z)/3.0;
          return vec4(ret, ret, ret, c.a);
      }
  ]]

function CharacterSelect:getCharacterButtons()
  local characterButtons = {}

  local randomCharacterButton = Button({hFill = true, vFill = true})
  randomCharacterButton.characterId = consts.RANDOM_CHARACTER_SPECIAL_VALUE
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
    characterButton.onClick = function(self, inputSource, holdTime)
      local character = characters[self.characterId]
      if inputSource and inputSource.player then
        player = inputSource.player
      else
         player = GAME.localPlayer
      end
      play_optional_sfx(themes[config.theme].sounds.menu_validate)
      if character:canSuperSelect() and holdTime > consts.SUPER_SELECTION_START + consts.SUPER_SELECTION_DURATION then
        -- super select
        if character.panels and panels[character.panels] then
          player:setPanels(character.panels)
        end
        if character.stage and stages[character.stage] then
          player:setStage(character.stage)
        end
      end
      player:setCharacter(self.characterId)
      player.cursor:updatePosition(9, 2)
    end

    if characters[characterButton.characterId] and characters[characterButton.characterId]:canSuperSelect() then
      local superSelectShader = love.graphics.newShader(super_select_pixelcode)
      -- add super select image as a child
      characterButton.superSelectImage = ImageContainer({image = themes[config.theme].images.IMG_super, hFill = true, vFill = true, hAlign = "center", vAlign = "center"})
      characterButton:addChild(characterButton.superSelectImage)
      characterButton.superSelectImage:setVisibility(false)
      characterButton.superSelectImage.drawSelf = function(self)
        set_shader(superSelectShader)
        love.graphics.draw(self.image, self.x, self.y, 0, self.scale, self.scale)
        set_shader()
      end

      local function updateSuperSelection(button, timer)
        if timer > consts.SUPER_SELECTION_START then
          if button.superSelectImage.isVisible == false then
            button.superSelectImage:setVisibility(true)
          end
          local progress = (timer - consts.SUPER_SELECTION_START) / consts.SUPER_SELECTION_DURATION
          if progress <= 1 then
            superSelectShader:send("percent", progress)
          end
        end
      end

      local function resetSuperSelection(button)
        button.superSelectImage:setVisibility(false)
        superSelectShader:send("percent", 0)
      end

      -- add shader update for touch
      characterButton.onHold = function(self, timer)
        updateSuperSelection(self, timer)
      end

      characterButton.onRelease = function(self, x, y, timeHeld)
        resetSuperSelection(self)
        if self:inBounds(x, y) then
          self:onClick(nil, timeHeld)
        end
      end

      Focusable(characterButton)
      characterButton.holdTime = 0
      characterButton.receiveInputs = function(self, inputs, dt, inputSource)
        if inputs.isPressed["Swap1"] then
          self.holdTime = self.holdTime + dt
          updateSuperSelection(self, self.holdTime)
        else
          resetSuperSelection(self)
          self:yieldFocus()
          self:onClick(inputSource, self.holdTime)
          self.holdTime = 0
        end
      end
    else
      characterButton.onSelect = characterButton.onClick
    end
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
  self.uiRoot:addChild(cursor)

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
    value = player.settings.level,
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

    if inputs.isDown["Swap1"] or inputs.isDown["Start"] then
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

function CharacterSelect:createRankedSelection(player, width)
  
  local rankedSelector = BoolSelector({startValue = player.settings.wantsRanked, vFill = true, width = width, vAlign = "center", hAlign = "center"})
  rankedSelector.onValueChange = function(boolSelector, value)
    player:setWantsRanked(value)
  end

  Focusable(rankedSelector)

  rankedSelector.receiveInputs = function(self, inputs)
    if inputs.isDown["Up"] then
      self:setValue(true)
    elseif inputs.isDown["Down"] then
      self:setValue(false)
    elseif inputs.isDown["Swap2"] then
      self:yieldFocus()
    end
  end

  player:subscribe(rankedSelector, "wantsRanked", rankedSelector.setValue)

  return rankedSelector
end

function CharacterSelect:update(dt)
  for i = 1, #self.ui.cursors do
    self.ui.cursors[i]:receiveInputs(self.ui.cursors[i].player.inputConfiguration, dt)
  end
  if GAME.battleRoom and GAME.battleRoom.spectating then
    if input.isDown["MenuEsc"] then
      GAME.battleRoom:shutdown()
      sceneManager:switchToScene(sceneManager:createScene("Lobby"))
    end
  end
  if self:customUpdate() then
    return
  end
end

function CharacterSelect:draw()
  self.backgroundImg:draw()
  self.uiRoot:draw()
  self:customDraw()
end

function CharacterSelect:leave()
  GAME.battleRoom:shutdown()
  play_optional_sfx(themes[config.theme].sounds.menu_cancel)
  sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
end

return CharacterSelect
