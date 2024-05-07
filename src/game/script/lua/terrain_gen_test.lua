function generate_terrain()
    math.randomseed(os.time())
    local blocks = {}
    local air = 0
    local stone = 1
    local grass = 2
    local chunk_material = stone
    if chunk_x == 0 then
       chunk_material = grass
    end
    if chunk_y == 0 then
       chunk_material = air
    end
    for i = 1, 64 * 64 * 64 do
        blocks[i] = chunk_material
    end
    return blocks
end

chunk = generate_terrain()
