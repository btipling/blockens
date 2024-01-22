function generate_chunk()
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        if blocks[i] == nil then
            if x % 10 == 0 and z % 10 == 0 then
                blocks[i] = 5
            else
                blocks[i] = 0
            end
        end
    end
    return blocks
end

chunk = generate_chunk()