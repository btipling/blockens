function rgba_to_int(r, g, b, a)
    return (a << 24) | (b << 16) | (g << 8) | r
end

function darken(color, brightness)
    local finalColor = 0
    local a = (color >> 24) & 0xFF
    local b = (color >> 16) & 0xFF
    local g = (color >> 8) & 0xFF
    local r = color & 0xFF
    finalColor = finalColor | (a << 24) 
    finalColor = finalColor | (math.floor(b * (brightness / 255)) << 16) 
    finalColor = finalColor | (math.floor(g * (brightness / 255)) << 8)
    finalColor = finalColor | math.floor(r * (brightness / 255))
    return finalColor
end

function generate_textures()
    math.randomseed(os.time())
    local textures = {}
    for i = 1, 3 * 16 * 16 do
        local brightnessLevel = 255 - (math.random(96) | 0)
        pixelcolor = rgba_to_int(181, 58, 21, 255)
        ii = i - 1
        x = ii % 16
        y = math.floor(ii / 16) % 16
        s = math.floor(ii / (16 * 16))
        
        if (x + ((y * 3) >> 2) * 4) % 8 == 0 or y % 4 == 0 then
            pixelcolor = rgba_to_int(188, 175, 165, 255)
        end

        if s == 2 then
            brightnessLevel = brightnessLevel * 0.5
        end

        pixelcolor = darken(pixelcolor, brightnessLevel)
        textures[i] = pixelcolor
    end
    return textures
end

-- Calling the function to generate the textures
textures = generate_textures()
-- textures now contains three 16x16 textures
