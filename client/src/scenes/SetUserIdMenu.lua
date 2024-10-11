local Scene = require("client.src.scenes.Scene")
local InputField = require("client.src.ui.InputField")
local input = require("common.lib.inputManager")
local utf8 = require("common.lib.utf8Additions")
local class = require("common.lib.class")
local GraphicsUtil = require("client.src.graphics.graphics_util")
local TextButton = require("client.src.ui.TextButton")
local Label = require("client.src.ui.Label")

-- @module setNameMenu
-- Scene for setting the username
local SetUserIdMenu = class(function(self, sceneParams)
  self.keepMusic = true
  self:load(sceneParams)
end, Scene)

SetUserIdMenu.name = "SetUserIdMenu"


function SetUserIdMenu:load(sceneParams)
  local menuX, menuY = unpack(themes[config.theme].main_menu_screen_pos)
  self.backgroundImg = themes[config.theme].images.bg_main
  self.serverIp = sceneParams.serverIp

  self.idInputField = InputField({
    x = menuX,
    y = menuY + 30,
    vAlign = "top",
    width = 200,
    height = 25,
    value =  read_user_id_file(self.serverIp)
  })

  self.confirmationButton = TextButton({
    label = Label({text = "go_"}),
    x = menuX,
    y = menuY + 60,
    vAlign = "top",
    onClick = function() self:confirmId() end
  })

  self.warningLabel = Label({
    text = "THIS IS THE EQUIVALENT TO YOUR ACCOUNT AND PASSWORD IN ONE\n" ..
           "DO NOT SHARE WITH ANYONE\n" ..
           "ONLY CHANGE TO SYNC YOUR ID BETWEEN DIFFERENT DEVICES\n" ..
           "ALTERING THIS TO SOMETHING ELSE THAN AN EXISTING ID WILL MAKE IT IMPOSSIBLE TO CONNECT TO 2P VS ONLINE FOR THIS SERVER\n",
    translate = false,
    wrap = true,
    hFill = true,
    hAlign = "center",
    vAlign = "bottom",
    y = -50,
    fontSize = 20,
  })

  self.idInputField:setFocus(0, 0)
  self.idInputField.offset = utf8.len(self.idInputField.value)
  self.uiRoot:addChild(self.idInputField)
  self.uiRoot:addChild(self.confirmationButton)
  self.uiRoot:addChild(self.warningLabel)
end

function SetUserIdMenu:confirmId()
  local hasNonDigits = string.match(self.idInputField.value, "[^%d]")
  if not hasNonDigits and self.idInputField.value:len() > 0 then
    -- not much point in doing validation but let's stay numeric and non-empty at least
    GAME.theme:playValidationSfx()
    write_user_id_file(self.idInputField.value, self.serverIp)
    -- this is dirty but with how stupid nested OptionsMenu is, there is no way to get back right to where we came from
    GAME.navigationStack:pop()
  else
    GAME.theme:playCancelSfx()
  end
end

function SetUserIdMenu:update(dt)
  if input.allKeys.isDown["return"] then
    self:confirmId()
  elseif input.allKeys.isDown["escape"] then
    GAME.navigationStack:pop()
  end
end

function SetUserIdMenu:draw()
  self.backgroundImg:draw()
  local menuX, menuY = unpack(themes[config.theme].main_menu_screen_pos)
  GraphicsUtil.printf("Enter User ID (or paste from clipboard)", menuX, menuY)
  self.uiRoot:draw()
end

return SetUserIdMenu