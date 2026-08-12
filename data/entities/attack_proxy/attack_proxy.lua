local make_drone = require("data/entities/mining_drone/mining_drone_entity")

local name = names.drone_name
make_drone(name, {r = 1, g = 1, b = 1, a = 0.5}, "base")

local empty_rotated_animation = function()
  return
  {
    filename = "__core__/graphics/empty.png",
    width = 1,
    height= 1,
    direction_count = 1,
    animation_speed = 1
  }
end

local empty_attack_parameters = function()
  return
  {
    type = "projectile",
    ammo_category = util.ammo_category(shared.ammo_category),
    cooldown = 1,
    range = 0,
    ammo_type =
    {
      target_type = "entity"
    },
    animation = empty_rotated_animation()
  }
end

local sprite_width = 768
local sprite_height = 768
local sprite_scale = 0.5
local shifts = shared.depots["mining-depot"].shifts

local duration = 70
local size = 768
local particle_path = "__Mining_Drones__/data/entities/mining_depot/Scene_layer-particle"

local particle_stripes = function(direction)
  local stripes = {}
  for k = 10, 80 do
    table.insert(stripes,
    {
      filename = particle_path..string.format("/%s/Scene_layer-main_%04g.png", direction, k),
      width_in_frames = 1,
      height_in_frames = 1
    })
  end
  return stripes
end

local make_smoke = function(name, tint, direction, custom)
  local r, g, b = tint[1] or tint.r, tint[2] or tint.g, tint[3] or tint.b
  --r = (r + 0.2) / 1.2
  --g = (g + 0.2) / 1.2
  --b = (b + 0.2) / 1.2
  if not custom then
    r = (r + 0.5) / 1.5
    g = (g + 0.5) / 1.5
    b = (b + 0.5) / 1.5
  end
  local smoke =
  {
    type = "explosion",
    name = "depot-smoke-"..name.."-"..direction,
    fade_in_duration = 0,
    fade_out_duration = 10,
    render_layer = "higher-object-above",
    height = 0,
    flags = {"placeable-off-grid"},
    animations =
    {
      tint = {r, g, b},
      stripes = particle_stripes(direction),
      width = size,
      height = size,
      frame_count = duration,
      priority = "high",
      animation_speed = 1,
      scale = sprite_scale,
      shift = shifts[direction]
    }
  }
  data:extend{smoke}

end


local size = 768
local particle_path = "__Mining_Drones__/data/entities/mining_depot/Scene_layer-particle"

local custom_resources =
{
  ["iron-ore"] = true,
  ["copper-ore"] = true,
  ["stone"] = true,
  ["uranium-ore"] = true,
  ["coal"] = true
}

local pot_stripes = function(direction, resource)
  local stripes = {}
  if custom_resources[resource] then
    for k = 0, 16 do
      table.insert(stripes,
      {
        filename = particle_path..string.format("/pot_%s/%s/Scene_layer-main_%04g.png", direction, resource, k),
        width_in_frames = 1,
        height_in_frames = 1
      })
    end
  else
    for k = 0, 16 do
      table.insert(stripes,
      {
        filename = particle_path..string.format("/pot_%s/Scene_layer-main_%04g.png", direction, k),
        width_in_frames = 1,
        height_in_frames = 1
      })
    end
  end
  return stripes
end

local should_glow =
{
  ["uranium-ore"] = true
}

local make_pot = function(name, tint, direction, custom)

  local r, g, b = tint[1] or tint.r, tint[2] or tint.g, tint[3] or tint.b

  if not custom then
    r = (r + 0.5) / 1.5
    g = (g + 0.5) / 1.5
    b = (b + 0.5) / 1.5
  end

  local pot =
  {
    type = "animation",
    name = "depot-pot-"..name.."-"..direction,
    tint = (custom and {1, 1, 1}) or {r, g, b},
    stripes = pot_stripes(direction, name),
    width = size,
    height = size,
    frame_count = 17,
    priority = "high",
    animation_speed = 0.000000000001,
    scale = sprite_scale,
    shift = shifts[direction],
    draw_as_glow = should_glow[name],
  }
  data:extend{pot}

end


local proxy_flags = {"placeable-neutral", "placeable-off-grid", "not-on-map", "not-in-kill-statistics", "not-repairable"}
--local proxy_flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"}

--Resources can be mined into any kind of item, not just plain items - modded ores yielding
--tools, ammo, item-with-entity-data and so on all have to be recognised as well.
local item_types = {}
for item_type in pairs (defines.prototypes.item) do
  table.insert(item_types, item_type)
end

local get_item = function(name)
  for k, item_type in pairs (item_types) do
    local prototypes = data.raw[item_type]
    local prototype = prototypes and prototypes[name]
    if prototype then return prototype end
  end
end

local make_recipes = function(entity)

  if not entity.minable then return end

  local results = entity.minable.results or {{entity.minable.result}}
  if not next(results) then return end

  --A resource that asks for a fluid without saying how much of it can't be mined by a depot,
  --and would otherwise generate a recipe with a nil ingredient amount.
  local fluid = entity.minable.required_fluid
  local fluid_amount = entity.minable.fluid_amount
  if fluid and not fluid_amount then return end

  local recipe_name = "mine-"..entity.name

  local resource_localised_name = entity.localised_name or {"entity-name."..entity.name}
  local localised_name
  if fluid then
    local fluid_prototype = data.raw.fluid[fluid]
    local fluid_localised_name = (fluid_prototype and fluid_prototype.localised_name) or {"fluid-name."..fluid}
    localised_name = {"mine-with-fluid", resource_localised_name, fluid_localised_name}
  else
    localised_name = {"mine", resource_localised_name}
  end

  local recipe_results = {}
  local seen = {}
  for k, result in pairs (results) do
    local name = result.name or result[1]
    --Fluid results can't go in the depot's output inventory, and a recipe can only list
    --each product once.
    if name and not seen[name] and get_item(name) then
      seen[name] = true
      table.insert(recipe_results, {type = "item", name = name, amount = (2 ^ 16) - 1, show_details_in_recipe_tooltip = false})
    end
  end

  if not next(recipe_results) then return end

  local recipe =
  {
    type = "recipe",
    name = recipe_name,
    localised_name = localised_name,
    icon = entity.dark_background_icon or entity.icon,
    icon_size = entity.icon_size,
    icons = entity.icons,
    ingredients =
    {
      {type = "item", name = names.drone_name, amount = 1},
      fluid and {type = "fluid", name = fluid, amount = fluid_amount * 10}
    },
    results = recipe_results,
    categories = {names.mining_depot},
    subgroup = "extraction-machine",
    --overload_multiplier = 100,
    hide_from_player_crafting = true,
    main_product = "",
    allow_decomposition = false,
    allow_as_intermediate = false,
    allow_intermediates = true,
    order = entity.order or entity.name,
    allow_inserter_overload = false,
    energy_required = 1.166
  }
  data:extend{recipe}

  local map_color = entity.map_color or { r = 0.869, g = 0.5, b = 0.130, a = 0.5 }
  for k = 1, shared.variation_count do
    make_drone(entity.name..shared.drone_name..k, map_color, entity.localised_name or {"entity-name."..entity.name})
  end

  return true
end

local count = 0

local axe_mining_ore_trigger =
{
  type = "play-sound",
  sound =
  {
    aggregation =
    {
      max_count = 3,
      remove = true
    },
    variations =
    {
      {
        filename = "__core__/sound/axe-mining-ore-1.ogg",
        volume = 0.4
      },
      {
        filename = "__core__/sound/axe-mining-ore-2.ogg",
        volume = 0.4
      },
      {
        filename = "__core__/sound/axe-mining-ore-3.ogg",
        volume = 0.4
      },
      {
        filename = "__core__/sound/axe-mining-ore-4.ogg",
        volume = 0.4
      },
      {
        filename = "__core__/sound/axe-mining-ore-5.ogg",
        volume = 0.4
      }
    }
  }
}
local mining_wood_trigger =
{
  type = "play-sound",
  sound =
  {
    variations =
    {
      {
        filename = "__core__/sound/mining-wood-1.ogg",
        volume = 0.4
      },
      {
        filename = "__core__/sound/mining-wood-2.ogg",
        volume = 0.4
      }
    }
  }
}


local sound_enabled = not settings.startup.mute_drones.value

local make_resource_attack_proxy = function(resource)
  local attack_proxy =
  {
    type = "unit",
    name = shared.attack_proxy_name..resource.name,
    icon = "__core__/graphics/empty.png",
    icon_size = 1,
    flags = proxy_flags,
    order = "zzzzzz",
    max_health = shared.mining_damage * 1000000,
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    collision_mask = {colliding_with_tiles_only = true, layers = {}},
    selection_box = nil,
    run_animation = empty_rotated_animation(),
    attack_parameters = empty_attack_parameters(),
    movement_speed = 0,
    distance_per_frame = 0,
    --pollution_to_join_attack = 0,
    distraction_cooldown = 0,
    vision_distance = 0
  }

  local damaged_trigger =
  {
    sound_enabled and axe_mining_ore_trigger or nil
  }

  local particle = resource.minable.mining_particle
  if particle then
    table.insert(damaged_trigger,
    {
      type = "create-particle",
      repeat_count = 3,
      particle_name = particle,
      initial_height = 0,
      speed_from_center = 0.025,
      speed_from_center_deviation = 0.025,
      initial_vertical_speed = 0.025,
      initial_vertical_speed_deviation = 0.025,
      offset_deviation = resource.selection_box
    })
    attack_proxy.dying_trigger_effect =
    {
      type = "create-particle",
      repeat_count = 5,
      particle_name = particle,
      initial_height = 0,
      speed_from_center = 0.045,
      speed_from_center_deviation = 0.035,
      initial_vertical_speed = 0.045,
      initial_vertical_speed_deviation = 0.035,
      offset_deviation = resource.selection_box
    }
  end

  if next(damaged_trigger) then
    attack_proxy.damaged_trigger_effect = damaged_trigger
  end

  data:extend{attack_proxy}
  count = count + 1

end

local custom_tints =
{
  ["iron-ore"] = {0.54, 0.8, 0.9},
  ["copper-ore"] = {0.85, 0.5, 0.30},
  ["stone"] = {0.75, 0.65, 0.4},
  ["uranium-ore"] = {0.6, 0.9, 0.15},
  ["coal"] = {0.25, 0.25, 0.25}
}

for k, resource in pairs (data.raw.resource) do
  --Only resources a depot can actually mine get the rest of the prototypes. Resources that
  --yield nothing but fluid, like crude oil, would otherwise generate a proxy, four smokes
  --and four pot animations that can never be reached.
  if resource.minable and (resource.minable.result or resource.minable.results) and make_recipes(resource) then
    make_resource_attack_proxy(resource)
    local custom = false
    local map_color = resource.map_color or { r = 0.869, g = 0.5, b = 0.130, a = 1 }
    if custom_tints[resource.name] then
      map_color = custom_tints[resource.name]
      custom = true
    end
    make_smoke(resource.name, map_color, "north", custom)
    make_smoke(resource.name, map_color, "east", custom)
    make_smoke(resource.name, map_color, "south", custom)
    make_smoke(resource.name, map_color, "west", custom)
    make_pot(resource.name, map_color, "north", custom)
    make_pot(resource.name, map_color, "east", custom)
    make_pot(resource.name, map_color, "south", custom)
    make_pot(resource.name, map_color, "west", custom)
  end
end
