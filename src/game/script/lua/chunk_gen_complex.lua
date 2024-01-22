function generate_chunk()
    math.randomseed(os.time())
    local blocks = {}
    local air = 0
    local stone = 1
    local grass = 2
    local dirt = 3
    local lava = 4
    local water = 5
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        blocks[i] = air
        if y <= 63 and y > 55 and x < 20 and z < 20 then
            blocks[i] = water
            goto continue
        end
        if  y == 63 then
            blocks[i] = grass
        elseif y > 50 then
            blocks[i] = dirt
            if y < 55 then
                if math.random(100) == 1 then
                    blocks[i] = stone
                end
            end
        elseif y > 20 then
            blocks[i] = stone
            if y < 25 then
                if math.random(100) == 1 then
                    blocks[i] = lava
                end
            end
        else
            blocks[i] = lava
        end
        ::continue::
    end
    return blocks
end

chunk = generate_chunk()