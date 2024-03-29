function generate_chunk()
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        blocks[i] = 0
        if y <= 63 and y > 55 and x < 20 and z < 20 then
            blocks[i] = 5 -- water
            goto continue
        end
        if  y == 63 then
            blocks[i] = 2 -- grass
        elseif y > 50 then
            blocks[i] = 3 -- dirt
        elseif y > 20 then
            blocks[i] = 1 -- stone
        else
            blocks[i] = 4 -- lava 
        end
        ::continue::
    end
    return blocks
end

chunk = generate_chunk()