local wait = coroutine.yield

function fmainloop()
    local func = main_select_mode
    local arg = nil
    while true do
        func,arg = func(arg)
    end
end

function main_select_mode()
    local args = {nil, "50.17.236.201", "50.18.48.184", "127.0.0.1"}
    while true do
        gprint("Press a key to choose\n"
            ..  "1: 1P endless\n"
            ..  "2: 2P endless on U.S. East server\n"
            ..  "3: 2P endless on U.S. West server\n"
            ..  "4: 2P endless on localhost", 300, 280)
        for i=1,4 do
            if this_frame_keys[tostring(i)] then
                return i==1 and main_solo or main_net_vs_setup, args[i]
            end
        end
        wait()
    end
end

function main_solo()
    P1 = Stack()
    make_local_panels(P1, "000000")
    while true do
        P1:local_run()
        if P1.game_over then
            error("game over lol")
        end
        wait()
    end
    -- TODO: transition to some other state instead of erroring.
end

function main_net_vs_setup(ip)
    network_init(ip)
    P1 = Stack()
    P2 = Stack()
    P2.pos_x = 172
    P2.score_x = 410
    while P1.panel_buffer == "" or P2.panel_buffer == "" do
        gprint("Waiting for opponent...", 300, 280)
        do_messages()
        wait()
    end
    return main_net_vs
end

function main_net_vs()
    while true do
        do_messages()
        P1:local_run()
        P2:foreign_run()
        if P1.game_over then
            error("game over lol")
        end
        wait()
    end
    -- TODO: transition to some other state instead of erroring.
end
