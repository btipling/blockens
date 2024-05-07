function generate_terrain()

    set_frequency(0.02)
    set_jitter(15.5)
    set_octaves(30)
    set_noise_type(NT_CELLUAR)

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

        if chunk_y == 0 then
            if y == 63 then
            chunk_material = grass
            else
                if y >= 60 then
                    chunk_material = dirt
                end
            end
        end

        blocks[i] = chunk_material
        local n = gen_noise(x + (chunk_x * 64), y + (chunk_y * 64), z + (chunk_z * 64))
        if chunk_y == 1 then
            if y > 50 then
                blocks[i] = air
            else
                if n > 0.7 then
                    blocks[i] = grass
                    if n < 0.6 then
                        blocks[i] = dirt
                    end
                end
            end
        else
            if y < 25 then
                if n >= 0.35 then
                    blocks[i] = lava
                else
                    if n > 0.3 and n < 0.35 then
                        blocks[i] = lava
                    end
                end
            else
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
