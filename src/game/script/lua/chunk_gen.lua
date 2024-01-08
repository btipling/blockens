function generate_chunk()
    math.randomseed(os.time())
    local blocks = {}
    for i = 1, 64 * 64 * 64 do
        blocks[i] = 1
    end
    return blocks
end

-- Calling the function to generate the chunk
chunk = generate_chunk()
-- chunk now contains a 64x64x64 chunk
