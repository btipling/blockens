function generate_chunk()
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        blocks[i] = 3
        if x == 63 and y == 0 and z == 63 then
          blocks[i] = 4
        end
        ::continue::
    end
    return blocks
end

chunk = generate_chunk()