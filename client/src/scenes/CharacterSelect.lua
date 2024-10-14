local consts = require("common.engine.consts")
local input = require("common.lib.inputManager")
local class = require("common.lib.class")
local tableUtils = require("common.lib.tableUtils")
local GameModes = require("common.engine.GameModes")
local Scene = require("client.src.scenes.Scene")
local StageCarousel = require("client.src.ui.StageCarousel")
local LevelSlider = require("client.src.ui.LevelSlider")
local PanelCarousel = require("client.src.ui.PanelCarousel")
local PagedUniGrid = require("client.src.ui.PagedUniGrid")
local Button = require("client.src.ui.Button")
local TextButton = require("client.src.ui.TextButton")
local GridCursor = require("client.src.ui.GridCursor")
local Focusable = require("client.src.ui.Focusable")
local ImageContainer = require("client.src.ui.ImageContainer")
local Label = require("client.src.ui.Label")
local BoolSelector = require("client.src.ui.BoolSelector")
local UiElement = require("client.src.ui.UIElement")
local StackPanel = require("client.src.ui.StackPanel")
local PixelFontLabel = require("client.src.ui.PixelFontLabel")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local SoundController = require("client.src.music.SoundController")
local Character = require("client.src.mods.Character")
local Slider = require("client.src.ui.Slider")
local Carousel = require("client.src.ui.Carousel")

-- @module CharacterSelect
-- The character select screen scene
local CharacterSelect = class(function(self)
  self.backgroundImg = themes[config.theme].images.bg_select_screen
  self.music = "select_screen"
  self.fallbackMusic = "main"
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

function CharacterSelect:load()
  self.ui = {}
  self.ui.cursors = {}
  self.ui.characterIcons = {}
  self.ui.playerInfos = {}
  self:customLoad()
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
  player:connectSignal("selectedCharacterIdChanged", selectedCharacterIcon, selectedCharacterIcon.updateImage)

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
    player:connectSignal("levelChanged", levelIcon, levelIcon.updateImage)

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
    scale = 3
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

  -- load icon
  local loadIcon = ImageContainer({
    image = themes[config.theme].images.IMG_loading,
    hAlign = "center",
    vAlign = "center",
    hFill = true,
    vFill = true,
    isVisible = not player.hasLoaded
  })
  playerIcon:addChild(loadIcon)

  -- ready icon
  local readyIcon = ImageContainer({
    image = themes[config.theme].images.IMG_ready,
    hAlign = "center",
    vAlign = "center",
    hFill = true,
    vFill = true,
    isVisible = player.settings.wantsReady and player.hasLoaded
  })
  playerIcon:addChild(readyIcon)

  loadIcon.update = function(self, loaded)
    self:setVisibility(not loaded)
    readyIcon:setVisibility(loaded and player.settings.wantsReady)
  end
  player:connectSignal("hasLoadedChanged", loadIcon, loadIcon.update)
  readyIcon.update = function(self, wantsReady)
    self:setVisibility(wantsReady and player.hasLoaded)
  end
  player:connectSignal("wantsReadyChanged", readyIcon, readyIcon.update)

  return playerIcon
end

function CharacterSelect:createReadyButton()
  local readyButton = TextButton({
    hFill = true,
    vFill = true,
    label = Label({text = "ready"}),
    backgroundColor = {1, 1, 1, 0},
    outlineColor = {1, 1, 1, 1}
  })

  -- assign player generic callback
  readyButton.onClick = function(self, inputSource, holdTime)
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
    hFill = true,
    vFill = true,
    label = Label({text = "leave"}),
    backgroundColor = {1, 1, 1, 0},
    outlineColor = {1, 1, 1, 1},
    onClick = function()
        GAME.theme:playCancelSfx()
        self:leave()
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
  player:connectSignal("selectedStageIdChanged", stageCarousel, stageCarousel.setPassengerById)

  -- player number icon
  local playerIndex = tableUtils.indexOf(GAME.battleRoom.players, player)
  local playerNumberIcon = ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    scale = 2,
  })

  if #GAME.battleRoom.players > 1 then
    playerNumberIcon.hAlign = "center"
    playerNumberIcon.vAlign = "top"
    playerNumberIcon.y = 2
  else
    playerNumberIcon.hAlign = "left"
    playerNumberIcon.vAlign = "center"
    playerNumberIcon.x = (width - stageCarousel:getSelectedPassenger().image.width) / 2 - playerNumberIcon.width - 4
  end

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
      hFill = true,
      vFill = true,
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
    characterButton.label = Label({text = character.display_name, translate = character.id == consts.RANDOM_CHARACTER_SPECIAL_VALUE, vAlign = "top", hAlign = "center", wrap = true})
    characterButton:addChild(characterButton.label)

    if character.flag and themes[config.theme].images.flags[character.flag] then
      characterButton.flag = ImageContainer({image = themes[config.theme].images.flags[character.flag], vAlign = "bottom", hAlign = "right", x = -2, y = -2, width = 16, height = 16})
      characterButton:addChild(characterButton.flag)
    end

    if character.stage and stages[character.stage] then
      -- draw the stage icon in the center
      characterButton.stageIcon = ImageContainer({image = stages[character.stage].images.thumbnail, vAlign = "bottom", hAlign = "center", y = -2, width = 32, height = 16})
      characterButton:addChild(characterButton.stageIcon)
    end

    if character.panels and panels[character.panels] then
      -- draw the color 1 normal panel in the left corner
      -- it's only available on the sheet so we got to render it to its own canvas first
      local panels = panels[character.panels]
      local canvas = love.graphics.newCanvas(panels.size, panels.size)
      canvas:renderTo(function()
        panels:drawPanelFrame(1, "normal", 0, 0, panels.size)
      end)

      characterButton.panelIcon = ImageContainer({image = canvas, vAlign = "bottom", hAlign = "left", x = 2, y = -2, width = 16, height = 16})
      characterButton:addChild(characterButton.panelIcon)
    end

    characterButtons[#characterButtons + 1] = characterButton
  end

  -- assign player generic callbacks
  for i = 1, #characterButtons do
    local characterButton = characterButtons[i]
    characterButton.onClick = function(selfElement, inputSource, holdTime)
      local character = characters[selfElement.characterId]
      local player
      if inputSource and inputSource.player then
        player = inputSource.player
      elseif tableUtils.trueForAny(GAME.battleRoom.players, function(p) return p == GAME.localPlayer end) then
         player = GAME.localPlayer
      else
        return
      end
      GAME.theme:playValidationSfx()
      if character then
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
      end
      player:setCharacter(selfElement.characterId)
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
    GraphicsUtil.setShader(self.shader)
    GraphicsUtil.draw(self.image, self.x, self.y, 0, self.scale, self.scale)
    GraphicsUtil.setShader()
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
      self:onClick(input.mouse, timeHeld)
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
  local pageCounterLabel = Label({
    text = loc("page") .. " " .. pagedUniGrid.currentPage .. "/" .. #pagedUniGrid.pages,
    hAlign = "center",
    vAlign = "top",
    translate = false
  })
  pageCounterLabel.updatePage = function(self, grid, page)
    self:setText(loc("page") .. " " .. page .. "/" .. #grid.pages)
  end
  pagedUniGrid:connectSignal("pageTurned", pageCounterLabel, pageCounterLabel.updatePage)
  return pageCounterLabel
end

function CharacterSelect:createPageTurnButtons(pagedUniGrid)
  local x, y = pagedUniGrid:getScreenPos()
  pagedUniGrid.pageTurnButtons.left.x = x - pagedUniGrid.unitSize
  pagedUniGrid.pageTurnButtons.right.x = x + pagedUniGrid.width + pagedUniGrid.unitSize / 2
  pagedUniGrid.pageTurnButtons.left.y = y + pagedUniGrid.height / 2 - pagedUniGrid.unitSize / 4
  pagedUniGrid.pageTurnButtons.right.y = y + pagedUniGrid.height / 2 - pagedUniGrid.unitSize / 4

  self.uiRoot:addChild(pagedUniGrid.pageTurnButtons.left)
  self.uiRoot:addChild(pagedUniGrid.pageTurnButtons.right)
  return pagedUniGrid.pageTurnButtons
end

function CharacterSelect:createCursor(grid, player)
  local cursor = GridCursor({
    grid = grid,
    activeArea = {x1 = 1, y1 = 2, x2 = 9, y2 = 5},
    translateSubGrids = true,
    startPosition = {x = 9, y = 2},
    player = player,
    -- this needs to be index, not playerNumber, as playerNumber is a server prop
    frameImages = themes[config.theme].images.IMG_char_sel_cursors[tableUtils.indexOf(GAME.battleRoom.players, player)],
  })

  player:connectSignal("wantsReadyChanged", cursor, cursor.setRapidBlinking)

  cursor.escapeCallback = function()
    GAME.theme:playCancelSfx()
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
  local panelCarousel = PanelCarousel({hAlign = "center", vAlign = "top", hFill = true, height = height})
  panelCarousel:setColorCount(player.settings.levelData.colors)
  panelCarousel:loadPanels()

  -- panel carousel
  panelCarousel.onSelectCallback = function()
    player:setPanels(panelCarousel:getSelectedPassenger().id)
  end

  panelCarousel.onBackCallback = function()
    panelCarousel:setPassengerById(player.settings.panelId)
  end

  panelCarousel.onPassengerUpdateCallback = function(carousel, selectedPassenger)
    player:setPanels(selectedPassenger.id)
  end

  panelCarousel:setPassengerById(player.settings.panelId)

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:connectSignal("selectedStageIdChanged", panelCarousel, panelCarousel.setPassengerById)
  player:connectSignal("colorCountChanged", panelCarousel, panelCarousel.setColorCount)

  -- player number icon
  local playerIndex = tableUtils.indexOf(GAME.battleRoom.players, player)
  local playerNumberIcon = ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    hAlign = "left",
    vAlign = "center",
    scale = 2,
    x = 2
  })

  panelCarousel.playerNumberIcon = playerNumberIcon
  panelCarousel:addChild(panelCarousel.playerNumberIcon)

  return panelCarousel
end

function CharacterSelect:createLevelSlider(player, imageWidth, height)
  local levelSlider = LevelSlider({
    tickLength = imageWidth,
    value = player.settings.level,
    onValueChange = function(s)
      GAME.theme:playMoveSfx()
    end,
    hAlign = "center",
    vAlign = "center",
  })

  Focusable(levelSlider)
  levelSlider.receiveInputs = function(self, inputs)
    if inputs:isPressedWithRepeat("Left") then
      self:setValue(self.value - 1)
    end

    if inputs:isPressedWithRepeat("Right") then
      self:setValue(self.value + 1)
    end

    if inputs.isDown["Swap2"] then
      if self.onBackCallback then
        self:onBackCallback()
      end
      GAME.theme:playCancelSfx()
      self:yieldFocus()
    end

    if inputs.isDown["Swap1"] or inputs.isDown["Start"] then
      if self.onSelectCallback then
        self:onSelectCallback()
      end
      GAME.theme:playValidationSfx()
      self:yieldFocus()
    end
  end

  -- level slider
  levelSlider.onSelectCallback = function(self)
    player:setLevel(self.value)
  end

  levelSlider.setValueFromPos = function(self, x)
    local screenX, screenY = self:getScreenPos()
    self:setValue(math.floor((x - screenX) / self.tickLength) + self.min)
    player:setLevel(self.value)
  end

  levelSlider.onBackCallback = function(self)
    self:setValue(player.settings.level)
  end

  -- wrap in an extra element so we can offset properly as levelslider is fixed height + width
  local uiElement = UiElement({height = height, hFill = true})
  Focusable(uiElement)
  uiElement.levelSlider = levelSlider
  uiElement.levelSlider.yieldFocus = function()
    uiElement:yieldFocus()
  end
  uiElement:addChild(levelSlider)
  uiElement.receiveInputs = function(self, inputs)
    self.levelSlider:receiveInputs(inputs)
  end

  -- to update the UI if code gets changed from the backend (e.g. network messages)
  player:connectSignal("levelChanged", levelSlider, levelSlider.setValue)

  -- player number icon
  local playerIndex = tableUtils.indexOf(GAME.battleRoom.players, player)
  local playerNumberIcon = ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    hAlign = "left",
    vAlign = "center",
    scale = 2,
    x = 2
  })

  uiElement.playerNumberIcon = playerNumberIcon
  uiElement:addChild(uiElement.playerNumberIcon)

  return uiElement
end

function CharacterSelect:createRankedSelection(player, width)
  local rankedSelector = BoolSelector({startValue = player.settings.wantsRanked, vFill = true, width = width, vAlign = "center", hAlign = "center"})
  rankedSelector.onValueChange = function(boolSelector, value)
    GAME.theme:playValidationSfx()
    player:setWantsRanked(value)
  end

  Focusable(rankedSelector)

  rankedSelector.receiveInputs = function(self, inputs)
    if inputs.isDown["Up"] then
      self:setValue(true)
    elseif inputs.isDown["Down"] then
      self:setValue(false)
    elseif inputs.isDown["Swap1"] then
      GAME.theme:playValidationSfx()
      self:yieldFocus()
    elseif inputs.isDown["Swap2"] then
      GAME.theme:playCancelSfx()
      self:yieldFocus()
    end
  end

  player:connectSignal("wantsRankedChanged", rankedSelector, rankedSelector.setValue)

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

function CharacterSelect:createStyleSelection(player, width)
  local styleSelector = BoolSelector({
    startValue = (player.settings.style == GameModes.Styles.MODERN),
    vFill = true,
    width = width,
    vAlign = "center",
    hAlign = "center",
  })

  -- onValueChange should get implemented by the caller
  -- as likely the UI needs to be altered to accomodate the style choice

  Focusable(styleSelector)

  styleSelector.receiveInputs = function(self, inputs)
    if inputs.isDown["Up"] then
      self:setValue(true)
    elseif inputs.isDown["Down"] then
      self:setValue(false)
    elseif inputs.isDown["Swap1"] then
      GAME.theme:playValidationSfx()
      self:yieldFocus()
    elseif inputs.isDown["Swap2"] then
      GAME.theme:playCancelSfx()
      self:yieldFocus()
    end
  end

  player:connectSignal("styleChanged", styleSelector, function(p, style)
      if style == GameModes.Styles.MODERN then
        styleSelector:setValue(true)
      else
        styleSelector:setValue(false)
      end
    end
  )

  -- player number icon
  local playerIndex = tableUtils.indexOf(GAME.battleRoom.players, player)
  local playerNumberIcon = ImageContainer({
    image = themes[config.theme].images.IMG_players[playerIndex],
    hAlign = "left",
    vAlign = "center",
    x = 4,
    scale = 2,
  })
  styleSelector.playerNumberIcon = playerNumberIcon
  styleSelector:addChild(styleSelector.playerNumberIcon)

  return styleSelector
end

function CharacterSelect:createRecordsBox(lastText)
  local stackPanel = StackPanel({alignment = "top", hFill = true, vAlign = "center"})

  local lastLines = UiElement({hFill = true})
  local lastLinesLabel = PixelFontLabel({ text = lastText, xScale = 0.5, yScale = 1, hAlign = "left", x = 10})
  local lastLinesValue = PixelFontLabel({ text = self.lastScore, xScale = 0.5, yScale = 1, hAlign = "right", x = -10})
  lastLines.height = lastLinesLabel.height + 4
  lastLines.label = lastLinesLabel
  lastLines.value = lastLinesValue
  lastLines:addChild(lastLinesLabel)
  lastLines:addChild(lastLinesValue)
  stackPanel.lastLines = lastLines
  stackPanel:addElement(lastLines)

  local record = UiElement({hFill = true})
  local recordLabel = PixelFontLabel({ text = "record", xScale = 0.5, yScale = 1, hAlign = "left", x = 10})
  local recordValue = PixelFontLabel({ text = self.record, xScale = 0.5, yScale = 1, hAlign = "right", x = -10})
  record.height = recordLabel.height + 4
  record.label = recordLabel
  record.value = recordValue
  record:addChild(recordLabel)
  record:addChild(recordValue)
  stackPanel.record = record
  stackPanel:addElement(record)

  stackPanel.setLastResult = function(stackPanel, value)
    stackPanel.lastLines.value:setText(value)
  end

  stackPanel.setRecord = function(stackPanel, value)
    stackPanel.record.value:setText(value)
  end

  return stackPanel
end

function CharacterSelect:createPlayerInfo(player)
  local stackPanel = StackPanel({alignment = "top", hFill = true, vAlign = "top"})

  stackPanel.leagueLabel = Label({
    x = 4,
    text = loc("ss_rating") .. " " .. ((player.league) or "none"),
    translate = false
  })
  stackPanel.leagueLabel.update = function(self, league)
    self:setText(loc("ss_rating") .. " " .. (league or "none"))
  end

  stackPanel.ratingLabel = Label({
    x = 4,
    text = player.rating or "",
    translate = false
  })
  stackPanel.ratingLabel.update = function(self, rating, ratingDiff)
    if ratingDiff > 0 then
      self:setText(tostring(rating) .. " (+" .. ratingDiff .. ")", nil, false)
    elseif ratingDiff < 0 then
      self:setText(tostring(rating) .. " (" .. ratingDiff .. ")", nil, false)
    else
      self:setText(tostring(rating), nil, false)
    end
  end

  stackPanel.winsLabel = Label({
    x = 4,
    text = loc("ss_wins") .. " " .. player:getWinCountForDisplay(),
    translate = false
  })
  stackPanel.winsLabel.update = function(self, winCount)
    self:setText(loc("ss_wins") .. " " .. winCount, nil, false)
  end

  stackPanel.winrateLabel = Label({
    x = 4,
    text = "ss_winrate"
  })

  stackPanel.winrateValueLabel = Label({
    x = 4,
    text = "  " .. loc("ss_current_rating") .. " " .. tostring(player.winrate) .. "%",
    translate = false
  })
  stackPanel.winrateValueLabel.update = function(self, winrate)
    self:setText("  " .. loc("ss_current_rating") .. tostring(winrate) .. "%", nil, false)
  end

  stackPanel.winrateExpectedLabel = Label({
    x = 4,
    text = ""
  })
  if GAME.battleRoom.ranked then
    stackPanel.winrateExpectedLabel:setText(loc("ss_expected_rating") .. " " .. player.expectedWinrate .. "%")
  end
  stackPanel.winrateExpectedLabel.update = function(self, expectedWinrate)
    self:setText("  " .. loc("ss_expected_rating") .. tostring(expectedWinrate) .. "%", nil, false)
  end

  player:connectSignal("leagueChanged", stackPanel.leagueLabel, stackPanel.leagueLabel.update)
  player:connectSignal("ratingChanged", stackPanel.ratingLabel, stackPanel.ratingLabel.update)
  player:connectSignal("winsChanged", stackPanel.winsLabel, stackPanel.winsLabel.update)
  player:connectSignal("winrateChanged", stackPanel.winrateValueLabel, stackPanel.winrateValueLabel.update)
  player:connectSignal("expectedWinrateChanged", stackPanel.winrateExpectedLabel, stackPanel.winrateExpectedLabel.update)

  stackPanel:addElement(stackPanel.leagueLabel)
  stackPanel:addElement(stackPanel.ratingLabel)
  stackPanel:addElement(stackPanel.winsLabel)
  stackPanel:addElement(stackPanel.winrateLabel)
  stackPanel:addElement(stackPanel.winrateValueLabel)

  return stackPanel
end

function CharacterSelect:createRankedStatusPanel()
  local rankedStatus = StackPanel({
    alignment = "top",
    hAlign = "center",
    vAlign = "top",
    y = 40,
    width = 300
  })
  rankedStatus.rankedLabel = Label({
    text = "",
    hAlign = "center",
    vAlign = "top"
  })
  if GAME.battleRoom.ranked then
    rankedStatus.rankedLabel:setText("ss_ranked")
  else
    rankedStatus.rankedLabel:setText("ss_casual")
  end
  rankedStatus.commentLabel = Label({
    text = GAME.battleRoom.rankedComments or "",
    hAlign = "center",
    vAlign = "top",
    translate = false
  })
  rankedStatus:addElement(rankedStatus.rankedLabel)
  rankedStatus:addElement(rankedStatus.commentLabel)

  rankedStatus.update = function(self, ranked, comments)
    if ranked then
      rankedStatus.rankedLabel:setText("ss_ranked")
    else
      rankedStatus.rankedLabel:setText("ss_casual")
    end
    rankedStatus.commentLabel:setText(comments, nil, false)
  end

  GAME.battleRoom:connectSignal("rankedStatusChanged", rankedStatus, rankedStatus.update)

  return rankedStatus
end

function CharacterSelect:createSpeedSlider(player, height, min)
  local speedSlider = Slider({
    min = min or 1,
    max = 99,
    value = player.settings.speed,
    onValueChange = function(slider)
      player:setSpeed(slider.value)
    end,
    hAlign = "center",
    vAlign = "center",
  })
  Focusable(speedSlider)

  player:connectSignal("startingSpeedChanged", speedSlider, speedSlider.setValue)

  -- wrap in an extra element so we can offset properly as speedSlider is fixed height + width
  local uiElement = UiElement({height = height, hFill = true})
  Focusable(uiElement)
  uiElement.speedSlider = speedSlider
  uiElement.speedSlider.yieldFocus = function()
    uiElement:yieldFocus()
  end
  uiElement:addChild(speedSlider)
  uiElement.receiveInputs = function(self, inputs)
    self.speedSlider:receiveInputs(inputs)
  end

  return uiElement
end

function CharacterSelect:createDifficultyCarousel(player, height)
  local passengers = {
    { id = 1, uiElement = Label({text = "easy", vAlign = "center", hAlign = "center"})},
    { id = 2, uiElement = Label({text = "normal", vAlign = "center", hAlign = "center"})},
    { id = 3, uiElement = Label({text = "hard", vAlign = "center", hAlign = "center"})},
    { id = 4, uiElement = Label({text = "ss_ex_mode", vAlign = "center", hAlign = "center"})},
  }
  local difficultyCarousel = Carousel({
    hAlign = "center",
    vAlign = "top",
    hFill = true,
    height = height,
    passengers = passengers,
    selectedId = player.settings.difficulty
  })

  difficultyCarousel.onPassengerUpdateCallback = function(carousel, selectedPassenger)
    player:setDifficulty(selectedPassenger.id)
    self:refresh()
  end

  return difficultyCarousel
end

function CharacterSelect:update(dt)
  for _, cursor in ipairs(self.ui.cursors) do
    if cursor.player.isLocal and cursor.player.human then
      if not cursor.player.inputConfiguration then
        cursor:receiveInputs(input, dt)
      elseif cursor.player.settings.inputMethod == "controller" then
        cursor:receiveInputs(cursor.player.inputConfiguration, dt)
      end
    end
  end
  if GAME.battleRoom and GAME.battleRoom.spectating then
    if input.isDown["MenuEsc"] then
      GAME.theme:playCancelSfx()
      GAME.netClient:leaveRoom()
      GAME.battleRoom.online = false
      GAME.navigationStack:pop(nil, function() GAME.battleRoom:shutdown() end)
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
  GAME.navigationStack:pop(nil,
    function()
      if GAME.battleRoom then
        GAME.battleRoom:shutdown()
      end
    end)
end

return CharacterSelect
