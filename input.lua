function love.keypressed(key, unicode)
    keys[key] = true
    if key == k_raise1 or key == k_raise2 then
        --Even if the user releases the key this frame, we should do a raise.
        keys.protect_raise = true
    end
end

function love.keyreleased(key, unicode)
    if key == k_raise1 or key == k_raise2 then
        keys[key] = false
    end
end

function controls(stack)
    local new_dir = 0
    if (keys[k_raise1] or keys[k_raise2] or keys.protect_raise)
            and (not stack.prevent_manual_raise) then
        stack.manual_raise = true
        stack.manual_raise_yet = false
    end

    if keys[k_swap1] and not stack.swap_1_pressed then
        stack.swap_1 = true
        stack.swap_1_pressed = true
    else
        stack.swap_1_pressed = false
    end

    if keys[k_swap2] and not stack.swap_2_pressed then
        stack.swap_2 = true
        stack.swap_2_pressed = true
    else
        stack.swap_2_pressed = false
    end

    if keys[k_up] then
        new_dir = DIR_UP
    elseif keys[k_down] then
        new_dir = DIR_DOWN
    elseif keys[k_left] then
        new_dir = DIR_LEFT
    elseif keys[k_right] then
        new_dir = DIR_RIGHT
    end
    if new_dir == stack.cur_dir and stack.cur_timer ~= stack.cur_wait_time then
        stack.cur_timer = stack.cur_timer + 1
    else
        stack.cur_dir = new_dir
        stack.cur_timer = 0
    end
    keys[k_up] = false
    keys[k_down] = false
    keys[k_left] = false
    keys[k_right] = false
    keys[k_swap1] = false
    keys[k_swap2] = false
    keys.protect_raise = false
end

--[[void Controls_SetDefaults()
{
   P1InputSource=INPUT_KEYBOARD;

   k_Up=SCAN_UP;
   k_Down=SCAN_DOWN;
   k_Left=SCAN_LEFT;
   k_Right=SCAN_RIGHT;

   k_Swap1=SCAN_E;
   k_Swap2=SCAN_D;
   k_Raise1=SCAN_Q;
   k_Raise2=SCAN_W;
}--]]

--[[void Controls_NewGame()
{
   swap_1_pressed = false
   swap_2_pressed = false
   Input_DirPressed=0;
   P1ManualRaise=0;
   P1ManualRaiseYet=0;
}--]]
