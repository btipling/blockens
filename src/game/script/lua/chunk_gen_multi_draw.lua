function generate_chunk()
    local blocks = {}
    local stone = 1
    local lava = 4
    local air = 0
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        local stone1Start = 12
        local stone1End = 7
        local stone2Start = 5
        local stone2End = 0
        blocks[i] = air
        if  y <= stone1Start and y >= stone1End and x < 5 and z < 5  then
            blocks[i] = stone
        end
        if  y <= stone2Start and y >= stone2End and x < 5 and z < 5 then
            blocks[i] = stone
        end
        if y == 6 and x == 0 and z == 0 then
            blocks[i] = lava
        end
    end
    return blocks
end

chunk = generate_chunk()