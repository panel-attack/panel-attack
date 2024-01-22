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
local tableUtils = require("tableUtils")
local UiElement = require("ui.UIElement")
local GameModes = require("GameModes")
local GFX_SCALE = consts.GFX_SCALE
local StackPanel = require("ui.StackPanel")
local PixelFontLabel = require("ui.PixelFontLabel")

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

function CharacterSelect:createPlayerIcon(player)
  local playerIcon = UiElement({hFill = true, vFill = true})

  local selectedCharacterIcon = ImageContainer({
    hFill = true,
    vFill = true,
    image = characters[player.settings.selectedCharacterId].images.icon,
    drawBorders = true,
    outlineColor = {1, 1, 1, 1}
  })

   -- character image
   selectedCharacterIcon.updateImage = function(image, characterId)
    image:setImage(characters[characterId].images.icon)
  end
  player:subscribe(selectedCharacterIcon, "selectedCharacterId", selectedCharacterIcon.updateImage)

  playerIcon:addChild(selectedCharacterIcon)

  -- level icon
  if player.settings.style == GameModes.Styles.MODERN and player.settings.level then
    local levelIcon = ImageContainer({
      image = themes[config.theme].images.IMG_levels[player.settings.level],
      hAlign = "right",
      vAlign = "bottom",
      x = -2,
      y = -2
    })

    levelIcon.updateImage = function(image, level)
      image:setImage(themes[config.theme].images.IMG_levels[level])
    end
    player:subscribe(levelIcon, "level", levelIcon.updateImage)

    playerIcon:addChild(levelIcon)
  end

  -- player number icon
  local playerIndex = tableUtils.indexOf(GAME.battleRoom.players, player)
  local playerNumberIcon = ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    hAlign = "left",
    vAlign = "bottom",
    x = 2,
    y = -2,
    scale = GFX_SCALE
  })
  playerIcon:addChild(playerNumberIcon)

  -- player name
  local playerName = Label({
    text = player.name,
    translate = false,
    hAlign = "center",
    vAlign = "top"
  })
  playerIcon:addChild(playerName)

  return playerIcon
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
    stageCarousel:setPassengerById(player.settings.selectedStageId)
  end

  stageCarousel:setPassengerById(player.settings.selectedStageId)

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:subscribe(stageCarousel, "selectedStageId", stageCarousel.setPassengerById)

  -- player number icon
  local playerIndex = tableUtils.indexOf(GAME.battleRoom.players, player)
  local playerNumberIcon = ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    hAlign = "center",
    vAlign = "center",
    scale = 2,
  })
  playerNumberIcon.x = - stageCarousel:getSelectedPassenger().image.width / 2 - playerNumberIcon.width

  stageCarousel.playerNumberIcon = playerNumberIcon
  stageCarousel:addChild(stageCarousel.playerNumberIcon)

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

  for i = 0, #characters_ids_for_current_theme do
    local characterButton = Button({
      width = 96,
      height = 96,
    })

    local character
    if i == 0 then
      character = Character.getRandomCharacter()
    else
      character = characters[characters_ids_for_current_theme[i]]
    end

    characterButton.characterId = character.id
    characterButton.image = ImageContainer({image = character.images.icon, hFill = true, vFill = true})
    characterButton:addChild(characterButton.image)
    characterButton.label = Label({text = character.display_name, translate = character.id == consts.RANDOM_CHARACTER_SPECIAL_VALUE, vAlign = "top", hAlign = "center"})
    characterButton:addChild(characterButton.label)

    if character.flag and themes[config.theme].images.flags[character.flag] then
      characterButton.flag = ImageContainer({image = themes[config.theme].images.flags[character.flag], vAlign = "bottom", hAlign = "right", x = -2, y = -2, scale = 0.5})
      characterButton:addChild(characterButton.flag)
    end

    characterButtons[#characterButtons + 1] = characterButton
  end

  -- assign player generic callbacks
  for i = 1, #characterButtons do
    local characterButton = characterButtons[i]
    characterButton.onClick = function(self, inputSource, holdTime)
      local character = characters[self.characterId]
      local player
      if inputSource and inputSource.player then
        player = inputSource.player
      elseif tableUtils.trueForAny(GAME.battleRoom.players, function(p) return p == GAME.localPlayer end) then
         player = GAME.localPlayer
      else
        return
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
      character:playSelectionSfx()
      player:setCharacter(self.characterId)
      player.cursor:updatePosition(9, 2)
    end

    if characters[characterButton.characterId] and characters[characterButton.characterId]:canSuperSelect() then
      self.applySuperSelectInteraction(characterButton)
    else
      characterButton.onSelect = characterButton.onClick
    end
  end

  return characterButtons
end

local function updateSuperSelectShader(image, timer)
  if timer > consts.SUPER_SELECTION_START then
    if image.isVisible == false then
      image:setVisibility(true)
    end
    local progress = (timer - consts.SUPER_SELECTION_START) / consts.SUPER_SELECTION_DURATION
    if progress <= 1 then
      image.shader:send("percent", progress)
    end
  else
    if image.isVisible then
      image:setVisibility(false)
    end
    image.shader:send("percent", 0)
  end
end

function CharacterSelect.applySuperSelectInteraction(characterButton)
  -- creating the super select image + shader
  local superSelectImage = ImageContainer({image = themes[config.theme].images.IMG_super, hFill = true, vFill = true, hAlign = "center", vAlign = "center"})
  superSelectImage.shader = love.graphics.newShader(super_select_pixelcode)
  superSelectImage.drawSelf = function(self)
    set_shader(self.shader)
    love.graphics.draw(self.image, self.x, self.y, 0, self.scale, self.scale)
    set_shader()
  end

  -- add it to the button
  characterButton.superSelectImage = superSelectImage
  characterButton:addChild(characterButton.superSelectImage)
  superSelectImage:setVisibility(false)

  -- set the generic update function
  characterButton.updateSuperSelectShader = updateSuperSelectShader

  -- touch interaction
  -- by implementing onHold we can provide updates to the shader
  characterButton.onHold = function(self, timer)
    self.updateSuperSelectShader(self.superSelectImage, timer)
  end

  -- we need to override the standard onRelease to reset the shader
  characterButton.onRelease = function(self, x, y, timeHeld)
    self.updateSuperSelectShader(self.superSelectImage, 0)
    if self:inBounds(x, y) then
      self:onClick(nil, timeHeld)
    end
  end

  -- keyboard / controller interaction
  -- by applying focusable we can turn it into an "on release" interaction rather than on press by taking control of input interpretation
  Focusable(characterButton)
  characterButton.holdTime = 0
  characterButton.receiveInputs = function(self, inputs, dt, inputSource)
    if inputs.isPressed["Swap1"] then
      -- measure the time the press is held for
      self.holdTime = self.holdTime + dt
    else
      self:yieldFocus()
      -- apply the actual click on release with the held time and reset it afterwards
      self:onClick(inputSource, self.holdTime)
      self.holdTime = 0
    end
    self.updateSuperSelectShader(self.superSelectImage, self.holdTime)
  end
end

function CharacterSelect:createCharacterGrid(characterButtons, grid, width, height)
  local characterGrid = PagedUniGrid({x = 0, y = 0, unitSize = grid.unitSize, gridWidth = width, gridHeight = height, unitMargin = grid.unitMargin})

  for i = 1, #characterButtons do
    characterGrid:addElement(characterButtons[i])
  end

  return characterGrid
end

function CharacterSelect:createPageIndicator(pagedUniGrid)
  local pageCounterLabel = Label({text = loc("page"), hAlign = "center", vAlign = "top", translate = false})
  pageCounterLabel.drawSelf = function(self)
    local text = loc("page") .. " " .. pagedUniGrid.currentPage .. "/" .. #pagedUniGrid.pages
    if self.text ~= text then
      self:setText(text, nil, false)
    end
    GraphicsUtil.drawClearText(self.drawable, self.x, self.y)
  end
  return pageCounterLabel
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

  panelCarousel:setPassengerById(player.settings.panelId)

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:subscribe(panelCarousel, "panelId", panelCarousel.setPassengerById)

  -- player number icon
  local playerIndex = tableUtils.indexOf(GAME.battleRoom.players, player)
  local playerNumberIcon = ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    hAlign = "center",
    vAlign = "center",
    scale = 2,
  })
  playerNumberIcon.x = - panelCarousel:getSelectedPassenger().uiElement.width / 2 - playerNumberIcon.width

  panelCarousel.playerNumberIcon = playerNumberIcon
  panelCarousel:addChild(panelCarousel.playerNumberIcon)

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

  -- player number icon
  local playerIndex = tableUtils.indexOf(GAME.battleRoom.players, player)
  local playerNumberIcon = ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    hAlign = "left",
    vAlign = "center",
    scale = 2
  })
  playerNumberIcon.x = -4 - playerNumberIcon.width

  levelSlider.playerNumberIcon = playerNumberIcon
  levelSlider:addChild(levelSlider.playerNumberIcon)

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

  -- player number icon
  local playerIndex = tableUtils.indexOf(GAME.battleRoom.players, player)
  local playerNumberIcon = ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    hAlign = "left",
    vAlign = "center",
    x = 4,
    scale = 2,
  })
  rankedSelector.playerNumberIcon = playerNumberIcon
  rankedSelector:addChild(rankedSelector.playerNumberIcon)

  return rankedSelector
end

function CharacterSelect:createRecordsBox()
  local stackPanel = StackPanel({alignment = "top", hFill = true, vAlign = "center"})

  local lastLines = UiElement({hFill = true})
  local lastLinesLabel = PixelFontLabel({ text = "last lines", xScale = 0.5, yScale = 1, hAlign = "left", x = 20})
  local lastLinesValue = PixelFontLabel({ text = self.lastScore, xScale = 0.5, yScale = 1, hAlign = "right", x = -20})
  lastLines.height = lastLinesLabel.height + 4
  lastLines.label = lastLinesLabel
  lastLines.value = lastLinesValue
  lastLines:addChild(lastLinesLabel)
  lastLines:addChild(lastLinesValue)
  stackPanel.lastLines = lastLines
  stackPanel:addElement(lastLines)

  local record = UiElement({hFill = true})
  local recordLabel = PixelFontLabel({ text = "record", xScale = 0.5, yScale = 1, hAlign = "left", x = 20})
  local recordValue = PixelFontLabel({ text = self.record, xScale = 0.5, yScale = 1, hAlign = "right", x = -20})
  record.height = recordLabel.height + 4
  record.label = recordLabel
  record.value = recordValue
  record:addChild(recordLabel)
  record:addChild(recordValue)
  stackPanel.record = record
  stackPanel:addElement(record)

  stackPanel.setLastLines = function(stackPanel, value)
    stackPanel.lastLines.value:setText(value)
  end

  stackPanel.setRecord = function(stackPanel, value)
    stackPanel.record.value:setText(value)
  end

  return stackPanel
end

function CharacterSelect:update(dt)
  for _, cursor in ipairs(self.ui.cursors) do
    if cursor.player.isLocal and cursor.player.human then
      cursor:receiveInputs(cursor.player.inputConfiguration, dt)
    end
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
