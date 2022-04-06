local celib = require "custom_entities"

--spikeball is offset by 3 tiles from its source block.
--the spawn function will create the spikeball itself,, then the source block + chains over it .

--todo: 
--add knockback SFX when corpses are hit by the trap
local spikeball_texture_id
do
    local spikeball_texture_def = TextureDefinition.new()
    spikeball_texture_def.width = 128
    spikeball_texture_def.height = 128
    spikeball_texture_def.tile_width = 128
    spikeball_texture_def.tile_height = 128

    spikeball_texture_def.texture_path = 'spikeball.png'
    spikeball_texture_id = define_texture(spikeball_texture_def)
end
local chain_half_texture_id
do
    local chain_half_texture_def = TextureDefinition.new()
    chain_half_texture_def.width = 128
    chain_half_texture_def.height = 128
    chain_half_texture_def.tile_width = 128
    chain_half_texture_def.tile_height = 128

    chain_half_texture_def.texture_path = 'chain_half.png'
    chain_half_texture_id = define_texture(chain_half_texture_def)
end
local source_block_texture_id
do
    local source_block_texture_def = TextureDefinition.new()
    source_block_texture_def.width = 128
    source_block_texture_def.height = 128
    source_block_texture_def.tile_width = 128
    source_block_texture_def.tile_height = 128

    source_block_texture_def.texture_path = 'source_block.png'
    source_block_texture_id = define_texture(source_block_texture_def)
end
local function spikeball_trap_set(uid)
    local ent = get_entity(uid)
    local x, y, l = get_position(uid)

    ent:set_texture(spikeball_texture_id)

    ent.flags = set_flag(ent.flags, ENT_FLAG.NO_GRAVITY)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.COLLIDES_WALLS)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.INTERACT_WITH_SEMISOLIDS)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.INTERACT_WITH_WATER)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.INTERACT_WITH_WEBS)

    ent:set_draw_depth(7)

    ent.width = 1
    ent.height = 1
    --spawn the "source" tile, if this is destroyed the custom entity should just turn into a regular old unchained spikeball
    ent.owner_uid = spawn_grid_entity(ENT_TYPE.ACTIVEFLOOR_CHAINEDPUSHBLOCK, x, y, l)
    local source_block = get_entity(ent.owner_uid)
    source_block:set_texture(source_block_texture_id)
    --move_state determines the direction the ball will spin in
    ent.move_state = 1
    if math.random(2) == 1 then
        ent.move_state = 2 --we cant set move_state to -1 because its an unsigned int,, just check the exact number later
    end
    --health determines the speed of the ball
    ent.health = math.random(20, 40)
end

local function spikeball_trap_update(ent)
    ent.velocityx = 0
    ent.velocityy = 0

    ent.animation_frame = 208

    --move from a fixed position based on the source block
    local source_block = get_entity(ent.owner_uid)
    local sx, sy, sl = get_position(ent.owner_uid)
    local x, y, l = get_position(ent.uid)
    local move_dir = 1
    if ent.move_state == 2 then
        move_dir = -1
    end
    local angle = move_dir*ent.stand_counter/ent.health

    if source_block == nil then
        local spikeball = get_entity(spawn(ENT_TYPE.ACTIVEFLOOR_UNCHAINED_SPIKEBALL, x, y, l, math.random(-1, 1), 1))
        spikeball.velocityx = -12*math.sin(angle)
        spikeball.velocityy = 8*math.cos(angle)
        kill_entity(ent.uid)
    else
        ent.x = sx + source_block.velocityx + (3*math.cos(angle))
        ent.y = sy + source_block.velocityy + (3*math.sin(angle))

        ent.angle = angle
    end
    --damage living things on contact
    for _, v in ipairs(get_entities_by(0, MASK.PLAYER | MASK.MOUNT | MASK.MONSTER, l)) do
        local other_ent = get_entity(v)
        if ent:overlaps_with(other_ent) and other_ent.invincibility_frames_timer == 0 and not test_flag(other_ent.flags, ENT_FLAG.TAKE_NO_DAMAGE) then
            local ex, ey, el = get_position(v)
            local kbdir = 1
            if (ex-x) < 0 then kbdir = -1 end
            other_ent:damage(
                ent.uid,
                2,
                80,
                (kbdir)*ent.health/250,
                math.sin(ey-y)/2,
                25
            )
            --manual knockback for corpses for some reason
            if test_flag(other_ent.flags, ENT_FLAG.DEAD) then
                other_ent.velocityx = (kbdir)*ent.health/250
                other_ent.velocityy = math.sin(ey-y)/2
                --play a sound here
            end
            other_ent.invincibility_frames_timer = 25
        end
    end
    --damage specific items on contact
    local damageable_items = {ENT_TYPE.ITEM_POT, ENT_TYPE.ITEM_CRATE, ENT_TYPE.ITEM_SKULL, ENT_TYPE.ITEM_LAVAPOT, ENT_TYPE.ITEM_CHEST, ENT_TYPE.ITEM_POTOFGOLD, ENT_TYPE.ITEM_VAULTCHEST}
    for _, v in ipairs(get_entities_by_type(damageable_items)) do
        local other_ent = get_entity(v)
        local ex, ey, el = get_position(v)
        local kbdir = 1
        if (ex-x) < 0 then kbdir = -1 end
        if ent:overlaps_with(other_ent) and other_ent.invincibility_frames_timer == 0 and not test_flag(other_ent.flags, ENT_FLAG.TAKE_NO_DAMAGE) then
            other_ent:damage(
                ent.uid,
                2,
                80,
                (kbdir)*ent.health/250,
                math.sin(ey-y)/2,
                25
            )
            other_ent.invincibility_frames_timer = 20
        end
    end
end
local function spikeball_chain_set(uid, spikeball_uid, distance_from_anchor_block)
    local ent = get_entity(uid)
    local spikeball = get_entity(spikeball_uid)
    local x, y, l = get_position(uid)

    --if this is the last piece of the chain,, change it to the half texture
    if distance_from_anchor_block == 0 then
        ent:set_texture(chain_half_texture_id)
    end

    ent.flags = set_flag(ent.flags, ENT_FLAG.NO_GRAVITY)
    ent.flags = set_flag(ent.flags, ENT_FLAG.TAKE_NO_DAMAGE)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.COLLIDES_WALLS)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.INTERACT_WITH_SEMISOLIDS)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.INTERACT_WITH_WATER)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.INTERACT_WITH_WEBS)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.CLIMBABLE)

    ent.owner_uid = spikeball.owner_uid
    ent.price = distance_from_anchor_block

    ent.health = spikeball.health
    ent.stand_counter = spikeball.stand_counter
    ent.move_state = spikeball.move_state

    ent:set_draw_depth(7) 
end
local function spikeball_chain_update(ent)
    ent.velocityx = 0
    ent.velocityy = 0

    --move from a fixed position based on the source block
    local source_block = get_entity(ent.owner_uid)
    local sx, sy, sl = get_position(ent.owner_uid)
    local x, y, l = get_position(ent.uid)
    local move_dir = 1
    if ent.move_state == 2 then
        move_dir = -1
    end
    local angle = move_dir*ent.stand_counter/ent.health

    if source_block == nil then
        kill_entity(ent.uid)
    else
        ent.x = sx + source_block.velocityx + (ent.price*math.cos(angle))
        ent.y = sy + source_block.velocityy + (ent.price*math.sin(angle))

        ent.angle = angle+1.5708
    end
end

register_option_button("spawn_spikeball_trap", "spawn_spikeball_trap", 'spike_spikeball_trap', function ()
    local x, y, l = get_position(players[1].uid)
    local spikeball = spawn(ENT_TYPE.ITEM_ROCK, x+3, y, l, 0, 0)
    local chain1 = spawn(ENT_TYPE.ITEM_CHAIN, x+3, y, l, 0, 0)
    local chain2 = spawn(ENT_TYPE.ITEM_CHAIN, x+3, y, l, 0, 0)
    local chain3 = spawn(ENT_TYPE.ITEM_CHAIN, x+3, y, l, 0, 0)
    spikeball_trap_set(spikeball)
    set_post_statemachine(spikeball, spikeball_trap_update)

    spikeball_chain_set(chain1, spikeball, 2)
    set_post_statemachine(chain1, spikeball_chain_update)
    spikeball_chain_set(chain2, spikeball, 1)
    set_post_statemachine(chain2, spikeball_chain_update)
    spikeball_chain_set(chain3, spikeball, 0)
    set_post_statemachine(chain3, spikeball_chain_update)
end)