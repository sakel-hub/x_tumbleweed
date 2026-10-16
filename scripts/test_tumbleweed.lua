-- luacheck: ignore
--[[
    Automated Unit Test Suite for x_tumbleweed
    Validates mob registration, B3D frame-range animations, appearance resolution,
    continuous ground bouncing, obstacle hopping, cliff drop-offs, punch physics,
    death breakup, and biome drop integration.
--]]

local total_tests = 0
local passed_tests = 0

local function assert_eq(desc, actual, expected)
    total_tests = total_tests + 1
    if actual == expected then
        passed_tests = passed_tests + 1
        print("  [PASS] " .. desc)
    else
        print("  [FAIL] " .. desc .. " (expected: " .. tostring(expected) .. ", got: " .. tostring(actual) .. ")")
        error("Assertion failed: " .. desc)
    end
end

local function assert_true(desc, val)
    assert_eq(desc, not not val, true)
end

print("==================================================")
print("  Running x_tumbleweed & x_mob_core Unit Tests")
print("==================================================")

-- Setup mock engine environment
local script_dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
local modpath = script_dir .. ".."

local registered_mob_defs = {}
local registered_spawn_defs = {}
local spawned_entities = {}

_G.core = {
    get_translator = function(_modname)
        return function(str) return str end
    end,
    get_modpath = function(_modname)
        return modpath
    end,
    registered_nodes = {
        ["default:desert_sand"] = {
            walkable = true,
            tiles = { "default_desert_sand.png" },
        },
        ["default:stone"] = {
            walkable = true,
            tiles = { "default_stone.png" },
        },
        ["air"] = { walkable = false },
    },
    registered_items = {
        ["default:stick"] = {},
        ["default:dry_shrub"] = {},
    },
    registered_biomes = {
        ["desert"] = { name = "desert" },
        ["sandstone_desert"] = { name = "sandstone_desert" },
        ["cold_desert"] = { name = "cold_desert" },
        ["desert_ocean"] = { name = "desert_ocean" },
        ["everness:forsaken_desert"] = { name = "everness:forsaken_desert" },
        ["everness:forsaken_desert_ocean"] = { name = "everness:forsaken_desert_ocean" },
        ["everness:coral_desert"] = { name = "everness:coral_desert" },
        ["rainforest"] = { name = "rainforest" },
    },
    registered_decorations = {
        deco_desert = {
            deco_type = "simple",
            biomes = { "desert", "sandstone_desert" },
            decoration = "default:dry_shrub",
        },
    },
    get_node = function(pos)
        local nx = math.floor(pos.x + 0.5)
        local ny = math.floor(pos.y + 0.5)
        if ny < 0 then
            return { name = "default:desert_sand" }
        elseif nx >= 1 and (ny == 0 or ny == 1) then
            return { name = "default:stone" }
        end
        return { name = "air" }
    end,
    get_node_or_nil = function(pos)
        return core.get_node(pos)
    end,
    line_of_sight = function(_p1, p2)
        local n = core.get_node(p2)
        local def = core.registered_nodes[n.name]
        return not (def and def.walkable)
    end,
    get_biome_data = function(_pos)
        return { biome = 1 }
    end,
    get_biome_name = function(_id)
        return "desert"
    end,
    sound_play = function() return 1 end,
    add_particlespawner = function(_def)
        return 42
    end,
    serialize = function(t)
        local parts = {}
        for k, v in pairs(t) do
            local val_str = type(v) == "string" and string.format("%q", v) or tostring(v)
            parts[#parts + 1] = string.format("[%q] = %s", k, val_str)
        end
        return "return {" .. table.concat(parts, ",") .. "}"
    end,
    deserialize = function(str)
        if not str or str == "" then return nil end
        local fn = loadstring and loadstring(str) or load(str)
        if fn then
            local ok, res = pcall(fn)
            if ok then return res end
        end
        return nil
    end,
    add_entity = function(pos, name, staticdata)
        local ent = {
            name = name,
            _properties = {},
            _yaw = 0,
            _vel = { x = 0, y = 0, z = 0 },
            set_properties = function(s, p) s._properties = p end,
            set_yaw = function(s, y) s._yaw = y end,
            set_velocity = function(s, v) s._vel = v end,
            get_velocity = function(s) return s._vel end,
            get_pos = function() return pos or { x = 0, y = 0, z = 0 } end,
            get_luaentity = function(s) return s end,
        }
        local obj = {
            _properties = {},
            set_properties = function(s, p) s._properties = p; ent._properties = p end,
            set_yaw = function(_, y) ent._yaw = y end,
            set_velocity = function(_, v) ent._vel = v end,
            get_velocity = function(_) return ent._vel end,
            get_pos = function(_) return pos or { x = 0, y = 0, z = 0 } end,
            get_luaentity = function(_) return ent end,
            is_valid = function() return true end,
        }
        ent.object = obj
        local reg = registered_mob_defs[name]
        if reg and reg.on_activate then
            local data = staticdata and core.deserialize(staticdata) or {}
            reg.on_activate(ent, data)
        end
        spawned_entities[#spawned_entities + 1] = obj
        return obj
    end,
    dir_to_yaw = function(dir)
        local atan2 = math.atan2 or math.atan
        return -atan2(dir.x, dir.z)
    end,
    yaw_to_dir = function(yaw)
        return { x = -math.sin(yaw), y = 0, z = math.cos(yaw) }
    end,
    log = function() end,
    register_on_mods_loaded = function(fn)
        fn()
    end,
    register_entity = function() end,
}

_G.minetest = _G.core
_G.vector = {
    normalize = function(v)
        local len = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
        if len == 0 then return { x = 0, y = 0, z = 0 } end
        return { x = v.x / len, y = v.y / len, z = v.z / len }
    end,
    add = function(a, b)
        return { x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }
    end,
}

-- Mock x_mob_core
local mock_wall_collision = false
local mock_wall_normal = nil

_G.x_mob_core = {
    register_mob = function(name, def)
        local orig_punch = def.on_punch
        local wrapped_def = {}
        for k, v in pairs(def) do wrapped_def[k] = v end
        wrapped_def.on_punch = function(self, puncher, time, caps, dir, dmg)
            if orig_punch then
                local res = orig_punch(self, puncher, time, caps, dir, dmg)
                if res == true then return true end
            end
            return x_mob_core.handle_punch(self, puncher, time, caps, dir, dmg, def)
        end
        registered_mob_defs[name] = wrapped_def
    end,
    register_spawn = function(name, def)
        def._parsed_biomes = {}
        if def.biomes then
            for _, b in ipairs(def.biomes) do
                def._parsed_biomes[b] = true
            end
        end
        registered_spawn_defs[name] = def
    end,
    set_horizontal_velocity = function(self, speed, yaw)
        local dir = core.yaw_to_dir(yaw)
        self.object:set_velocity({ x = dir.x * speed, y = 0, z = dir.z * speed })
    end,
    has_wall_collision = function(_self, _pos, _dtime)
        return mock_wall_collision, mock_wall_normal
    end,
    drop_items = function(_origin, drops, _options)
        return drops
    end,
    play_animation = function(obj, anim, _params)
        local ent = obj:get_luaentity()
        local anim_def = ent and ent._def and ent._def.animations and ent._def.animations[anim]
        if anim_def and anim_def.range and obj.set_animation then
            obj:set_animation(anim_def.range, anim_def.speed, 0, anim_def.loop)
            return true
        end
        return false
    end,
    handle_punch = function(self, puncher, _time, tool_capabilities, _dir, damage, def)
        local fleshy_dmg = (tool_capabilities and tool_capabilities.damage_groups and tool_capabilities.damage_groups.fleshy)
            or damage
            or 1
        self.hp = (self.hp or 10) - fleshy_dmg
        self.target = puncher
        if def and def.on_hurt then
            def.on_hurt(self, puncher, fleshy_dmg)
        end
        if self.hp <= 0 then
            self.is_dead = true
            self.state = "dying"
            if def and def.on_death then
                def.on_death(self, puncher)
            end
            return true
        end
        return true
    end,
}

-- Load XTumbleweed
dofile(modpath .. "/api.lua")
dofile(modpath .. "/entity.lua")

-- Test 1: Verification of Registration & Attributes
assert_true("x_tumbleweed:tumbleweed registered in x_mob_core", registered_mob_defs["x_tumbleweed:tumbleweed"] ~= nil)
local mdef = registered_mob_defs["x_tumbleweed:tumbleweed"]

assert_eq("Initial properties mesh is B3D", mdef.initial_properties.mesh, "x_tumbleweed_tumbleweed.b3d")
assert_eq("Auto scan is disabled", mdef.auto_scan, false)
assert_eq("Melee is disabled", mdef.melee, false)
assert_eq("Shooter is disabled", mdef.shooter, false)
assert_eq("Health bar is disabled", mdef.health_bar, false)
assert_eq("Die in water is enabled", mdef.die_in_water, true)
assert_eq("Makes footstep sound is enabled", mdef.makes_footstep_sound, true)
assert_eq("Knockback mult is 0 (custom punch impulse)", mdef.knockback_mult, 0)
assert_eq("Health regen is disabled", mdef.health_regen, false)
assert_eq("Can flee is disabled", mdef.can_flee, false)
assert_eq("Mob type is passive", mdef.mob_type, "passive")
assert_eq("Aggro radius is 0", mdef.aggro_radius, 0)
assert_true("Damage effect is configured", mdef.damage_effect ~= nil)
assert_eq("Damage effect type is smoke", mdef.damage_effect.type, "smoke")
assert_eq("Damage effect color is sand dust", mdef.damage_effect.color, "#D2B48C")
assert_eq("Damage effect count is 10", mdef.damage_effect.count, 10)
assert_true("Sounds configuration exists", mdef.sounds ~= nil and mdef.sounds.hurt ~= nil)

-- Test 2: Animation Frame Ranges
assert_true("Walk animation has frame range", mdef.animations.walk.range ~= nil)
assert_eq("Walk animation start frame", mdef.animations.walk.range.x, 1)
assert_eq("Walk animation end frame", mdef.animations.walk.range.y, 30)
assert_eq("Stand animation start frame", mdef.animations.stand.range.x, 31)
assert_eq("Stand animation end frame", mdef.animations.stand.range.y, 32)

-- Test 3: Natural Spawning Registration
assert_true("Natural spawn registered in x_mob_core", registered_spawn_defs["x_tumbleweed:tumbleweed"] ~= nil)
local sdef = registered_spawn_defs["x_tumbleweed:tumbleweed"]
assert_eq("Active object count is 1", sdef.active_object_count, 1)
assert_eq("Spawn chance is 1200", sdef.chance, 1200)

-- Test 4: Appearance Resolution (Scale & Camouflage)
local scale, tex = XTumbleweed.resolve_appearance({ x = 0, y = 1, z = 0 }, false, {})
assert_true("Scale is generated between 0.5 and 1.5", scale >= 0.5 and scale <= 1.5)
assert_true("Texture is assigned", tex ~= nil and #tex > 0)

local child_scale, _ = XTumbleweed.resolve_appearance({ x = 0, y = 1, z = 0 }, true, {})
assert_eq("Child tumbleweed scale is strictly 0.5", child_scale, 0.5)

-- Test 5: Biome Decoration Drop Cache
assert_true("Biome drops cached for desert", XTumbleweed.biome_drops["desert"] ~= nil)
assert_eq("Desert drop includes dry_shrub", XTumbleweed.biome_drops["desert"][1], "default:dry_shrub")

local mock_player = {
    is_player = function() return true end,
    get_wielded_item = function()
        return {
            get_tool_capabilities = function()
                return { max_drop_level = 2 }
            end,
        }
    end,
}
local drops = XTumbleweed.get_biome_drops({ x = 0, y = 0, z = 0 }, mock_player)
assert_true("Generated drop entries list", #drops >= 1)
assert_eq("Drop item name matches cached desert vegetation", drops[1].name, "default:dry_shrub")

-- Test 6: Mock Entity Lifecycle Activation & Bouncing Locomotion
local anim_played = nil
local set_anim_called = false
local mock_obj = {
    _vel = { x = 0, y = 0, z = 0 },
    _props = {},
    _yaw = 0,
    set_properties = function(s, p) s._props = p end,
    set_velocity = function(s, v) s._vel = v end,
    get_velocity = function(s) return s._vel end,
    set_yaw = function(s, y) s._yaw = y end,
    get_yaw = function(s) return s._yaw end,
    get_pos = function() return { x = 0, y = 0.5, z = 0 } end,
    is_valid = function() return true end,
    set_animation = function(_s, range, speed, blend, loop)
        set_anim_called = true
        anim_played = { range = range, speed = speed, blend = blend, loop = loop }
    end,
}

local mock_mob = {
    name = "x_tumbleweed:tumbleweed",
    object = mock_obj,
    _def = mdef,
    hp = 10,
    is_dead = false,
}
mock_obj.get_luaentity = function() return mock_mob end

-- Trigger on_activate
mdef.on_activate(mock_mob, {})
assert_true("Mob scale is initialized", mock_mob.scale ~= nil)
assert_true("Object properties visual_size updated", mock_obj._props.visual_size ~= nil)
assert_true("Base texture registered", mock_mob.base_texture ~= nil)

-- Test 7: Continuous Ground Bouncing Impulse
-- When touching ground, a healthy tumbleweed should bounce upward (v_y >= 3.0) and move forward
mock_mob._hop_cooldown = 0
mock_obj._yaw = 0
mdef.on_step(mock_mob, 0.05, { touching_ground = true })
assert_true("Tumbleweed bounced upward on ground (vy >= 3.0)", mock_obj._vel.y >= 3.0)
assert_true("Tumbleweed rolls forward along heading", mock_obj._vel.z > 0)
assert_true("Hop cooldown reset after bounce", mock_mob._hop_cooldown > 0)

-- Test 8: Mid-Flight Velocity Preservation
-- In mid-air, vertical velocity is preserved from engine gravity while directional speed is maintained
mdef.on_step(mock_mob, 0.05, { touching_ground = false })
assert_true("Airborne flight preserves vertical speed", mock_obj._vel.y >= 3.0)
assert_true("Airborne flight maintains horizontal forward speed", mock_obj._vel.z > 0)

-- Test 9: Obstacle Clearing Leap
-- Facing a solid node at chest level triggers an obstacle leap (vy >= 4.8)
mock_mob._hop_cooldown = 0
mock_obj._yaw = -math.pi / 2.0 -- Facing +X towards default:stone at pos.x > 0.5
mdef.on_step(mock_mob, 0.05, { touching_ground = true })
assert_true("Obstacle hop impulse >= 4.8 m/s", mock_obj._vel.y >= 4.8)

-- Test 10: Wall Deflection
mock_wall_collision = true
mock_wall_normal = { x = -1, y = 0, z = 0 }
mock_mob._turn_timer = 0.3
mdef.on_step(mock_mob, 0.05, { touching_ground = true })
assert_true("Wall deflection turned yaw away from wall", mock_obj._yaw ~= 0)
mock_wall_collision = false
mock_wall_normal = nil

-- Test 11: Frame-range animation playback
x_mob_core.play_animation(mock_obj, "walk")
assert_true("B3D set_animation called with frame range", set_anim_called)
assert_eq("Walk frame range start is 1", anim_played.range.x, 1)
assert_eq("Walk frame range end is 30", anim_played.range.y, 30)

-- Test 12: Punch interaction
local punched_dir = { x = 1, y = 0, z = 0 }
mdef.on_punch(mock_mob, mock_player, 1.0, { damage_groups = { fleshy = 3 } }, punched_dir, 3)
assert_eq("Mob takes fleshy damage via combat_handler (10 - 3 = 7)", mock_mob.hp, 7)
assert_true("Mob launched horizontally in punch direction", mock_obj._vel.x > 0)
assert_eq("Mob given vertical launch impulse 2.0", mock_obj._vel.y, 2.0)
assert_eq("Mob target is cleared by on_hurt", mock_mob.target, nil)
assert_eq("Mob state remains walk after punch", mock_mob.state, "walk")

-- Test 12b: On-step target and state sanitization
mock_mob.target = mock_player
mock_mob.state = "fleeing"
mdef.on_step(mock_mob, 0.05, { touching_ground = true })
assert_eq("Mob target cleared on step", mock_mob.target, nil)
assert_eq("Mob state reset to walk on step", mock_mob.state, "walk")

-- Test 13: Lethal punch and Child Breakup
spawned_entities = {}
mdef.on_punch(mock_mob, mock_player, 1.0, { damage_groups = { fleshy = 10 } }, punched_dir, 10)
assert_true("Mob transitioned to dead on lethal punch", mock_mob.is_dead)

-- Test 14: Child Tumbleweed Scaling Verification
local child_staticdata = core.serialize({
    is_child = true,
    scale = 0.5,
    chosen_texture = "x_tumbleweed_tumbleweed_2.png",
})
local child_obj = core.add_entity({ x = 0, y = 1, z = 0 }, "x_tumbleweed:tumbleweed", child_staticdata)
local child_ent = child_obj:get_luaentity()
assert_eq("Child tumbleweed spawned with exact 0.5 scale", child_ent.scale, 0.5)
assert_eq("Child visual size properties set to 0.5", child_obj._properties.visual_size.x, 0.5)
assert_eq("Child inherited parent texture", child_ent.chosen_texture, "x_tumbleweed_tumbleweed_2.png")

-- Test 15: Automatic Biome Discovery
local function table_contains(tbl, val)
    for i = 1, #tbl do
        if tbl[i] == val then return true end
    end
    return false
end

assert_true("Auto-discovered everness:forsaken_desert", table_contains(XTumbleweed.allowed_biomes, "everness:forsaken_desert"))
assert_true("Auto-discovered everness:coral_desert", table_contains(XTumbleweed.allowed_biomes, "everness:coral_desert"))
assert_true("Excluded everness:forsaken_desert_ocean", not table_contains(XTumbleweed.allowed_biomes, "everness:forsaken_desert_ocean"))
assert_true("Excluded desert_ocean", not table_contains(XTumbleweed.allowed_biomes, "desert_ocean"))
assert_true("Excluded rainforest", not table_contains(XTumbleweed.allowed_biomes, "rainforest"))
assert_true("Auto-discovered biome registered in spawn definition", XTumbleweed._spawn_def._parsed_biomes["everness:forsaken_desert"] == true)

-- Test 16: Developer API Singular Alias and Method Syntax
XTumbleweed:add_allowed_biome({ "my_mod:salt_flats" })
assert_true("Custom biome added via singular alias", table_contains(XTumbleweed.allowed_biomes, "my_mod:salt_flats"))
assert_true("Custom biome synced in spawn definition", XTumbleweed._spawn_def._parsed_biomes["my_mod:salt_flats"] == true)

-- Test 17: Extensible Spawn Nodes Registration
XTumbleweed.add_spawn_nodes({ "group:gravel", "my_mod:baked_clay" })
assert_true("Custom group parsed in spawn definition", XTumbleweed._spawn_def._parsed_groups["gravel"] == true)
assert_true("Custom node parsed in spawn definition", XTumbleweed._spawn_def._parsed_nodes["my_mod:baked_clay"] == true)

print("==================================================")
print(string.format("  All %d tests passed successfully! [100%%]", passed_tests))
print("==================================================")
