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
local tableUtils = require("tableUtils")
local utf8 = require("utf8")
local class = require("class")

--@module setNameMenu
-- Scene for setting the username
local SetNameMenu = class(
  function (self, sceneParams)
    self:load(sceneParams)
  end,
  Scene
)

SetNameMenu.name = "SetNameMenu"
sceneManager:addScene(SetNameMenu)

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

local warningText = ""
local backgroundImg = nil -- set in load

function SetNameMenu:load(sceneParams)
  backgroundImg = themes[config.theme].images.bg_main
  nameField:setVisibility(true)
  nameField:setFocus(0, 0)
  nameField.offset = utf8.len(nameField.value)
  self.prevScene = sceneParams.prevScene
end

function SetNameMenu:drawBackground()
  backgroundImg:draw()
end

function SetNameMenu:update(dt)
  backgroundImg:update(dt)
  if not input.allKeys.isDown["return"] and tableUtils.trueForAny(input.allKeys.isDown, function(val) return val end) then
    warningText = ""
  end

  local toPrint = loc("op_enter_name") .. " (" .. nameField.value:len() .. "/" .. NAME_LENGTH_LIMIT .. ")" .. "\n" .. warningText
  gprint(toPrint, unpack(themes[config.theme].main_menu_screen_pos))
  
  if input.allKeys.isDown["return"] then
    if nameField.value == "" then
      warningText = loc("op_username_blank_warning")
    else
      Menu.playValidationSfx()
      config.name = nameField.value
      write_conf_file()
      sceneManager:switchToScene(self.prevScene)
    end
  end
  if input.allKeys.isDown["escape"] then
    Menu.playCancelSfx()
    sceneManager:switchToScene("MainMenu")
  end
  
  nameField:draw()
end

function SetNameMenu:unload()  
  nameField:setVisibility(false)
  nameField:unfocus()
end

return SetNameMenu