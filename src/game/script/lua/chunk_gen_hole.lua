function generate_chunk()
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        local holeStart = 10
        local holeEnd = 54
        blocks[i] = 2
        if  y > holeStart and y < holeEnd and x > holeStart and x < holeEnd then
            blocks[i] = 0 -- air
        end
    end
    return blocks
end

chunk = generate_chunk()