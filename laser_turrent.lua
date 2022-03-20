local celib = require "custom_entities"

--TODO: better solution when player is over the turrent and gets a limit of the angle
--Spot distance for the trap is 6 tiles (?) and based on distance (circle), doesn't detect if 6 tiles below but on ground, doing a little jump makes it detect you
--2.5 secs cooldown for shooting?

local function get_diffs(uid1, uid2)
    local x, y = get_position(uid1)
    local tx, ty = get_position(uid2)
    return tx - x, ty - y
end

---@param ent Container
local function set_func(ent)
    --ent.hitboxx = 0.4
    --ent.hitboxy = 0.4
    ent.health = 2
    ent.inside = ENT_TYPE.FX_EXPLOSION
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
    spawn(ENT_TYPE.ITEM_LASERTRAP_SHOT, x+dir_x*0.3, y, l, dir_x*0.4, 0)
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
            ydiff = -0.01
        end
        to_angle = math.atan(ydiff / xdiff)
    end
    to_angle = to_angle < 0 and math.pi + to_angle or to_angle
    return to_angle, xdiff, ydiff
end

local function point_up(turrent)
    local to_angle
    turrent.idle_counter = 0
    to_angle = test_flag(turrent.flags, ENT_FLAG.FACING_LEFT) and 1.5708 or -1.5708
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
        else --update, unattached
            --TODO: Check if MASK.MONSTER is necessary and other masks
            if ent.overlay.type.search_flags & (MASK.PLAYER | MASK.MONSTER | MASK.MOUNT) ~= 0 then
                if ent.idle_counter > 180 then
                    shoot_straight_laser(ent)
                    ent.idle_counter = 0
                else
                    ent.idle_counter = ent.idle_counter + 1
                end
                to_angle = math.pi
                ent.angle = to_angle
            else
                to_angle = point_up(ent)
            end
        end
    else
        to_angle = point_up(ent)
    end
    messpect(to_angle)
    move_to_angle(ent, to_angle, 0.05)
end

local turrent_id = celib.new_custom_entity(set_func, update_func, celib.CARRY_TYPE.HELD, ENT_TYPE.ITEM_CRATE)
celib.init()

register_option_button("spawn_trap", "spawn turrent", "spawn turrent", function ()
    local x, y, l = get_position(players[1].uid)
    x, y = math.floor(x), math.floor(y)
    local over = get_grid_entity_at(x, y+1, l)
    local uid
    if over ~= -1 then
        uid = spawn_over(ENT_TYPE.ITEM_CRATE, over, 0, -1)
    else
        uid = spawn(ENT_TYPE.ITEM_CRATE, x, y, l, 0, 0)
    end
    celib.set_custom_entity(uid, turrent_id)
end)