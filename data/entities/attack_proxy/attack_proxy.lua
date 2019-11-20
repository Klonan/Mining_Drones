local make_proxy = function(size)

  local attack_proxy =
  {
    type = "simple-entity",
    name = shared.attack_proxy_name..size,
    icon = "__base__/graphics/icons/ship-wreck/small-ship-wreck.png",
    icon_size = 32,
    flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
    order = "d[remnants]-d[ship-wreck]-c[small]-a",
    max_health = shared.mining_damage * 1000000,
    collision_box = {{-size/2, -size/2}, {size/2, size/2}},
    collision_mask = {},
    selection_box = nil,
    pictures =
    {
      {
        filename = "__base__/graphics/entity/ship-wreck/small-ship-wreck-a.png",
        width = 1,
        height= 1
      },
    }
  }

  data:extend{attack_proxy}
end

for k = 1, 10 do
  make_proxy(k)
end



local recipes = data.raw.recipe
local make_depot_recipe = function(item_prototype)
  local recipe_name = "mine-"..item_prototype.name
  if recipes[recipe_name] then return end
  local results = {}
  for k = 1, 24 do
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
    ingredients = {{names.drone_name, 1}},
    results = results,
    category = names.mining_depot,
    subgroup = "extraction-machine",
    overload_multiplier = 200,
    hide_from_player_crafting = true,
    allow_decomposition = false,
    allow_as_intermediate = false,
    allow_intermediates = true
  }
  data:extend{recipe}
end

local is_stupid = function(entity)
  --Thanks NPE
  return entity.name:find("wreckage")
end

local items = data.raw.item
local make_recipes = function(entity)
  if is_stupid(entity) then return end
  if not entity.minable then return end
  if entity.minable.result then
    make_depot_recipe(items[entity.minable.result])
  end

  if entity.minable.results then
    for k, result in pairs (entity.minable.results) do
      make_depot_recipe(items[result.name])
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
        volume = 0.75
      },
      {
        filename = "__core__/sound/axe-mining-ore-2.ogg",
        volume = 0.75
      },
      {
        filename = "__core__/sound/axe-mining-ore-3.ogg",
        volume = 0.75
      },
      {
        filename = "__core__/sound/axe-mining-ore-4.ogg",
        volume = 0.75
      },
      {
        filename = "__core__/sound/axe-mining-ore-5.ogg",
        volume = 0.75
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
        volume = 0.75
      },
      {
        filename = "__core__/sound/mining-wood-2.ogg",
        volume = 0.75
      }
    }
  }
}

local make_resource_attack_proxy = function(resource)

  local attack_proxy =
  {
    type = "simple-entity",
    name = shared.attack_proxy_name..resource.name,
    icon = "__base__/graphics/icons/ship-wreck/small-ship-wreck.png",
    icon_size = 32,
    flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
    order = "d[remnants]-d[ship-wreck]-c[small]-a",
    max_health = shared.mining_damage * 1000000,
    collision_box = resource.collision_box,
    collision_mask = {},
    selection_box = nil,
    pictures =
    {
      {
        filename = "__base__/graphics/entity/ship-wreck/small-ship-wreck-a.png",
        width = 1,
        height= 1
      },
    }
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

  data:extend{attack_proxy}
  count = count + 1

end

for k, resource in pairs (data.raw.resource) do
  if resource.minable and resource.minable.result and not resource.minable.required_fluid then
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
    type = "simple-entity",
    name = shared.attack_proxy_name..tree.name,
    icon = "__base__/graphics/icons/ship-wreck/small-ship-wreck.png",
    icon_size = 32,
    flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
    order = "d[remnants]-d[ship-wreck]-c[small]-a",
    max_health = shared.mining_damage * 1000000,
    collision_box = tree.collision_box,
    collision_mask = {},
    selection_box = nil,
    pictures =
    {
      {
        filename = "__base__/graphics/entity/ship-wreck/small-ship-wreck-a.png",
        width = 1,
        height= 1
      },
    }
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
  --error(serpent.block(tree))

  if tree.variations and tree.variations[1].leaf_generation then
    --table.insert(dying_trigger, tree.variations[1].leaf_generation)
    table.insert(damaged_trigger, tree.variations[1].leaf_generation)
  end

  if tree.variations and tree.variations[1].branch_generation then
    --table.insert(dying_trigger, tree.variations[1].branch_generation)
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
