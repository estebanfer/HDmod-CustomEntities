local nosacrifice = require "nosacrifice_items"
--TODO: check piranha spotting players max distance on HD

local function b(flag) return (1 << (flag-1)) end

local function set_piranha_skeleton(uid)
    --TODO: Hitbox?
    --set_entity_flags(uid, set_flag(get_entity_flags(uid), ENT_FLAG.TAKE_NO_DAMAGE))
    local ent = get_entity(uid)
    ent.hitboxx = 0.35
    ent.hitboxy = 0.25
    nosacrifice.add_uid(uid)
    --offsety?
    --get_entity(uid):set_texture(piranha_corpse_texture)
end

local function piranha_move(ent)
    local vx = test_flag(ent.flags, ENT_FLAG.FACING_LEFT) and -1 or 1
    if get_entities_overlapping_hitbox(0, MASK.FLOOR | MASK.ACTIVEFLOOR, get_hitbox(ent.uid, 0, 0.01*vx), ent.layer)[1] then
        ent.flags = ent.flags ~ b(ENT_FLAG.FACING_LEFT)
        vx = vx * -1
    end
    ent.velocityx = vx * 0.05
    local hitbox = get_hitbox(ent.uid, 0, 0, 0.15):extrude(-0.2)
    if not get_entities_overlapping_hitbox(0, MASK.WATER, hitbox, ent.layer)[1] then
        ent.velocityy = ent.velocityy - 0.01
    else
        ent.velocityy = 0
    end
end

local function chase_target(ent, px, py)
    local tx, ty = get_position(ent.chased_target_uid)
    local xdiff, ydiff = tx - px, ty - py
    local dist = distance(ent.uid, ent.chased_target_uid) * 20
    local vx, vy = xdiff / dist, ydiff / dist
    local hitbox = get_hitbox(ent.uid, 0, vx, vy+0.15):extrude(-0.2)
    if not get_entities_overlapping_hitbox(0, MASK.WATER, hitbox, ent.layer)[1] then
        vy = ent.velocityy - 0.01
    end
    ent.velocityx, ent.velocityy = vx, vy
    ent.flags = xdiff > 0 and clr_flag(ent.flags, ENT_FLAG.FACING_LEFT) or set_flag(ent.flags, ENT_FLAG.FACING_LEFT)
end

local function get_targetable_player(players_close)
    for _, uid in ipairs(players_close) do
        ---@type Player
        local chased = get_entity(uid)
        if chased.wet_effect_timer == 300 and chased.invincibility_frames_timer == 0 then
            return chased
        end
    end
    return nil
end

---@param ent Tadpole
local function piranha_update(ent)
    --ent.animation_frame = get_frame() % 8 --check how many frames piranha has
    ent.lock_input_timer = 512
    ---@type Player
    local chased = get_entity(ent.chased_target_uid)
    if chased then
        if chased.wet_effect_timer == 300 and chased.invincibility_frames_timer == 0 and distance(ent.uid, chased.uid) < 7 then
            local px, py = get_position(ent.uid)
            chase_target(ent, px, py)
        else
            ent.chased_target_uid = -1
            piranha_move(ent)
        end
    else
        local px, py, pl = get_position(ent.uid)
        local target = get_targetable_player(get_entities_at(0, MASK.PLAYER, px, py, pl, 7))
        if target then
            ent.chased_target_uid = target.uid
            chase_target(ent, px, py)
        else
            piranha_move(ent)
        end
    end
    if ent.wet_effect_timer < 300 and ent.standing_on_uid ~= -1 then
        local x, y, l = get_position(ent.uid)
        set_piranha_skeleton(spawn(ENT_TYPE.ITEM_ROCK, x, y, l, 0, 0))
        ent:destroy()
    end
end

register_option_button("spawn_piranha", "spawn_piranha", "spawn_piranha", function ()
    local x, y, l = get_position(players[1].uid)
    local uid = spawn(ENT_TYPE.MONS_TADPOLE, x, y, l, 0, 0)
    set_post_statemachine(uid, piranha_update)
end)