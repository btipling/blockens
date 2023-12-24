function rgba_to_int(r, g, b, a)
    return (r << 24) | (g << 16) | (b << 8) | a
end

function generate_textures()
    local textures = {}
    for i = 1, 3 * 16 * 16 do
        -- You can customize each texture here as needed
        textures[i] = rgba_to_int(255, 0, 0, 255) -- Red color
    end
    return textures
end

-- Calling the function to generate the textures
textures = generate_textures()
-- textures now contains three 16x16 textures