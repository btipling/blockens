function generate_chunk()
    math.randomseed(os.time())
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 6
        if x % 2 == 0 then
            blocks[i] = 2
        else
            blocks[i] = 1
        end
        if y % 2 == 0 then
            blocks[i] = 3
        end
    end
    return blocks
end

chunk = generate_chunk()
