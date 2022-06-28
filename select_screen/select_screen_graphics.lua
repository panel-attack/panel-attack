
local select_screen_graphics = {
  v_align_center = {__Ready = true, __Random = true, __Leave = true},
  is_special_value = {__Leave = true, __Level = true, __Panels = true, __Ready = true, __Stage = true, __Mode = true, __Random = true},
  spacing = 8,
  text_height = 13,
}

function select_screen_graphics.draw(self, select_screen)
  self.select_screen = select_screen

  select_screen_graphics.menu_width = select_screen.COLUMNS * 100
  select_screen_graphics.menu_height = select_screen.ROWS * 80

  set_color(unpack(colors.white))

  -- Go through the grid, drawing the buttons, handling horizontal spans
  for i = 1, select_screen.ROWS do
    for j = 1, select_screen.COLUMNS do
      local value = self.select_screen.drawMap[self.select_screen.current_page][i][j]
      local span_width = 1
      if self.is_special_value[value] then
        if j == 1 or self.select_screen.drawMap[self.select_screen.current_page][i][j - 1] ~= value then
          -- detect how many blocks the special value spans
          if j ~= select_screen.COLUMNS then
            for u = j + 1, select_screen.COLUMNS do
              if self.select_screen.drawMap[self.select_screen.current_page][i][u] == value then
                span_width = span_width + 1
              else
                break
              end
            end
          end
        else
          -- has already been drawn
          span_width = 0
        end
      end

      if span_width ~= 0 then
        self:drawButton(i, j, span_width, 1, value, "center", self.v_align_center[value] and "center" or "top")
      end
    end
  end

  self:drawPlayerInfo()
  self:drawMatchTypeString()
  self:drawPagingIndicator()
  self:draw1pRecords()
end

function select_screen_graphics.drawPlayerInfo(self)
  -- Draw the player information buttons
  self:drawButton(0, 1, 1, 1, "P1", "center")
  assert(GAME.battleRoom, "need battle room")
  assert(self.select_screen.my_player_number and (self.select_screen.my_player_number == 1 or self.select_screen.my_player_number == 2), "need number")
  local my_rating_difference, op_rating_difference = self:calculateRatingDiffBetweenGames()
  self:drawButton(0, 2, 2, 1, self:get_player_state_str(self.select_screen.my_player_number, my_rating_difference, GAME.battleRoom.playerWinCounts[self.select_screen.my_player_number], GAME.battleRoom.playerWinCounts[self.select_screen.op_player_number], self.select_screen.my_expected_win_ratio), "left", "top", true)
  if self.select_screen.players[self.select_screen.my_player_number] and GAME.battleRoom.playerNames[2] then
    self:drawButton(0, 7, 1, 1, "P2", "center")
    self:drawButton(0, 8, 2, 1, self:get_player_state_str(self.select_screen.op_player_number, op_rating_difference, GAME.battleRoom.playerWinCounts[self.select_screen.op_player_number], GAME.battleRoom.playerWinCounts[self.select_screen.my_player_number], self.select_screen.op_expected_win_ratio), "left", "top", true)
  end
end

function select_screen_graphics.calculateRatingDiffBetweenGames(self)
  -- Calculate the rating difference
  local my_rating_difference = ""
  local op_rating_difference = ""
  if current_server_supports_ranking and not self.select_screen.currentRoomRatings[self.select_screen.my_player_number].placement_match_progress then
    if self.select_screen.currentRoomRatings[self.select_screen.my_player_number].difference then
      if self.select_screen.currentRoomRatings[self.select_screen.my_player_number].difference >= 0 then
        my_rating_difference = "(+" .. self.select_screen.currentRoomRatings[self.select_screen.my_player_number].difference .. ") "
      else
        my_rating_difference = "(" .. self.select_screen.currentRoomRatings[self.select_screen.my_player_number].difference .. ") "
      end
    end
    if self.select_screen.currentRoomRatings[self.select_screen.op_player_number].difference then
      if self.select_screen.currentRoomRatings[self.select_screen.op_player_number].difference >= 0 then
        op_rating_difference = "(+" .. self.select_screen.currentRoomRatings[self.select_screen.op_player_number].difference .. ") "
      else
        op_rating_difference = "(" .. self.select_screen.currentRoomRatings[self.select_screen.op_player_number].difference .. ") "
      end
    end
  end
  return my_rating_difference, op_rating_difference
end

-- Returns a string with the players rating, win rate, and expected rating
function select_screen_graphics.get_player_state_str(self, player_number, rating_difference, win_count, op_win_count, expected_win_ratio)
  local state = ""
  if current_server_supports_ranking then
    state = state .. loc("ss_rating") .. " " .. (self.select_screen.currentRoomRatings[player_number].league or "")
    if not self.select_screen.currentRoomRatings[player_number].placement_match_progress then
      state = state .. "\n" .. rating_difference .. self.select_screen.currentRoomRatings[player_number].new
    elseif self.select_screen.currentRoomRatings[player_number].placement_match_progress and self.select_screen.currentRoomRatings[player_number].new and self.select_screen.currentRoomRatings[player_number].new == 0 then
      state = state .. "\n" .. self.select_screen.currentRoomRatings[player_number].placement_match_progress
    end
  end
  if self.select_screen:isMultiplayer() then
    if current_server_supports_ranking then
      state = state .. "\n"
    end
    state = state .. loc("ss_wins") .. " " .. win_count
    if (current_server_supports_ranking and expected_win_ratio) or win_count + op_win_count > 0 then
      state = state .. "\n" .. loc("ss_winrate") .. "\n"
      local need_line_return = false
      if win_count + op_win_count > 0 then
        state = state .. "    " .. loc("ss_current_rating") .. " " .. (100 * round(win_count / (op_win_count + win_count), 2)) .. "%"
        need_line_return = true
      end
      if current_server_supports_ranking and expected_win_ratio then
        if need_line_return then
          state = state .. "\n"
        end
        state = state .. "    " .. loc("ss_expected_rating") .. " " .. expected_win_ratio .. "%"
      end
    end
  end
  return state
end

function select_screen_graphics.drawMatchTypeString(self)
  -- Draw the current match type result
  if self.select_screen:isNetPlay() then
    local match_type_str = ""
    if match_type == "Casual" then
      match_type_str = loc("ss_casual")
    elseif match_type == "Ranked" then
      match_type_str = loc("ss_ranked")
    end
    gprintf(match_type_str, 0, 15, canvas_width, "center")
    gprintf(match_type_message, 0, 30, canvas_width, "center")
  end
end

function select_screen_graphics.drawPagingIndicator(self)
  -- Draw an indicator that there are more character pages
  if self.select_screen.pages_amount ~= 1 then
    gprintf(loc("page") .. " " .. self.select_screen.current_page .. "/" .. self.select_screen.pages_amount, 0, 660, canvas_width, "center")
  end
end

function select_screen_graphics.draw1pRecords(self)
  -- Draw the current score and record
  if self.select_screen.character_select_mode == "1p_vs_yourself" and not GAME.battleRoom.trainingModeSettings then
    local xPosition1 = 196
    local xPosition2 = 320
    local yPosition = 24
    local lastScore = tostring(GAME.scores:lastVsScoreForLevel(self.select_screen.players[self.select_screen.my_player_number].level))
    local record = tostring(GAME.scores:recordVsScoreForLevel(self.select_screen.players[self.select_screen.my_player_number].level))
    draw_pixel_font("last lines", themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition, 0.5, 1.0)
    draw_pixel_font(lastScore,    themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition1, yPosition + 24, 0.5, 1.0)
    draw_pixel_font("record",     themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition, 0.5, 1.0)
    draw_pixel_font(record,       themes[config.theme].images.IMG_pixelFont_blue_atlas, standard_pixel_font_map(), xPosition2, yPosition + 24, 0.5, 1.0)
  end
end

-- Draws a button for the select screen.
  -- x grid position to draw in
  -- y grid position to draw in
  -- w number of grids wide
  -- h number of grids high
  -- str the type of button to draw
  -- halign, valign alignment
  -- set no_rect to false to hide the border
  function select_screen_graphics.drawButton(self, x, y, w, h, str, halign, valign, no_rect)
    self.x_padding = math.floor((canvas_width - self.menu_width) / 2)
    self.y_padding = math.floor((canvas_height - self.menu_height) / 2)
    self.render_x = self.x_padding + (y - 1) * 100 + self.spacing
    self.render_y = self.y_padding + (x - 1) * 100 + self.spacing
    self.button_width = w * 100 - 2 * self.spacing
    self.button_height = h * 100 - 2 * self.spacing
    no_rect = no_rect or str == "__Empty" or str == "__Reserved"
    if no_rect == false then
      grectangle("line", self.render_x, self.render_y, self.button_width, self.button_height)
    end
    local character = characters[str]
    if str == "P1" then
      if self.select_screen.players[self.select_screen.my_player_number].selectedCharacter then
        if self.select_screen.players[self.select_screen.my_player_number].selectedCharacter == random_character_special_value then
          character = random_character_special_value
        else
          character = characters[self.select_screen.players[self.select_screen.my_player_number].selectedCharacter]
        end
      else
        character = characters[self.select_screen.players[self.select_screen.my_player_number].character]
      end
    elseif str == "P2" then
      if self.select_screen.players[self.select_screen.op_player_number].selectedCharacter then
        if self.select_screen.players[self.select_screen.op_player_number].selectedCharacter == random_character_special_value then
          character = random_character_special_value
        else
          character = characters[self.select_screen.players[self.select_screen.op_player_number].selectedCharacter]
        end
      else
        character = characters[self.select_screen.players[self.select_screen.op_player_number].character]
      end
    end
    local width_for_alignment =self.button_width
    local x_add, y_add = 0, 0
    if valign == "center" then
      y_add = math.floor(0.5 * self.button_height - 0.5 * self.text_height) - 3
    elseif valign == "bottom" then
      y_add = math.floor(self.button_height - self.text_height)
    end

    if character then
      self:draw_character(character)
    end

    -- Based on the string type, render the right type of button
    local pstr
    if string.sub(str, 1, 2) == "__" then
      pstr = string.sub(str, 3)
    end
    if str == "__Mode" then
      if (self.select_screen:isMultiplayer()) then
        self:draw_match_type(self.select_screen.players[self.select_screen.my_player_number], 1, 0.4 * self.button_height)
        self:draw_match_type(self.select_screen.players[self.select_screen.op_player_number], 2, 0.7 * self.button_height)
      else
        self:draw_match_type(self.select_screen.players[self.select_screen.my_player_number], 1, 0.5 * self.button_height)
      end
    elseif str == "__Panels" then
      if (self.select_screen:isMultiplayer()) then
        self:draw_panels(self.select_screen.players[self.select_screen.my_player_number], 1, 0.4 * self.button_height)
        self:draw_panels(self.select_screen.players[self.select_screen.op_player_number], 2, 0.7 * self.button_height)
      else
        self:draw_panels(self.select_screen.players[self.select_screen.my_player_number], 1, 0.5 * self.button_height)
      end
    elseif str == "__Stage" then
      if (self.select_screen:isMultiplayer()) then
        self:draw_stage(self.select_screen.players[self.select_screen.my_player_number], 1, 0.25 * self.button_width)
        self:draw_stage(self.select_screen.players[self.select_screen.op_player_number], 2, 0.75 * self.button_width)
      else
        self:draw_stage(self.select_screen.players[self.select_screen.my_player_number], 1, 0.5 * self.button_width)
      end
    elseif str == "__Level" then
      if (self.select_screen:isMultiplayer()) then
        self:draw_levels(self.select_screen.players[self.select_screen.my_player_number], 1, 0.4 * self.button_height)
        self:draw_levels(self.select_screen.players[self.select_screen.op_player_number], 2, 0.7 * self.button_height)
      else
        self:draw_levels(self.select_screen.players[self.select_screen.my_player_number], 1, 0.5 * self.button_height)
      end
    elseif str == "P1" then
      self:draw_player(self.select_screen.players[self.select_screen.my_player_number], 1)
      pstr = GAME.battleRoom.playerNames[1]
    elseif str == "P2" then
      self:draw_player(self.select_screen.players[self.select_screen.op_player_number], 2)
      pstr = GAME.battleRoom.playerNames[2]
    elseif character and character ~= random_character_special_value then
      pstr = character.display_name
    elseif string.sub(str, 1, 2) ~= "__" then -- catch random_character_special_value case
      pstr = str:gsub("^%l", string.upper)
    end
    if x ~= 0 then
      if self.select_screen.players[self.select_screen.my_player_number] and self.select_screen.players[self.select_screen.my_player_number].cursor.positionId == str and ((str ~= "__Empty" and str ~= "__Reserved") or (self.select_screen.players[self.select_screen.my_player_number].cursor.position[1] == x and self.select_screen.players[self.select_screen.my_player_number].cursor.position[2] == y)) then
        self:draw_cursor(self.button_height, self.spacing, 1, self.select_screen.players[self.select_screen.my_player_number].ready)
        if self.select_screen.players[self.select_screen.my_player_number].cursor.can_super_select then
          self:draw_super_select(1)
        end
      end
      if self.select_screen:isMultiplayer() and self.select_screen.players[self.select_screen.op_player_number] and self.select_screen.players[self.select_screen.op_player_number].cursor.positionId == str and ((str ~= "__Empty" and str ~= "__Reserved") or (self.select_screen.players[self.select_screen.op_player_number].cursor.position[1] == x and self.select_screen.players[self.select_screen.op_player_number].cursor.position[2] == y)) then
        self:draw_cursor(self.button_height, self.spacing, 2, self.select_screen.players[self.select_screen.op_player_number].ready)
        if self.select_screen.players[self.select_screen.op_player_number].cursor.can_super_select then
          self:draw_super_select(2)
        end
      end
    end
    if str ~= "__Empty" and str ~= "__Reserved" then
      local loc_str = {Level = loc("level"), Mode = loc("mode"), Stage = loc("stage"), Panels = loc("panels"), Ready = loc("ready"), Random = loc("random"), Leave = loc("leave")}
      local to_p = loc_str[pstr]

      if character and character ~= random_character_special_value then
        local height = 17
        grectangle_color("fill", self.render_x / GFX_SCALE, (self.render_y + y_add) / GFX_SCALE, self.button_width/GFX_SCALE, height/GFX_SCALE, 0, 0, 0, 0.5)
        x_add = 0.025 * self.button_width
        width_for_alignment = 0.95 * self.button_width
      end

      gprintf(not to_p and pstr or to_p, self.render_x + x_add, self.render_y + y_add, width_for_alignment, halign)
    end
  end

  
-- Draw the character icon at the current button using globals *gross*
function select_screen_graphics.draw_character(self, character)
  -- draw character icon with its super selection or bundle character icon
  if character == random_character_special_value or not character:is_bundle() or character.images.icon then
    local icon_to_use = character == random_character_special_value and themes[config.theme].images.IMG_random_character or character.images.icon
    local orig_w, orig_h = icon_to_use:getDimensions()
    local scale = self.button_width / math.max(orig_w, orig_h) -- keep image ratio
    menu_drawf(icon_to_use, self.render_x + 0.5 * self.button_width, self.render_y + 0.5 * self.button_height, "center", "center", 0, scale, scale)
    if str ~= "P1" and str ~= "P2" then
      if character.stage then
        local orig_w, orig_h = stages[character.stage].images.thumbnail:getDimensions()
        menu_drawf(stages[character.stage].images.thumbnail, self.render_x + 10, self.render_y + self.button_height - 7, "center", "center", 0, 16 / orig_w, 9 / orig_h)
      end
      if character.panels then
        local orig_w, orig_h = panels[character.panels].images.classic[1][1]:getDimensions()
        menu_drawf(panels[character.panels].images.classic[1][1], self.render_x + 7, character.stage and self.render_y + self.button_height - 19 or self.render_y + self.button_height - 6, "center", "center", 0, 12 / orig_w, 12 / orig_h)
      end
    end
  elseif character and character:is_bundle() then -- draw bundle character generated thumbnails
    local sub_characters = character.sub_characters
    local sub_characters_count = math.min(4, #sub_characters) -- between 2 and 4 (inclusive), by design

    local thumbnail_1 = characters[sub_characters[1]].images.icon
    local thumb_y_padding = 0.25 * self.button_height
    local thumb_1_and_2_y_padding = sub_characters_count >= 3 and -thumb_y_padding or 0
    local scale_1 = self.button_width * 0.5 / math.max(thumbnail_1:getWidth(), thumbnail_1:getHeight())
    menu_drawf(thumbnail_1, self.render_x + 0.25 * self.button_width, self.render_y + 0.5 * self.button_height + thumb_1_and_2_y_padding, "center", "center", 0, scale_1, scale_1)

    local thumbnail_2 = characters[sub_characters[2]].images.icon
    local scale_2 = self.button_width * 0.5 / math.max(thumbnail_2:getWidth(), thumbnail_2:getHeight())
    menu_drawf(thumbnail_2, self.render_x + 0.75 * self.button_width, self.render_y + 0.5 * self.button_height + thumb_1_and_2_y_padding, "center", "center", 0, scale_2, scale_2)

    if sub_characters_count >= 3 then
      local thumbnail_3 = characters[sub_characters[3]].images.icon
      local scale_3 = self.button_width * 0.5 / math.max(thumbnail_3:getWidth(), thumbnail_3:getHeight())
      local thumb_3_x_padding = sub_characters_count == 3 and 0.25 * self.button_width or 0
      menu_drawf(thumbnail_3, self.render_x + 0.25 * self.button_width + thumb_3_x_padding, self.render_y + 0.75 * self.button_height, "center", "center", 0, scale_3, scale_3)
    end
    if sub_characters_count == 4 then
      local thumbnail_4 = characters[sub_characters[4]].images.icon
      local scale_4 = self.button_width * 0.5 / math.max(thumbnail_4:getWidth(), thumbnail_4:getHeight())
      menu_drawf(thumbnail_4, self.render_x + 0.75 * self.button_width, self.render_y + 0.75 * self.button_height, "center", "center", 0, scale_4, scale_4)
    end
  end

  -- draw flag in the bottom-right corner
  if character and character ~= random_character_special_value and character.flag then
    local flag_icon = themes[config.theme].images.flags[character.flag]
    if flag_icon then
      local orig_w, orig_h = flag_icon:getDimensions()
      local scale = 0.2 * self.button_width / orig_w -- keep image ratio
      menu_drawf(flag_icon, self.render_x + self.button_width - 1, self.render_y + self.button_height - 1, "right", "bottom", 0, scale, scale)
    end
  end
end

-- Draws the players "flashing ready" effect on their current cursor
function select_screen_graphics.draw_super_select(self, player_num)
  local super_select_pixelcode = [[
      uniform float percent;
      vec4 effect( vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords )
      {
          vec4 c = Texel(tex, texture_coords) * color;
          if( texture_coords.x < percent )
          {
            return c;
          }
          float ret = (c.x+c.y+c.z)/3.0;
          return vec4(ret, ret, ret, c.a);
      }
  ]]

  -- one per player, should we put them into cursor_data even though it's meaningless?
  local super_select_shaders = {love.graphics.newShader(super_select_pixelcode), love.graphics.newShader(super_select_pixelcode)}

  local ratio = select_being_pressed_ratio(player_num)
  if ratio > super_selection_enable_ratio then
    super_select_shaders[player_num]:send("percent", linear_smooth(ratio, super_selection_enable_ratio, 1.0))
    set_shader(super_select_shaders[player_num])
    menu_drawf(themes[config.theme].images.IMG_super, self.render_x +self.button_width * 0.5, self.render_y + self.button_height * 0.5, "center", "center")
    set_shader()
  end
end

-- Draw the base cursor for the player
function select_screen_graphics.draw_cursor(self, button_height, spacing, player_num, ready)
  local cur_blink_frequency = 4
  local cur_pos_change_frequency = 8
  local draw_cur_this_frame = false
  local cursor_frame = 1
  if ready then
    if (math.floor(self.select_screen.menu_clock / cur_blink_frequency) + player_num) % 2 + 1 == player_num then
      draw_cur_this_frame = true
    end
  else
    draw_cur_this_frame = true
    cursor_frame = (math.floor(self.select_screen.menu_clock / cur_pos_change_frequency) + player_num) % 2 + 1
  end
  if draw_cur_this_frame then
    local cur_img = themes[config.theme].images.IMG_char_sel_cursors[player_num][cursor_frame]
    local cur_img_left = themes[config.theme].images.IMG_char_sel_cursor_halves.left[player_num][cursor_frame]
    local cur_img_right = themes[config.theme].images.IMG_char_sel_cursor_halves.right[player_num][cursor_frame]
    local cur_img_w, cur_img_h = cur_img:getDimensions()
    local cursor_scale = (button_height + (spacing * 2)) / cur_img_h
    menu_drawq(cur_img, cur_img_left, self.render_x - spacing, self.render_y - spacing, 0, cursor_scale, cursor_scale)
    menu_drawq(cur_img, cur_img_right, self.render_x + self.button_width + spacing - cur_img_w * cursor_scale / 2, self.render_y - spacing, 0, cursor_scale, cursor_scale)
  end
end

-- Draw the players current character, player number etc
function select_screen_graphics.draw_player(self, player, player_number)
  if characters[player.character] and not characters[player.character].fully_loaded then
    menu_drawf(themes[config.theme].images.IMG_loading, self.render_x +self.button_width * 0.5, self.render_y + self.button_height * 0.5, "center", "center")
  elseif player.wants_ready then
    menu_drawf(themes[config.theme].images.IMG_ready, self.render_x +self.button_width * 0.5, self.render_y + self.button_height * 0.5, "center", "center")
  end
  local scale = 0.25 *self.button_width / math.max(themes[config.theme].images.IMG_players[player_number]:getWidth(), themes[config.theme].images.IMG_players[player_number]:getHeight()) -- keep image ratio
  menu_drawf(themes[config.theme].images.IMG_players[player_number], self.render_x + 1, self.render_y + self.button_height - 1, "left", "bottom", 0, scale, scale)
  scale = 0.25 *self.button_width / math.max(themes[config.theme].images.IMG_levels[player.level]:getWidth(), themes[config.theme].images.IMG_levels[player.level]:getHeight()) -- keep image ratio
  menu_drawf(themes[config.theme].images.IMG_levels[player.level], self.render_x +self.button_width - 1, self.render_y + self.button_height - 1, "right", "bottom", 0, scale, scale)
end

-- Draw the panel selection UI
function select_screen_graphics.draw_panels(self, player, player_number, y_padding)
  local panels_max_width = 0.25 * self.button_height
  local panels_width = math.min(panels_max_width, panels[player.panels_dir].images.classic[1][1]:getWidth())
  local padding_x = 0.5 *self.button_width - 3 * panels_width -- center them, not 3.5 mysteriously?
  if player.level >= 9 then
    padding_x = padding_x - 0.5 * panels_width
  end
  local is_selected = player.cursor.selected and player.cursor.positionId == "__Panels"
  if is_selected then
    padding_x = padding_x - panels_width
  end
  local panels_scale = panels_width / panels[player.panels_dir].images.classic[1][1]:getWidth()
  menu_drawf(themes[config.theme].images.IMG_players[player_number], self.render_x + padding_x, self.render_y + y_padding, "center", "center")
  padding_x = padding_x + panels_width
  if is_selected then
    gprintf("<", self.render_x + padding_x - 0.5 * panels_width, self.render_y + y_padding - 0.5 * self.text_height, panels_width, "center")
    padding_x = padding_x + panels_width
  end
  for i = 1, 8 do
    if i ~= 7 and (i ~= 6 or player.level >= 9) then
      menu_drawf(panels[player.panels_dir].images.classic[i][1], self.render_x + padding_x, self.render_y + y_padding, "center", "center", 0, panels_scale, panels_scale)
      padding_x = padding_x + panels_width
    end
  end
  if is_selected then
    gprintf(">", self.render_x + padding_x - 0.5 * panels_width, self.render_y + y_padding - 0.5 * self.text_height, panels_width, "center")
  end
end

-- Draw the difficulty level selection UI
function select_screen_graphics.draw_levels(self, player, player_number, y_padding)
  local level_max_width = 0.2 * self.button_height
  local level_width = math.min(level_max_width, themes[config.theme].images.IMG_levels[1]:getWidth())
  local padding_x = math.floor(0.5 *self.button_width - 5.5 * level_width)
  local is_selected = player.cursor.selected and player.cursor.positionId == "__Level"
  if is_selected then
    padding_x = padding_x - level_width
  end
  local level_scale = level_width / themes[config.theme].images.IMG_levels[1]:getWidth()
  menu_drawf(themes[config.theme].images.IMG_players[player_number], self.render_x + padding_x, self.render_y + y_padding, "center", "center")
  local ex_scaling = level_width / themes[config.theme].images.IMG_levels[11]:getWidth()
  menu_drawf(themes[config.theme].images.IMG_players[player_number], self.render_x + padding_x, self.render_y + y_padding, "center", "center")
  padding_x = padding_x + level_width
  if is_selected then
    gprintf("<", self.render_x + padding_x - 0.5 * level_width, self.render_y + y_padding - 0.5 * self.text_height, level_width, "center")
    padding_x = padding_x + level_width
  end
  for i = 1, #level_to_starting_speed do --which should equal the number of levels in the game
    local additional_padding = math.floor(0.5 * (themes[config.theme].images.IMG_levels[i]:getWidth() - level_width))
    padding_x = padding_x + additional_padding
    local use_unfocus = player.level < i
    if use_unfocus then
      menu_drawf(themes[config.theme].images.IMG_levels_unfocus[i], self.render_x + padding_x, self.render_y + y_padding, "center", "center", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale))
    else
      menu_drawf(themes[config.theme].images.IMG_levels[i], self.render_x + padding_x, self.render_y + y_padding, "center", "center", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale))
    end
    if i == player.level then
      menu_drawf(themes[config.theme].images.IMG_level_cursor, self.render_x + padding_x, self.render_y + y_padding + themes[config.theme].images.IMG_levels[i]:getHeight() * 0.5, "center", "top", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale))
    end
    padding_x = padding_x + level_width + additional_padding
  end
  if is_selected then
    gprintf(">", self.render_x + padding_x - 0.5 * level_width, self.render_y + y_padding - 0.5 * self.text_height, level_width, "center")
  end
end

-- Draw the Casual/Ranked selection UI
function select_screen_graphics.draw_match_type(self, player, player_number, y_padding)
  local padding_x = math.floor(0.5 *self.button_width - themes[config.theme].images.IMG_players[player_number]:getWidth() * 0.5 - 46) -- ty GIMP; no way to know the size of the text?
  menu_drawf(themes[config.theme].images.IMG_players[player_number], self.render_x + padding_x, self.render_y + y_padding, "center", "center")
  padding_x = padding_x + themes[config.theme].images.IMG_players[player_number]:getWidth()
  local to_print
  if player.ranked then
    to_print = loc("ss_casual") .. " [" .. loc("ss_ranked") .. "]"
  else
    to_print = "[" .. loc("ss_casual") .. "] " .. loc("ss_ranked")
  end
  gprint(to_print, self.render_x + padding_x, self.render_y + y_padding - 0.5 * self.text_height - 1)
end

-- Draw the stage select UI
function select_screen_graphics.draw_stage(self, player, player_number, x_padding)
  local stage_dimensions = {80, 45}
  local y_padding = math.floor(0.5 * self.button_height)
  local padding_x = math.floor(x_padding - 0.5 * stage_dimensions[1])
  local is_selected = player.cursor.selected and player.cursor.positionId == "__Stage"
  if is_selected then
    local arrow_pos = self.select_screen:isNetPlay() and {math.floor(self.render_x + x_padding - 20), math.floor(self.render_y + y_padding - stage_dimensions[2] * 0.5 - 15)} or {math.floor(self.render_x + padding_x - 13), math.floor(self.render_y + y_padding + 0.25 * self.text_height)}
    gprintf("<", arrow_pos[1], arrow_pos[2], 10, "center")
  end
  -- background for thumbnail
  grectangle("line", self.render_x + padding_x, math.floor(self.render_y + y_padding - stage_dimensions[2] * 0.5), stage_dimensions[1], stage_dimensions[2])

  -- thumbnail or composed thumbnail (for bundles without thumbnails)
  if player.selectedStage == random_stage_special_value or (player.selectedStage and not stages[player.selectedStage]) or (player.selectedStage and stages[player.selectedStage] and stages[player.selectedStage].images.thumbnail) or (not player.selectedStage and stages[player.stage].images.thumbnail) then
    local thumbnail = themes[config.theme].images.IMG_random_stage
    if player.selectedStage and stages[player.selectedStage] and stages[player.selectedStage].images.thumbnail then
      thumbnail = stages[player.selectedStage].images.thumbnail
    elseif not player.selectedStage and stages[player.stage].images.thumbnail then
      thumbnail = stages[player.stage].images.thumbnail
    end
    menu_drawf(thumbnail, self.render_x + padding_x, self.render_y + y_padding - 1, "left", "center", 0, stage_dimensions[1] / thumbnail:getWidth(), stage_dimensions[2] / thumbnail:getHeight())
  elseif player.selectedStage and stages[player.selectedStage]:is_bundle() then
    local half_stage_dimensions = {math.floor(stage_dimensions[1] * 0.5), math.floor(stage_dimensions[2] * 0.5)}
    local sub_stages = stages[player.selectedStage].sub_stages
    local sub_stages_count = math.min(4, #sub_stages) -- between 2 and 4 (inclusive), by design

    local thumbnail_1 = stages[sub_stages[1]].images.thumbnail
    local thumb_y_padding = math.floor(half_stage_dimensions[2] * 0.5)
    local thumb_1_and_2_y_padding = sub_stages_count >= 3 and -thumb_y_padding or 0
    menu_drawf(thumbnail_1, self.render_x + padding_x, self.render_y + y_padding - 1 + thumb_1_and_2_y_padding, "left", "center", 0, half_stage_dimensions[1] / thumbnail_1:getWidth(), half_stage_dimensions[2] / thumbnail_1:getHeight())

    local thumbnail_2 = stages[sub_stages[2]].images.thumbnail
    menu_drawf(thumbnail_2, self.render_x + padding_x + half_stage_dimensions[1], self.render_y + y_padding - 1 + thumb_1_and_2_y_padding, "left", "center", 0, half_stage_dimensions[1] / thumbnail_2:getWidth(), half_stage_dimensions[2] / thumbnail_2:getHeight())

    if sub_stages_count >= 3 then
      local thumbnail_3 = stages[sub_stages[3]].images.thumbnail
      local thumb_3_x_padding = sub_stages_count == 3 and math.floor(half_stage_dimensions[1] * 0.5) or 0
      menu_drawf(thumbnail_3, self.render_x + padding_x + thumb_3_x_padding, self.render_y + y_padding - 1 + thumb_y_padding, "left", "center", 0, half_stage_dimensions[1] / thumbnail_3:getWidth(), half_stage_dimensions[2] / thumbnail_3:getHeight())
    end
    if sub_stages_count == 4 then
      local thumbnail_4 = stages[sub_stages[4]].images.thumbnail
      menu_drawf(thumbnail_4, self.render_x + padding_x + half_stage_dimensions[1], self.render_y + y_padding - 1 + thumb_y_padding, "left", "center", 0, half_stage_dimensions[1] / thumbnail_4:getWidth(), half_stage_dimensions[2] / thumbnail_4:getHeight())
    end
  end

  -- player image
  local player_icon_pos = self.select_screen:isNetPlay() and {math.floor(self.render_x + padding_x + stage_dimensions[1] * 0.5), math.floor(self.render_y + y_padding - stage_dimensions[2] * 0.5 - 7)} or {math.floor(self.render_x + padding_x - 10), math.floor(self.render_y + y_padding - stage_dimensions[2] * 0.25)}
  menu_drawf(themes[config.theme].images.IMG_players[player_number], player_icon_pos[1], player_icon_pos[2], "center", "center")
  -- display name
  local display_name = nil
  if player.selectedStage == random_stage_special_value or (player.selectedStage and not stages[player.selectedStage]) then
    display_name = loc("random")
  elseif player.selectedStage then
    display_name = stages[player.selectedStage].display_name
  else
    display_name = stages[player.stage].display_name
  end
  gprintf(display_name, self.render_x + padding_x, math.floor(self.render_y + y_padding + stage_dimensions[2] * 0.5), stage_dimensions[1], "center", nil, 1, small_font)

  padding_x = padding_x + stage_dimensions[1]

  if is_selected then
    local arrow_pos = self.select_screen:isNetPlay() == "2p_net_vs" and {math.floor(self.render_x + x_padding + 11), math.floor(self.render_y + y_padding - stage_dimensions[2] * 0.5 - 15)} or {math.floor(self.render_x + padding_x + 3), math.floor(self.render_y + y_padding + 0.25 * self.text_height)}
    gprintf(">", arrow_pos[1], arrow_pos[2], 10, "center")
  end
end

return select_screen_graphics