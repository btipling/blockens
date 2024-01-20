function generate_chunk()
    -- block id 0 is air
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        -- Define the boundaries of the hole
        local holeStart = 10
        local holeEnd = 54
        blocks[i] = 0
        -- Check if the current block is within the hole boundaries
        if  y == 63 and x < 15 and z == 0 then
            blocks[i] = 2
        end
    end
    return blocks
end

-- Calling the function to generate the chunk
chunk = generate_chunk()
-- chunk now contains a 64x64x64 chunk with a hole in the center