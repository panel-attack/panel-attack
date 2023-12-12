local Scene = require("scenes.Scene")
local InputField = require("ui.InputField")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local input = require("inputManager")
local save = require("save")
local utf8 = require("utf8")
local class = require("class")

-- @module setNameMenu
-- Scene for setting the username
local SetUserIdMenu = class(function(self, sceneParams)
  self:load(sceneParams)
end, Scene)

SetUserIdMenu.name = "SetUserIdMenu"
sceneManager:addScene(SetUserIdMenu)

local menuX, menuY = unpack(themes[config.theme].main_menu_screen_pos)

function SetUserIdMenu:load(sceneParams)
  backgroundImg = themes[config.theme].images.bg_main
  self.serverIp = sceneParams.serverIp

  self.idInputField = InputField({
    x = menuX,
    y = menuY + 50,
    width = 200,
    height = 25,
    value =  read_user_id_file(self.serverIp),
    isVisible = false
  })

  self.idInputField:setVisibility(true)
  self.idInputField:setFocus(0, 0)
  self.idInputField.offset = utf8.len(self.idInputField.value)
end

function SetUserIdMenu:update(dt)
  if input.allKeys.isDown["return"] then
    local hasNonDigits = string.match(self.idInputField.value, "[^%d]")
    if not hasNonDigits and self.idInputField.value:len() > 0 then
      -- not much point in doing validation but let's stay numeric and non-empty at least
      Menu.playValidationSfx()
      write_user_id_file(self.idInputField.value, self.serverIp)
      -- this is dirty but with how stupid nested OptionsMenu is, there is no way to get back right to where we came from
      sceneManager:switchToScene("MainMenu")
    else
      Menu.playCancelSfx()
    end
  elseif input.allKeys.isDown["escape"] then
    sceneManager:switchToScene("MainMenu")
  elseif input.allKeys.isDown["a"] then
    local phi = 5
  end

  GAME.gfx_q:push({self.draw, {self}})
end

function SetUserIdMenu:drawBackground()
  backgroundImg:draw()
end

function SetUserIdMenu:draw()
  gprintf("Enter User ID (or paste from clipboard)", menuX, menuY)
  self.idInputField:draw()
end
