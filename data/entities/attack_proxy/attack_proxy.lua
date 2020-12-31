local make_drone = require("data/entities/mining_drone/mining_drone_entity")

local empty_rotated_animation = function()
  return
  {
    filename = "__base__/graphics/entity/ship-wreck/small-ship-wreck-a.png",
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
    ammo_category = "bullet",
    cooldown = 1,
    range = 0,
    ammo_type =
    {
      category = util.ammo_category("mining-drone"),
      target_type = "entity",
      --action = {}
    },
    animation = empty_rotated_animation()
  }
end

local proxy_flags = {"placeable-neutral", "placeable-off-grid", "not-on-map", "not-in-kill-statistics", "not-repairable"}
--local proxy_flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"}

local items = data.raw.item
local tools = data.raw.tool
local get_item = function(name)
  if items[name] then return items[name] end
  if tools[name] then return tools[name] end
end

local make_recipes = function(entity)

  if not entity.minable then return end

  local results = entity.minable.results or {{entity.minable.result}}
  if not next(results) then return end
  local fluid = entity.minable.required_fluid

  local recipe_name = "mine-"..entity.name

  local localised_name = {"mine", entity.localised_name or {"entity-name."..entity.name}}

  local recipe_results = {}
  for k, result in pairs (results) do
    local name = result.name or result[1]
    local item_prototype = get_item(name)
    if item_prototype then
      table.insert(recipe_results, {type = "item", name = name, amount = (2 ^ 16) - 1, show_details_in_recipe_tooltip = false})
    end
  end

  --error(serpent.block{results = results, recipe_results = recipe_results})

  if not next(recipe_results) then return end

  local recipe =
  {
    type = "recipe",
    name = recipe_name,
    localised_name = localised_name,
    icon = entity.dark_background_icon or entity.icon,
    icon_size = entity.icon_size,
    icons = entity.icons,
    icon_mipmap = entity.icon_mipmap,
    ingredients =
    {
      {type = "item", name = names.drone_name, amount = 1},
      fluid and {type = "fluid", name = fluid, amount = entity.minable.fluid_amount * 10}
    },
    results = recipe_results,
    category = names.mining_depot,
    subgroup = "extraction-machine",
    overload_multiplier = 100,
    hide_from_player_crafting = true,
    main_product = "",
    allow_decomposition = false,
    allow_as_intermediate = false,
    allow_intermediates = true,
    order = entity.order or entity.name,
    allow_inserter_overload = false
  }
  data:extend{recipe}

  local map_color = entity.map_color or { r = 0.869, g = 0.5, b = 0.130, a = 0.5 }
  for k = 1, shared.variation_count do
    make_drone(entity.name..shared.drone_name..k, map_color, entity.localised_name or {"entity-name."..entity.name})
  end
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
    icon = "__base__/graphics/icons/ship-wreck/small-ship-wreck.png",
    icon_size = 32,
    flags = proxy_flags,
    order = "zzzzzz",
    max_health = shared.mining_damage * 1000000,
    collision_box = {{-0.1, -0.1}, {0.1, 0.1}},
    collision_mask = {"colliding-with-tiles-only"},
    selection_box = nil,
    run_animation = empty_rotated_animation(),
    attack_parameters = empty_attack_parameters(),
    movement_speed = 0,
    distance_per_frame = 0,
    pollution_to_join_attack = 0,
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
      entity_name = particle,
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
      entity_name = particle,
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

for k, resource in pairs (data.raw.resource) do
  if resource.minable and (resource.minable.result or resource.minable.results) then
    make_recipes(resource)
    make_resource_attack_proxy(resource)
  end
end
