local celib = require "custom_entities"
--movable.price is used as a cooldown for whip "no damage" effect
local green_knight_texture_id
do
    green_knight_texture_def = get_texture_definition(TEXTURE.DATA_TEXTURES_MONSTERS01_0)
    green_knight_texture_def.texture_path = 'green_knight.png'
    green_knight_texture_id = define_texture(green_knight_texture_def)
end
--this should probably be put away somewhere correct and not here but this is fine for now..
local function play_sound_at_entity(snd, uid, volume)
    local v = 0.5
    if volume ~= nil then
        v = volume
    end
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
    audio:set_parameter(VANILLA_SOUND_PARAM.VALUE, v)
    
    -- unpause after init
    audio:set_pause(false)
end
local function green_knight_set(uid)
    local ent = get_entity(uid)
    local x, y, l = get_position(uid)
    ent.flags = clr_flag(ent.flags, ENT_FLAG.CAN_BE_STOMPED)
    --set the caveman to be awake
    ent.move_state = 0
    ent.state = 1
    ent:set_texture(green_knight_texture_id)
end
local function green_knight_update(ent)
    --manage price timer
    if ent.price > 0 then
        ent.price = ent.price - 1
    end
    --rule #4928: no talking to other cavemen
    ent.cooldown_timer = 180
    ent.stand_counter = 180
    if ent.move_state == 2 then
        ent.move_state = 1
    end
    --rule #4929: no picking up items
    ent.can_pick_up_timer = 179
    --rule #4931: no tripping
end
local function ignore_whip_damage(ent, damage_dealer, damage_amount, velocityx, velocityy, stun_amount, iframes)
    if damage_dealer.type.id == ENT_TYPE.ITEM_WHIP and ent.price == 0 and ent.health > 2 then
        generate_particles(PARTICLEEMITTER.NOHITEFFECT_STARS, ent.uid)
        ent.price = 10 --cooldown
        play_sound_at_entity(VANILLA_SOUND.ENEMIES_ENEMY_HIT_INVINCIBLE, ent.uid)
        return true
    end
end
local function become_caveman(ent, damage_dealer, damage_amount, velocityx, velocityy, stun_amount, iframes)
    if damage_dealer.type.id ~= ENT_TYPE.ITEM_WHIP and ent.health > 2 then
        if ent.health - damage_amount <= 2 then
            ent:set_texture(ent.type.texture)
            --sfx and green rubble here
            ent.flags = set_flag(ent.flags, ENT_FLAG.CAN_BE_STOMPED)
            play_sound_at_entity(VANILLA_SOUND.ENEMIES_OLMITE_ARMOR_BREAK, ent.uid)
            for i=1, 4, 1 do
                local x, y, l = get_position(ent.uid)
                local rubble = get_entity(spawn(ENT_TYPE.ITEM_RUBBLE, x, y, l, math.random(-10, 10)/100, math.random(1, 6)/30))
                rubble.animation_frame = 41
                rubble.color.r = 155
                rubble.color.g = 35
                rubble.color.b = 200
            end
        end
    end
end

register_option_button("spawn_green_knight", "spawn_green_knight", 'spawn_green_knight', function ()
    local x, y, l = get_position(players[1].uid)
    local green_knight = spawn(ENT_TYPE.MONS_CAVEMAN, x-5, y, l, 0, 0)
    green_knight_set(green_knight)
    set_post_statemachine(green_knight, green_knight_update)
    set_on_damage(green_knight, ignore_whip_damage)
    set_on_damage(green_knight, become_caveman)
end)