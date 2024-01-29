function generate_chunk()
    math.randomseed(os.time())
    local ox = 64 / 2
    local oz = 64 / 2
    local dim = 15
    local blocks = {}
    local offset = 0
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
        if y >= 40 then
            goto continue
        end
        local _dim = dim - (y/2)
        if y % 5 == 0 then
           offset = math.random(10)
        end
        _dim = _dim - offset
        if _dim < 0 then
           goto continue
        end
        if (x - ox) + (z - oz) <= _dim then
            blocks[i] = grass
        end
        ::continue::
    end
    return blocks
end

chunk = generate_chunk()
