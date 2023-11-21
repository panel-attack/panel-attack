local CharacterSelect = require("scenes.CharacterSelect")
local sceneManager = require("scenes.sceneManager")
local class = require("class")

--@module SelectScreen1LocalPlayer
-- An abstract implementation of the select screen for game modes with only 1 local player
-- It implements the callbacks to update the matchSetup to always update player 1 on interactions
local SelectScreen1LocalPlayer = class(
  function (self, sceneParams)
  end,
  CharacterSelect
)

function SelectScreen1LocalPlayer:assignCallbacks()
    -- stage carousel
    self.ui.stageCarousel.onSelectCallback = function()
      self.matchSetup:setStage(self.ui.stageCarousel:getSelectedPassenger().id)
    end

    self.ui.stageCarousel.onBackCallback = function()
      self.ui.stageCarousel:setPassenger(self.matchSetup.players[1].stage)
    end

    -- panel carousel
    self.ui.panelCarousel.onSelectCallback = function()
      self.matchSetup:setPanels(self.ui.panelCarousel:getSelectedPassenger().id)
    end

    self.ui.panelCarousel.onBackCallback = function()
      self.ui.panelCarousel:setPassenger(self.matchSetup.players[1].panelId)
    end

    -- character grid
    for i = 1, #self.ui.characterGrid.elements do
      local characterButton = self.ui.characterGrid.elements[i]
      characterButton.onClick = function()
        play_optional_sfx(themes[config.theme].sounds.menu_validate)
        self.matchSetup:setCharacter(characterButton.characterId)
        self.ui.cursor:updatePosition(9, 2)
      end
      characterButton.onSelect = characterButton.onClick
    end

    -- level slider
    self.ui.levelSlider.onBackCallback = function ()
      self.ui.levelSlider:setValue(self.matchSetup.players[1].level)
    end

    self.ui.levelSlider.onSelectCallback = function ()
      self.matchSetup:setLevel(self.ui.levelSlider.value)
    end

    self.ui.levelSlider.onValueChange = function()
      self.matchSetup:setLevel(self.ui.levelSlider.value)
    end

    -- cursor
    self.ui.cursor.escapeCallback = function()
      if self.ui.cursor.selectedGridPos.x == 9 and self.ui.cursor.selectedGridPos.y == 6 then
        play_optional_sfx(themes[config.theme].sounds.menu_cancel)
        sceneManager:switchToScene("MainMenu")
      else
        self.ui.cursor:updatePosition(9, 6)
      end
    end

    self.ui.cursor.raise1Callback = function()
      self.ui.characterGrid:turnPage(-1)
    end

    self.ui.cursor.raise2Callback = function()
      self.ui.characterGrid:turnPage(1)
    end

    -- ready button
    self.ui.readyButton.onClick = function ()
      self.matchSetup:setWantsReady(not self.matchSetup.players[1].wantsReady)
    end

    -- character image
    local updateSelectedCharacterImage = function(characterId)
      if characterId == random_character_special_value then
        self.ui.selectedCharacter:setImage(themes[config.theme].images.IMG_random_character)
      else
        self.ui.selectedCharacter:setImage(characters[characterId].images.icon)
      end
    end
    self.matchSetup:subscribe("characterId", 1, updateSelectedCharacterImage)
  end

  return SelectScreen1LocalPlayer