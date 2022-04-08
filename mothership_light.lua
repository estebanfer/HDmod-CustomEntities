local celib = require "custom_entities"
local BRIGHTNESS = 1.0
--TODO: sapphire drop chances are wrong (probably)

local lightbulb_texture_id
do
    local lightbulb_texture_def = TextureDefinition.new()
    lightbulb_texture_def.width = 128
    lightbulb_texture_def.height = 128
    lightbulb_texture_def.tile_width = 128
    lightbulb_texture_def.tile_height = 128

    lightbulb_texture_def.texture_path = "lightbulb.png"
    lightbulb_texture_id = define_texture(lightbulb_texture_def)
end

local function light_update(light_emitter)
    refresh_illumination(light_emitter)
    light_emitter.brightness = BRIGHTNESS
end

local function mothership_light_set(ent)
    ent.hitboxx = 0.35
    ent.hitboxy = 0.4
    ent:set_texture(lightbulb_texture_id)
    local light_emitter = create_illumination(Color:new(0.2, 0.3, 1, 1), 3, ent.uid)
    light_emitter.brightness = BRIGHTNESS
    light_emitter.brightness_multiplier = 3.0
    return {
        light_emitter = light_emitter
    }
end

local function mothership_light_update(ent, c_data)
    if not ent.overlay or test_flag(ent.flags, ENT_FLAG.DEAD) then
        kill_entity(ent.uid)
        local rand = math.random(8)
        if rand == 7 then
            local x, y, l = get_position(ent.uid)
            spawn(ENT_TYPE.ITEM_SAPPHIRE_SMALL, x, y, l, math.random()*0.2-0.1, math.random()*0.1)
        elseif rand == 8 then
            local x, y, l = get_position(ent.uid)
            spawn(ENT_TYPE.ITEM_SAPPHIRE, x, y, l, math.random()*0.2-0.1, math.random()*0.1)
        end
    end
    light_update(c_data.light_emitter)
end

local mothership_light_id = celib.new_custom_entity(mothership_light_set, mothership_light_update)
celib.init()

register_option_button("spawn_tank", "spawn tank", "", function ()
    local x, y, l = get_position(players[1].uid)
    x, y = math.floor(x), math.floor(y)
    local uid = spawn_over(ENT_TYPE.ITEM_ICESPIRE, get_grid_entity_at(x, y+1, l), 0, -0.9)
    celib.set_custom_entity(uid, mothership_light_id)
end)