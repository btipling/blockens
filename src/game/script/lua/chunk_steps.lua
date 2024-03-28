function generate_chunk()
    local blocks = {}
    local step_start = 0
    for i = 1, 64 * 64 * 64 do
        local _i = i - 1
        local x = _i % 64
        local y = math.floor(_i / 64) % 64
        local z = math.floor(_i / (64 * 64)) % 64
        local max_step_height = 30
        blocks[i] = 0
        if y < max_step_height then
           local step_end = 100 - (y*2)
           local step_start = 120 - step_end
           if x < step_start or x > step_end or z < step_start or z > step_end then
              blocks[i] = 0
              goto continue
           end
           -- if z > step_start or z < step_end then
              -- goto continue
           -- end
           blocks[i] = 2
           ::continue::
        end
    end
    return blocks
end

chunk = generate_chunk()