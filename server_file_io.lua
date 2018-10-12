------
--- Module with IO functions for save game state
--- Write data in files and handle exception in IO operations
-- @module server_file_io 
------

local lfs = require('lfs')

--- Check if is really a file
-- @function check_is_file
-- @param name string with name of the file
-- return boolean, true if is a file, else if not.
function check_is_file(name) 
    if type(name)~='string' then return false end

    if not check_is_dir(name) then
        return os.rename(name,name) and true or false
        -- note that the short evaluation is to
        -- return false instead of a possible nil
    end

    return false
end

--- Check if is a directory
-- @function check_is_file_dir
-- @param name name of the file
-- @return boolean, true if is a directory, false if is not.
function check_is_file_dir(name) 
    if type(name)~='string' then return false end

    -- @fixme this is a trick
    return os.rename(name, name) and true or false
end

--- Check if is a directory (most accurately than check_is_file)
-- @function check_is_dir
-- @param name string with name of the file
-- @return boolean, true if is a directory, false if not.
function check_is_dir(name) 
    if type(name)~='string' then return false end

    local currrent_dir = lfs.currentdir() 
    local is_dir = lfs.chdir(name) and true or false 

    lfs.chdir(current_dir)

    return is_dir
end

--- Create a directory using path
-- @function make_dir 
-- @param path string with path of the new directory
-- @return nil
function make_dir(path) 
    print('make_dir(path)')
    local sep, pStr = package.config:sub(1, 1), ''

    for dir in path:gmatch('[^' .. sep .. ']+') do
        pStr = pStr .. dir .. sep
        lfs.mkdir(pStr)
    end

    print('got to the end of make_dir(path)')
end

--- Write text in player files
-- @function write_playters_file
-- @param nil
-- @return nil
function write_players_file() 

    -- handle exceptions with IO operations
    pcall(function() 
        local file = assert(io.open('players.txt', 'w')) 

        io.output(file)
        io.write(json.encode(playerbase.players))
        io.close(file)
    end)
end

--- Read data of the players file
-- @function read_players_file
-- @param nil
-- return nil
function read_players_file() 
    pcall(function() 
        local file = assert(io.open('players.txt', 'r')) 

        io.input(file)
        playerbase.players = json.decode(io.read('*all'))
        io.close(file)
    end) 
end

--- Write data in file deleted_players.txt 
-- @function write_deleted_players_file
-- @param nil
-- @return nil
function write_deleted_players_file() 

    -- Handle IO operation
    pcall(function()
        local file = assert(io.open('deleted_players.txt', 'w')) 

        io.output(file)
        io.write(json.encode(playerbase.players))
        io.close(file)
    end) 
end

--- Read data of deleted players 
-- @function read_deletd_players_file
-- @param nil
-- @return nil
function read_deleted_players_file() 
    pcall(function()
        local file = assert(io.open('deleted_players.txt', 'r')) 

        io.input(file)
        playerbase.deleted_players = json.decode(io.read('*all'))
        io.close(file)
    end) 
end

--- Save data in leaderboard
-- @function write_leaderboard_file
-- @param nil
-- @param nil
function write_leaderboard_file() 

    pcall(function()
        local file = assert(io.open('leaderboard.txt', 'w')) 

        io.output(file)
        io.write(json.encode(leaderboard.players))
        io.close(file)
    end) 
end

--- Read leaderboard 
-- @function read_leaderboard_file
-- @param nil
-- @param nil
function read_leaderboard_file() 
    pcall(function()
        local file = assert(io.open('leaderboard.txt', 'r')) 

        io.input(file)
        leaderboard.players = json.decode(io.read('*all'))
        io.close(file)
    end) 
end

--- Save replay
-- @function write_replay_file
-- @param replay Stack of the moves
-- @param path of file
-- @param filename string with name of the file
-- @return nil
function write_replay_file(replay, path, filename) 

    pcall(function()
        print('about to open new replay file for writing')
        make_dir(path)
        local file = assert(io.open(path..'/'..filename, 'w')) 
        print('past file open')
        io.output(file)
        io.write(json.encode(replay))
        io.close(file)
        print('finished write_replay_file()')
    end) 
end
--- User csprng to generate random issues
-- @function read_csprng_seed_file
-- @param nil
-- @return nil
function read_csprng_seed_file()
    pcall(function()
        local file = io.open('csprng_seed.txt', 'r') 

        if file then
            io.input(file)
            csprng_seed = io.read('*all')
            io.close(file)
        else
            print('csprng_seed.txt could not be read.  Writing a new ' .. 
                'default (2000) csprng_seed.txt')
            local new_file = io.open('csprng_seed.txt', 'w')
            io.output(new_file)
            io.write('2000')
            io.close(new_file)
            csprng_seed = '2000'
        end

        if tonumber(csprng_seed) then
            local temporary = tonumber(csprng_seed)
            csprng_seed = temporary
        else 
            print('ERROR: csprng_seed.txt content is not numeric. ' ..  
                'Using default (2000) as csprng_seed')
            csprng_seed = 2000
        end
    end) 
end

--old function commented
-- function write_replay_file(replay_table, file_name) pcall(function()
-- local f = io.open(file_name, 'w')
-- io.output(file)
-- io.write(json.encode(replay_table))
-- io.close(file)
-- end) end
