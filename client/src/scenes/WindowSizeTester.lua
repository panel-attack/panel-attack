local Scene = require("client.src.scenes.Scene")
local class = require("common.lib.class")
local Grid = require("client.src.ui.Grid")
local Label = require("client.src.ui.Label")
local ValueLabel = require("client.src.ui.ValueLabel")
local Slider = require("client.src.ui.Slider")
local ButtonGroup = require("client.src.ui.ButtonGroup")
local TextButton = require("client.src.ui.TextButton")
local tableUtils = require("common.lib.tableUtils")

local WindowSizeTester = class(function(self, params)
  self:load()
end,
Scene)

WindowSizeTester.name = "WindowSizeTester"

function WindowSizeTester:load()
  self.originalResize = love.resize
  love.resize = function(newWidth, newHeight)
    self.originalResize(newWidth, newHeight)
    self:onResize()
  end


  -- x, y
  -- width, height
  -- borderless
  -- maximized
  -- resizable
  -- fullscreen
  -- fullscreentype
  -- displayindex
  -- desktop dimensions
  local grid = Grid({
    unitSize = 40,
    gridWidth = 22,
    gridHeight = 10,
    hAlign = "center",
    vAlign = "center",
  })

  local dWidth, dHeight = love.window.getDesktopDimensions(config.display)
  local width, height, flags = love.window.getMode()
  local x, y, displayIndex = love.window.getPosition()
  local desktopSizeLabel = Label({text = "Desktop size: " .. dWidth .. "x" .. dHeight})
  local maximizedLabel = ValueLabel({valueFunction = function() return "Maximized: " .. tostring(love.window.isMaximized()) end})
  self.uiRoot.fullscreenSelection = ButtonGroup({
    buttons = {
      TextButton({width = 60, label = Label({text = "op_off"})}),
      TextButton({width = 60, label = Label({text = "op_on"})})
    },
    values = {false, true},
    selectedIndex = flags.fullscreen and 2 or 1,
    onChange = function(group, value)
      GAME.theme:playMoveSfx()
      love.window.setFullscreen(value)
    end
  })

  self.uiRoot.widthSlider = Slider({
    min = dWidth - 200,
    max = dWidth + 200,
    value = width,
    tickLength = 2,
    onValueChange = function(slider)
      local _, height, flags = love.window.getMode()
      if not flags.fullscreen then
        love.window.restore()
        love.window.updateMode(slider.value, height)
        self:onResize()
      else
        -- in case the updateMode is made invalid by fullscreen/maximize, set the values back
        slider.value = width
        slider.valueText:set(slider.value)
      end
    end
  })
  self.uiRoot.heightSlider = Slider({
    min = dHeight - 200,
    max = dHeight + 200,
    value = height,
    tickLength = 2,
    onValueChange = function(slider)
      local width, height, flags = love.window.getMode()
      if not flags.fullscreen then
        love.window.restore()
        love.window.updateMode(width, slider.value)
        self:onResize()
      else
        -- in case the updateMode is made invalid by fullscreen/maximize, set the values back
        slider.value = height
        slider.valueText:set(slider.value)
      end
    end
  })
  self.uiRoot.xSlider = Slider({
    min = -100,
    max = 100,
    value = x,
    tickLength = 4,
    onValueChange = function(slider)
      local x, y = love.window.getPosition()
      if not love.window.getFullscreen() then
        love.window.restore()
        love.window.setPosition(slider.value, y)
      else
        slider.value = x
        slider.valueText:set(slider.value)
      end
    end
  })
  self.uiRoot.ySlider = Slider({
    min = -200,
    max = 200,
    value = y,
    tickLength = 2,
    onValueChange = function(slider)
      local x, y = love.window.getPosition()
      if not love.window.getFullscreen() then
        love.window.restore()
        love.window.setPosition(x, slider.value)
      else
        slider.value = y
        slider.valueText:set(slider.value)
      end
    end
  })

  grid:createElementAt(1, 1, 20, 1, "desktopDimensions", desktopSizeLabel)
  grid:createElementAt(1, 2, 20, 1, "maximized", maximizedLabel)
  grid:createElementAt(1, 3, 20, 1, nil, TextButton({label = Label({text = "maximize", translate = false}),
  onClick = function() love.window.maximize() end}))
  grid:createElementAt(1, 4, 2, 1, nil, Label({text = "fullscreen", translate = false}))
  grid:createElementAt(3, 4, 20, 1, "fullscreen", self.uiRoot.fullscreenSelection)
  grid:createElementAt(1, 5, 2, 1, nil, Label({text = "width", translate = false}))
  grid:createElementAt(3, 5, 20, 1, "width", self.uiRoot.widthSlider)
  grid:createElementAt(1, 6, 2, 1, nil, Label({text = "height", translate = false}))
  grid:createElementAt(3, 6, 20, 1, "height", self.uiRoot.heightSlider)
  grid:createElementAt(1, 7, 2, 1, nil, Label({text = "x", translate = false}))
  grid:createElementAt(3, 7, 20, 1, "x", self.uiRoot.xSlider)
  grid:createElementAt(1, 8, 2, 1, nil, Label({text = "y", translate = false}))
  grid:createElementAt(3, 8, 20, 1, "y", self.uiRoot.ySlider)
  grid:createElementAt(1, 9, 20, 1, "back", TextButton({
    label = Label({text = "back"}),
    onClick =
    function()
      love.resize = self.originalResize
      GAME.navigationStack:pop()
    end
  }))

  self.uiRoot:addChild(grid)
end

function WindowSizeTester:onResize()
  -- need to manually update without triggering the callbacks from the controls
  local width, height, flags = love.window.getMode()
  local x, y, displayIndex = love.window.getPosition()

  self.uiRoot.fullscreenSelection.value = flags.fullscreen
  self.uiRoot.fullscreenSelection:buttonClicked(
    self.uiRoot.fullscreenSelection.buttons[tableUtils.indexOf(self.uiRoot.fullscreenSelection.values, flags.fullscreen)]
  )
  self.uiRoot.widthSlider.value = width
  self.uiRoot.widthSlider.valueText:set(self.uiRoot.widthSlider.value)
  self.uiRoot.heightSlider.value = height
  self.uiRoot.heightSlider.valueText:set(self.uiRoot.heightSlider.value)
  self.uiRoot.xSlider.value = x
  self.uiRoot.xSlider.valueText:set(self.uiRoot.xSlider.value)
  self.uiRoot.ySlider.value = y
  self.uiRoot.ySlider.valueText:set(self.uiRoot.ySlider.value)
end

function WindowSizeTester:update()

end

function WindowSizeTester:draw()
  self.uiRoot:draw()
end


return WindowSizeTester