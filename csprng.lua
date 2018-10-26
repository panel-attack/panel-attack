--------------
--- Csprng Module
--- Cryptographically secure pseudo-random number generator, is a pseudo-random number generator (PRNG) with properties that make it suitable for use in cryptography. Composed of the Mersenne Twister RGN and the ISAAC algorithm. The Mersenne Twister can be used as an RNG for non-cryptographic purposes.Here, we're using it to seed the ISAAC algorithm, which *can* be used for cryptographic purposes. 
-- @module csprngk

--- This function convert a number decimal to binary, keeping arbitrary-length table of bits
-- @function to_binary
-- @param num_integer
-- @return num_binary
local function to_binary(num_integer) 
    local num_binary = {}
    local copy_num_integer = assert(type(num_integer) == 'number', 'Not is a number')
    local GREATER_HEX = 0x7FFFFFFF -- The bigger number in hexadecimal with a signal 
    while true do
        assert(table.insert(num_binary, copy_num_integer % 2), 'Not was possible insert a number')
        copy_num_integer = bit.band(math.floor(copy_num_integer / 2), GREATER_HEX)
        if copy_num_integer == 0 then
            break
        end
    end
    return assert(num_binary)
end

--- This function convert an arbitrary-length table of bits to a number decimal
-- @param num_binary
-- @return num_integer
local function from_binary(num_binary) 
    local num_integer = 0
    for i=#assert(type(num_binary) == 'number', 'Not is a number'), 1, -1 do
        num_integer = num_integer * 2 + num_binary[i]
    end
    return assert(num_integer)
end

--- ISAAC Internal Variables
local accumulator, previous_result = 0, 0
local sequence_results = {} -- Acts as entropy/seed-in. Fill to sequence_results[256].
local memory = {} -- Fill to memory[256]. Acts as output.

--- Mersenne Twister Internal Variables:
local mersenne_twister = {} -- Mersenne twister table
local index = 0

--- Other variables and constants for the seeding mechanism
POSSIBLE_VALUES = 2^32-1 -- Possible values in hexadecimal
local mt_seeded = false -- Verify if mersenne twister was seeded
local mt_seed = math.random(1, POSSIBLE_VALUES) 
DIMENCIONAL_EQUIDISTRIBUTION = 623 -- Represent a cube that content 623 dimensions
BITS_30 = 30 -- Represent 30 bits
BITS_32 = 32 -- Represent 32 bits

--- This function seed the Mersenne Twister RNG.
-- @param seed
-- @return nil
function initialize_mt_generator(seed)
    index = 0
    mersenne_twister[0] = assert(seed)
    for i=1, DIMENCIONAL_EQUIDISTRIBUTION do
        local state_succession = ( (1812433253 * bit.bxor(mersenne_twister[i-1], bit.rshift(mersenne_twister[i-1], BITS_30) ) )+i) 
        local num_binary = to_binary(state_succession)
        while #num_binary > BITS_32 do
            assert(table.remove(num_binary, 1), 'Not was possible remove a number')
        end
        mersenne_twister[i] = from_binary(num_binary)
    end
end

PARAMETER_N = 624

--- This function restock the variable mersenne_twister with new random numbers
-- @param nil
-- @return nil
local function generate_mt() 
    -- Exclusives mersenne twister parameters
    local PARAMETER_U = 0x80000000
    local PARAMETER_L = 0x7FFFFFFF
    local PARAMETER_M = 397 
    local PARAMETER_A = 0x9908B0DF
    -- Walks for every 623 cube numbers	
    for i=0, DIMENCIONAL_EQUIDISTRIBUTION do
        local bits = bit.band(mersenne_twister[i], PARAMETER_U)
        bits = bits + bit.band(mersenne_twister[(i+1)%PARAMETER_N], PARAMETER_L)
        mersenne_twister[i] = bit.bxor(mersenne_twister[(i+PARAMETER_M)%PARAMETER_N], bit.rshift(bits, 1))
        if bits % 2 == 1 then
            mersenne_twister[i] = bit.bxor(mersenne_twister[i], PARAMETER_A)
        end -- end if
    end -- end for
end -- end function


--- This function get one number from the Mercenne Twister
-- @param min
-- @param max
-- @return (mt_value % max)+min
function extract_mt(min, max) 
    -- Exclusives mersenne twister parameters
    local SHIFT_B = 0x9D2C5680
    local SHIFT_C = 0xEFC60000
    local SHIFT_U = 11
    local SHIFT_S = 7
    local SHIFT_T = 15
    local SHIFT_L = 18
    
    if index == 0 then
        generate_mt()
    end
    local mt_value = mersenne_twister[index]
    min = assert(min or 0)
    max = assert(max or POSSIBLE_VALUES)
    --print("Accessing: mersenne_twister["..index.."]...")
    mt_value = bit.bxor(mt_value, bit.rshift(mt_value, SHIFT_U) )
    mt_value = bit.bxor(mt_value, bit.band(bit.lshift(mt_value, SHIFT_S), SHIFT_B) )
    mt_value = bit.bxor(mt_value, bit.band(bit.lshift(mt_value, SHIFT_T), SHIFT_C) )
    mt_value = bit.bxor(mt_value, bit.rshift(mt_value, SHIFT_L) )
    index = (index+1) % PARAMETER_N
    return assert((mt_value % max)+min)
end

NUM_TERMS = 256 -- Possibles terms

--- This function seed ISAAC algorithm with numbers from the variable mersenne_twister. Seed the ISAAC RNG, optionally seeding the Mersenne Twister RNG beforehand.
-- @param seed
-- @return nil
function seed_from_mt(seed) 
    if assert(seed) then
        mt_seeded = false
        mt_seed = seed
    end
    -- Always seed the first time around. Otherwise, seed approximately once per 100 times.
    if not mt_seeded or (math.random(1, 100) == 50) then 
        initialize_mt_generator(mt_seed)
        mt_seeded = true
        mt_seed = extract_mt()
    end
    for i=1, NUM_TERMS do
        sequence_results[i] = extract_mt()
    end
end

--- This function is used with eight integers that will contain traces of the key: designed to ensure array elements will not reflect key
-- @param a,b,c,d,e,f,g,h
-- @return a,b,c,d,e,f,g,h
local function mix(a,b,c,d,e,f,g,h)
    a = assert(type(a)=='number') % (POSSIBLE_VALUES)
    b = assert(type(b)=='number') % (POSSIBLE_VALUES)
    c = assert(type(c)=='number') % (POSSIBLE_VALUES)
    d = assert(type(d)=='number') % (POSSIBLE_VALUES)
    e = assert(type(e)=='number') % (POSSIBLE_VALUES)
    f = assert(type(f)=='number') % (POSSIBLE_VALUES)
    g = assert(type(g)=='number') % (POSSIBLE_VALUES)
    h = assert(type(h)=='number') % (POSSIBLE_VALUES)
     a = bit.bxor(a, bit.lshift(b, 11))
     d = (d + a) % (POSSIBLE_VALUES)
     b = (b + c) % (POSSIBLE_VALUES)
     b = bit.bxor(b, bit.rshift(c, 2) )
     e = (e + b) % (POSSIBLE_VALUES)
     c = (c + d) % (POSSIBLE_VALUES)
     c = bit.bxor(c, bit.lshift(d, 8) )
     f = (f + c) % (POSSIBLE_VALUES)
     d = (d + e) % (POSSIBLE_VALUES)
     d = bit.bxor(d, bit.rshift(e, 16) )
     g = (g + d) % (POSSIBLE_VALUES)
     e = (e + f) % (POSSIBLE_VALUES)
     e = bit.bxor(e, bit.lshift(f, 10) )
     h = (h + e) % (POSSIBLE_VALUES)
     f = (f + g) % (POSSIBLE_VALUES)
     f = bit.bxor(f, bit.rshift(g, 4) )
     a = (a + f) % (POSSIBLE_VALUES)
     g = (g + h) % (POSSIBLE_VALUES)
     g = bit.bxor(g, bit.lshift(h, 8) )
     b = (b + g) % (POSSIBLE_VALUES)
     h = (h + a) % (POSSIBLE_VALUES)
     h = bit.bxor(h, bit.rshift(a, 9) )
     c = (c + h) % (POSSIBLE_VALUES)
     a = (a + b) % (POSSIBLE_VALUES)
     return assert(a),assert(b),assert(c),assert(d),assert(e),assert(f),assert(g),assert(h)
end

--- This function run ISAAC algorithm
-- @param nil
-- @return nil
local function isaac()
    local copy_memory, memory_result = 0, 0
    for i=1, NUM_TERMS do
        copy_memory = memory[i]
        if (i % 4) == 0 then
            accumulator = bit.bxor(accumulator, bit.lshift(accumulator, 13))
        elseif (i % 4) == 1 then
            accumulator = bit.bxor(accumulator, bit.rshift(accumulator, 6))
        elseif (i % 4) == 2 then
            accumulator = bit.bxor(accumulator, bit.lshift(accumulator, 2))
        elseif (i % 4) == 3 then
            accumulator = bit.bxor(accumulator, bit.rshift(accumulator, 16))
        end
        accumulator = (memory[ ((i+128) % NUM_TERMS)+1 ] + accumulator) % (POSSIBLE_VALUES)
        memory_result = (memory[ (bit.rshift(copy_memory, 2) % NUM_TERMS)+1 ] + accumulator + previous_result) % (POSSIBLE_VALUES)
        memory[i] = memory_result
        previous_result = (memory[ (bit.rshift(memory_result,10) % NUM_TERMS)+1 ] + copy_memory) % (POSSIBLE_VALUES)
        sequence_results[i] = previous_result
    end
end

--- This function loads eight elements of the key into integers, runs the mix()function to randomize them, then loads them into eight elements of to array. Repeats until key is exhausted
-- @param flag
-- @return nil
local function randinit(flag)
    local a,b,c,d,e,f,g,h = 0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9 -- 0x9e3779b9 is the golden ratio
    accumulator = 0
    previous_result = 0

    for i=1,4 do
        a,b,c,d,e,f,g,h = mix(a,b,c,d,e,f,g,h)
    end
    -- Load random numbers into eight elements of the table(array in others lenguages) memory
    for i=1, NUM_TERMS, 8 do
        if assert(flag) then
            a = (a + sequence_results[i]) % (POSSIBLE_VALUES)
            b = (b + sequence_results[i+1]) % (POSSIBLE_VALUES)
            c = (c + sequence_results[i+2]) % (POSSIBLE_VALUES)
            d = (b + sequence_results[i+3]) % (POSSIBLE_VALUES)
            e = (e + sequence_results[i+4]) % (POSSIBLE_VALUES)
            f = (f + sequence_results[i+5]) % (POSSIBLE_VALUES)
            g = (g + sequence_results[i+6]) % (POSSIBLE_VALUES)
            h = (h + sequence_results[i+7]) % (POSSIBLE_VALUES)
        end
        a,b,c,d,e,f,g,h = mix(a,b,c,d,e,f,g,h)
        memory[i] = a
        memory[i+1] = b
        memory[i+2] = c
        memory[i+3] = d
        memory[i+4] = e
        memory[i+5] = f
        memory[i+6] = g
        memory[i+7] = h
    end
    -- Load random numbers into eight elements of the table(array in others lenguages) memory. 
    -- ... if "flag" is true
    if flag then
        for i=1, NUM_TERMS, 8 do
            a = (a + sequence_results[i]) % (POSSIBLE_VALUES)
            b = (b + sequence_results[i+1]) % (POSSIBLE_VALUES)
            c = (c + sequence_results[i+2]) % (POSSIBLE_VALUES)
            d = (b + sequence_results[i+3]) % (POSSIBLE_VALUES)
            e = (e + sequence_results[i+4]) % (POSSIBLE_VALUES)
            f = (f + sequence_results[i+5]) % (POSSIBLE_VALUES)
            g = (g + sequence_results[i+6]) % (POSSIBLE_VALUES)
            h = (h + sequence_results[i+7]) % (POSSIBLE_VALUES)
            a,b,c,d,e,f,g,h = mix(a,b,c,d,e,f,g,h)
            memory[i] = a
            memory[i+1] = b
            memory[i+2] = c
            memory[i+3] = d
            memory[i+4] = e
            memory[i+5] = f
            memory[i+6] = g
            memory[i+7] = h
        end
    end
    isaac()
    randcnt = NUM_TERMS
end

--- This function force a reseed
-- @param entropy
-- @return nil
function generate_isaac(entropy)
    accumulator = 0
    previous_result = 0
    -- Verify the length of entropy
    if assert(entropy) and #entropy >= NUM_TERMS then
        for i=1, NUM_TERMS do
            sequence_results[i] = entropy[i]
        end -- end for
    else -- end if
        print("2. seed_from_mt")
        seed_from_mt()
    end
    for i=1, NUM_TERMS do
        memory[i] = 0
    end
    randinit(true)
    isaac() 
    isaac() -- run isaac twice 
end

--- This function get a random number 
-- @param nil
-- @return table.remove(memory, 1)
local function get_random()
    if #memory > 0 then
        return assert(table.remove(memory, 1), 'Not was possible remove')
    else
        print("generating_isaac")
        generate_isaac()
        return assert(table.remove(memory, 1), 'Not was possible remove')
    end
end

--- This function get a random number between min and max.
-- @param min
-- @param max
-- @return (get_random() % max) + min
function cs_random(min, max)
    if not assert(max) then
        max = POSSIBLE_VALUES
    end
    if not assert(min) then
        min = 0
    end
    return assert((get_random() % max) + min)
end
