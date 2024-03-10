function generate_chunk()
    math.randomseed(os.time())
    local trees = {}
    local num_trees = 25
    local leaves_r = 3
    for i = 1, num_trees do
        local cx = math.random(64)
        local cz = math.random(64)
        if cx > (64 - leaves_r) then
           cx = cx - leaves_r
        end
        if cz > (64 - leaves_r) then
           cz = cz - leaves_r
        end
        if cx < leaves_r then
           cx = cx + leaves_r
        end
        if cz < leaves_r then
           cz = cz + leaves_r
        end
        pos = {cx, cz}
        table.insert(trees, pos)
    end
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
        local tree = 6
        local leaves = 10
        local r = 5
        blocks[i] = air
        if y >= 10 then
            goto continue
        end
        for index, pos in ipairs(trees) do
            cx = pos[1]
            cz = pos[2]
            if cx == x and cz == z then
                if y <= 7 then
                   blocks[i] = tree
                else
                    blocks[i] = leaves
                end
            elseif y >= 2 and (x - cx)^2 + (z - cz)^2 <= leaves_r^2 then
                blocks[i] = leaves
            end
        end
        ::continue::
    end
    return blocks
end

chunk = generate_chunk()
