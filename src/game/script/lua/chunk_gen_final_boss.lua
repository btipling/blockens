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
        if x == 63 and y == 63 and z == 63 then
            blocks[i] = 4
        end
        if x == 63 and y == 63 and z == 62 then
            blocks[i] = 4
        end
        if x == 62 and y == 63 and z == 63 then
            blocks[i] = 4
        end
    end
    return blocks
end

chunk = generate_chunk()