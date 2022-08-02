local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local InputField = require("ui.InputField")
local Label = require("ui.Label")
local LevelSlider = require("ui.LevelSlider")
local scene_manager = require("scenes.scene_manager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")
local input = require("inputManager")
local save = require("save")

--@module BasicMenu
local set_name_menu = Scene("set_name_menu")

local menu_x, menu_y = unpack(main_menu_screen_pos)
local name_field = InputField({
    x = menu_x - 25,
    y = menu_y + 50,
    width = 200,
    height = 25,
    placeholder_text = love.graphics.newText(love.graphics.getFont(), "username"),
    value = config.name,
    is_visible = false
})

function set_name_menu:init()
  scene_manager:addScene(self)
end

function set_name_menu:load(sceneParams)
  name_field.is_visible = true
  self.prevScene = sceneParams.prevScene
end

function set_name_menu:update()
  local to_print = loc("op_enter_name") .. " (" .. name_field.value:len() .. "/" .. NAME_LENGTH_LIMIT .. ")"
  gprint(to_print, unpack(main_menu_screen_pos))
  
  if input.allKeys.isDown["return"] then
    play_optional_sfx(themes[config.theme].sounds.menu_validate)
    config.name = name_field.value
    save.write_conf_file()
    scene_manager:switchScene(self.prevScene)
  end
  if input.allKeys.isDown["escape"] then
    play_optional_sfx(themes[config.theme].sounds.menu_cancel)
    scene_manager:switchScene("main_menu")
  end
  
end

function set_name_menu:unload()  
  name_field.is_visible = false
  name_field.has_focus = false
end

return set_name_menu