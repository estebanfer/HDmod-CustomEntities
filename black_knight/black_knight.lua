local celib = require "custom_entities"

local black_knight_texture_id
do
    black_knight_texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_MONSTERS01_0)
    black_knight_texture_def.texture_path = 'black_knight.png'
    black_knight_texture_id = define_texture(black_knight_texture_def)
end
local shield_texture_id
do
    shield_texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_ITEMS_0)
    shield_texture_def.texture_path = 'shield.png'
    shield_texture_id = define_texture(shield_texture_def)
end
local function black_knight_set(uid)
    local ent = get_entity(uid)
    ent:set_texture(black_knight_texture_id)
    local x, y, l = get_position(uid)
    local shield = get_entity(spawn(ENT_TYPE.ITEM_METAL_SHIELD, x, y, l, 0, 0))
    shield:set_texture(shield_texture_id)
    pick_up(uid, shield.uid)
end
local function black_knight_update(ent)
    --give the tikiman a speedboost so its as fast as a shoppie
    if ent.movex ~= 0 then
        ent.x = ent.x + 0.025*ent.movex
    end
    if ent.move_state == 6 then
        --aggro shoppie behavior from scratch
        if players[1] ~= nil then
            local px, py, pl = get_position(players[1].uid)
            local x, y, l = get_position(ent.uid)
            if py > y and ent.standing_on_uid ~= -1 then
                ent.velocityy = 0.21
            end
            if math.abs(px-x) > 6 and ent.standing_on_uid ~= -1 then
                ent.velocityy = 0.21
            end
        end
    end
end
local function black_knight_death(ent, damage_dealer, damage_amount, velocityx, velocityy, stun_amount, iframes)
    if ent.health - damage_amount <= 0 then
        local x, y, l = get_position(ent.uid)
        local held_item = get_entity(ent.holding_uid)
        if held_item ~= nil then
            held_item.velocityx = ent.velocityx
            held_item.velocityy = ent.velocityy
        end
        local grub = spawn(ENT_TYPE.MONS_GRUB, x, y, l, 0, 0)
        ent:drop(get_entity(ent.holding_uid))
        ent.x = -900
        --create a new,, silent corpse :)))
        kill_entity(grub) --grubs make a good way to generate blood based on whether or not the player has vlads cape
        set_timeout(function()
            if ent.frozen_timer == 0 then --leave no corpse if frozen,, crushing should be fine .
                local corpse = get_entity(spawn(ENT_TYPE.MONS_TIKIMAN, x, y, l, 0, 0))
                corpse:set_texture(black_knight_texture_id)
                corpse.velocityx = ent.velocityx
                corpse.velocityy = ent.velocityy
                corpse.flags = set_flag(corpse.flags, ENT_FLAG.DEAD)
                corpse.health = 0
                corpse:light_on_fire(ent.onfire_effect_timer)
                corpse.wet_effect_timer = ent.wet_effect_timer
            end
        end, 1)
    end
end

register_option_button("spawn_black_knight", "spawn_black_knight", 'spawn_black_knight', function ()
    local x, y, l = get_position(players[1].uid)
    local black_knight = spawn(ENT_TYPE.MONS_TIKIMAN, x-5, y, l, 0, 0)
    black_knight_set(black_knight)
    set_post_statemachine(black_knight, black_knight_update)
    set_on_damage(black_knight, black_knight_death)
end)