

--#region drawing funcs

select_screen_graphics = class(function(self, state)
  self.v_align_center = {__Ready = true, __Random = true, __Leave = true}
  self.is_special_value = {__Leave = true, __Level = true, __Panels = true, __Ready = true, __Stage = true, __Mode = true, __Random = true}
  self.ROWS = 5
  self.COLUMNS = 9
end)

function select_screen_graphics.draw(self, select_screen)
  self.select_screen = select_screen

  -- Go through the grid, drawing the buttons, handling horizontal spans
  for i = 1, self.ROWS do
    for j = 1, self.COLUMNS do
      local value = self.select_screen.drawMap[self.select_screen.current_page][i][j]
      local span_width = 1
      if self.is_special_value[value] then
        if j == 1 or self.select_screen.drawMap[self.select_screen.current_page][i][j - 1] ~= value then
          -- detect how many blocks the special value spans
          if j ~= self.COLUMNS then
            for u = j + 1, self.COLUMNS do
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
        self.draw_button(i, j, span_width, 1, value, "center", self.v_align_center[value] and "center" or "top")
      end
    end
  end
end

function select_screen_graphics.drawPlayerInfo(self)
  -- Draw the player information buttons
  self.draw_button(0, 1, 1, 1, "P1")
  assert(GAME.battleRoom, "need battle room")
  assert(my_player_number and (my_player_number == 1 or my_player_number == 2), "need number")
  self.draw_button(0, 2, 2, 1, get_player_state_str(my_player_number, my_rating_difference, GAME.battleRoom.playerWinCounts[my_player_number], GAME.battleRoom.playerWinCounts[op_player_number], my_expected_win_ratio), "left", "top", true)
  if cursor_data[1].state and GAME.battleRoom.playerNames[2] then
    self.draw_button(0, 7, 1, 1, "P2")
    self.draw_button(0, 8, 2, 1, get_player_state_str(op_player_number, op_rating_difference, GAME.battleRoom.playerWinCounts[op_player_number], GAME.battleRoom.playerWinCounts[my_player_number], op_expected_win_ratio), "left", "top", true)
  --state = state.." "..json.encode(op_state)
  end
end


function select_screen_graphics.drawMatchTypeString(self)
  -- Draw the current match type result
  if select_screen:isNetPlay() then
    if not cursor_data[1].state.ranked and not cursor_data[2].state.ranked then
      match_type_message = ""
    end
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
  if select_screen.character_select_mode == "1p_vs_yourself" and not GAME.battleRoom.trainingModeSettings then
    local xPosition1 = 196
    local xPosition2 = 320
    local yPosition = 24
    local lastScore = tostring(GAME.scores:lastVsScoreForLevel(self.select_screen.roomState.players[self.select_screen.my_player_number].level))
    local record = tostring(GAME.scores:recordVsScoreForLevel(self.select_screen.roomState.players[self.select_screen.my_player_number].level))
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
  function select_screen.drawButton(self, x, y, w, h, str, halign, valign, no_rect)
    no_rect = no_rect or str == "__Empty" or str == "__Reserved"
    halign = halign or "center"
    valign = valign or "top"
    local menu_width = Y * 100
    local menu_height = X * 80
    local spacing = 8
    local text_height = 13
    local x_padding = math.floor((canvas_width - menu_width) / 2)
    local y_padding = math.floor((canvas_height - menu_height) / 2)
    set_color(unpack(colors.white))
    render_x = x_padding + (y - 1) * 100 + spacing
    render_y = y_padding + (x - 1) * 100 + spacing
    button_width = w * 100 - 2 * spacing
    button_height = h * 100 - 2 * spacing
    if no_rect == false then
      grectangle("line", render_x, render_y, button_width, button_height)
    end
    local character = characters[str]
    if str == "P1" then
      if cursor_data[1].state.character_is_random then
        if cursor_data[1].state.character_is_random == random_character_special_value then
          character = random_character_special_value
        else
          character = characters[cursor_data[1].state.character_is_random]
        end
      else
        character = characters[cursor_data[1].state.character]
      end
    elseif str == "P2" then
      if cursor_data[2].state.character_is_random then
        if cursor_data[2].state.character_is_random == random_character_special_value then
          character = random_character_special_value
        else
          character = characters[cursor_data[2].state.character_is_random]
        end
      else
        character = characters[cursor_data[2].state.character]
      end
    end
    local width_for_alignment = button_width
    local x_add, y_add = 0, 0
    if valign == "center" then
      y_add = math.floor(0.5 * button_height - 0.5 * text_height) - 3
    elseif valign == "bottom" then
      y_add = math.floor(button_height - text_height)
    end
  
    if character then
      x_add = 0.025 * button_width
      width_for_alignment = 0.95 * button_width
      draw_character(character)
    end
  
    -- Based on the string type, render the right type of button
    local pstr
    if string.sub(str, 1, 2) == "__" then
      pstr = string.sub(str, 3)
    end
    if str == "__Mode" then
      if (select_screen:isMultiplayer()) then
        draw_match_type(cursor_data[1], 1, 0.4 * button_height)
        draw_match_type(cursor_data[2], 2, 0.7 * button_height)
      else
        draw_match_type(cursor_data[1], 1, 0.5 * button_height)
      end
    elseif str == "__Panels" then
      if (select_screen:isMultiplayer()) then
        draw_panels(cursor_data[1], 1, 0.4 * button_height)
        draw_panels(cursor_data[2], 2, 0.7 * button_height)
      else
        draw_panels(cursor_data[1], 1, 0.5 * button_height)
      end
    elseif str == "__Stage" then
      if (select_screen:isMultiplayer()) then
        draw_stage(cursor_data[1], 1, 0.25 * button_width)
        draw_stage(cursor_data[2], 2, 0.75 * button_width)
      else
        draw_stage(cursor_data[1], 1, 0.5 * button_width)
      end
    elseif str == "__Level" then
      if (select_screen:isMultiplayer()) then
        draw_levels(cursor_data[1], 1, 0.4 * button_height)
        draw_levels(cursor_data[2], 2, 0.7 * button_height)
      else
        draw_levels(cursor_data[1], 1, 0.5 * button_height)
      end
    elseif str == "P1" then
      draw_player_state(cursor_data[1], 1)
      pstr = GAME.battleRoom.playerNames[1]
    elseif str == "P2" then
      draw_player_state(cursor_data[2], 2)
      pstr = GAME.battleRoom.playerNames[2]
    elseif character and character ~= random_character_special_value then
      pstr = character.display_name
    elseif string.sub(str, 1, 2) ~= "__" then -- catch random_character_special_value case
      pstr = str:gsub("^%l", string.upper)
    end
    if x ~= 0 then
      if cursor_data[1].state and cursor_data[1].state.cursor == str and ((str ~= "__Empty" and str ~= "__Reserved") or (cursor_data[1].position[1] == x and cursor_data[1].position[2] == y)) then
        draw_cursor(button_height, spacing, 1, cursor_data[1].state.ready)
        if cursor_data[1].can_super_select then
          draw_super_select(1)
        end
      end
      if select_screen:isMultiplayer() and cursor_data[2].state and cursor_data[2].state.cursor == str and ((str ~= "__Empty" and str ~= "__Reserved") or (cursor_data[2].position[1] == x and cursor_data[2].position[2] == y)) then
        draw_cursor(button_height, spacing, 2, cursor_data[2].state.ready)
        if cursor_data[2].can_super_select then
          draw_super_select(2)
        end
      end
    end
    if str ~= "__Empty" and str ~= "__Reserved" then
      local loc_str = {Level = loc("level"), Mode = loc("mode"), Stage = loc("stage"), Panels = loc("panels"), Ready = loc("ready"), Random = loc("random"), Leave = loc("leave")}
      local to_p = loc_str[pstr]
      gprintf(not to_p and pstr or to_p, render_x + x_add, render_y + y_add, width_for_alignment, halign)
    end
  end

  
-- Draw the character icon at the current button using globals *gross*
function select_screen.draw_character(character)
  -- draw character icon with its super selection or bundle character icon
  if character == random_character_special_value or not character:is_bundle() or character.images.icon then
    local icon_to_use = character == random_character_special_value and themes[config.theme].images.IMG_random_character or character.images.icon
    local orig_w, orig_h = icon_to_use:getDimensions()
    local scale = button_width / math.max(orig_w, orig_h) -- keep image ratio
    menu_drawf(icon_to_use, render_x + 0.5 * button_width, render_y + 0.5 * button_height, "center", "center", 0, scale, scale)
    if str ~= "P1" and str ~= "P2" then
      if character.stage then
        local orig_w, orig_h = stages[character.stage].images.thumbnail:getDimensions()
        menu_drawf(stages[character.stage].images.thumbnail, render_x + 10, render_y + button_height - 7, "center", "center", 0, 16 / orig_w, 9 / orig_h)
      end
      if character.panels then
        local orig_w, orig_h = panels[character.panels].images.classic[1][1]:getDimensions()
        menu_drawf(panels[character.panels].images.classic[1][1], render_x + 7, character.stage and render_y + button_height - 19 or render_y + button_height - 6, "center", "center", 0, 12 / orig_w, 12 / orig_h)
      end
    end
  elseif character and character:is_bundle() then -- draw bundle character generated thumbnails
    local sub_characters = character.sub_characters
    local sub_characters_count = math.min(4, #sub_characters) -- between 2 and 4 (inclusive), by design

    local thumbnail_1 = characters[sub_characters[1]].images.icon
    local thumb_y_padding = 0.25 * button_height
    local thumb_1_and_2_y_padding = sub_characters_count >= 3 and -thumb_y_padding or 0
    local scale_1 = button_width * 0.5 / math.max(thumbnail_1:getWidth(), thumbnail_1:getHeight())
    menu_drawf(thumbnail_1, render_x + 0.25 * button_width, render_y + 0.5 * button_height + thumb_1_and_2_y_padding, "center", "center", 0, scale_1, scale_1)

    local thumbnail_2 = characters[sub_characters[2]].images.icon
    local scale_2 = button_width * 0.5 / math.max(thumbnail_2:getWidth(), thumbnail_2:getHeight())
    menu_drawf(thumbnail_2, render_x + 0.75 * button_width, render_y + 0.5 * button_height + thumb_1_and_2_y_padding, "center", "center", 0, scale_2, scale_2)

    if sub_characters_count >= 3 then
      local thumbnail_3 = characters[sub_characters[3]].images.icon
      local scale_3 = button_width * 0.5 / math.max(thumbnail_3:getWidth(), thumbnail_3:getHeight())
      local thumb_3_x_padding = sub_characters_count == 3 and 0.25 * button_width or 0
      menu_drawf(thumbnail_3, render_x + 0.25 * button_width + thumb_3_x_padding, render_y + 0.75 * button_height, "center", "center", 0, scale_3, scale_3)
    end
    if sub_characters_count == 4 then
      local thumbnail_4 = characters[sub_characters[4]].images.icon
      local scale_4 = button_width * 0.5 / math.max(thumbnail_4:getWidth(), thumbnail_4:getHeight())
      menu_drawf(thumbnail_4, render_x + 0.75 * button_width, render_y + 0.75 * button_height, "center", "center", 0, scale_4, scale_4)
    end
  end

  -- draw flag in the bottom-right corner
  if character and character ~= random_character_special_value and character.flag then
    local flag_icon = themes[config.theme].images.flags[character.flag]
    if flag_icon then
      local orig_w, orig_h = flag_icon:getDimensions()
      local scale = 0.2 * button_width / orig_w -- keep image ratio
      menu_drawf(flag_icon, render_x + button_width - 1, render_y + button_height - 1, "right", "bottom", 0, scale, scale)
    end
  end
end

-- Draws the players "flashing ready" effect on their current cursor
function select_screen.draw_super_select(player_num)
  local ratio = select_being_pressed_ratio(player_num)
  if ratio > super_selection_enable_ratio then
    super_select_shaders[player_num]:send("percent", linear_smooth(ratio, super_selection_enable_ratio, 1.0))
    set_shader(super_select_shaders[player_num])
    menu_drawf(themes[config.theme].images.IMG_super, render_x + button_width * 0.5, render_y + button_height * 0.5, "center", "center")
    set_shader()
  end
end

-- Draw the base cursor for the player
function select_screen.draw_cursor(button_height, spacing, player_num, ready)
  local cur_blink_frequency = 4
  local cur_pos_change_frequency = 8
  local draw_cur_this_frame = false
  local cursor_frame = 1
  if ready then
    if (math.floor(menu_clock / cur_blink_frequency) + player_num) % 2 + 1 == player_num then
      draw_cur_this_frame = true
    end
  else
    draw_cur_this_frame = true
    cursor_frame = (math.floor(menu_clock / cur_pos_change_frequency) + player_num) % 2 + 1
  end
  if draw_cur_this_frame then
    local cur_img = themes[config.theme].images.IMG_char_sel_cursors[player_num][cursor_frame]
    local cur_img_left = themes[config.theme].images.IMG_char_sel_cursor_halves.left[player_num][cursor_frame]
    local cur_img_right = themes[config.theme].images.IMG_char_sel_cursor_halves.right[player_num][cursor_frame]
    local cur_img_w, cur_img_h = cur_img:getDimensions()
    local cursor_scale = (button_height + (spacing * 2)) / cur_img_h
    menu_drawq(cur_img, cur_img_left, render_x - spacing, render_y - spacing, 0, cursor_scale, cursor_scale)
    menu_drawq(cur_img, cur_img_right, render_x + button_width + spacing - cur_img_w * cursor_scale / 2, render_y - spacing, 0, cursor_scale, cursor_scale)
  end
end

-- Draw the players current character, player number etc
function select_screen.draw_player_state(cursor_data, player_number)
  if characters[cursor_data.state.character] and not characters[cursor_data.state.character].fully_loaded then
    menu_drawf(themes[config.theme].images.IMG_loading, render_x + button_width * 0.5, render_y + button_height * 0.5, "center", "center")
  elseif cursor_data.state.wants_ready then
    menu_drawf(themes[config.theme].images.IMG_ready, render_x + button_width * 0.5, render_y + button_height * 0.5, "center", "center")
  end
  local scale = 0.25 * button_width / math.max(themes[config.theme].images.IMG_players[player_number]:getWidth(), themes[config.theme].images.IMG_players[player_number]:getHeight()) -- keep image ratio
  menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x + 1, render_y + button_height - 1, "left", "bottom", 0, scale, scale)
  scale = 0.25 * button_width / math.max(themes[config.theme].images.IMG_levels[cursor_data.state.level]:getWidth(), themes[config.theme].images.IMG_levels[cursor_data.state.level]:getHeight()) -- keep image ratio
  menu_drawf(themes[config.theme].images.IMG_levels[cursor_data.state.level], render_x + button_width - 1, render_y + button_height - 1, "right", "bottom", 0, scale, scale)
end

-- Draw the panel selection UI
function select_screen.draw_panels(cursor_data, player_number, y_padding)
  local panels_max_width = 0.25 * button_height
  local panels_width = math.min(panels_max_width, panels[cursor_data.state.panels_dir].images.classic[1][1]:getWidth())
  local padding_x = 0.5 * button_width - 3 * panels_width -- center them, not 3.5 mysteriously?
  if cursor_data.state.level >= 9 then
    padding_x = padding_x - 0.5 * panels_width
  end
  local is_selected = cursor_data.selected and cursor_data.state.cursor == "__Panels"
  if is_selected then
    padding_x = padding_x - panels_width
  end
  local panels_scale = panels_width / panels[cursor_data.state.panels_dir].images.classic[1][1]:getWidth()
  menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x + padding_x, render_y + y_padding, "center", "center")
  padding_x = padding_x + panels_width
  if is_selected then
    gprintf("<", render_x + padding_x - 0.5 * panels_width, render_y + y_padding - 0.5 * text_height, panels_width, "center")
    padding_x = padding_x + panels_width
  end
  for i = 1, 8 do
    if i ~= 7 and (i ~= 6 or cursor_data.state.level >= 9) then
      menu_drawf(panels[cursor_data.state.panels_dir].images.classic[i][1], render_x + padding_x, render_y + y_padding, "center", "center", 0, panels_scale, panels_scale)
      padding_x = padding_x + panels_width
    end
  end
  if is_selected then
    gprintf(">", render_x + padding_x - 0.5 * panels_width, render_y + y_padding - 0.5 * text_height, panels_width, "center")
  end
end

-- Draw the difficulty level selection UI
function select_screen.draw_levels(cursor_data, player_number, y_padding)
  local level_max_width = 0.2 * button_height
  local level_width = math.min(level_max_width, themes[config.theme].images.IMG_levels[1]:getWidth())
  local padding_x = math.floor(0.5 * button_width - 5.5 * level_width)
  local is_selected = cursor_data.selected and cursor_data.state.cursor == "__Level"
  if is_selected then
    padding_x = padding_x - level_width
  end
  local level_scale = level_width / themes[config.theme].images.IMG_levels[1]:getWidth()
  menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x + padding_x, render_y + y_padding, "center", "center")
  local ex_scaling = level_width / themes[config.theme].images.IMG_levels[11]:getWidth()
  menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x + padding_x, render_y + y_padding, "center", "center")
  padding_x = padding_x + level_width
  if is_selected then
    gprintf("<", render_x + padding_x - 0.5 * level_width, render_y + y_padding - 0.5 * text_height, level_width, "center")
    padding_x = padding_x + level_width
  end
  for i = 1, #level_to_starting_speed do --which should equal the number of levels in the game
    local additional_padding = math.floor(0.5 * (themes[config.theme].images.IMG_levels[i]:getWidth() - level_width))
    padding_x = padding_x + additional_padding
    local use_unfocus = cursor_data.state.level < i
    if use_unfocus then
      menu_drawf(themes[config.theme].images.IMG_levels_unfocus[i], render_x + padding_x, render_y + y_padding, "center", "center", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale))
    else
      menu_drawf(themes[config.theme].images.IMG_levels[i], render_x + padding_x, render_y + y_padding, "center", "center", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale))
    end
    if i == cursor_data.state.level then
      menu_drawf(themes[config.theme].images.IMG_level_cursor, render_x + padding_x, render_y + y_padding + themes[config.theme].images.IMG_levels[i]:getHeight() * 0.5, "center", "top", 0, (i == 11 and ex_scaling or level_scale), (i == 11 and ex_scaling or level_scale))
    end
    padding_x = padding_x + level_width + additional_padding
  end
  if is_selected then
    gprintf(">", render_x + padding_x - 0.5 * level_width, render_y + y_padding - 0.5 * text_height, level_width, "center")
  end
end

-- Draw the Casual/Ranked selection UI
function select_screen.draw_match_type(cursor_data, player_number, y_padding)
  local padding_x = math.floor(0.5 * button_width - themes[config.theme].images.IMG_players[player_number]:getWidth() * 0.5 - 46) -- ty GIMP; no way to know the size of the text?
  menu_drawf(themes[config.theme].images.IMG_players[player_number], render_x + padding_x, render_y + y_padding, "center", "center")
  padding_x = padding_x + themes[config.theme].images.IMG_players[player_number]:getWidth()
  local to_print
  if cursor_data.state.ranked then
    to_print = loc("ss_casual") .. " [" .. loc("ss_ranked") .. "]"
  else
    to_print = "[" .. loc("ss_casual") .. "] " .. loc("ss_ranked")
  end
  gprint(to_print, render_x + padding_x, render_y + y_padding - 0.5 * text_height - 1)
end

-- Draw the stage select UI
function select_screen.draw_stage(self, cursor_data, player_number, x_padding)
  local stage_dimensions = {80, 45}
  local y_padding = math.floor(0.5 * button_height)
  local padding_x = math.floor(x_padding - 0.5 * stage_dimensions[1])
  local is_selected = cursor_data.selected and cursor_data.state.cursor == "__Stage"
  if is_selected then
    local arrow_pos = select_screen:isNetPlay() and {math.floor(render_x + x_padding - 20), math.floor(render_y + y_padding - stage_dimensions[2] * 0.5 - 15)} or {math.floor(render_x + padding_x - 13), math.floor(render_y + y_padding + 0.25 * text_height)}
    gprintf("<", arrow_pos[1], arrow_pos[2], 10, "center")
  end
  -- background for thumbnail
  grectangle("line", render_x + padding_x, math.floor(render_y + y_padding - stage_dimensions[2] * 0.5), stage_dimensions[1], stage_dimensions[2])

  -- thumbnail or composed thumbnail (for bundles without thumbnails)
  if cursor_data.state.stage_is_random == random_stage_special_value or (cursor_data.state.stage_is_random and not stages[cursor_data.state.stage_is_random]) or (cursor_data.state.stage_is_random and stages[cursor_data.state.stage_is_random] and stages[cursor_data.state.stage_is_random].images.thumbnail) or (not cursor_data.state.stage_is_random and stages[cursor_data.state.stage].images.thumbnail) then
    local thumbnail = themes[config.theme].images.IMG_random_stage
    if cursor_data.state.stage_is_random and stages[cursor_data.state.stage_is_random] and stages[cursor_data.state.stage_is_random].images.thumbnail then
      thumbnail = stages[cursor_data.state.stage_is_random].images.thumbnail
    elseif not cursor_data.state.stage_is_random and stages[cursor_data.state.stage].images.thumbnail then
      thumbnail = stages[cursor_data.state.stage].images.thumbnail
    end
    menu_drawf(thumbnail, render_x + padding_x, render_y + y_padding - 1, "left", "center", 0, stage_dimensions[1] / thumbnail:getWidth(), stage_dimensions[2] / thumbnail:getHeight())
  elseif cursor_data.state.stage_is_random and stages[cursor_data.state.stage_is_random]:is_bundle() then
    local half_stage_dimensions = {math.floor(stage_dimensions[1] * 0.5), math.floor(stage_dimensions[2] * 0.5)}
    local sub_stages = stages[cursor_data.state.stage_is_random].sub_stages
    local sub_stages_count = math.min(4, #sub_stages) -- between 2 and 4 (inclusive), by design

    local thumbnail_1 = stages[sub_stages[1]].images.thumbnail
    local thumb_y_padding = math.floor(half_stage_dimensions[2] * 0.5)
    local thumb_1_and_2_y_padding = sub_stages_count >= 3 and -thumb_y_padding or 0
    menu_drawf(thumbnail_1, render_x + padding_x, render_y + y_padding - 1 + thumb_1_and_2_y_padding, "left", "center", 0, half_stage_dimensions[1] / thumbnail_1:getWidth(), half_stage_dimensions[2] / thumbnail_1:getHeight())

    local thumbnail_2 = stages[sub_stages[2]].images.thumbnail
    menu_drawf(thumbnail_2, render_x + padding_x + half_stage_dimensions[1], render_y + y_padding - 1 + thumb_1_and_2_y_padding, "left", "center", 0, half_stage_dimensions[1] / thumbnail_2:getWidth(), half_stage_dimensions[2] / thumbnail_2:getHeight())

    if sub_stages_count >= 3 then
      local thumbnail_3 = stages[sub_stages[3]].images.thumbnail
      local thumb_3_x_padding = sub_stages_count == 3 and math.floor(half_stage_dimensions[1] * 0.5) or 0
      menu_drawf(thumbnail_3, render_x + padding_x + thumb_3_x_padding, render_y + y_padding - 1 + thumb_y_padding, "left", "center", 0, half_stage_dimensions[1] / thumbnail_3:getWidth(), half_stage_dimensions[2] / thumbnail_3:getHeight())
    end
    if sub_stages_count == 4 then
      local thumbnail_4 = stages[sub_stages[4]].images.thumbnail
      menu_drawf(thumbnail_4, render_x + padding_x + half_stage_dimensions[1], render_y + y_padding - 1 + thumb_y_padding, "left", "center", 0, half_stage_dimensions[1] / thumbnail_4:getWidth(), half_stage_dimensions[2] / thumbnail_4:getHeight())
    end
  end

  -- player image
  local player_icon_pos = select_screen:isNetPlay() and {math.floor(render_x + padding_x + stage_dimensions[1] * 0.5), math.floor(render_y + y_padding - stage_dimensions[2] * 0.5 - 7)} or {math.floor(render_x + padding_x - 10), math.floor(render_y + y_padding - stage_dimensions[2] * 0.25)}
  menu_drawf(themes[config.theme].images.IMG_players[player_number], player_icon_pos[1], player_icon_pos[2], "center", "center")
  -- display name
  local display_name = nil
  if cursor_data.state.stage_is_random == random_stage_special_value or (cursor_data.state.stage_is_random and not stages[cursor_data.state.stage_is_random]) then
    display_name = loc("random")
  elseif cursor_data.state.stage_is_random then
    display_name = stages[cursor_data.state.stage_is_random].display_name
  else
    display_name = stages[cursor_data.state.stage].display_name
  end
  gprintf(display_name, render_x + padding_x, math.floor(render_y + y_padding + stage_dimensions[2] * 0.5), stage_dimensions[1], "center", nil, 1, small_font)

  padding_x = padding_x + stage_dimensions[1]

  if is_selected then
    local arrow_pos = select_screen:isNetPlay() == "2p_net_vs" and {math.floor(render_x + x_padding + 11), math.floor(render_y + y_padding - stage_dimensions[2] * 0.5 - 15)} or {math.floor(render_x + padding_x + 3), math.floor(render_y + y_padding + 0.25 * text_height)}
    gprintf(">", arrow_pos[1], arrow_pos[2], 10, "center")
  end
end
--#endregion