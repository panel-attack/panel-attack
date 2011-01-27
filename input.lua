


--[[int P1InputSource;
#define INPUT_NONE     0
#define INPUT_DISABLED 0
#define INPUT_KEYBOARD 1]]



swap_1_pressed = false
swap_2_pressed = false
--int Input_DirPressed =   -- last dir pressed


-- keyboard assignment vars
k_up = "up"
k_down = "down"
k_left = "left"
k_right = "right"
k_swap1 = "z"
k_swap2 = "z"
k_raise1 = "x"
k_raise2 = "x"
keys = {k_up=false, k_down=false, k_left=false, k_right=false, k_swap1=false,
    k_swap2=false, k_raise1=false, k_raise2=false}

function love.keypressed(key, unicode)
    keys[key] = true
    --error(tostring(key)..tostring(k_down))
    --for i,v in ipairs(keys) do print(i,v) end
end

--[[function love.keyreleased(key)
    keys[key] = false
end--]]

function input_init()
    love.keyboard.setKeyRepeat(500,50)
end

function controls()
    local new_dir = 0
    if keys[k_raise1] or keys[k_raise2] then
        if not P1_prevent_manual_raise then
            P1_manual_raise = true
            P1_manual_raise_yet = false
        end
    end

    if keys[k_swap1] then
        if not swap_1_pressed then
            P1_swap_1 = true
            swap_1_pressed = true
        end
    else
        swap_1_pressed = false
    end

    if keys[k_swap2] then
        if not swap_2_pressed then
            P1_swap_2 = true
            swap_2_pressed = true
        end
    else
        swap_2_pressed = false
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
    if new_dir == P1_cur_dir then
        if P1_cur_timer ~= P1_cur_wait_time then
            P1_cur_timer = P1_cur_timer + 1
        end
    else
        P1_cur_dir = new_dir
        P1_cur_timer = 0
    end
    keys = {k_up=false, k_down=false, k_left=false, k_right=false, k_swap1=false,
        k_swap2=false, k_raise1=false, k_raise2=false}
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
