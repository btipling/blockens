function generate_descriptor()
  
    set_frequency(0.01)
    set_jitter(0)
    set_octaves(1)
    set_noise_type(NT_OPEN_SIMPLEX2)

    local air = 0
    local stone = 1
    local grass = 2
    local dirt = 3
    local lava = 4
    local water = 5

    add_block_id(0, air)
    add_block_id(1, stone)
    add_block_id(2, grass)
    add_block_id(3, dirt)
    add_block_id(4, lava)
    add_block_id(5, water)

    local root_node = get_root_node()
    set_desc_block(root_node, stone)
    set_y_cond(root_node, OP_GTE, 64)

    local top_chunk = set_y_cond_true(root_node)
    set_desc_block(top_chunk, grass)

end

generate_descriptor()
