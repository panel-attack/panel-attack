-- KillaVanilla's RNG('s), composed of the Mersenne Twister RNG and the ISAAC algorithm.

-- Exposed functions:
-- initialize_mt_generator(seed) - Seed the Mersenne Twister RNG.
-- extract_mt() - Get a number from the Mersenne Twister RNG.
-- seed_from_mt(seed) - Seed the ISAAC RNG, optionally seeding the Mersenne Twister RNG beforehand.
-- generate_isaac() - Force a reseed.
-- cs_random(min, max) - Get a random number between min and max.

-- Helper functions:
local function toBinary(num_integer) -- Convert from an integer to an arbitrary-length table of bits
    local num_binary = {}
    local copy_num_integer = num_integer
    local GREATER_HEX = 0x7FFFFFFF 
    while true do
        table.insert(num_binary, copy_num_integer % 2)
        copy_num_integer = bit.band(math.floor(copy_num_integer / 2), GREATER_HEX)
        if copy_num_integer == 0 then
            break
        end
    end
    return num_binary
end

local function fromBinary(num_binary) -- Convert from an arbitrary-length table of bits (from toBinary) to an integer
    local num_integer = 0
    for i=#num_binary, 1, -1 do
        num_integer = num_integer * 2 + num_binary[i]
    end
    return num_integer
end

-- ISAAC internal state:
local accumulator, previous_result = 0, 0
local sequence_results = {} -- Acts as entropy/seed-in. Fill to sequence_results[256].
local memory = {} -- Fill to memory[256]. Acts as output.

-- Mersenne Twister State:
local mersenne_twister = {} -- Twister state
local index = 0

-- Other variables for the seeding mechanism
POSSIBLE_VALUES = 2^32-1
local mt_seeded = false
local mt_seed = math.random(1, POSSIBLE_VALUES)

-- The Mersenne Twister can be used as an RNG for non-cryptographic purposes.
-- Here, we're using it to seed the ISAAC algorithm, which *can* be used for cryptographic purposes.

DIMENCIONAL_EQUIDISTRIBUTION = 623
BITS_30 = 30
BITS_32 = 32

function initialize_mt_generator(seed)
    index = 0
    mersenne_twister[0] = seed
    for i=1, DIMENCIONAL_EQUIDISTRIBUTION do
        local state_succession = ( (1812433253 * bit.bxor(mersenne_twister[i-1], bit.rshift(mersenne_twister[i-1], BITS_30) ) )+i)
        local num_binary = toBinary(state_succession)
        while #num_binary > BITS_32 do
            table.remove(num_binary, 1)
        end
        mersenne_twister[i] = fromBinary(num_binary)
    end
end

PARAMETER_N = 624

local function generate_mt() -- Restock the mersenne_twister with new random numbers.
    local PARAMETER_U = 0x80000000
    local PARAMETER_L = 0x7FFFFFFF
    local PARAMETER_M = 397 
    local PARAMETER_A = 0x9908B0DF
	
    for i=0, DIMENCIONAL_EQUIDISTRIBUTION do
        local bits = bit.band(mersenne_twister[i], PARAMETER_U)
        bits = bits + bit.band(mersenne_twister[(i+1)%PARAMETER_N], PARAMETER_L)
        mersenne_twister[i] = bit.bxor(mersenne_twister[(i+PARAMETER_M)%PARAMETER_N], bit.rshift(bits, 1))
        if bits % 2 == 1 then
            mersenne_twister[i] = bit.bxor(mersenne_twister[i], PARAMETER_A)
        end
    end
end



function extract_mt(min, max) -- Get one number from the Mersenne Twister.
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
    min = min or 0
    max = max or POSSIBLE_VALUES
    --print("Accessing: mersenne_twister["..index.."]...")
    mt_value = bit.bxor(mt_value, bit.rshift(mt_value, SHIFT_U) )
    mt_value = bit.bxor(mt_value, bit.band(bit.lshift(mt_value, SHIFT_S), SHIFT_B) )
    mt_value = bit.bxor(mt_value, bit.band(bit.lshift(mt_value, SHIFT_T), SHIFT_C) )
    mt_value = bit.bxor(mt_value, bit.rshift(mt_value, SHIFT_L) )
    index = (index+1) % PARAMETER_N
    return (mt_value % max)+min
end

NUM_TERMS = 256

function seed_from_mt(seed) -- seed ISAAC with numbers from the mersenne_twister:
    if seed then
        mt_seeded = false
        mt_seed = seed
    end
    if not mt_seeded or (math.random(1, 100) == 50) then -- Always seed the first time around. Otherwise, seed approximately once per 100 times.
        initialize_mt_generator(mt_seed)
        mt_seeded = true
        mt_seed = extract_mt()
    end
    for i=1, NUM_TERMS do
        sequence_results[i] = extract_mt()
    end
end

local function mix(a,b,c,d,e,f,g,h)
    a = a % (POSSIBLE_VALUES)
    b = b % (POSSIBLE_VALUES)
    c = c % (POSSIBLE_VALUES)
    d = d % (POSSIBLE_VALUES)
    e = e % (POSSIBLE_VALUES)
    f = f % (POSSIBLE_VALUES)
    g = g % (POSSIBLE_VALUES)
    h = h % (POSSIBLE_VALUES)
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
     return a,b,c,d,e,f,g,h
end

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

local function randinit(flag)
    local a,b,c,d,e,f,g,h = 0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9,0x9e3779b9-- 0x9e3779b9 is the golden ratio
    accumulator = 0
    previous_result = 0

    for i=1,4 do
        a,b,c,d,e,f,g,h = mix(a,b,c,d,e,f,g,h)
    end
    for i=1, NUM_TERMS, 8 do
        if flag then
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

function generate_isaac(entropy)
    accumulator = 0
    previous_result = 0

    if entropy and #entropy >= NUM_TERMS then
        for i=1, NUM_TERMS do
            sequence_results[i] = entropy[i]
        end
    else
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

local function getRandom()
    if #memory > 0 then
        return table.remove(memory, 1)
    else
        print("generating_isaac")
        generate_isaac()
        return table.remove(memory, 1)
    end
end

function cs_random(min, max)
    if not max then
        max = POSSIBLE_VALUES
    end
    if not min then
        min = 0
    end
    return (getRandom() % max) + min
end
