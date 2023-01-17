local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local InputField = require("ui.InputField")
local Label = require("ui.Label")
local LevelSlider = require("ui.LevelSlider")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local input = require("inputManager")
local save = require("save")

--@module setNameMenu
local setNameMenu = Scene("setNameMenu")

local menuX, menuY = unpack(themes[config.theme].main_menu_screen_pos)
local nameField = InputField({
    x = menuX - 25,
    y = menuY + 50,
    width = 200,
    height = 25,
    placeholder = "username",
    value = config.name,
    isVisible = false
})

function setNameMenu:init()
  sceneManager:addScene(self)
end

function setNameMenu:load(sceneParams)
  nameField:setVisibility(true)
  nameField:setFocus(0, 0)
  self.prevScene = sceneParams.prevScene
end

function setNameMenu:drawBackground()
  themes[config.theme].images.bg_main:draw()
end

function setNameMenu:update()
  local toPrint = loc("op_enter_name") .. " (" .. nameField.value:len() .. "/" .. NAME_LENGTH_LIMIT .. ")"
  gprint(toPrint, unpack(themes[config.theme].main_menu_screen_pos))
  
  if input.allKeys.isDown["return"] then
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    config.name = nameField.value
    save.write_conf_file()
    sceneManager:switchToScene(self.prevScene)
  end
  if input.allKeys.isDown["escape"] then
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    sceneManager:switchToScene("mainMenu")
  end
  
  nameField:draw()
end

function setNameMenu:unload()  
  nameField:setVisibility(false)
  nameField:unfocus()
end

return setNameMenu