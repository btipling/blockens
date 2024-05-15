function generate_descriptor()

    set_frequency(0.015)
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
    register_block_id(13, water)

    local root_node = get_root_node()
    add_desc_block(root_node, air)
    
    set_y_cond(root_node, OP_GTE, 64)
    local top_chunk = set_y_cond_true(root_node)
    add_desc_block(top_chunk, air)
    local bot_chunk = set_y_cond_false(root_node)
    add_desc_block(bot_chunk, water)

    set_noise_cond_with_div(top_chunk, OP_LTE, 128)
    local hill = set_noise_cond_true(top_chunk)

    add_desc_block_with_depth(hill, grass, 1)
    add_desc_block_with_depth(hill, dirt, 5)
    add_desc_block_with_depth(hill, stone, 10)

    add_desc_block(grass_field, grass)

    set_noise_cond_with_div(bot_chunk, OP_LTE, 128)

    local underground = set_noise_cond_true(bot_chunk)

    add_desc_block(underground, water)
    add_desc_block_with_depth(underground, stone, 30)
    add_desc_block_with_depth(underground, lava, 5)

end

generate_descriptor()
