function rgba_to_int(r, g, b, a)
    return (a << 24) | (b << 16) | (g << 8) | r
end

function darken(color, brightness)
    local a = (color >> 24) & 0xFF
    local b = (color >> 16) & 0xFF
    local g = (color >> 8) & 0xFF
    local r = color & 0xFF
    return (a << 24) | ((b * (brightness/255)) << 16) | ((g * (brightness/255)) << 8) | (r * (brightness/255))
end

function generate_textures()
    local textures = {}
    for i = 1, 3 * 16 * 16 do
        -- You can customize each texture here as needed
        pixelcolor = rgba_to_int(255, 0, 0, 255) -- Red color
        -- if on the third surface, darken
        if i > 16 * 16 * 2 then
            pixelcolor = rgba_to_int(255, 100, 100, 255)
        end
        if i < 16 * 16 + 1 then
            pixelcolor = darken(pixelcolor, 150)
        end
        textures[i] = pixelcolor
    end
    return textures
end

-- Calling the function to generate the textures
textures = generate_textures()
-- textures now contains three 16x16 textures