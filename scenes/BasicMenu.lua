local Scene = require("scenes.Scene")
local Button = require("ui.Button")
local Slider = require("ui.Slider")
local Label = require("ui.Label")
local scene_manager = require("scenes.scene_manager")
local Menu = require("ui.Menu")
local ButtonGroup = require("ui.ButtonGroup")

--@module BasicMenu
local BasicMenu = class(
  function (self, name, options)
    self.name = name
    self.game_mode = options.game_mode
  end,
  Scene
)

local selected_id = 1

local speed_slider = Slider({
    min = 1, 
    max = 99, 
    value = GAME.config.endless_speed or 1, 
    is_visible = false
})

local font = love.graphics.getFont() 
local difficulty_buttons = ButtonGroup(
    {
      Button({text = love.graphics.newText(font, loc("easy")), width = 60, height = 25}),
      Button({text = love.graphics.newText(font, loc("normal")), width = 60, height = 25}),
      Button({text = love.graphics.newText(font, loc("hard")), width = 60, height = 25}),
      -- TODO: localize "EX Mode"
      Button({text = love.graphics.newText(font, "EX Mode")}),
    },
    {1, 2, 3, 4},
    {
      selected_index = GAME.config.endless_difficulty or 1,
      onChange = function() play_optional_sfx(themes[config.theme].sounds.menu_move) end
    }
)

function BasicMenu:startGame()
  if config.endless_speed ~= speed_slider.value or config.endless_difficulty ~= difficulty_buttons.value then
    config.endless_speed = speed_slider.value
    config.endless_difficulty = difficulty_buttons.value
    --gprint("saving settings...", unpack(main_menu_screen_pos))
    --wait()
    write_conf_file()
  end
  stop_the_music()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene(nil)
  
  func = main_endless_time_setup
  arg = {self.game_mode, speed_slider.value, difficulty_buttons.value}
end

local function exitMenu()
  play_optional_sfx(themes[config.theme].sounds.menu_validate)
  scene_manager:switchScene("main_menu")
end

function BasicMenu:init()
  scene_manager:addScene(self)
  
  local menu_options = {
    Label({text = love.graphics.newText(font, loc("speed")), is_visible = false}),
    Label({text = love.graphics.newText(font, loc("difficulty")), is_visible = false}),
    Button({text = love.graphics.newText(font, loc("go_")), onClick = function() self:startGame() end, is_visible = false}),
    Button({text = love.graphics.newText(font, loc("back")), onClick = exitMenu, is_visible = false}),
  }
  
  local x, y = unpack(main_menu_screen_pos)
  y = y + 100
  self.menu = Menu({
      {menu_options[1], speed_slider},
      {menu_options[2], difficulty_buttons},
      {menu_options[3]},
      {menu_options[4]},
      }, {x = x, y = y})
  self.menu:setVisibility(false)
end

function BasicMenu:load()
  GAME.backgroundImage = themes[config.theme].images.bg_main
  reset_filters()
  if themes[config.theme].musics["main"] then
    find_and_add_music(themes[config.theme].musics, "main")
  end

  for i, button in ipairs(difficulty_buttons.buttons) do
    button.width = 60
    button.height = 25
  end
  
  self.menu:setVisibility(true)
end

function BasicMenu:update()  
  local lastScore, record = unpack(self:getScores(difficulty_buttons.value))
  
  local xPosition1 = 520
  local xPosition2 = xPosition1 + 150
  local yPosition = 270

  draw_pixel_font("last score", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition, 0.5, 1.0)
  draw_pixel_font(lastScore, themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition + 24, 0.5, 1.0)
  draw_pixel_font("record", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition, 0.5, 1.0)
  draw_pixel_font(record, themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition + 24, 0.5, 1.0)
  
  self.menu:update()
  self.menu:draw()
end

function BasicMenu:unload()  
  self.menu:setVisibility(false)
end

return BasicMenu