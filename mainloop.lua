function fmainloop()
    local func = main_init
    local arg = nil
    while true do
        func,arg = func(arg)
    end
end

function main_init()
    P1 = Stack()
    P2 = Stack()
    P2.pos_x = 172
    P2.score_x = 410
    return main_wait_for_handshake
end

function main_wait_for_handshake()
    while P1.panel_buffer == "" or P2.panel_buffer == "" do
        do_messages()
        coroutine.yield()
    end
    return main_network_vs
end

function main_network_vs()
    while true do
        do_messages()
        P1:local_run()
        P2:foreign_run()
        if P1.game_over then
            error("game over lol")
        end
        coroutine.yield()
    end
end
