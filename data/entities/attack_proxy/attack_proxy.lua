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

--local proxy_flags = {"placeable-neutral", "placeable-off-grid", "not-on-map", "not-in-kill-statistics"}
local proxy_flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"}

local recipes = data.raw.recipe
local make_depot_recipe = function(entity, item_prototype, fluid_ingredient)
  if not item_prototype then return end
  local recipe_name = "mine-"..item_prototype.name
  if recipes[recipe_name] then return end
  local results = {}
  for k = 1, 60 do
    results[k] = {type = "item", name = item_prototype.name, amount = item_prototype.stack_size, show_details_in_recipe_tooltip = false}
  end
  local recipe =
  {
    type = "recipe",
    name = recipe_name,
    localised_name = {"", "Mine ", item_prototype.localised_name or {"item-name."..item_prototype.name}},
    icon = item_prototype.icon,
    icon_size = item_prototype.icon_size,
    icons = item_prototype.icons,
    ingredients =
    {
      {type = "item", name = names.drone_name, amount = 1},
      fluid_ingredient
    },
    results = results,
    category = names.mining_depot,
    subgroup = "extraction-machine",
    overload_multiplier = 100,
    hide_from_player_crafting = true,
    allow_decomposition = false,
    allow_as_intermediate = false,
    allow_intermediates = true
  }
  data:extend{recipe}
  local map_color = (entity.type == "tree" and {r = 0.19, g = 0.39, b = 0.19, a = 0.40}) or entity.map_color or { r = 0.869, g = 0.5, b = 0.130, a = 0.5 }
  for k = 1, shared.variation_count do
    --log("Making drone "..r..g..b)
    make_drone(recipe_name..shared.drone_name..k, map_color)
  end
end

local is_stupid = function(entity)
  --Thanks NPE
  return entity.name:find("wreckage")
end

local items = data.raw.item
local make_recipes = function(entity)
  if is_stupid(entity) then return end
  if not entity.minable then return end
  log(entity.name)

  if entity.minable.result then
    local name = entity.minable.result or entity.minable.result[1]
    make_depot_recipe(entity, items[name], entity.minable.required_fluid and {type = "fluid", name = entity.minable.required_fluid, amount = entity.minable.fluid_amount * 10})
  end

  if entity.minable.results then
    for k, result in pairs (entity.minable.results) do
      local name = result.name or result[1]
      make_depot_recipe(entity, items[name], entity.minable.required_fluid and {type = "fluid", name = entity.minable.required_fluid, amount = entity.minable.fluid_amount * 10})
    end
  end
end

local count = 0


local axe_mining_ore_trigger =
{
  type = "play-sound",
  sound =
  {
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
    collision_box = resource.collision_box,
    collision_mask = {"colliding-with-tiles-only"},
    selection_box = nil,
    run_animation =empty_rotated_animation(),
    attack_parameters = empty_attack_parameters(),
    movement_speed = 0,
    distance_per_frame = 0,
    pollution_to_join_attack = 0,
    distraction_cooldown = 0,
    vision_distance = 0
  }

  local damaged_trigger =
  {
    axe_mining_ore_trigger
  }
  attack_proxy.damaged_trigger_effect = damaged_trigger

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

  data:extend{attack_proxy}
  count = count + 1

end

for k, resource in pairs (data.raw.resource) do
  if resource.minable and (resource.minable.result or resource.minable.results) then
    make_recipes(resource)
    make_resource_attack_proxy(resource)
  end
end

for k, rock in pairs (data.raw["simple-entity"]) do
  if rock.minable then
    make_recipes(rock)
    make_resource_attack_proxy(rock)
  end
end


local make_tree_proxy = function(tree)

  local attack_proxy =
  {
    type = "unit",
    name = shared.attack_proxy_name..tree.name,
    icon = "__base__/graphics/icons/ship-wreck/small-ship-wreck.png",
    icon_size = 32,
    flags = proxy_flags,
    order = "zzzzzz",
    max_health = shared.mining_damage * 1000000,
    collision_box = tree.collision_box,
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
    mining_wood_trigger
  }
  attack_proxy.damaged_trigger_effect = damaged_trigger

  local particle = tree.minable and tree.minable.mining_particle
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
      offset_deviation = tree.selection_box
    })
  end


  local dying_trigger = {}

  if tree.corpse then
    table.insert(dying_trigger,
    {
      type = "create-entity",
      entity_name = tree.corpse
    })
  end

  if tree.variations and tree.variations[1].leaf_generation then
    table.insert(damaged_trigger, tree.variations[1].leaf_generation)
  end

  if tree.variations and tree.variations[1].branch_generation then
    table.insert(damaged_trigger, tree.variations[1].branch_generation)
  end

  if dying_trigger[1] then
    attack_proxy.dying_trigger_effect = dying_trigger
  end

  data:extend{attack_proxy}
  count = count + 1
end

for k, tree in pairs (data.raw.tree) do
  if tree.minable then
    make_recipes(tree)
    make_tree_proxy(tree)
  end
end

local make_size_proxy = function(size)

  local attack_proxy =
  {
    type = "unit",
    name = shared.attack_proxy_name..size,
    icon = "__base__/graphics/icons/ship-wreck/small-ship-wreck.png",
    icon_size = 32,
    flags = proxy_flags,
    order = "zzzzzz",
    max_health = shared.mining_damage * 1000000,
    collision_box = tree.collision_box,
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

  data:extend{attack_proxy}
end

for k = 1, 10 do
  make_proxy(k)
end
