local math_random = math.random
local math_floor = math.floor
local table_insert = table.insert
local table_remove = table.remove
local math_sqrt = math.sqrt
local math_round = math.round
local math_abs = math.abs

local drop_values = {
	["small-spitter"] = 8,
	["small-biter"] = 8,
	["medium-spitter"] = 16,
	["medium-biter"] = 16,
	["big-spitter"] = 32,
	["big-biter"] = 32,
	["behemoth-spitter"] = 96,
	["behemoth-biter"] = 96,
	["small-worm-turret"] = 128,
	["medium-worm-turret"] = 160,
	["big-worm-turret"] = 196,
	["behemoth-worm-turret"] = 256,
	["biter-spawner"] = 640,
	["spitter-spawner"] = 640
}

local drop_raffle = {}
for _ = 1, 64, 1 do table_insert(drop_raffle, "iron-ore") end
for _ = 1, 40, 1 do table_insert(drop_raffle, "copper-ore") end
for _ = 1, 32, 1 do table_insert(drop_raffle, "stone") end
for _ = 1, 32, 1 do table_insert(drop_raffle, "coal") end
for _ = 1, 6, 1 do table_insert(drop_raffle, "wood") end
for _ = 1, 4, 1 do table_insert(drop_raffle, "landfill") end
for _ = 1, 3, 1 do table_insert(drop_raffle, "uranium-ore") end
local size_of_drop_raffle = #drop_raffle

local drop_vectors = {}
for x = -2, 2, 0.1 do
	for y = -2, 2, 0.1 do
		table_insert(drop_vectors, {x, y})
	end
end
local size_of_drop_vectors = #drop_vectors

local function on_player_joined_game(event)
	local surface = game.surfaces["railway_troopers"]
	local player = game.players[event.player_index]
	if player.online_time == 0 then
		player.teleport(surface.find_non_colliding_position("character", game.forces.player.get_spawn_position(surface), 32, 0.5), surface)
	end
end

local function set_commands(unit_group)
	local surface = unit_group.surface
	local position = unit_group.position
	local commands = {}
	for x = position.x, -8196, -32 do
		if surface.is_chunk_generated({math_floor(x / 32), math_floor(position.y / 32)}) then
			commands[#commands + 1] = {
				type = defines.command.attack_area,
				destination = {x = x, y = position.y},
				radius = 16,
				distraction = defines.distraction.by_anything
			}
		else
			break
		end
	end
	
	unit_group.set_command({
		type = defines.command.compound,
		structure_type = defines.compound_command.return_last,
		commands = commands
	})
end

local function send_wave(spawner, search_radius)
	local biters = spawner.surface.find_enemy_units(spawner.position, search_radius, "player")	
	if biters[1] then
		local unit_group = spawner.surface.create_unit_group({position = spawner.position, force = "enemy"})
		for _, unit in pairs(biters) do unit_group.add_member(unit) end
		set_commands(unit_group)
	end
end

local function on_entity_spawned(event)
	global.on_entity_spawned_counter = global.on_entity_spawned_counter + 1
	
	if global.on_entity_spawned_counter % 16384 == 8192 then
		send_wave(event.spawner, 512)
		return
	end
	
	if global.on_entity_spawned_counter % 2048 == 1024 then
		send_wave(event.spawner, 256)
		return
	end
	
	if global.on_entity_spawned_counter % 512 == 256 then
		send_wave(event.spawner, 128)
		return
	end
	
	if global.on_entity_spawned_counter % 128 == 64 then
		send_wave(event.spawner, 16)
		return
	end
end

local function on_entity_died(event)
	local entity = event.entity
	if not entity.valid then return end
	
	if entity.type == "unit" and entity.spawner then
		entity.spawner.damage(20, game.forces[1])
	end	
	
	if not drop_values[entity.name] then return end	
	table_insert(global.drop_schedule, {{entity.position.x, entity.position.y}, drop_values[entity.name]})
end

local refined_concretes = {"black", "blue", "cyan", "green", "purple"}

local function draw_west_side(surface, left_top)	
	for x = 0, 31, 1 do
		for y = 0, 31, 1 do
			local position = {left_top.x + x, left_top.y + y}
			surface.set_tiles({{name = "deepwater-green", position = position}}, true)
			if math_random(1, 64) == 1 then surface.create_entity({name = "fish", position = position}) end
		end
	end
	
	if math_random(1, 8) == 1 then
		surface.create_entity({name = "crude-oil", position = {left_top.x + math_random(0, 31), left_top.y + math_random(0, 31)}, amount = 200000 + math_abs(left_top.x * 500)})
	end
	
	if math_random(1, 16) == 1 and left_top.x < -96 then
		local p = {left_top.x + math_random(0, 31), left_top.y + math_random(0, 31)}
		local tile_name = refined_concretes[math_random(1, #refined_concretes)] .. "-refined-concrete"
		local y_count = math_random(8, 24)
		for x = 0, math_random(8, 24), 1 do
			for y = 0, y_count, 1 do
				local position = {p[1] + x, p[2] + y}
				if position[2] < surface.map_gen_settings.height * 0.5 then
					surface.set_tiles({{name = tile_name, position = position}}, true)
				end
			end
		end
	end
end

local infini_ores = {"iron-ore", "iron-ore", "copper-ore", "coal", "stone"}

local function on_chunk_generated(event)
	local surface = event.surface
	local left_top = event.area.left_top
	
	if left_top.y >= surface.map_gen_settings.height * 0.5 then return end
	if left_top.y < surface.map_gen_settings.height * -0.5 then return end
	
	if left_top.x < -32 then
		draw_west_side(surface, left_top)
		return
	end
	
	if left_top.y == 0 and left_top.x < 64 then
		for x = 0, 30, 2 do
			surface.create_entity({name = "straight-rail", position = {left_top.x + x, 0}, direction = 2, force = "player"})
		end
		if left_top.x == -32 then
			local entity = surface.create_entity({name = "cargo-wagon", position = {-24, 0}, force = "player", direction = 2})
			entity.get_inventory(defines.inventory.cargo_wagon).insert({name = "firearm-magazine", count = 128})
			entity.get_inventory(defines.inventory.cargo_wagon).insert({name = "shotgun", count = 1})
			entity.get_inventory(defines.inventory.cargo_wagon).insert({name = "shotgun-shell", count = 16})
			entity.get_inventory(defines.inventory.cargo_wagon).insert({name = "light-armor", count = 2})
			entity.get_inventory(defines.inventory.cargo_wagon).insert({name = "grenade", count = 3})
			entity.get_inventory(defines.inventory.cargo_wagon).insert({name = "pistol", count = 5})
		end
	end
	
	if math_random(1, 10) == 1 and left_top.x > 0 then
		local position = {left_top.x + math_random(0, 31), left_top.y + math_random(0, 31)}
		surface.create_entity({name = infini_ores[math_random(1, #infini_ores)], position = position, amount = 9999999})
		local direction = 0
		if left_top.y < 0 then direction = 4 end
		local e = surface.create_entity({name = "burner-mining-drill", position = position, force = "neutral", direction = direction})
		e.minable = false
		e.destructible = false
		e.insert({name = "coal", count = math_random(8, 36)})
	end
end

local type_whitelist = {
	["artillery-wagon"] = true,
	["car"] = true,
	["cargo-wagon"] = true,
	["construction-robot"] = true,
	["container"] = true,
	["curved-rail"] = true,
	["electric-pole"] = true,
	["entity-ghost"] = true,
	["fluid-wagon"] = true,
	["heat-pipe"] = true,
	["inserter"] = true,
	["lamp"] = true,
	["locomotive"] = true,
	["logistic-robot"] = true,
	["rail-chain-signal"] = true,
	["rail-signal"] = true,
	["splitter"] = true,
	["straight-rail"] = true,
	["tile-ghost"] = true,
	["train-stop"] = true,	
	["transport-belt"] = true,
	["underground-belt"] = true,
}

local function deny_building(event)
	local entity = event.created_entity
	if not entity.valid then return end
	
	if type_whitelist[event.created_entity.type] then return end

	if entity.position.x < -32 then return end

	if event.player_index then
		game.players[event.player_index].insert({name = entity.name, count = 1})		
	else	
		local inventory = event.robot.get_inventory(defines.inventory.robot_cargo)
		inventory.insert({name = entity.name, count = 1})													
	end
	
	event.created_entity.surface.create_entity({
		name = "flying-text",
		position = entity.position,
		text = "Can only be built west!",
		color = {r=0.98, g=0.66, b=0.22}
	})
	
	entity.destroy()
end

local function on_built_entity(event)
	deny_building(event)
end

local function on_robot_built_entity(event)
	deny_building(event)
end

local function send_tick_wave()
	if game.tick % 54000 ~= 3600 then return end
	local surface = game.surfaces["railway_troopers"]
	local spawners = surface.find_entities_filtered({type = "unit-spawner"})
	if not spawners[1] then return end
	
	local search_radius = 4
	for _, player in pairs(game.connected_players) do
		if player.position.x > search_radius then search_radius = math_floor(player.position.x) end
	end
	if search_radius > 512 then search_radius = 512 end
	
	send_wave(spawners[math_random(1, #spawners)], search_radius)
end

local function drop_schedule()
	local surface = game.surfaces["railway_troopers"]
	for key, entry in pairs(global.drop_schedule) do
		for _ = 1, 3, 1 do
			local vector = drop_vectors[math_random(1, size_of_drop_vectors)]
			surface.spill_item_stack({entry[1][1] + vector[1], entry[1][2] + vector[2]}, {name = drop_raffle[math_random(1, size_of_drop_raffle)], count = 1}, true)		
			global.drop_schedule[key][2] = global.drop_schedule[key][2] - 1
			if global.drop_schedule[key][2] <= 0 then
				table_remove(global.drop_schedule, key)
				break
			end
		end
	end
end

local function on_tick()
	drop_schedule()
	send_tick_wave()
end

local function on_init()
	global.drop_schedule = {}
	global.on_entity_spawned_counter = 0

	game.map_settings.enemy_evolution.destroy_factor = 0.001
	game.map_settings.enemy_evolution.pollution_factor = 0	
	game.map_settings.enemy_evolution.time_factor = 0
	game.map_settings.enemy_expansion.enabled = true
	game.map_settings.enemy_expansion.max_expansion_cooldown = 900
	game.map_settings.enemy_expansion.min_expansion_cooldown = 900
	game.map_settings.enemy_expansion.settler_group_max_size = 128
	game.map_settings.enemy_expansion.settler_group_min_size = 32
	game.map_settings.enemy_expansion.max_expansion_distance = 16
	game.map_settings.pollution.enemy_attack_pollution_consumption_modifier = 0.25
	
	local map_gen_settings = {
		["height"] = 128,
		["water"] = 0.1,
		["starting_area"] = 0.60,
		["cliff_settings"] = {cliff_elevation_interval = 0, cliff_elevation_0 = 0},
		["autoplace_controls"] = {
			["coal"] = {frequency = 0, size = 0.65, richness = 0.5},
			["stone"] = {frequency = 0, size = 0.65, richness = 0.5},
			["copper-ore"] = {frequency = 0, size = 0.65, richness = 0.5},
			["iron-ore"] = {frequency = 0, size = 0.65, richness = 0.5},
			["uranium-ore"] = {frequency = 0, size = 1, richness = 1},
			["crude-oil"] = {frequency = 0, size = 1, richness = 0.75},
			["trees"] = {frequency = 2, size = 0.15, richness = 1},
			["enemy-base"] = {frequency = 256, size = 2, richness = 1},
		},
	}
	
	local surface = game.create_surface("railway_troopers", map_gen_settings)
	surface.request_to_generate_chunks({0,0}, 4)
	surface.force_generate_chunk_requests()
	
	local force = game.forces.player
	
	force.set_spawn_position({0, 0}, surface)	
	
	force.technologies["landfill"].researched = true
	force.technologies["railway"].researched = true
	force.technologies["engine"].researched = true
	
	local types_to_disable = {
		["ammo"] = true,
		["armor"] = true,
		["car"] = true,
		["gun"] = true,
		["capsule"] = true,
	}
	
	for _, recipe in pairs(game.recipe_prototypes) do
		if types_to_disable[recipe.subgroup.name] then
			force.set_hand_crafting_disabled_for_recipe(recipe.name, true)
		end
	end
end

local Event = require 'utils.event'
Event.on_init(on_init)
Event.add(defines.events.on_tick, on_tick)
Event.add(defines.events.on_built_entity, on_built_entity)
Event.add(defines.events.on_robot_built_entity, on_robot_built_entity)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_entity_spawned, on_entity_spawned)
Event.add(defines.events.on_player_joined_game, on_player_joined_game)
Event.add(defines.events.on_chunk_generated, on_chunk_generated)