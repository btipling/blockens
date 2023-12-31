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
        pixelcolor = rgba_to_int(103, 82, 49, 255)
        ii = i - 1
        x = ii % 16
        y = math.floor(ii / 16) % 16
        s = math.floor(ii / (16 * 16))


        if x > 0 and x < 15 and (s == 0 or s == 2) and y > 0 and y < 15 then
            pixelcolor = rgba_to_int(188, 152, 49, 98)
            local xd = (x - 7)
            local yd = (y - 7)
            if xd < 0 then
                xd = 1 - xd
            end
            if yd < 0 then
                yd = 1 - yd
            end
            if yd > xd then
                xd = yd
            end
            brightnessLevel = 196 - (math.random(32) | 0) + xd % 3 * 32
            pixelcolor = darken(pixelcolor, brightnessLevel)
        else
            brightnessLevel = brightnessLevel * (150 - 100) / 100
            if x % 2 == 0 then
                brightnessLevel = brightnessLevel * 150  / 100
            end
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
