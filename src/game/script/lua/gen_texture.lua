function rgba_to_int(r, g, b, a)
    return (a << 24) | (b << 16) | (g << 8) | r
end

function generate_textures()
    local textures = {}
    for i = 1, 3 * 16 * 16 do
        textures[i] = rgba_to_int(255, 0, 0, 255) 
    end
    return textures
end

textures = generate_textures()