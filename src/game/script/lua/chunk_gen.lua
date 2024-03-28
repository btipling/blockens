function generate_chunk()
    math.randomseed(os.time())
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        blocks[i] = 1
    end
    return blocks
end

chunk = generate_chunk()
