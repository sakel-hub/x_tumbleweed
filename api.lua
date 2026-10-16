--[[
    X Tumbleweed. Adds tumbleweeds.
    Copyright (C) 2025-2026 SaKeL

    This library is free software; you can redistribute it and/or
    modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 2.1 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library; if not, see <https://www.gnu.org/licenses/>.
--]]

local S = core.get_translator("x_tumbleweed")

---@class XTumbleweed
---@field allowed_biomes string[] Allowed spawning biome identifiers
---@field biome_drops table<string, string[]> Pre-indexed decoration drop names per biome
---@field textures string[] Default base texture filenames
---@field sounds table<string, string> Audio specifications
XTumbleweed = {
    allowed_biomes = {
        "desert",
        "sandstone_desert",
        "cold_desert",
    },
    biome_drops = {},
    textures = {
        "x_tumbleweed_tumbleweed_1.png",
        "x_tumbleweed_tumbleweed_2.png",
        "x_tumbleweed_tumbleweed_3.png",
    },
    sounds = {
        neutral = "x_tumbleweed_tumbleweed",
    },
}

---Checks if an indexed array table contains a specific scalar value.
---@param tbl table|nil
---@param val string|number
---@return boolean
local function table_contains(tbl, val)
    if not tbl or type(tbl) ~= "table" then return false end
    for i = 1, #tbl do
        if tbl[i] == val then return true end
    end
    return false
end

---Adds biome identifiers to the allowed spawn list and updates the x_mob_core spawner.
---@param self_or_biomes any Table namespace or array of biome names
---@param biomes_opt? string[] Optional array of biome names if invoked via method syntax
function XTumbleweed.add_allowed_biomes(self_or_biomes, biomes_opt)
    local biomes = (type(self_or_biomes) == "table" and self_or_biomes ~= XTumbleweed) and self_or_biomes or biomes_opt
    if not biomes or type(biomes) ~= "table" then return end

    for i = 1, #biomes do
        local bname = biomes[i]
        if not table_contains(XTumbleweed.allowed_biomes, bname) then
            XTumbleweed.allowed_biomes[#XTumbleweed.allowed_biomes + 1] = bname
        end
    end

    if XTumbleweed._spawn_def then
        if XTumbleweed._spawn_def._parsed_biomes then
            for i = 1, #XTumbleweed.allowed_biomes do
                XTumbleweed._spawn_def._parsed_biomes[XTumbleweed.allowed_biomes[i]] = true
            end
        end
        if XTumbleweed._spawn_def.biomes then
            XTumbleweed._spawn_def.biomes = XTumbleweed.allowed_biomes
        end
    end
end

---Backwards-compatible singular alias for add_allowed_biomes.
XTumbleweed.add_allowed_biome = XTumbleweed.add_allowed_biomes

---Adds ground nodes or node groups to the tumbleweed spawner definition.
---@param self_or_nodes any Table namespace or array of node or group names
---@param nodes_opt? string[] Optional array of node or group names if invoked via method syntax
function XTumbleweed.add_spawn_nodes(self_or_nodes, nodes_opt)
    local nodes = (type(self_or_nodes) == "table" and self_or_nodes ~= XTumbleweed) and self_or_nodes or nodes_opt
    if not nodes or type(nodes) ~= "table" then return end

    if XTumbleweed._spawn_def then
        XTumbleweed._spawn_def.nodes = XTumbleweed._spawn_def.nodes or {}
        for i = 1, #nodes do
            local nodename = nodes[i]
            if not table_contains(XTumbleweed._spawn_def.nodes, nodename) then
                XTumbleweed._spawn_def.nodes[#XTumbleweed._spawn_def.nodes + 1] = nodename
            end
            if nodename:sub(1, 6) == "group:" then
                local gname = nodename:sub(7)
                XTumbleweed._spawn_def._parsed_groups = XTumbleweed._spawn_def._parsed_groups or {}
                XTumbleweed._spawn_def._parsed_groups[gname] = true
            else
                XTumbleweed._spawn_def._parsed_nodes = XTumbleweed._spawn_def._parsed_nodes or {}
                XTumbleweed._spawn_def._parsed_nodes[nodename] = true
            end
        end
    end
end

---Resolves the dropped item name for a registered node or item.
---@param item_name string
---@return string
local function resolve_drop_item(item_name)
    local item_def = core.registered_nodes[item_name] or core.registered_items[item_name]
    if item_def and item_def.drop then
        local drop_val = item_def.drop
        if type(drop_val) == "string" and drop_val ~= "" then
            return drop_val
        elseif type(drop_val) == "table" and drop_val.items then
            for i = 1, #drop_val.items do
                local entry = drop_val.items[i]
                if entry and entry.items and #entry.items > 0 then
                    return entry.items[1]
                end
            end
        end
    end
    return item_name
end

---Pre-indexes simple decoration drops and auto-discovers desert biomes once all mods have loaded.
---Eliminates per-death iteration over core.registered_decorations and removes any need
---for hardcoded dependencies on third-party biome mods like Everness or Ethereal.
core.register_on_mods_loaded(function()
    -- 1. Auto-discover registered desert and dune biomes across all loaded mods
    if core.registered_biomes then
        local discovered = {}
        for name, bdef in pairs(core.registered_biomes) do
            local bname = (type(name) == "string" and name) or (type(bdef) == "table" and bdef.name)
            if bname and (bname:find("desert") or bname:find("dune")) then
                -- Exclude ocean, underwater, subterranean, or river biome variants
                if not (bname:find("ocean") or bname:find("under") or bname:find("water")
                        or bname:find("sea") or bname:find("river") or bname:find("cave")) then
                    discovered[#discovered + 1] = bname
                end
            end
        end
        if #discovered > 0 then
            XTumbleweed.add_allowed_biomes(discovered)
        end
    end

    -- 2. Pre-index simple decoration drops by biome
    local drops_by_biome = {}

    if core.registered_decorations then
        for _, deco in pairs(core.registered_decorations) do
            if deco.deco_type == "simple" and deco.biomes and deco.decoration then
                local biomes = deco.biomes
                if type(biomes) == "string" then
                    biomes = { biomes }
                end

                local items = deco.decoration
                if type(items) == "string" then
                    items = { items }
                end

                for b = 1, #biomes do
                    local bname = biomes[b]
                    drops_by_biome[bname] = drops_by_biome[bname] or {}
                    local biome_list = drops_by_biome[bname]

                    for d = 1, #items do
                        local resolved = resolve_drop_item(items[d])
                        if resolved and not table_contains(biome_list, resolved) then
                            biome_list[#biome_list + 1] = resolved
                        end
                    end
                end
            end
        end
    end

    XTumbleweed.biome_drops = drops_by_biome
end)

---Resolves decorative vegetation drops for a given world position and puncher tool capability.
---@param pos Vector World coordinate of defeat
---@param puncher? ObjectRef Player or entity who broke the tumbleweed
---@return table[] drops Drop table formatted for x_mob_core.drop_items
function XTumbleweed.get_biome_drops(pos, puncher)
    local biome_name = ""
    local bdata = core.get_biome_data(pos)
    if bdata and bdata.biome then
        biome_name = core.get_biome_name(bdata.biome) or ""
    end

    local candidate_items = XTumbleweed.biome_drops[biome_name]
    if not candidate_items or #candidate_items == 0 then
        candidate_items = { "default:stick" }
    end

    local max_drop_level = 1
    if puncher and puncher:is_player() then
        local wielded = puncher:get_wielded_item()
        local caps = wielded and wielded:get_tool_capabilities()
        if caps and caps.max_drop_level and caps.max_drop_level > 1 then
            max_drop_level = caps.max_drop_level
        end
    end

    local drop_rolls = math.random(1, 3)
    local drop_entries = {}

    for _ = 1, drop_rolls do
        local chosen_item = candidate_items[math.random(1, #candidate_items)]
        local multiplier = math.random(1, max_drop_level)
        local count = math.random(1, 3) * multiplier
        drop_entries[#drop_entries + 1] = {
            name = chosen_item,
            min = count,
            max = count,
            chance = 1.0,
        }
    end

    return drop_entries
end

---Spawns modern structured ground dust particles when a tumbleweed hops an obstacle.
---@param pos Vector Origin position
---@param scale number Visual scale multiplier
---@param texture string Base texture applied to dust particles
function XTumbleweed.spawn_hop_particles(pos, scale, texture)
    local hs = 0.3 * scale
    local tex = texture or "x_tumbleweed_tumbleweed_1.png"

    core.add_particlespawner({
        amount = 6,
        time = 0.4,
        pos = {
            min = { x = pos.x - hs, y = pos.y - 0.2 * scale, z = pos.z - hs },
            max = { x = pos.x + hs, y = pos.y + 0.1, z = pos.z + hs },
        },
        vel = {
            min = { x = -0.6, y = 1.2, z = -0.6 },
            max = { x = 0.6, y = 2.4, z = 0.6 },
        },
        acc = {
            min = { x = 0, y = -7.0, z = 0 },
            max = { x = 0, y = -9.81, z = 0 },
        },
        jitter = {
            min = { x = -0.2, y = -0.1, z = -0.2 },
            max = { x = 0.2, y = 0.1, z = 0.2 },
        },
        drag = { x = 0.4, y = 0.2, z = 0.4 },
        bounce = 0.25,
        size = { min = 0.8 * scale, max = 1.5 * scale },
        exptime = { min = 0.3, max = 0.7 },
        collisiondetection = true,
        collision_removal = true,
        texture = tex,

        -- Legacy backwards-compatible fallbacks
        minpos = { x = pos.x - hs, y = pos.y - 0.2 * scale, z = pos.z - hs },
        maxpos = { x = pos.x + hs, y = pos.y + 0.1, z = pos.z + hs },
        minvel = { x = -0.6, y = 1.2, z = -0.6 },
        maxvel = { x = 0.6, y = 2.4, z = 0.6 },
        minacc = { x = 0, y = -7.0, z = 0 },
        maxacc = { x = 0, y = -9.81, z = 0 },
        minexptime = 0.3,
        maxexptime = 0.7,
        minsize = 0.8 * scale,
        maxsize = 1.5 * scale,
    })
end

---Spawns modern animated death particles upon defeat or water dissolution.
---@param pos Vector Origin position
function XTumbleweed.spawn_death_particles(pos)
    core.add_particlespawner({
        amount = 9,
        time = 0.5,
        pos = {
            min = { x = pos.x - 0.2, y = pos.y - 0.1, z = pos.z - 0.2 },
            max = { x = pos.x + 0.2, y = pos.y + 0.3, z = pos.z + 0.2 },
        },
        vel = {
            min = { x = -2.5, y = 1.5, z = -2.5 },
            max = { x = 2.5, y = 3.5, z = 2.5 },
        },
        acc = {
            min = { x = -1.5, y = -6.0, z = -1.5 },
            max = { x = 1.5, y = -9.81, z = 1.5 },
        },
        jitter = {
            min = { x = -0.3, y = -0.2, z = -0.3 },
            max = { x = 0.3, y = 0.2, z = 0.3 },
        },
        drag = { x = 0.6, y = 0.3, z = 0.6 },
        bounce = 0.3,
        size = { min = 16, max = 24 },
        exptime = { min = 0.5, max = 1.0 },
        collisiondetection = true,
        texture = "x_tumbleweed_death_particle_animated.png",
        animation = {
            type = "vertical_frames",
            aspect_w = 16,
            aspect_h = 16,
            length = 1.0,
        },

        -- Legacy backwards-compatible fallbacks
        minpos = { x = pos.x - 0.2, y = pos.y - 0.1, z = pos.z - 0.2 },
        maxpos = { x = pos.x + 0.2, y = pos.y + 0.3, z = pos.z + 0.2 },
        minvel = { x = -2.5, y = 1.5, z = -2.5 },
        maxvel = { x = 2.5, y = 3.5, z = 2.5 },
        minacc = { x = -1.5, y = -6.0, z = -1.5 },
        maxacc = { x = 1.5, y = -9.81, z = 1.5 },
        minexptime = 0.5,
        maxexptime = 1.0,
        minsize = 16,
        maxsize = 24,
    })
end

---Resolves visual scaling and texture (including 25% ground tile camouflage) on activation.
---@param pos Vector World position
---@param is_child boolean Whether entity was spawned as a split fragment
---@param data table Persistent session data table
---@return number scale
---@return string texture
function XTumbleweed.resolve_appearance(pos, is_child, data)
    local scale = data.scale
    if not scale then
        if is_child then
            scale = 0.5
        else
            scale = math.random(50, 150) / 100
        end
    end

    local tex = data.chosen_texture
    if not tex then
        local roll = math.random(1, 100)
        if roll <= 25 then
            -- 25% camouflage chance: blend with surface node below
            local ground_node
            for dy = 1, 3 do
                local check_pos = { x = pos.x, y = math.floor(pos.y + 0.5) - dy, z = pos.z }
                local node = core.get_node(check_pos)
                local gdef = core.registered_nodes[node.name]
                if gdef and gdef.walkable and gdef.tiles then
                    ground_node = node
                    break
                end
            end

            if ground_node then
                local ground_def = core.registered_nodes[ground_node.name]
                local tile = ground_def.tiles[1]
                if type(tile) == "table" then
                    tile = tile.name or (tile[1] and (type(tile[1]) == "table" and tile[1].name or tile[1]))
                end
                if type(tile) == "string" and tile ~= "" then
                    local mask_idx = math.random(1, 3)
                    tex = tile .. "^[mask:x_tumbleweed_tumbleweed_mask_" .. mask_idx .. ".png"
                end
            end
        end

        if not tex then
            tex = XTumbleweed.textures[math.random(1, #XTumbleweed.textures)]
        end
    end

    return scale, tex
end

---Registers a tumbleweed mob entity with standardized x_mob_core lifecycle and physical properties.
---@param name string Technical entity name (e.g. "x_tumbleweed:tumbleweed")
---@param def? table Optional override definition
function XTumbleweed.register_entity(name, def)
    local _def = def or {}

    _def.initial_properties = {
        physical = true,
        collide_with_objects = true,
        collisionbox = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
        selectionbox = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5, rotate = true },
        visual = "mesh",
        mesh = "x_tumbleweed_tumbleweed.b3d",
        textures = { "x_tumbleweed_tumbleweed_1.png" },
        backface_culling = false,
        visual_size = { x = 1, y = 1, z = 1 },
        hp_max = 10,
        infotext = S("Tumbleweed"),
    }

    _def.makes_footstep_sound = true
    _def.armor_groups = { fleshy = 100 }
    _def.knockback_mult = 0
    _def.auto_scan = false
    _def.melee = false
    _def.shooter = false
    _def.can_wander = false
    _def.health_bar = false
    _def.can_flinch = false
    _def.die_in_water = true
    _def.death_duration = 0.5

    _def.sounds = {
        distance = 16.0,
        hurt = { name = XTumbleweed.sounds.neutral, gain = 0.8 },
        random = { name = XTumbleweed.sounds.neutral, gain = 0.6, min_interval = 12.0, max_interval = 28.0 },
    }

    _def.animations = {
        walk  = { range = { x = 1, y = 30 }, speed = 30, loop = true },
        stand = { range = { x = 31, y = 32 }, speed = 0, loop = false },
    }

    _def.on_activate = function(self, data)
        local pos = self.object:get_pos() or { x = 0, y = 0, z = 0 }
        local is_child = self.is_child or (data and data.is_child) or false

        local scale, texture = XTumbleweed.resolve_appearance(pos, is_child, data or {})
        self.scale = scale
        self.is_child = is_child
        self.chosen_texture = texture
        self.base_texture = { texture }
        self._chosen_textures = { texture }

        self.saved_data = self.saved_data or {}
        self.saved_data.scale = scale
        self.saved_data.is_child = is_child
        self.saved_data.chosen_texture = texture

        local half = 0.5 * scale
        local update_props = {
            visual_size = { x = scale, y = scale, z = scale },
            collisionbox = { -half, -half, -half, half, half, half },
            selectionbox = { -half, -half, -half, half, half, half, rotate = true },
            textures = { texture },
        }
        self.object:set_properties(update_props)

        if not data or not data.saved_data then
            self.object:set_yaw(math.random() * math.pi * 2.0)
        end

        self._hop_cooldown = 0
        self._turn_timer = 0
    end

    _def.on_punch = function(self, puncher, _time_from_last_punch, _tool_capabilities, dir, _damage)
        if self.is_dead or self.state == "dying" then return true end

        core.sound_play({
            name = XTumbleweed.sounds.neutral,
        }, {
            object = self.object,
            gain = 0.8,
            max_hear_distance = 16.0,
        })

        if dir then
            local pdir = vector.normalize({ x = dir.x, y = 0, z = dir.z })
            self.object:set_velocity({ x = pdir.x * 4.0, y = 2.0, z = pdir.z * 4.0 })
            self.object:set_yaw(core.dir_to_yaw(dir))
        end

        self._puncher = puncher

        -- Return false so x_mob_core's public combat_handler calculates standard
        -- weapon damage, updates hp, displays damage particles, and executes lethal death.
        return false
    end

    _def.on_death = function(self, killer)
        local pos = self.object:get_pos()
        if not pos then return end

        local scale = self.scale or 1.0
        XTumbleweed.spawn_death_particles(pos)

        -- 33% chance to split into 4 child tumbleweeds (if not dissolved in liquid and not already a child)
        if math.random(1, 3) == 3 and not self.in_water and not self.is_child then
            local base_angle = math.random() * math.pi * 2.0
            local child_texture = self.chosen_texture or "x_tumbleweed_tumbleweed_1.png"
            for i = 1, 4 do
                local angle = base_angle + (i - 1) * (math.pi / 2.0)
                local offset = {
                    x = math.cos(angle) * 0.8,
                    y = 0.2,
                    z = math.sin(angle) * 0.8,
                }
                local child_pos = vector.add(pos, offset)
                local child_staticdata = core.serialize({
                    is_child = true,
                    scale = 0.5,
                    chosen_texture = child_texture,
                })
                local child_obj = core.add_entity(child_pos, self.name, child_staticdata)
                if child_obj then
                    local child_ent = child_obj:get_luaentity()
                    if child_ent then
                        child_ent.is_child = true
                        child_ent.scale = 0.5
                        child_ent.chosen_texture = child_texture
                        child_ent.saved_data = child_ent.saved_data or {}
                        child_ent.saved_data.is_child = true
                        child_ent.saved_data.scale = 0.5
                        child_ent.saved_data.chosen_texture = child_texture
                    end
                    local half = 0.5 * 0.5
                    child_obj:set_properties({
                        visual_size = { x = 0.5, y = 0.5, z = 0.5 },
                        collisionbox = { -half, -half, -half, half, half, half },
                        selectionbox = { -half, -half, -half, half, half, half, rotate = true },
                        textures = { child_texture },
                    })
                    child_obj:set_yaw(angle - math.pi / 2.0)
                end
            end
        end

        -- Drop regional biome vegetation when defeated by player
        local active_killer = killer or self._puncher
        if active_killer and active_killer:is_player() then
            local drops = XTumbleweed.get_biome_drops(pos, active_killer)
            local drop_pos = { x = pos.x, y = pos.y + 0.4 * scale, z = pos.z }
            x_mob_core.drop_items(drop_pos, drops, {
                particles = true,
                trails = true,
                particle_color = "#D2B48C",
            })
        end
    end

    _def.on_step = function(self, dtime, moveresult)
        if self.is_dead or self.state == "dying" then return end

        local pos = self.object:get_pos()
        if not pos then return end

        local scale = self.scale or 1.0
        local yaw = self.object:get_yaw() or 0.0
        local on_ground = (moveresult and moveresult.touching_ground) == true

        self._hop_cooldown = (self._hop_cooldown or 0) - dtime

        -- Horizontal wall collision and glance deflection
        local is_colliding, wall_normal = x_mob_core.has_wall_collision(self, pos, dtime)
        if is_colliding then
            self._turn_timer = (self._turn_timer or 0) + dtime
            if self._turn_timer >= 0.25 then
                self._turn_timer = 0
                if wall_normal and (wall_normal.x ~= 0 or wall_normal.z ~= 0) then
                    yaw = core.dir_to_yaw(wall_normal) + (math.random() - 0.5) * 1.2
                else
                    yaw = math.random() * math.pi * 2.0
                end
                self.object:set_yaw(yaw)
            end
        else
            self._turn_timer = 0
        end

        local dir_x = -math.sin(yaw)
        local dir_z = math.cos(yaw)
        local speed = 2.0

        if on_ground then
            -- 1. Drop-off / cliff detection: line of sight from foot level downward
            local will_fall = false
            if core.line_of_sight then
                local ypos = pos.y - 0.5 * scale
                local check_dist = 0.5 * scale + 0.5
                local not_blocking_sight = core.line_of_sight(
                    { x = pos.x + dir_x * check_dist, y = ypos, z = pos.z + dir_z * check_dist },
                    { x = pos.x + dir_x * check_dist, y = ypos - 1.0, z = pos.z + dir_z * check_dist }
                )
                will_fall = (not_blocking_sight == true)
            end

            -- 2. Obstacle detection: probe forward 1 node along heading at body and low heights
            local probe_dist = 0.5 * scale + 0.3
            local probe_pos = {
                x = pos.x + dir_x * probe_dist,
                y = pos.y,
                z = pos.z + dir_z * probe_dist,
            }
            local probe_node = core.get_node(probe_pos)
            local probe_def = core.registered_nodes[probe_node.name]
            local blocked = probe_def and probe_def.walkable
            if not blocked then
                local low_node = core.get_node({
                    x = probe_pos.x,
                    y = pos.y - 0.25 * scale,
                    z = probe_pos.z,
                })
                local low_def = core.registered_nodes[low_node.name]
                blocked = low_def and low_def.walkable
            end

            if will_fall then
                -- Rolling over a cliff: maintain horizontal push, do not jump upward so it drops naturally
                x_mob_core.set_horizontal_velocity(self, speed, yaw)
                x_mob_core.play_animation(self.object, "walk", { speed = 1.0, loop = true })
            elseif blocked and self._hop_cooldown <= 0 then
                -- Obstacle leap: clear 1-block ledge with dust feedback
                self.object:set_velocity({
                    x = dir_x * speed,
                    y = 5.0,
                    z = dir_z * speed,
                })
                self._hop_cooldown = 0.35
                XTumbleweed.spawn_hop_particles(pos, scale, self.chosen_texture)
                x_mob_core.play_animation(self.object, "walk", { speed = 1.0, loop = true })
            elseif self._hop_cooldown <= 0 then
                -- Continuous natural ground bounce: hop along terrain with dust puffs
                local bounce_vy = (3.8 + (math.random() - 0.5) * 0.6) * math.sqrt(scale)
                self.object:set_velocity({
                    x = dir_x * speed,
                    y = bounce_vy,
                    z = dir_z * speed,
                })
                self._hop_cooldown = 0.18
                XTumbleweed.spawn_hop_particles(pos, scale, self.chosen_texture)
                x_mob_core.play_animation(self.object, "walk", { speed = 1.0, loop = true })
            else
                -- Brief ground contact between bounces
                x_mob_core.set_horizontal_velocity(self, speed, yaw)
                x_mob_core.play_animation(self.object, "walk", { speed = 1.0, loop = true })
            end
        else
            -- In flight (airborne bounce or falling): maintain forward rolling momentum along yaw
            local vel = self.object:get_velocity() or { x = 0, y = 0, z = 0 }
            self.object:set_velocity({
                x = dir_x * speed,
                y = vel.y,
                z = dir_z * speed,
            })
            x_mob_core.play_animation(self.object, "walk", { speed = 1.0, loop = true })
        end
    end

    x_mob_core.register_mob(name, _def)
end



---Backwards-compatible no-op globalstep (spawning handled automatically by x_mob_core).
---@diagnostic disable-next-line: unused-local
function XTumbleweed.globalstep(self, dtime)
    -- Intentionally no-op; x_mob_core hybrid spawner coordinates natural world population.
end

return XTumbleweed
