function generate_chunk()
    -- block id 0 is air
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        -- Define the boundaries of the hole
        if blocks[i] == nil then
            if x % 10 == 0 and z % 10 == 0 then
                blocks[i] = 5
            else
                blocks[i] = 0
            end
        end
    end
    return blocks
end

-- Calling the function to generate the chunk
chunk = generate_chunk()
-- chunk now contains a 64x64x64 chunk with a hole in the center