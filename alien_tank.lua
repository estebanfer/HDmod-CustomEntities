--TODO: alien and bombs velocity
--Bombs travel 4.5 tiles aprox?

local function alien_tank_set(ent)
    ent.hitboxx = 0.4
    ent.hitboxy = 0.4
    --ent:set_texture(alien_tank_texture)
end

local function spotted_player(ent)
    local hitbox
    local x, y, l = get_position(ent.uid)
    if test_flag(ent.flags, ENT_FLAG.FACING_LEFT) then
        hitbox = AABB:new(x-5.5, y+5.5, x-ent.hitboxx, y-2)
    else
        hitbox = AABB:new(x+ent.hitboxx, y+5.5, x+5.5, y-2)
    end
    return get_entities_overlapping_hitbox(0, MASK.PLAYER, hitbox, l)[1] ~= nil
end

local function alien_tank_update(ent)
    ent.jump_timer = 2
    if ent.idle_counter > 120 and spotted_player(ent) then
        local x, y, l = get_position(ent.uid)
        local vx = test_flag(ent.flags, ENT_FLAG.FACING_LEFT) and -1 or 1
        get_entity(spawn(ENT_TYPE.ITEM_BOMB, x+vx*0.3, y, l, vx*0.1, 0.1)).last_owner_uid = ent.uid
        ent.idle_counter = 0
    end
end

register_option_button("spawn_tank", "spawn tank", "", function ()
    local x, y, l = get_position(players[1].uid)
    local uid = spawn(ENT_TYPE.MONS_ALIEN, x+1, y, l, 0, 0)
    alien_tank_set(get_entity(uid))
    set_post_statemachine(uid, alien_tank_update)
end)