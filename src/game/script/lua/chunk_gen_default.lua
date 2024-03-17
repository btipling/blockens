function generate_chunk()
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        blocks[i] = 0
        if  y == 63 then
            blocks[i] = 2 -- grass
        else
            blocks[i] = 1 -- dirt 
        end
    end
    return blocks
end

chunk = generate_chunk()