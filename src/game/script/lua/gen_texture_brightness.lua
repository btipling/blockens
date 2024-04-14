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
        ii = i - 1
        x = ii % 16
        y = math.floor(ii / 16) % 16
        s = math.floor(ii / (16 * 16))
        pixelcolor = rgba_to_int(255, 0, 0, 255)
        if s == 0 then
            pixelcolor = rgba_to_int(255, 200, 200, 255)
        end
        if s == 1 and y <= 1 then
            pixelcolor = rgba_to_int(255, 200, 200, 255)
        end
        if s == 2 then
            pixelcolor = darken(pixelcolor, 150)
        end
        textures[i] = pixelcolor
    end
    return textures
end

textures = generate_textures()