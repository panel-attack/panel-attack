function love.keypressed(key, unicode)
    keys[key] = true
    protected_keys[key] = true
end

function love.keyreleased(key, unicode)
    keys[key] = false
end

function controls(stack)
    local new_dir = 0
    if (keys[k_raise1] or keys[k_raise2] or protected_keys[k_raise1] or
            protected_keys[k_raise2]) and (not stack.prevent_manual_raise) then
        stack.manual_raise = true
        stack.manual_raise_yet = false
    end

    stack.swap_1 = protected_keys[k_swap1]
    stack.swap_2 = protected_keys[k_swap2]

    if keys[k_up] or protected_keys[k_up] then
        new_dir = DIR_UP
    elseif keys[k_down] or protected_keys[k_down] then
        new_dir = DIR_DOWN
    elseif keys[k_left] or protected_keys[k_left] then
        new_dir = DIR_LEFT
    elseif keys[k_right] or protected_keys[k_right] then
        new_dir = DIR_RIGHT
    end

    if new_dir == stack.cur_dir then
        if stack.cur_timer ~= stack.cur_wait_time then
            stack.cur_timer = stack.cur_timer + 1
        end
    else
        stack.cur_dir = new_dir
        stack.cur_timer = 0
    end

    protected_keys = {}
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
   Input_DirPressed=0;
   P1ManualRaise=0;
   P1ManualRaiseYet=0;
}--]]
