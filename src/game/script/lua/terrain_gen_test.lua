function generate_terrain()
    math.randomseed(SEED)
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
        local n = gen_noise(x + (chunk_x * 64), y + (chunk_y * 64), z + (chunk_z * 64))
        if chunk_y == 1 then
            if math.random(y % 64) > 10 then
                blocks[i] = air
            else
            if y > 50 then
                blocks[i] = air
            else
                if y < 6 then
                    blocks[i] = grass
                    if y < 5 then
                    blocks[i] = dirt
                    end
                else
                    if n > 0.7 then
                        blocks[i] = grass
                        if n < 0.6 then
                            blocks[i] = dirt
                        end
                    end
                end
            end
        end
        else
            chunk_material = stone
            if y == 63 then
                chunk_material = grass
            else
                if y >= 60 then
                    chunk_material = dirt
                end
            end
            if y < 25 then
                if n >= 0.35 then
                    blocks[i] = lava
                else
                    if n > 0.3 and n < 0.35 then
                        blocks[i] = lava
                    end
                end
            end
        end
    end

    return blocks
end

chunk = generate_terrain()
