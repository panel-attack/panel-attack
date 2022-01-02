require("graphics_util")

menu_font = love.graphics.getFont()
CLICK_MENUS = {} -- All click menus currently showing in the game

-- A series of buttons with text strings that can be clicked or use input to navigate
-- Buttons are laid out vertically and scroll buttons are added if not all options fit.
Click_menu =
  class(
  function(self, x, y, width, height, active_idx)
    self.x = x or 0
    self.y = y or 0
    self.width = width or (canvas_width - self.x - 30) --width not used yet for scrolling
    self.height = height or (canvas_height - self.y - 30) --scrolling does care about height
    self.new_item_y = 0
    self.menu_controls = {
      up = {
        text = love.graphics.newText(menu_font, "^"),
        x = self.width - 30,
        y = 10,
        w = 30,
        h = 30,
        outlined = true,
        visible = false
      },
      down = {
        text = love.graphics.newText(menu_font, "v"),
        x = self.width - 30,
        y = 80,
        w = 30,
        h = 30,
        outlined = true,
        visible = false
      }
    }
    self.buttons = {}
    self.buttons_outlined = 1
    self.padding = 2 -- the padding around the entire menu
    self.button_padding = 4 -- the padding around one particular button
    self.padding_between_buttons = 8 -- the vertical padding between two buttons
    self.background = nil
    self.new_item_y = 0
    self.arrow = ">"
    self.arrow_padding = 12
    self.active = true
    self.visible = true
    CLICK_MENUS[#CLICK_MENUS + 1] = self
    self.active_idx = active_idx or 1 -- the currently selected button
    self.id = #CLICK_MENUS
    self.top_visible_button = 1
    self.clock = 1

    self:layout_buttons()
  end
)

function Click_menu.add_button(self, string_text, selectFunction, escapeFunction, leftFunction, rightFunction)
  self.buttons[#self.buttons + 1] = {
    text = love.graphics.newText(menu_font, string_text),
    stringText = string_text,
    x = 0,
    y = 0,
    w = nil,
    h = nil,
    outlined = self.buttons_outlined,
    selectFunction = selectFunction,
    escapeFunction = escapeFunction,
    leftFunction = leftFunction,
    rightFunction = rightFunction
  }
  self.buttons[#self.buttons].y = self.new_item_y or 0

  self:resize_to_fit()
  self:layout_buttons()
end

-- Sets the string for the menu text
function Click_menu.set_button_text(self, button_idx, string)
  self.buttons[button_idx].text = love.graphics.newText(menu_font, string)
end


-- Sets the string to render to the right of the menu text
function Click_menu.set_button_setting(self, button_idx, new_setting)
  self.buttons[button_idx].current_setting = love.graphics.newText(menu_font, new_setting)
end

-- Sets the button at the given index's visibility
function Click_menu.set_button_visibility(self, idx, visible)
  self.buttons[idx].visible = visible
end

-- Gets the button at the given index's width including padding
function Click_menu.get_button_width(self, idx)
  return self.buttons[idx].w or self.buttons[idx].text:getWidth() + 2 * self.button_padding
end

-- Gets the button at the given index's height including padding
function Click_menu.get_button_height(self, idx)
  if self.buttons and self.buttons[idx] then
    return self.buttons[idx].h or self.buttons[idx].text:getHeight() + 2 * self.button_padding
  else
    return 0
  end
end

-- Gets the button at the given index's current setting width including padding
function Click_menu.get_button_setting_width(self, idx)
  local result = 0
  if self.buttons[idx].current_setting then
    result = self.buttons[idx].current_setting:getWidth() + 2 * self.button_padding
  end
  return result
end

-- Removes this menu from the list of menus
function Click_menu.remove_self(self)
  CLICK_MENUS[self.id] = nil
end

-- PRIVATE
-- Recalculates top_visible_button
function Click_menu.update_top_button(self)
  if self.active_idx < self.top_visible_button then
    self.top_visible_button = math.max(self.active_idx, 1)
  elseif self.active_idx > self.top_visible_button + self.button_limit - 1 then
    self.top_visible_button = math.max(math.min(self.active_idx - (self.button_limit - 1), #self.buttons), 1)
  end
end

-- Sets the current selected button and scrolls to it if needed
function Click_menu.set_active_idx(self, idx)
  idx = wrap(1, idx, #self.buttons)
  self.active_idx = idx
  local top_visible_button_before = self.top_visible_button
  self:update_top_button()
  if self.top_visible_button ~= top_visible_button_before or not self.buttons[idx].visible then
    self:layout_buttons()
  end
end

-- Repositions in the x direction so the menu doesn't go off the screen
function Click_menu.resize_to_fit(self)
  for k, v in pairs(self.buttons) do
    self.current_setting_x = math.max(self.current_setting_x or 0, self:get_button_width(k) + 2 * (self.button_padding or 0))
    local potential_width = self:get_button_width(#self.buttons) + 2 * self.padding
    if self.buttons[k].current_setting then
      potential_width = potential_width + 2 * self.padding
    end
    self.width = math.max(self.width, potential_width)
    self.current_setting_x = math.max(self.current_setting_x or 0, self.buttons[#self.buttons].text:getWidth() + (self.button_padding))
  end
end

-- Positions the buttons, scrolls, and makes sure the scroll buttons are visible if needed
function Click_menu.layout_buttons(self)
  self.new_item_y = self.padding
  self.active_idx = self.active_idx or 1
  self.button_limit = 1
  if #self.buttons > 0 then
    local firstButtonHeight = self:get_button_height(1) + (2 * self.padding)
    local eachExtraButtonHeight = self:get_button_height(1) + self.padding_between_buttons
    self.button_limit = self.button_limit + math.floor((self.height - firstButtonHeight) / eachExtraButtonHeight)
  end

  --scroll up or down if not showing the active button
  self:update_top_button()

  local menu_is_full = false
  for i = 1, #self.buttons do
    if i < self.top_visible_button then
      self.buttons[i].visible = false
    elseif i < self.top_visible_button + self.button_limit then
      self.buttons[i].visible = true
      self.buttons[i].x = self.padding
      self.buttons[i].y = self.new_item_y
      self.new_item_y = self.new_item_y + self:get_button_height(i) + self.padding_between_buttons
    else --button doesn't fit
      menu_is_full = true
      self.buttons[i].visible = false
    end
  end

  if #self.buttons > self.button_limit then
    self:show_controls(true)
  else
    self:show_controls(false)
  end
end

-- Sets the visibility of the scroll controls
function Click_menu.show_controls(self, bool)
  if bool or #self.buttons > self.button_limit then
    for k, v in pairs(self.menu_controls) do
      self.menu_controls[k].visible = true
    end
  else
    for k, v in pairs(self.menu_controls) do
      self.menu_controls[k].visible = false
    end
  end
end

function Click_menu.selectButton(self, buttonIndex)
  self:set_active_idx(buttonIndex)
  self.buttons[self.active_idx].selectFunction()
end

function Click_menu.selectPreviousIndex(self)
  self:set_active_idx(wrap(1, self.active_idx - 1, #self.buttons))
end

function Click_menu.selectNextIndex(self)
  self:set_active_idx(wrap(1, self.active_idx + 1, #self.buttons))
end

-- Responds to input
function Click_menu.update(self)
  self.clock = self.clock + 1

  if GAME.focused == false then
    return
  end
  
  if self.visible then
    if menu_up(K[1]) then
      self:selectPreviousIndex()
    elseif menu_down(K[1]) then
      self:selectNextIndex()
    elseif menu_enter(K[1]) then
      if self.buttons[self.active_idx].selectFunction then
        self:selectButton(self.active_idx)
      end
    elseif menu_escape(K[1]) then
      if self.buttons[self.active_idx].escapeFunction then
        self.buttons[self.active_idx].escapeFunction()
      end
    elseif menu_left(K[1]) then
      if self.buttons[self.active_idx].leftFunction then
        self.buttons[self.active_idx].leftFunction()
      end
    elseif menu_right(K[1]) then
      if self.buttons[self.active_idx].rightFunction then
        self.buttons[self.active_idx].rightFunction()
      end
    end
  end
end

-- Draws the menu
function Click_menu.draw(self)
  if self.visible then
    if self.background then
      menu_drawf(self.background, self.x, self.y)
    end
    if self.outline then
    --TO DO whole menu outline, maybe
    --grectangle("line", self.x + self.buttons[i].x, self.y + self.buttons[i].y, self.get_button_width(self,i), button_height)
    end
    --draw buttons (not including menu controls)
    for i = 1, #self.buttons do
      if self.buttons[i].visible then
        local buttonX = self.x + self.buttons[i].x
        local buttonY = self.y + self.buttons[i].y
        local buttonSettingX = self.x + (self.current_setting_x or 0)
        local buttonTextY = buttonY + self.button_padding
        local width = self:get_button_width(i)
        local height = self:get_button_height(i)
        if self.buttons[i].background then
          menu_drawf(self.buttons[i].background, buttonX, buttonY)
        else
          local grey = 0.3
          local alpha = 0.7
          grectangle_color("fill", buttonX / GFX_SCALE, buttonY / GFX_SCALE, width / GFX_SCALE, height / GFX_SCALE, grey, grey, grey, alpha)

          if self.buttons[i].current_setting then
            local currentSettingWidth = self:get_button_setting_width(i)
            grectangle_color("fill", buttonSettingX / GFX_SCALE, buttonY / GFX_SCALE, currentSettingWidth / GFX_SCALE, height / GFX_SCALE, grey, grey, grey, alpha)
          end
        end
        if self.buttons[i].outlined then
          local grey = 0.5
          local alpha = 0.7
          grectangle_color("line", buttonX / GFX_SCALE, buttonY / GFX_SCALE, width / GFX_SCALE, height / GFX_SCALE, grey, grey, grey, alpha)
        end
        menu_draw(self.buttons[i].text, buttonX + self.button_padding, buttonTextY)
        if self.buttons[i].current_setting then
          menu_draw(self.buttons[i].current_setting, buttonSettingX + self.button_padding, buttonTextY)
        end
      end
    end

    --draw menu controls (up and down scrolling buttons, so far)
    for k, control in pairs(self.menu_controls) do
      if control.visible then
        if control.background then
          menu_drawf(control.background, self.x + control.x, self.y + control.y)
        end
        if control.outlined then
          grectangle("line", self.x + control.x, self.y + control.y, control.w, control.h)
        end
        menu_draw(control.text, self.x + control.x + self.button_padding, self.y + control.y + self.button_padding)
        if control.current_setting then
          menu_draw(control.current_setting, self.x + (self.current_setting_x or 0), self.y + control.y + self.button_padding)
        end
      end
    end

    --draw arrow
    if self.active_idx and self.buttons[1] then
      local animationX = (math.cos(math.rad(self.clock * 6)) * 5) - 9
      local xPosition = self.x + self.buttons[self.active_idx].x - self.arrow_padding + animationX
      local yPosition = self.y + self.button_padding + self.buttons[self.active_idx].y - 3
      gprintf(self.arrow or ">", xPosition+1, yPosition+1, 100, "left", nil, nil, 2)
    end
  end
end

-- Moves the menu to the given location
function Click_menu.move(self, x, y)
  self.x = x or 0
  self.y = y or 0
end

-- Handles taps or clicks on the menu
function Click_menu.click_or_tap(self, x, y, touchpress)
  if self.active then
    self.idx_selected = nil

    -- Handle tapping on a menu option
    for i = 1, #self.buttons do
      if y >= self.y + self.buttons[i].y and y <= self.y + self.buttons[i].y + self:get_button_height(i) and x >= self.x + self.buttons[i].x and x <= self.x + self.buttons[i].x + self:get_button_width(i) then
        self.idx_selected = i
        self:selectButton(self.idx_selected)

        --TODO: consolidate with the input functions sound
        play_optional_sfx(themes[config.theme].sounds.menu_validate)
      end
    end

    -- Handle tapping on a button control
    for control_name, control in pairs(self.menu_controls) do
      if control.visible then
        if y >= self.y + control.y and y <= self.y + control.y + control.h and x >= self.x + control.x and x <= self.x + control.x + control.w then
          --print(menu_name.."'s "..control_name.." was clicked or tapped")
          this_frame_keys[control_name] = true
        end
      end
    end
  end
end
