local celib = require "custom_entities"

--this script will bug in OL,, but in PL its fine .
local mammoth_texture_id
do
    mammoth_texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_MONSTERSBIG03_0)
    mammoth_texture_def.texture_path = 'mammoth.png'
    mammoth_texture_id = define_texture(mammoth_texture_def)
end
--this should probably be put away somewhere correct and not here but this is fine for now..
local function play_sound_at_entity(snd, uid)
        local ent = get_entity(uid)
        local sound = get_sound(snd)
        local audio = sound:play(true)
        local x, y, _ = get_position(ent.uid)
        local sx, sy = screen_position(x, y)
        local d = screen_distance(distance(ent.uid, ent.uid))
        if players[1] ~= nil then
            d = screen_distance(distance(ent.uid, players[1].uid))
        end
        audio:set_parameter(VANILLA_SOUND_PARAM.POS_SCREEN_X, sx)
        audio:set_parameter(VANILLA_SOUND_PARAM.DIST_CENTER_X, math.abs(sx))
        audio:set_parameter(VANILLA_SOUND_PARAM.DIST_CENTER_Y, math.abs(sy))
        audio:set_parameter(VANILLA_SOUND_PARAM.DIST_Z, 0.0)
        audio:set_parameter(VANILLA_SOUND_PARAM.DIST_PLAYER, d)
        audio:set_parameter(VANILLA_SOUND_PARAM.VALUE, 0.5)
        
        -- unpause after init
        audio:set_pause(false)
end
local function mammoth_set(uid)
    local ent = get_entity(uid)
    local x, y, l = get_position(uid)

    ent:set_texture(mammoth_texture_id)

    --we are using price as a variable to keep track of when mammoth will shoot a freezray blast
    ent.price = 90
end
local function mammoth_update(ent)
    --remove the lamassu attack FX
    if get_entity(ent.attack_effect_entity.uid) ~= nil then
        ent.attack_effect_entity:remove()
    end
    ent.emitted_light.enabled = false
    ent.particle.x = -900
    --clear targetting logic so the mammoth doesnt try to turn around and face the player
    ent.chased_target_uid = -1
    ent.target_selection_timer = 60
    --determine state
    if ent.price > 20 then
        ent.move_state = 1
    else
        ent.move_state = 30
    end

    --do animations manually
    if ent.price <= 20 and ent.price > 16 then
        ent.animation_frame = 1
    elseif ent.price <= 16 and ent.price > 12 then
        ent.animation_frame = 2
    elseif ent.price <= 12 and ent.price > 8 then
        ent.animation_frame = 3
    elseif ent.price <= 8 and ent.price > 4 then
        ent.animation_frame = 4
    elseif ent.price <= 4 then
        ent.animation_frame = 5
    end

    --only decrease timer if the ent isnt stopped by anything
    if ent.lock_input_timer == 0 and ent.frozen_timer == 0 then
        ent.price = ent.price - 1
    end
    if ent.price == 0 or ent.frozen_timer ~= 0 then
        ent.price = 90
    end
    if ent.price == 4 then --create attack hitbox
        local x, y, l = get_position(ent.uid)
        play_sound_at_entity(VANILLA_SOUND.ITEMS_FREEZE_RAY, ent.uid)
        if test_flag(ent.flags, ENT_FLAG.FACING_LEFT) then
            local freezeray = get_entity(spawn(ENT_TYPE.ITEM_FREEZERAYSHOT, x-1, y-0.5, l, -0.25, 0))
            freezeray.angle = math.pi
        else
            local freezeray = get_entity(spawn(ENT_TYPE.ITEM_FREEZERAYSHOT, x+1, y-0.5, l, 0.25, 0))
        end
    end
end

register_option_button("spawn_mammoth", "spawn_mammoth", 'spawn_mammoth', function ()
    local x, y, l = get_position(players[1].uid)
    local mammoth = spawn(ENT_TYPE.MONS_LAMASSU, x-3, y, l, 0, 0)
    mammoth_set(mammoth)
    set_post_statemachine(mammoth, mammoth_update)
    set_on_kill(mammoth, function()
        local ent = get_entity(mammoth)
        local x, y, l = get_position(mammoth)
        kill_entity(spawn(ENT_TYPE.MONS_AMMIT, x+0.2, y-0.6, l, 0, 0))
        ent.x = -900 --destroy() and remove() both crash the game ????
    end)
end)