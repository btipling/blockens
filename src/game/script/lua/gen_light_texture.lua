function rgba_to_int(r, g, b, a)
    return (a << 24) | (b << 16) | (g << 8) | r
end


function generate_textures()
    math.randomseed(os.time())
    local textures = {}
    for i = 1, 3 * 16 * 16 do
        textures[i] = rgba_to_int(0xFF, 0xFF, 0xFF, 0xFF)
    end
    return textures
end

textures = generate_textures()
