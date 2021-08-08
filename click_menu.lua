require("graphics_util")

menu_font = love.graphics.getFont()
click_menus = {}
last_active_idx = 1

Click_menu = class(function(self, list, x, y, width, height, padding, active_idx, buttons_outlined, button_padding,background)
    self.x = x or 0
    self.y = y or 0
    self.width = width or love.graphics.getWidth()-self.x - 30 --width not used yet for scrolling
    self.height = height or love.graphics.getHeight()-self.y - 30 --scrolling does care about height
    self.new_item_y = 0
    self.menu_controls = 
    {
      up = 
      {
        text = love.graphics.newText(menu_font, "^"),
        x=self.width - 30,
        y=10,
        w=30,
        h=30,
        outlined=true,
        visible=false
      },
      down = 
      {
        text = love.graphics.newText(menu_font, "v"),
        x=self.width - 30,
        y=80,
        w=30,
        h=30,
        outlined=true,
        visible=false
      }
    }
    self.buttons = {}
    self.padding = padding or 0
    self.buttons_outlined = buttons_outlined
    self.button_padding = button_padding or 0
    self.background = background
    self.new_item_y = 0
    if list then
      for i=1,#list or 0 do
        self:add_button(list[i], nil, nil, nil, nil, self.buttons_outlined)
      end
    end
    self.arrow = ">"
    self.arrow_padding = 12
    self.active = true
    self.visible = true
    click_menus[#click_menus+1] = self
    self.active_idx = active_idx or 1
    self.id = #click_menus
    last_active_idx = self.active_idx
    self.top_visible_button = 1
        
        
        
    self:layout_buttons()
  end)

function Click_menu.add_button(self, string_text, x, y, w, h, outlined, button_padding, current_setting)  
-- x and y are optional. by default will add underneath existing menu buttons
-- w and h are optional. by default, button width will be the width of the text
  self.w = w or 0
  self.h = h or 0
  if x or y then
    self.fixed_buttons[#self.fixed_buttons] = 
    {
      text=love.graphics.newText(menu_font, string_text),
      x=x or 0,
      y=y or 0,
      w=w,
      h=h,
      outlined=self.buttons_outlined or outlined,
      current_setting = current_setting
    }
  else 
    self.buttons[#self.buttons+1] = 
    {
      text=love.graphics.newText(menu_font, string_text),
      x=x or 0,
      y=y or 0,
      w=w,
      h=h,
      outlined=self.buttons_outlined or outlined,
      current_setting = current_setting
    }
    if self.buttons[#self.buttons].current_setting then
    self.buttons[#self.buttons].current_setting = love.graphics.newText(menu_font, self.buttons[#self.buttons].current_setting)
    end
    self.buttons[#self.buttons].y = self.new_item_y or 0
  end
  self:resize_to_fit()
  self:layout_buttons()
  
end

function Click_menu.set_button_setting(self, button_idx, new_setting)
  self.buttons[button_idx].current_setting = love.graphics.newText(menu_font, new_setting)
end

function Click_menu.set_button_visibility(self, idx, visible)
  self.buttons[idx].visible = visible
end

function Click_menu.get_button_width(self, idx)
  return self.buttons[idx].w or self.buttons[idx].text:getWidth()+2*self.button_padding
end

function Click_menu.get_button_height(self, idx)
  if self.buttons  and self.buttons[idx] then
    return self.buttons[idx].h or self.buttons[idx].text:getHeight()+2*self.button_padding
  else
    return 0
  end
end

function Click_menu.remove_self(self)
  last_active_idx = self.active_idx
  click_menus[self.id] = nil
end

function Click_menu.set_active_idx(self, idx)
  idx = wrap(1,idx,#self.buttons)
  self.active_idx = idx
  local top_visible_button_before = self.top_visible_button
  if self.active_idx < self.top_visible_button then
    self.top_visible_button = math.max(self.active_idx, 1)
  end
  if self.active_idx > self.top_visible_button + self.button_limit then
    self.top_visible_button = math.max(self.active_idx - self.button_limit, 1)
  end
  if self.top_visible_button ~= top_visible_button_before or not self.buttons[idx].visible then
    self:layout_buttons()
  end
end

function Click_menu.set_current_setting(self, idx, new_setting)
  if self.buttons[idx] then
    self.buttons[idx].current_setting = love.graphics.newText(menu_font, new_setting)
  end
end

function Click_menu.resize_to_fit(self)
  for k,v in pairs(self.buttons) do 
    self.current_setting_x = math.max(self.current_setting_x or 0, self:get_button_width(k) + 2*(self.button_padding or 0))
    local potential_width = self:get_button_width(#self.buttons) + 2*(self.padding or 0)
    if self.buttons[k].current_setting then
      potential_width = potential_width + 2*(self.padding or 0)
    end
    self.w = math.max(self.w , potential_width)
    self.current_setting_x = math.max(self.current_setting_x or 0, self.buttons[#self.buttons].text:getWidth()+(button_padding or self.button_padding or 0))
  end
end

function Click_menu.layout_buttons(self)
  self.new_item_y = self.padding or 0
  self.top_visible_button = self.top_visible_button or 1
  self.active_idx = self.active_idx or 1
  self.button_limit = math.min(self.button_limit or 1, #self.buttons)
  --scroll up or down if not showing the active button
  if self.active_idx < self.top_visible_button then
    self.top_visible_button = math.max(self.active_idx, 1)
  end
  if self.active_idx >= self.top_visible_button + self.button_limit then
    self.top_visible_button = math.max(self.active_idx - self.button_limit + 1, 1)
  end
  --reset button limit so it can be recalculated.
  self.button_limit = 0 --this will increase as there is room for more buttons.
  local menu_is_full = false
  for i=1,#self.buttons do
    if i < self.top_visible_button then
      self.buttons[i].visible = false
    elseif not menu_is_full and self.new_item_y + self:get_button_height(i) < self.height then
      self.buttons[i].visible = true
      self.buttons[i].x = self.button_padding
      self.buttons[i].y = self.new_item_y or 0
      self.new_item_y = self.new_item_y + self:get_button_height(i)+self.padding
      self.button_limit = self.button_limit + 1
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

function Click_menu.show_controls(self, bool)
  if bool or #self.buttons > self.button_limit then
    for k,v in pairs(self.menu_controls) do
      self.menu_controls[k].visible = true
    end
  else
    for k,v in pairs(self.menu_controls) do
      self.menu_controls[k].visible = false
    end
  end
end

function Click_menu.draw(self)
  if self.visible then
    if self.background then
      menu_drawf(self.background, self.x , self.y)
    end
    if self.outline then
      --TO DO whole menu outline, maybe
      --grectangle("line", self.x + self.buttons[i].x, self.y + self.buttons[i].y, self.get_button_width(self,i), button_height)
    end
    --draw buttons (not including fixed buttons, or menu controls)
    for i=1,#self.buttons do
      if self.buttons[i].visible then  
        if self.buttons[i].background then
          menu_drawf(self.buttons[i].background, self.x + self.buttons[i].x, self.y + self.buttons[i].y)
        end
        if self.buttons[i].outlined then
          grectangle("line", self.x + self.buttons[i].x, self.y + self.buttons[i].y, self:get_button_width(i), self:get_button_height(i))
        end
        menu_draw(self.buttons[i].text, self.x + self.buttons[i].x + self.button_padding, self.y + self.buttons[i].y + self.button_padding)
        if self.buttons[i].current_setting then
          menu_draw(self.buttons[i].current_setting, self.x + self.current_setting_x or 0, self.y + self.buttons[i].y + self.button_padding)
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
          menu_draw(control.current_setting, self.x + self.current_setting_x or 0, self.y + control.y + self.button_padding)
        end
      end
    end
    --TO DO: Draw fixed buttons
    if self.active_idx and self.buttons[1] then
      gprint(self.arrow or ">",
      self.x + 
      self.buttons[self.active_idx].x 
      - self.arrow_padding, 
      self.y +self.button_padding +
      self.buttons[self.active_idx].y)
    end
  end
end

function Click_menu.move(self, x, y)
  self.x = x or 0
  self.y = y or 0
end

function click_or_tap(x, y, touchpress)
  
  print(x..","..y)
  for menu_name,menu in pairs(click_menus) do
    if menu.active then
      menu.idx_selected = nil
      for i=1, #menu.buttons do
        if y >= menu.y + menu.buttons[i].y and y <= menu.y + menu.buttons[i].y + menu:get_button_height(i) and
        x >= menu.x + menu.buttons[i].x and x <= menu.x + menu.buttons[i].x + menu:get_button_width(i) then
          menu.idx_selected = i
          last_active_idx = menu_idx_selected
        end
      end
      for control_name, control in pairs(menu.menu_controls) do
        if control.visible then
          if y >= menu.y + control.y and y <= menu.y + control.y+ control.h and
          x >= menu.x + control.x and x <= menu.x + control.x + control.w then
            --print(menu_name.."'s "..control_name.." was clicked or tapped")
            this_frame_keys[control_name] = true
            
            --this method moves the menu's index, but doesn't let you move the leaderboard up/down
            -- if control_name == "up" then
              -- -- menu:set_active_idx(menu.active_idx - 1)
            -- elseif control_name == "down" then
              -- menu:set_active_idx(menu.active_idx + 1)
            -- end
            
            
            --attempt at getting repeat of the key to work (didn't work)
            --love:keypressed(control_name, control_name, repeating_key(control_name))
            
            
          end
        end
      end
    end
  end
end

function transform_coordinates(x,y)
  local lbx, lby, lbw, lbh = scale_letterbox(love.graphics.getWidth(), love.graphics.getHeight(), 16, 9)
  local scale = canvas_width/math.max(background:getWidth(),background:getHeight())
  return  (x-lbx)/scale*canvas_width/lbw,
          (y-lby)/scale*canvas_height/lbh
end

function love.mousepressed(x,y)
  click_or_tap(transform_coordinates(x,y))
end

function love.touchpressed(id, x, y, dx, dy, pressure)
  local _x, _y = transform_coordinates(x,y)
  click_or_tap(_x, _y, {id=id, x=_x, y=_y, dx=dx, dy=dy, pressure=pressure})
end


