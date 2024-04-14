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
        pixelcolor = rgba_to_int(0, 0, 255, 255)
        if i < 16 * 16 + 1 then
            if (i % 8 == 0 or (i - 1) % 8 == 0) and i % 16 ~= 0 and (i - 1) % 16 ~= 0 then
                pixelcolor = rgba_to_int(10, 10, 255, 255)
            elseif i > 112 and i < 145 then
                pixelcolor = rgba_to_int(10, 155, 10, 255)
            else
                pixelcolor = rgba_to_int(200, 200, 255, 255)
            end
        end
        if i > 16 * 16 and i < 16 * 16 + 33 then
            if (i % 8 == 0 or (i - 1) % 8 == 0) and i % 16 ~= 0 and (i - 1) % 16 ~= 0 then
                pixelcolor = rgba_to_int(10, 10, 255, 255)
            else
                pixelcolor = rgba_to_int(200, 200, 255, 255)
            end
        end
        -- if on the third surface, darken
        if i > 16 * 16 * 2 then
            if (i % 8 == 0 or (i - 1) % 8 == 0) and i % 16 ~= 0 and (i - 1) % 16 ~= 0 then
                pixelcolor = rgba_to_int(200, 200, 255, 255)
            elseif i > 624 and i < 657 then
                pixelcolor = rgba_to_int(100, 255, 100, 255)
            else
                pixelcolor = darken(pixelcolor, 150)
            end
        end
        textures[i] = pixelcolor
    end
    return textures
end

textures = generate_textures()
