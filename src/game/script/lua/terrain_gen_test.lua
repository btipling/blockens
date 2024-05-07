function generate_terrain()
    if chunk_y == 1 then
        set_frequency(0.05)
        set_jitter(0)
        set_octaves(1)
        set_noise_type(NT_CELLUAR)
        set_rotation_type(RT_XY)
    else
        set_frequency(0.02)
        set_jitter(15.5)
        set_octaves(30)
        set_noise_type(NT_CELLUAR)
        set_rotation_type(RT_XY)
    end

    local blocks = {}
    local air = 0
    local stone = 1
    local grass = 2
    local dirt = 3
    local lava = 4

    local chunk_material = stone
    if chunk_y == 1 then
        chunk_material = air
    end

    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64

        blocks[i] = chunk_material
        local n = gen_noise2(x + (chunk_x * 64), z + (chunk_z * 64))
        local inverted_norm_y = 64 - y / 64
        if chunk_y == 1 then
            if y > n then
                blocks[i] = grass
            end
        end
    end

    return blocks
end

chunk = generate_terrain()
