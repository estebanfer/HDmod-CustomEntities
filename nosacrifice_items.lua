local no_sacrifice_uids = {}
set_post_entity_spawn(function (ent)
    set_pre_collision2(ent.uid, function (altar, sacrifice_ent)
        if no_sacrifice_uids[sacrifice_ent.uid] then
            messpect("true")
            return true
        end
    end)
end, SPAWN_TYPE.ANY, MASK.FLOOR, ENT_TYPE.FLOOR_ALTAR)

set_callback(function ()
    no_sacrifice_uids = {}
end, ON.PRE_LEVEL_GENERATION)

local nosacrifice = {}
function nosacrifice.add_uid(uid)
    no_sacrifice_uids[uid] = true
end

return nosacrifice