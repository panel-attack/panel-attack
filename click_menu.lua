require("graphics_util")

menu_font = love.graphics.getFont()
click_menus = {}

Click_menu = class(function(self, list, x, y, padding, active_idx, has_outline, background)
    self.x = x or 0
    self.y = y or 0
    self.new_item_y = 0
    self.buttons = {}
    self.padding = padding or 0
    self.outline = has_outline
    self.background = background
    self.new_item_y = 0
    if list then
      for i=1,#list or 0 do
        self:add_button(list[i])
      end
    end
    self.active = true
    self.visible = true
    click_menus[#click_menus+1] = self
    self.active_idx = active_idx or 1
  end)

function Click_menu.add_button(self, string_text, x, y, w, h)  
-- x and y are optional. by default will add underneath existing menu buttons
-- w and h are optional. by default, button width will be the width of the text
  self.w = w
  self.h = h
  self.buttons[#self.buttons+1] = 
    {
      text=love.graphics.newText(menu_font, string_text),
      x=x or 0,
      y=y,
      w=w,
      h=h
      }
  if not self.buttons[#self.buttons].y then
    self.buttons[#self.buttons].y = self.new_item_y
    self.new_item_y = self.new_item_y + self.buttons[#self.buttons].text:getHeight()+self.padding
  end
end

function Click_menu.get_button_width(self, idx)
  return self.buttons[idx].w or self.buttons[idx].text:getWidth()
end

function Click_menu.get_button_height(self, idx)
  return self.buttons[idx].h or self.buttons[idx].text:getHeight()
end

function Click_menu.remove_self(self)
  for k,v in pairs(click_menus) do
    if v == self then
      click_menus[k] = nil
    end
  end
end

function Click_menu.draw(self)
  if self.visible then
    if self.background then
      menu_drawf(self.background, self.x , self.y)
    end
    if self.outline then
      grectangle("line", self.x + self.buttons[i].x, self.y + self.buttons[i].y, self.get_button_width(self,i), button_height)
    end
    
    for i=1,#self.buttons do
      if self.buttons[i].background then
        menu_drawf(self.buttons[i].background, self.x + self.buttons[i].x, self.y + self.buttons[i].y)
      end
      if self.buttons[i].outline then
        grectangle("line", self.x + self.buttons[i].x, self.y + self.buttons[i].y, self:get_button_width(i), self:get_button_height(i))
      end
      menu_draw(self.buttons[i].text, self.x + self.buttons[i].x, self.y + self.buttons[i].y)
    end
  end
end

function Click_menu.move(self, x, y)
  self.x = x or 0
  self.y = y or 0
end

function love.mousepressed(x,y)
  print(x..","..y)
  for k,menu in pairs(click_menus) do
    if menu.active then
      menu.idx_clicked = nil
      for i=1, #menu.buttons do
        print("checking menu button")
        print(menu:get_button_width(i))
        print(menu:get_button_height(i))
        if y >= menu.y + menu.buttons[i].y and y <= menu.y + menu.buttons[i].y + menu:get_button_height(i) and
        x >= menu.x + menu.buttons[i].x and x <= menu.x + menu.buttons[i].x + menu:get_button_width(i) then
          print("pressed menu item "..i)
          menu.idx_clicked = i
        end
      end
    end
  end
end

