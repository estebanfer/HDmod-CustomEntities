local celib = require "custom_entities"

local MOVE_MAP = {
    {0, 1},
    {1, 0},
    {0, -1},
    {-1, 0}
}

local function get_solid_grid_entity(x, y, l)
    local uid = get_grid_entity_at(x, y, l)
    return test_flag(get_entity_flags(uid), ENT_FLAG.SOLID) and uid or -1
end

local function bacterium_set(ent)
    ent.hitboxx = 0.45
    ent.hitboxy = 0.45
    ent.offsety = 0
    local x, y, l = get_position(ent.uid)
    ent.owner_uid = get_solid_grid_entity(x, y-1, l)
    messpect(ent.owner_uid)
    ent.flags = set_flag(ent.flags, ENT_FLAG.NO_GRAVITY)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.COLLIDES_WALLS)
    local is_inverse
    if math.random(2) == 1 then
        is_inverse = false
    else
        is_inverse = true
    end
    return {
        inverse = is_inverse,
        dir_state = 2,
        movex = is_inverse and -1 or 1,
        movey = 0
    }
end

local function will_collide_floor(ent, ent_info)
    local x, y, l = get_position(ent.uid)
    x = ent_info.movex == 0 and math.floor(x+0.5) or math.floor(x+(ent.hitboxx*ent_info.movex)+ent.velocityx+0.5)
    y = ent_info.movey == 0 and math.floor(y+0.5) or math.floor(y+(ent.hitboxy*ent_info.movey)+ent.velocityx+0.5)
    local floor_uid = get_solid_grid_entity(x, y, l)
    if floor_uid ~= -1 then
        return floor_uid
    end
end

local function will_be_out_of_owner(ent, ent_info)
    local ox, oy = get_position(ent.owner_uid)
    messpect(ent_info.movex, math.abs(ent.x + ent.velocityx - ent.hitboxx*ent_info.movex - ox), ent_info.movey, math.abs(ent.y + ent.velocityy - ent.hitboxy*ent_info.movey - oy))
    if (ent_info.movex ~= 0 and ent_info.movex*(ent.x + ent.velocityx - ent.hitboxx*ent_info.movex - ox) > 0.5)
    or (ent_info.movey ~= 0 and ent_info.movey*(ent.y + ent.velocityy - ent.hitboxy*ent_info.movey - oy) > 0.5)  then
        return true
    end
    return false
end

local function update_move(ent, ent_info, ox, oy)
    ent.x = ent_info.movex == 0 and ent.x or ox + (ent.hitboxx+0.025) * 2 * ent_info.movex --+ ent.velocityx
    ent.y = ent_info.movey == 0 and ent.y or oy + (ent.hitboxy+0.025) * 2 * ent_info.movey --+ ent.velocityy
    
    ent_info.movex, ent_info.movey = table.unpack(MOVE_MAP[ent_info.dir_state])
    ent.velocityx = ent_info.movex*0.1
    ent.velocityy = ent_info.movey*0.1
end

local function bacterium_update(ent, ent_info)
    if get_entity(ent.owner_uid) then
        if ent.stun_timer == 0 then
            ent.velocityx = ent_info.movex*0.1
            ent.velocityy = ent_info.movey*0.1
        else
            ent.velocityx = 0
            ent.velocityy = 0
        end
        messpect(ent_info.dir_state, ent.owner_uid)
        if will_be_out_of_owner(ent, ent_info) then
            local ox, oy, ol = get_position(ent.owner_uid)
            local next_floor_uid = get_solid_grid_entity(ox+ent_info.movex, oy+ent_info.movey, ol)
            if next_floor_uid ~= -1 then
                ent.owner_uid = next_floor_uid
            else
                ent_info.dir_state = ent_info.inverse and (ent_info.dir_state - 2) % 4 + 1 or ent_info.dir_state % 4 + 1
                update_move(ent, ent_info, ox, oy)
            end
        else
            local uid = will_collide_floor(ent, ent_info)
            if uid then
                ent_info.dir_state = ent_info.inverse and ent_info.dir_state % 4 + 1 or (ent_info.dir_state - 2) % 4 + 1
                ent_info.movex, ent_info.movey = ent_info.movex*-1, ent_info.movey*-1
                ent.owner_uid = uid
                local ox, oy, ol = get_position(uid)
                update_move(ent, ent_info, ox, oy)
            end
        end
    else
        if ent.standing_on_uid ~= -1 then
            ent.owner_uid = ent.standing_on_uid
            ent.standing_on_uid = -1
            ent.flags = set_flag(ent.flags, ENT_FLAG.NO_GRAVITY)
            ent.flags = clr_flag(ent.flags, ENT_FLAG.COLLIDES_WALLS)
        else
            ent.flags = clr_flag(ent.flags, ENT_FLAG.NO_GRAVITY)
            ent.flags = set_flag(ent.flags, ENT_FLAG.COLLIDES_WALLS)
        end
    end
end

local bacterium_id = celib.new_custom_entity(bacterium_set, bacterium_update)

celib.init()

register_option_button("spawn_bacterium", "spawn bacterium", "spawn bacterium", function ()
    local x, y, l = get_position(players[1].uid)
    x, y = math.floor(x), math.floor(y)
    local uid = spawn(ENT_TYPE.ITEM_ROCK, x, y, l, 0, 0)
    celib.set_custom_entity(uid, bacterium_id)
end)