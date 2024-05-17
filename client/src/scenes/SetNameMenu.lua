local Scene = require("scenes.Scene")
local InputField = require("ui.InputField")
local Label = require("ui.Label")
local sceneManager = require("scenes.sceneManager")
local Menu = require("ui.Menu")
local input = require("inputManager")
local utf8 = require("utf8")
local class = require("class")
local TextButton = require("ui.TextButton")

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

function SetNameMenu:load()
  local x, y = unpack(themes[config.theme].main_menu_screen_pos)
  self.promptLabel = Label({
    text = "op_enter_name",
    vAlign = "top",
    hAlign = "center",
    y = y
  })
  self.uiRoot:addChild(self.promptLabel)

  self.validationLabel = Label({
    text = "",
    vAlign = "top",
    hAlign = "center",
    y = y + 20,
    translate = false
  })
  self.uiRoot:addChild(self.validationLabel)

  self.nameField = InputField({
    y = y + 50,
    width = 200,
    height = 25,
    placeholder = "username",
    value = config.name,
    hAlign = "center",
    vAlign = "top",
    charLimit = NAME_LENGTH_LIMIT
  })
  self.uiRoot:addChild(self.nameField)

  self.nameLengthLabel = Label({
    x = self.nameField.width / 2 + 30,
    y = y + 50 + 5.5,
    vAlign = "top",
    hAlign = "center",
    translate = false,
    text = "(" .. self.nameField.value:len() .. "/" .. NAME_LENGTH_LIMIT .. ")"
  })
  self.uiRoot:addChild(self.nameLengthLabel)

  self.confirmationButton = TextButton({
    label = Label({text = "mm_set_name"}),
    y = y + 100,
    vAlign = "top",
    hAlign = "center",
    onClick = function(selfElement, inputSource, holdTime)
      self:confirmName()
    end
  })
  self.uiRoot:addChild(self.confirmationButton)

  self.backgroundImg = themes[config.theme].images.bg_main

  self.nameField:setFocus(0, 0)
  self.nameField.offset = utf8.len(self.nameField.value)
end

function SetNameMenu:confirmName()
  if self.nameField.value ~= "" then
    GAME.theme:playValidationSfx()
    config.name = self.nameField.value
    write_conf_file()
    self.nameField:unfocus()
    sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
  end
end

function SetNameMenu:update(dt)
  self.backgroundImg:update(dt)
  if self.validationLabel.text ~= "" and self.nameField.value ~= "" then
    self.validationLabel:setText("", nil, false)
  end

  if input.allKeys.isDown["return"] then
    self:confirmName()
  end
  if input.allKeys.isDown["escape"] then
    GAME.theme:playCancelSfx()
    self.nameField:unfocus()
    sceneManager:switchToScene(sceneManager:createScene("MainMenu"))
  end

  if self.nameField.hasFocus then
    self.nameLengthLabel:setText("(" .. self.nameField.value:len() .. "/" .. NAME_LENGTH_LIMIT .. ")")
    if self.nameField.value == "" then
      self.validationLabel:setText("op_username_blank_warning", nil, true)
    end
    self.confirmationButton:setEnabled(self.nameField.value ~= "")
  end
end

function SetNameMenu:draw()
  self.backgroundImg:draw()

  self.uiRoot:draw()
end

return SetNameMenu