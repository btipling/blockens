function generate_chunk()
    math.randomseed(os.time())
    local grass_r = 30
    local dirt_r = 25
    local stone_r = 5
    local grass_y = 10
    local dirt_y = 20;
    cx = 64/2
    cz = 64/2
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        if blocks[i] ~= nil then
            goto continue
        end
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        local air = 0
        local stone = 1
        local grass = 2;
        local dirt = 3
        local r = 5
        blocks[i] = air
        if cx == x and cz == z then
            blocks[i] = stone
        elseif y <= grass_y then
            local offset = math.random(10)
            local r = grass_r - (y/2) - (y % offset)
            if (x - cx)^2 + (z - cz)^2 <= r^2 then
               blocks[i] = grass
            end
        elseif y <= dirt_y then
            local offset = math.random(10)
            local r = dirt_r - (y/2) - (y % offset)
            if (x - cx)^2 + (z - cz)^2 <= r^2 then
               blocks[i] = dirt
            end
        else
            local offset = math.random(2)
            local r = stone_r - (x/4 % offset)
            if (x - cx)^2 + (z - cz)^2 <= r^2 then
               blocks[i] = stone
            end
        end
        ::continue::
    end
    return blocks
end

chunk = generate_chunk()
