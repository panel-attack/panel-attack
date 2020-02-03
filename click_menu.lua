menu_buttons = {}
menu_font = love.graphics.getFont()
menu_x = 0
menu_y = 0


Click_menu = class(function(self, x, y, list)
    self.x = x
    self.y = y
    self.new_item_y
    self.buttons = {}
    self:refresh(list)
  end)

function Click_menu.add_button(self, string_text, x, y, w, h)  
-- x and y are optional. by default will add underneath existing menu buttons
-- w and h are optional. by default, button width will be the width of the text
  self.w = w
  self.h = 
  self.buttons[#self.buttons+1] = 
    {
      text=love.graphics.newText(menu_font, string_text),
      x=x or self.x,
      y=y,
      w=w,
      h=h}
  if not y then
    self.buttons[#self.buttons].y = new_item_y
    self.new_item_y = self.new_item_y + self.buttons[#self.buttons].text:getHeight()
  end
end

function Click_menu.get_button_width(self, idx)
local ret = self.buttons[idx].w
  return

end


function Click_menu.refresh()

function love.mousepressed(x,y)
  menu_item_idx_clicked = nil
  print(x..","..y)
  for i=1, #menu_buttons do
    if y >= menu_buttons[i].y and y <= menu_buttons[i].y + menu_buttons[i].text:getHeight() and
    x >= menu_buttons[i].x and x <= menu_buttons[i].x + menu_buttons[i].text:getWidth() then
      print("pressed menu item "..i)
      menu_item_idx_clicked = i
    end
  end
end

function menu_move(x,y)
  local draw_y = y
  for i=1, #menu_buttons do
    menu_buttons[i].x = x
    menu_buttons[i].
end