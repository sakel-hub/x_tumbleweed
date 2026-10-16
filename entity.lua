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

XTumbleweed.register_entity("x_tumbleweed:tumbleweed")

-- Natural environmental spawning via x_mob_core hybrid spawner
local spawn_def = {
    biomes = XTumbleweed.allowed_biomes,
    nodes = {
        "group:sand",
        "group:stone",
        "group:soil",
        "default:desert_sand",
        "default:desert_sandstone",
        "default:sand",
        "default:sandstone",
    },
    chance = 1200,
    active_object_count = 1,
    group_min = 1,
    group_max = 1,
    min_light = 4,
    max_light = 15,
}

XTumbleweed._spawn_def = spawn_def
x_mob_core.register_spawn("x_tumbleweed:tumbleweed", spawn_def)
