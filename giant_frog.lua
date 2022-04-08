local celib = require "custom-entities"

--giant frogs spit only 5 frogs and then only jump (?)
local function giant_frog_set()

    return {
        spitting = false
    }
end

local function giant_frog_jump(ent)

end

local function giant_frog_spit(ent)
    local x, y, l = get_position(ent.uid)
    ent.animation_frame = 0
    local vx = test_flag(ent.flags, ENT_FLAG.FACING_LEFT) and -1 or 1
    get_entity(spawn(ENT_TYPE.MONS_FROG, x+vx, y+0.1, l, vx*0.2, 0.1)).last_owner_uid = ent.uid
    ent.idle_counter = 0
end

local function giant_frog_update(ent, c_data)
    if ent.standing_on_uid and ent.state ~= CHAR_STATE.JUMPING then
        if ent.jump_timer == 0 then
            if math.random(2) == 1 then
                giant_frog_jump(ent)
            else
                giant_frog_spit(ent)
                c_data.spitting = true
            end
            ent.jump_timer = math.random(120, 300)
        else
            if c_data.spitting then
                ent.animation_frame = math.floor(ent.idle_counter / 2)
                if ent.animation_frame > 4 then
                    c_data.spitting = false
                end
            end
        end
    end
end