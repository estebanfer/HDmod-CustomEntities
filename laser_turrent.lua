local celib = require "custom_entities"
local nosacrifice = require "nosacrifice_items"

--Turrent can be freezed on HD, idk how to make that work there
--Spot distance for the trap is 6 tiles (?) and based on distance (circle), doesn't detect if 6 tiles below but on ground, doing a little jump makes it detect you

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

---@param laser LightShot
local function laser_set(laser)
    ---@param _laser LightShot
    ---@param collider Movable
    set_pre_collision2(laser.uid, function (_laser, collider)
        if collider.type.search_flags & (MASK.PLAYER | MASK.MOUNT | MASK.MONSTER) ~= 0 then
            if collider.invincibility_frames_timer == 0 then
                collider:damage(_laser.uid, 1, 60, _laser.velocityx*0.75, 0.1, 30)
            end
            _laser:destroy()
            return true
        end
    end)
    --Plan B (Blue)
    --laser.emitted_light.brightness = 2.0
    --local light = laser.emitted_light.light1
    --light.red, light.green, light.blue = 0.2, 0.5, 1.0
end

local function spawn_turrent_rubble(x, y, l, amount)
    for _=1, amount do
        local rub = get_entity(spawn(ENT_TYPE.ITEM_RUBBLE, x, y, l, prng:random_float(PRNG_CLASS.PARTICLES)*0.5-0.25, prng:random_float(PRNG_CLASS.PARTICLES)*0.25))
        rub.animation_frame = 20
    end
end

---@param ent Movable
local function set_func(ent)
    ent.hitboxx = 0.4
    ent.hitboxy = 0.4
    ent.offsety = 0
    ent:set_texture(turrent_texture_id)
    ent.health = 2
    if ent.overlay and ent.overlay.type.search_flags == MASK.FLOOR then
        ent.flags = set_flag(ent.flags, ENT_FLAG.FACING_LEFT)
    end
    ent.flags = clr_flag(ent.flags, ENT_FLAG.TAKE_NO_DAMAGE)
    ent.flags = clr_flag(ent.flags, 22)
    set_on_kill(ent.uid, function (e)
        local x, y, l = get_position(e.uid)
        get_entity(spawn(ENT_TYPE.FX_EXPLOSION, x, y, l, 0, 0)).last_owner_uid = e.last_owner_uid
        spawn_turrent_rubble(x, y, l, 5)
    end)
    nosacrifice.add_uid(ent.uid)
    return {
        target_uid = -1
    }
end

local function shoot_laser(ent, xdiff, ydiff)
    local x, y, l = get_position(ent.uid)
    local dist = math.sqrt(xdiff*xdiff + ydiff*ydiff) * 3
    local vx, vy = xdiff / dist, ydiff / dist
    local laser = get_entity(spawn(ENT_TYPE.ITEM_LASERTRAP_SHOT, x+vx*2, y+vy*2, l, vx, vy))
    laser_set(laser)
    laser.angle = ent.angle
end

local function shoot_straight_laser(ent)
    local x, y, l = get_position(ent.uid)
    local dir_x = test_flag(ent.flags, ENT_FLAG.FACING_LEFT) and -1 or 1
    local laser = get_entity(spawn(ENT_TYPE.ITEM_LASERTRAP_SHOT, x+dir_x*0.74, y, l, dir_x*0.4, 0))
    laser.last_owner_uid = ent.uid
    laser_set(laser)
    laser.angle = ent.angle
end

local function move_to_angle(ent, to_angle, vel)
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
                if ent.idle_counter > 240 then
                    if math.abs(to_angle - ent.angle) < 0.1 and ydiff < -0.01 then
                        shoot_laser(ent, xdiff, ydiff)
                        ent.idle_counter = 0
                    end
                else
                    ent.idle_counter = ent.idle_counter + 1
                end
            end
            move_to_angle(ent, to_angle, 0.085)
        else --update, unattached
            if ent.overlay.type.search_flags & (MASK.PLAYER | MASK.MONSTER | MASK.MOUNT) ~= 0 then
                if ent.idle_counter > 240 then
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
