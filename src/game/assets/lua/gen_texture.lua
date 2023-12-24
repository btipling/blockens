function rgb_to_int(r, g, b)
    return (r << 16) | (g << 8) | b
end

function generate_textures()
    local textures = {}
    for i = 1, 3 * 16 * 16 do
        -- You can customize each texture here as needed
        textures[i] = rgb_to_int(255, 0, 0) -- Red color
    end
    return textures
end

-- Calling the function to generate the textures
textures = generate_textures()
-- textures now contains three 16x16 textures