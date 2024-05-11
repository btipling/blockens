function generate_descriptor()

    set_frequency(0.045)
    set_noise_type(NT_CELLUAR)
    set_fractal_type(FT_RIDGED)
    set_octaves(2)
    set_lacunarity(0.548)
    set_gain(1.0)
    set_weighted_strength(3.5)
    set_cell_dist_func(CDF_EUCLIDEAN_SQ)
    set_cell_return_type(CRT_DISTANCE_2_MUL)
    set_jitter(0.760)

    local air = 0
    local stone = 1
    local grass = 2
    local dirt = 3
    local lava = 4
    local water = 5

    register_block_id(0, air)
    register_block_id(1, stone)
    register_block_id(2, grass)
    register_block_id(3, dirt)
    register_block_id(4, lava)
    register_block_id(5, water)

    local root_node = get_root_node()
    set_desc_block(root_node, air)
    
    set_y_cond(root_node, OP_GTE, 64)
    local top_chunk = set_y_cond_true(root_node)
    set_desc_block(top_chunk, air)
    local bot_chunk = set_y_cond_false(root_node)
    set_desc_block(bot_chunk, stone)

    set_noise_cond_with_div(top_chunk, OP_LTE, 128)
    local hill = set_noise_cond_true(top_chunk)
    set_desc_block(hill, grass)


    set_y_cond(bot_chunk, OP_EQ, 63)
    local grass_field = set_y_cond_true(bot_chunk)
    set_desc_block(grass_field, grass)

    set_noise_cond_with_div(bot_chunk, OP_LTE, 128)
    local hill = set_noise_cond_true(bot_chunk)
    set_desc_block(hill, dirt)

end

generate_descriptor()
