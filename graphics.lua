------------
--- Graphics Module
--- load the game graphic
-- @module graphics 

require("input")
-- T13
local ceil = math.ceil --rounding
local len_garbage = #garbage_bounce_table --length of lua garbage

--- upload image file and returns drawn image
-- @function load_img
-- @param image_path image archive
-- @return draw_image drawing image
-- T11
function load_img(image_path)
    local img

    if pcall(
        function ()
            img = love.image.newImageData("assets/"..(config.assets_dir or default_assets_dir).."/"..image_path)
        end) then

        if config.assets_dir and config.assets_dir ~= default_assets_dir then
            print("loaded custom asset: "..config.assets_dir.."/"..image_path)
        end
    else
        img = love.image.newImageData("assets/"..default_assets_dir.."/"..image_path)
    end

    local draw_image = love.graphics.newImage(img)
    draw_image:setFilter("nearest","nearest")

    return draw_image
end

--- receives an image and draws it
-- @function draw 
-- @param img 
-- @param x position on the x_axis
-- @param y position on the y_axis
-- @param rot rotation
-- @param x_scale
-- @param y_scale 
-- @return nil 
-- T11
function draw(img, x, y, rot, x_scale, y_scale)
    rot = rot or 0
    x_scale = x_scale or 1
    y_scale = y_scale or 1
    gfx_q:push(
                {love.graphics.draw,
                {
                 img,
                 x*GFX_SCALE,
                 y*GFX_SCALE,
                 rot,
                 x_scale*GFX_SCALE,
                 y_scale*GFX_SCALE
                }
                })

end

--- draws the menu
-- @function menu_draw 
-- @param img 
-- @param x position on the x_axis
-- @param y position on the y_axis
-- @param rot rotation
-- @param x_scale
-- @param y_scale 
-- @return nil 
-- T11
function menu_draw(img, x, y, rot, x_scale,y_scale)
    rot = rot or 0
    x_scale = x_scale or 1
    y_scale = y_scale or 1
    gfx_q:push(
                {love.graphics.draw,
                {
                 img,
                 x,
                 y,
                 rot,
                 x_scale,
                 y_scale
                }
                })

end

--- draws the menu quad, the menu of right-cick
-- @function menu_drawq 
-- @param img 
-- @param quad quad panel
-- @param x position on the x_axis
-- @param y position on the y_axis
-- @param rot rotation
-- @param x_scale
-- @param y_scale 
-- @return nil 
-- T11
function menu_drawq(img, quad, x, y, rot, x_scale, y_scale)
    rot = rot or 0
    x_scale = x_scale or 1
    y_scale = y_scale or 1

    gfx_q:push(
                {love.graphics.draw,
                {
                 img,
                 quad,
                 x,
                 y,
                 rot,
                 x_scale,
                 y_scale
                }
                })

end

--- generates rectangles 
-- @function grectangle 
-- @param mode
-- @param x position on the x_axis
-- @param y position on the y_axis
-- @param width_rectangle 
-- @param height_rectangle
-- @return nil 
-- T5
-- T11
function grectangle(mode, x, y, width_rectangle, height_rectangle)
    gfx_q:push(
                {love.graphics.rectangle,
                {
                 mode,
                 x,
                 y,
                 width_rectangle,
                 height_rectangle
                 }
                })
end

--- print message on screen  
-- @function gprint 
-- @param str message that will be printed
-- @param x position on the x_axis
-- @param y position on the y_axis
-- @return nil 
-- T11
function gprint(str, x, y)
    gfx_q:push(
            {love.graphics.print,
            {
             str,
             x,
             y
            }
            })
end

-- current state of red, green, blue and alpha
-- T13, T5
local r_current = 0
local g_current = 0
local b_current = 0
local a_current = 0
local MAX_ALPHA

--- equals the colors received if the first ones are equal to zero  
-- @function set_color 
-- @param r red
-- @param g green
-- @param b blue 
-- @param a alpha 
-- @return nil 
-- T11
function set_color(r, g, b, a)
    a = a or MAX_ALPHA

    -- only do it if this color isn't the same as the previous one...
    if r_current ~= r or g_current ~= g or b_current ~= b or a_current ~= a then
        r_current, g_current, b_current, a_current = r, g, b, a
        gfx_q:push({love.graphics.setColor, {r, g, b, a}})
    end

end

local floor = math.floor

--- initiates the graphics of the game  
-- @function graphics_init 
-- @param nil
-- @return nil 
-- T11
function graphics_init()
    IMG_panels = {}
    for i=1,8 do
        IMG_panels[i]={}
        for j=1,7 do
            IMG_panels[i][j]=load_img("panel"..tostring(i)..tostring(j)..".png")
        end
    end

    IMG_panels[9]={}

    for j=1,7 do
        IMG_panels[9][j]=load_img("panel00.png")
    end

    local g_parts = {
                     "topleft", "botleft", "topright", "botright",
                     "top", "bot", "left", "right", "face", "pop",
                     "doubleface", "filler1", "filler2", "flash",
                     "portrait"
                    }

    IMG_garbage = {}
    for _,key in ipairs(characters) do

        local imgs = {}

        IMG_garbage[key] = imgs

        for _,part in ipairs(g_parts) do
            imgs[part] = load_img(""..key.."/"..part..".png")
        end

    end

    IMG_metal_flash = load_img("garbageflash.png")
    IMG_metal = load_img("metalmid.png")
    IMG_metal_l = load_img("metalend0.png")
    IMG_metal_r = load_img("metalend1.png")

    IMG_cursor = {
                  load_img("cur0.png"),
                  load_img("cur1.png")
                 }

    IMG_frame = load_img("frame.png")
    IMG_wall = load_img("wall.png")

    IMG_cards = {}
    IMG_cards[true] = {}
    IMG_cards[false] = {}

    for i=4,66 do
        IMG_cards[false][i] = load_img("combo"..tostring(floor(i/10))..tostring(i%10)..".png")
    end

    for i=2,13 do
        IMG_cards[true][i] = load_img("chain"..tostring(floor(i/10))..tostring(i%10)..".png")
    end

    for i=14,99 do
    IMG_cards[true][i] = load_img("chain00.png")
    end

    IMG_character_icons = {}

    for k,name in ipairs(characters) do
        IMG_character_icons[name] = load_img(""..name.."/icon.png")
    end

    local MAX_SUPPORTED_PLAYERS = 2
    IMG_char_sel_cursors = {}
    for player_num=1,MAX_SUPPORTED_PLAYERS do
        IMG_char_sel_cursors[player_num] = {}
        for position_num=1,2 do
            IMG_char_sel_cursors[player_num][position_num] = load_img("char_sel_cur_"..player_num.."P_pos"..position_num..".png")
        end
    end

    IMG_char_sel_cursor_halves = {left={}, right={}}
    for player_num=1,MAX_SUPPORTED_PLAYERS do

        IMG_char_sel_cursor_halves.left[player_num] = {}

        for position_num=1,2 do
            local cur_width, cur_height = IMG_char_sel_cursors[player_num][position_num]:getDimensions()
            local half_width, half_height = cur_width/2, cur_height/2
          IMG_char_sel_cursor_halves["left"][player_num][position_num] = love.graphics.newQuad(0,0,half_width,cur_height,cur_width, cur_height)
        end

        IMG_char_sel_cursor_halves.right[player_num] = {}

        for position_num=1,2 do
            local cur_width, cur_height = IMG_char_sel_cursors[player_num][position_num]:getDimensions()
            local half_width, half_height = cur_width/2, cur_height/2
            IMG_char_sel_cursor_halves.right[player_num][position_num] = love.graphics.newQuad(half_width,0,half_width,cur_height,cur_width, cur_height)
         end
    end

    character_display_names = {} -- players names --T13

    for k, original_name in ipairs(characters) do
        name_txt_file = love.filesystem.newFile("assets/"..config.assets_dir.."/"..original_name.."/name.txt")
        open_success, err = name_txt_file:open("r")
        local display_name = name_txt_file:read(name_txt_file:getSize())
        if display_name then
            character_display_names[original_name] = display_name
        else
            character_display_names[original_name] = original_name
        end
    end
    print("character_display_names: ")

    for k,v in pairs(character_display_names) do
        print(k.." = "..v)
    end

    character_display_names_to_original_names = {}

    for k,v in pairs(character_display_names) do
        character_display_names_to_original_names[v] = k
    end
end

--- subscribe the method update_cards of Stack class for update the cards   
-- @function Stack.update_cards 
-- @param self object 
-- @return nil 
-- T11
function Stack.update_cards(self)

    for i=self.card_q.first,self.card_q.last do
        local card = self.card_q[i]
        if card_animation[card.frame] then
            card.frame = card.frame + 1
            if(card_animation[card.frame]==nil) then
                self.card_q:pop()
            end
        else
            card.frame = card.frame + 1
        end
    end

end

--- subscribe the method draw_cards of Stack class for draw the cards  
-- @function Stack.draw_cards 
-- @param self object 
-- @return nil 
-- T11
function Stack.draw_cards(self)
    for i=self.card_q.first,self.card_q.last do
        local card = self.card_q[i]
        if card_animation[card.frame] then
            local draw_x = (card.x-1) * 16 + self.pos_x
            local draw_y = (11-card.y) * 16 + self.pos_y + self.displacement
                - card_animation[card.frame]
                draw(IMG_cards[card.chain][card.n], draw_x, draw_y)
         end
    end

end

--- subscribe the method render of Stack class for render  
-- @function Stack.render 
-- @param self object 
-- @return nil 
-- T11
function Stack.render(self)
    local mouse_x, mouse_y -- coordinates of mouse

    if config.debug_mode then
        mouse_x,mouse_y = love.mouse.getPosition()
        mouse_x = mouse_y / GFX_SCALE
        mouse_y = mouse_y / GFX_SCALE
    end

    if P1 == self then
        draw(IMG_garbage[self.character].portrait, self.pos_x, self.pos_y)
    else
        draw(IMG_garbage[self.character].portrait, self.pos_x+96, self.pos_y, 0, -1)
    end

    local shake_idx = #shake_arr - self.shake_time
    local shake = ceil((shake_arr[shake_idx] or 0) * 13)

    for row=0,self.height do
        for col=1,self.width do

            local panel = self.panels[row][col]
            local draw_x = (col-1) * 16 + self.pos_x
            local draw_y = (11-(row)) * 16 + self.pos_y + self.displacement - shake

            if panel.color ~= 0 and panel.state ~= "popped" then

                local draw_frame = 1
                if panel.garbage then
                    local imgs = {flash=IMG_metal_flash}
                    if not panel.metal then
                        imgs = IMG_garbage[self.garbage_target.character]
                    end

                    if panel.x_offset == 0 and panel.y_offset == 0 then
                        -- draw the entire block!
                        if panel.metal then
                            draw(IMG_metal_l, draw_x, draw_y)
                            draw(IMG_metal_r, draw_x+16*(panel.width-1)+8,draw_y)

                            for i=1,2*(panel.width-1) do
                                draw(IMG_metal, draw_x+8*i, draw_y)
                            end
                        else
                            local height, width = panel.height, panel.width
                            -- highest possible height
                            local top_y = draw_y - (height-1) * 16
                            -- verifies that the resulting height is odd, T13
                            local odd = ((height-(height%2))/2)%2==0

                            for i=0,height-1 do
                                for j=1,width-1 do
                                    draw((odd or height<3) and imgs.filler1 or imgs.filler2, draw_x+16*j-8, top_y+16*i) odd = not odd
                                end
                            end

                            if height%2==1 then
                                draw(imgs.face, draw_x+8*(width-1), top_y+16*((height-1)/2))
                            else
                                draw(imgs.doubleface, draw_x+8*(width-1), top_y+16*((height-2)/2))
                            end

                            draw(imgs.left, draw_x, top_y, 0, 1, height*16)
                            draw(imgs.right, draw_x+16*(width-1)+8, top_y, 0, 1, height*16)
                            draw(imgs.top, draw_x, top_y, 0, width*16)
                            draw(imgs.bot, draw_x, draw_y+14, 0, width*16)
                            draw(imgs.topleft, draw_x, top_y)
                            draw(imgs.topright, draw_x+16*width-8, top_y)
                            draw(imgs.botleft, draw_x, draw_y+13)
                            draw(imgs.botright, draw_x+16*width-8, draw_y+13)
                        end
                    end

                    if panel.state == "matched" then

                        local flash_time = panel.initial_time - panel.timer

                        if flash_time >= self.FRAMECOUNT_FLASH then

                            if panel.timer > panel.pop_time then
                                if panel.metal then
                                    draw(IMG_metal_l, draw_x, draw_y)
                                    draw(IMG_metal_r, draw_x+8, draw_y)
                                else
                                    draw(imgs.pop, draw_x, draw_y)
                                end
                            elseif panel.y_offset == -1 then
                                draw(IMG_panels[panel.color][
                                garbage_bounce_table[panel.timer] or 1], draw_x, draw_y)
                            end
                        elseif flash_time % 2 == 1 then
                            if panel.metal then
                                draw(IMG_metal_l, draw_x, draw_y)
                                draw(IMG_metal_r, draw_x+8, draw_y)
                            else
                                draw(imgs.pop, draw_x, draw_y)
                            end
                        else
                            draw(imgs.flash, draw_x, draw_y)
                         end
                    end

                    --this adds the drawing of state flags to garbage panels
                    if config.debug_mode then
                        gprint(panel.state, draw_x*3, draw_y*3)
                        if panel.match_anyway ~= nil then
                            gprint(tostring(panel.match_anyway), draw_x*3, draw_y*3+10)
                            if panel.debug_tag then
                                gprint(tostring(panel.debug_tag), draw_x*3, draw_y*3+20)
                            end
                        end
                        gprint(panel.chaining and "chaining" or "nah", draw_x*3, draw_y*3+30)
                    end
                else
                    if panel.state == "matched" then
                        local flash_time = self.FRAMECOUNT_MATCH - panel.timer
                        if flash_time >= self.FRAMECOUNT_FLASH then
                            draw_frame = 6
                        elseif flash_time % 2 == 1 then
                            draw_frame = 1
                        else
                            draw_frame = 5
                        end
                    elseif panel.state == "popping" then
                        draw_frame = 6
                    elseif panel.state == "landing" then
                        draw_frame = bounce_table[panel.timer + 1]
                    elseif panel.state == "swapping" then

                        if panel.is_swapping_from_left then
                            draw_x = draw_x - panel.timer * 4
                        else
                            draw_x = draw_x + panel.timer * 4
                        end
                    elseif panel.state == "dimmed" then
                        draw_frame = 7
                    elseif self.danger_col[col] then
                        draw_frame = danger_bounce_table[
                        wrap(1,self.danger_timer+1+floor((col-1)/2),#danger_bounce_table)]
                    else
                        draw_frame = 1
                    end

                    draw(IMG_panels[panel.color][draw_frame], draw_x, draw_y)

                    if config.debug_mode then
                        gprint(panel.state, draw_x*3, draw_y*3)
                        if panel.match_anyway ~= nil then
                            gprint(tostring(panel.match_anyway), draw_x*3, draw_y*3+10)
                            if panel.debug_tag then
                                gprint(tostring(panel.debug_tag), draw_x*3, draw_y*3+20)
                            end
                        end
                        gprint(panel.chaining and "chaining" or "nah", draw_x*3, draw_y*3+30)
                    end
                end
            end

            if config.debug_mode and mx >= draw_x and mx < draw_x + 16 and my >= draw_y and my < draw_y + 16 then
                mouse_panel = {row, col, panel}
                draw(IMG_panels[4][1], draw_x+16/3, draw_y+16/3, 0, 0.33333333, 0.3333333)
            end
        end
    end

    draw(IMG_frame, self.pos_x-4, self.pos_y-4)
    draw(IMG_wall, self.pos_x, self.pos_y - shake + self.height*16)

    if self.mode == "puzzle" then
        gprint("Moves: "..self.puzzle_moves, self.score_x, 100)
        gprint("Frame: "..self.CLOCK, self.score_x, 130)
    else

        gprint("Score: "..self.score, self.score_x, 100)
        gprint("Speed: "..self.speed, self.score_x, 130)
        gprint("Frame: "..self.CLOCK, self.score_x, 145)

        if self.mode == "time" then
            local time_left = 120 - self.CLOCK/60
            local mins = floor(time_left/60) -- currents minutes --T13
            local secs = floor(time_left%60) -- currents seconde

            gprint("Time: "..string.format("%01d:%02d",mins,secs), self.score_x, 160)
        elseif self.level then
            gprint("Level: "..self.level, self.score_x, 160)
        end

        gprint("Health: "..self.health, self.score_x, 175)
        gprint("Shake: "..self.shake_time, self.score_x, 190)
        gprint("Stop: "..self.stop_time, self.score_x, 205)
        gprint("Pre stop: "..self.pre_stop_time, self.score_x, 220)

        if config.debug_mode and self.danger then
            gprint("danger", self.score_x,235)
        end

        if config.debug_mode and self.danger_music then
            gprint("danger music", self.score_x, 250)
        end

        if config.debug_mode then
            gprint("cleared: "..(self.panels_cleared or 0), self.score_x, 265)
        end

        if config.debug_mode then
            gprint("metal q: "..(self.metal_panels_queued or 0), self.score_x, 280)
        end

        if config.debug_mode and self.input_state then
            local iraise, iswap, iup, idown, ileft, iright = unpack(base64decode[self.input_state])
            local inputs_to_print = "inputs:"

            if iraise then
                inputs_to_print = inputs_to_print.."\nraise"
            end --◄▲▼►
            if iswap then
                inputs_to_print = inputs_to_print.."\nswap"
            end

            if iup then
                inputs_to_print = inputs_to_print.."\nup"
            end

            if idown then
                inputs_to_print = inputs_to_print.."\ndown"
            end

            if ileft then
                inputs_to_print = inputs_to_print.."\nleft"
            end

            if iright then
                inputs_to_print = inputs_to_print.."\nright"
            end

            gprint(inputs_to_print, self.score_x, 295)
        end

        if match_type then
            gprint(match_type, 375, 15)
        end
    end
    self:draw_cards()
    self:render_cursor()
end

--- scales letterbox 
-- @function scale_letterbox     
-- @param width 
-- @param height 
-- @param w_ratio width ratio
-- @param h_ratio height ratio
-- @return ratio_letterbox 
-- T11
function scale_letterbox(width, height, w_ratio, h_ratio)
    if height / h_ratio > width / w_ratio then

        local scaled_height = h_ratio * width / w_ratio
        return 0, (height - scaled_height) / 2, width, scaled_height
    end

    local scaled_width = w_ratio * height / h_ratio

    return (width - scaled_width) / 2, 0, scaled_width, height
end

--- subscribe the method draw_cards of Stack class for render the cursor  
-- @function Stack.render_cursor 
-- @param self object 
-- @return nil 
-- T11
function Stack.render_cursor(self)
    draw(IMG_cursor[(floor(self.CLOCK/16)%2)+1], (self.cur_col-1)*16+self.pos_x-4, (11-(self.cur_row))*16+self.pos_y-4+self.displacement)
end

