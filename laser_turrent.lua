local celib = require "custom_entities"

--Spot distance for the trap is 6 tiles (?) and based on distance (circle), doesn't detect if 6 tiles below but on ground, doing a little jump makes it detect you
--2.5 secs cooldown for shooting?

local turrent_texture_id
do
    local turrent_texture_def = TextureDefinition.new()
    turrent_texture_def.width = 128
    turrent_texture_def.height = 128
    turrent_texture_def.tile_width = 128
    turrent_texture_def.tile_height = 128

    turrent_texture_def.texture_path = "turrent.png"
    turrent_texture_id = define_texture(turrent_texture_def)
end

local function get_diffs(uid1, uid2)
    local x, y = get_position(uid1)
    local tx, ty = get_position(uid2)
    return tx - x, ty - y
end

---@param ent Movable
local function set_func(ent)
    ent.hitboxx = 0.4
    ent.hitboxy = 0.4
    ent.offsety = 0
    ent:set_texture(turrent_texture_id)
    --Fixes a weird bug on transitions
    if ent.health then
        ent.health = 2
    else
        set_timeout(function()
            get_entity(ent.uid).health = 1
        end, 1)
    end
    if ent.overlay and ent.overlay.type.search_flags == MASK.FLOOR then
        ent.flags = set_flag(ent.flags, ENT_FLAG.FACING_LEFT)
    end
    ent.flags = clr_flag(ent.flags, ENT_FLAG.TAKE_NO_DAMAGE)
    set_on_kill(ent.uid, function (e)
        local x, y, l = get_position(e.uid)
        spawn(ENT_TYPE.FX_EXPLOSION, x, y, l, 0, 0)
    end)
    return {
        target_uid = -1
    }
end

local function shoot_laser(ent, xdiff, ydiff)
    local x, y, l = get_position(ent.uid)
    local dist = math.sqrt(xdiff*xdiff + ydiff*ydiff) * 3
    local vx, vy = xdiff / dist, ydiff / dist
    get_entity(spawn(ENT_TYPE.ITEM_LASERTRAP_SHOT, x+vx*2, y+vy*2, l, vx, vy)).angle = ent.angle
end

local function shoot_straight_laser(ent)
    local x, y, l = get_position(ent.uid)
    local dir_x = test_flag(ent.flags, ENT_FLAG.FACING_LEFT) and -1 or 1
    get_entity(spawn(ENT_TYPE.ITEM_LASERTRAP_SHOT, x+dir_x*0.74, y, l, dir_x*0.4, 0)).last_owner_uid = ent.uid
end

local function move_to_angle(ent, to_angle, vel)
    messpect("angle2", to_angle)
    local diff = to_angle - ent.angle
    if math.abs(diff) < vel then
        ent.angle = to_angle
    else
        ent.angle = diff > 0 and ent.angle + vel or ent.angle - vel 
    end
end

local MAX_DIST = 6
local function point_to_target(ent, c_data)
    local to_angle
    local xdiff, ydiff = get_diffs(ent.uid, c_data.target_uid)
    if math.sqrt(xdiff*xdiff + ydiff*ydiff) > MAX_DIST then
        c_data.target_uid = -1
        to_angle = -1.5708
    else
        if ydiff > 0 then
            to_angle = xdiff < 0 and 0.34906585 or -0.34906585 --20 deg, TODO: check angle in HD
        else
            to_angle = math.atan(ydiff / xdiff)
        end
    end
    to_angle = to_angle < 0 and math.pi + to_angle or to_angle
    return to_angle, xdiff, ydiff
end

local function point_up(turrent)
    local to_angle
    turrent.idle_counter = 0
    to_angle = test_flag(turrent.flags, ENT_FLAG.FACING_LEFT) and -1.5708 or 1.5708
    turrent.angle = to_angle
    return to_angle
end

local function update_func(ent, c_data)
    local to_angle = 0
    if ent.overlay then
        if ent.overlay.type.search_flags == MASK.FLOOR then --update, attached to ceiling
            messpect(c_data.target_uid)
            if c_data.target_uid == -1 then
                local x, y, layer = get_position(ent.uid)
                local targets = get_entities_at(0, MASK.PLAYER, x, y, layer, MAX_DIST)
                if targets[1] then
                        c_data.target_uid = targets[1]
                        to_angle = point_to_target(ent, c_data)
                else
                    ent.idle_counter = 0
                    to_angle = 1.5708
                end
            else
                local xdiff, ydiff
                to_angle, xdiff, ydiff = point_to_target(ent, c_data)
                if ent.idle_counter > 120 then
                    messpect(math.abs(to_angle - ent.angle) < 0.1, ydiff < -0.01)
                    if math.abs(to_angle - ent.angle) < 0.1 and ydiff < -0.01 then
                        shoot_laser(ent, xdiff, ydiff)
                        ent.idle_counter = 0
                    end
                else
                    ent.idle_counter = ent.idle_counter + 1
                end
            end
            move_to_angle(ent, to_angle, 0.05)
        else --update, unattached
            if ent.overlay.type.search_flags & (MASK.PLAYER | MASK.MONSTER | MASK.MOUNT) ~= 0 then
                if ent.idle_counter > 180 then
                    shoot_straight_laser(ent)
                    ent.idle_counter = 0
                else
                    ent.idle_counter = ent.idle_counter + 1
                end
                ent.angle = 0
            else
                ent.angle = point_up(ent)
            end
        end
    else
        ent.angle = point_up(ent)
    end
    messpect(to_angle)
end

local turrent_id = celib.new_custom_entity(set_func, update_func, celib.CARRY_TYPE.HELD, ENT_TYPE.ITEM_ROCK)
celib.init()

register_option_button("spawn_trap", "spawn turrent", "spawn turrent", function ()
    local x, y, l = get_position(players[1].uid)
    x, y = math.floor(x), math.floor(y)
    local over
    repeat
        over = get_grid_entity_at(x, y+1, l)
        y = y + 1
    until over ~= -1
    local uid = spawn_over(ENT_TYPE.ITEM_ROCK, over, 0, -1)
    celib.set_custom_entity(uid, turrent_id)
end)

local function spawn_turrent(x, y, l)
    local over, uid = get_grid_entity_at(x, y+1, l)
    if over ~= -1 then
        uid = spawn_over(ENT_TYPE.ITEM_ROCK, over, 0, -1)
    else
        uid = spawn(ENT_TYPE.ITEM_ROCK, x, y, l, 0, 0)
    end
    celib.set_custom_entity(uid, turrent_id)
end

local function is_solid_grid_entity(x, y, l)
    return test_flag(get_entity_flags(get_grid_entity_at(x, y, l)), ENT_FLAG.SOLID)
end
local function is_valid_turrent_spawn(x, y, l)
    if get_grid_entity_at(x, y, l) == -1 and is_solid_grid_entity(x, y+1, l) then
        return true
    end
    return false
end
local turrent_chance = define_procedural_spawn("turrent", spawn_turrent, is_valid_turrent_spawn)

---@param room_gen_ctx PostRoomGenerationContext
set_callback(function(room_gen_ctx)
    room_gen_ctx:set_procedural_spawn_chance(turrent_chance, 10)
end, ON.POST_ROOM_GENERATION)
