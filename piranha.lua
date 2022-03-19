require "Custom-Entities-lib.custom_entities"

local function b(flag) return (1 << (flag-1)) end

local function piranha_move(ent)
    local vx = test_flag(ent.flags, ENT_FLAG.FACING_LEFT) and -1 or 1
    if get_entities_overlapping_hitbox(0, MASK.FLOOR | MASK.ACTIVEFLOOR, get_hitbox(ent.uid, 0, 0.01*vx), ent.layer)[1] then
        ent.flags = ent.flags ~ b(ENT_FLAG.FACING_LEFT)
        vx = vx * -1
    end
    ent.velocityx = vx * 0.05
end

---@param ent Tadpole
local function piranha_update(ent)
    --ent.animation_frame = state.time_total % 8 --check how many frames piranha has
    ent.lock_input_timer = 512
    if ent.chased_target_uid then
        ---@type Player
        local chased = get_entity(ent.chased_target_uid)
        if chased.wet_effect_timer == 300 and chased.invincibility_frames_timer == 0 then
            local px, py = get_position(ent.uid)
            local tx, ty = get_position(ent.chased_target_uid)
            local xdiff, ydiff = tx - px, ty - py
            local dist = distance(ent.uid, ent.chased_target_uid) * 20
            local vx, vy = xdiff / dist, ydiff / dist
            local hitbox = get_hitbox(ent.uid, 0, vx, vy)
            if get_entities_overlapping_hitbox(0, MASK.WATER, hitbox, ent.layer)[1] then
                ent.velocityx, ent.velocityy = vx, vy
                ent.flags = xdiff > 0 and clr_flag(ent.flags, ENT_FLAG.FACING_LEFT) or set_flag(ent.flags, ENT_FLAG.FACING_LEFT)
            end
        else
            piranha_move(ent)
        end
    else
        piranha_move(ent)
    end
end