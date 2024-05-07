function generate_terrain()
    math.randomseed(os.time())
    local blocks = {}
    local air = 0
    local stone = 1
    local grass = 2
    local lava = 4
    local chunk_material = stone
    if chunk_y == 1 then
        chunk_material = grass
    end
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        blocks[i] = chunk_material
        local n = gen_noise(x + (chunk_x * 64), y + (chunk_y * 64), z + (chunk_z * 64))
        if n > 0.5 then
            blocks[i] = air
        end
    end
    return blocks
end

chunk = generate_terrain()
