local machine = util.copy(data.raw["assembling-machine"]["assembling-machine-3"])
local name = names.mining_depot
machine.name = name
machine.localised_name = {name}
local scale = 2
util.recursive_hack_make_hr(machine)
util.recursive_hack_scale(machine, scale)
machine.collision_box = {{-1.25, -2.25},{1.25, 2.25}}
machine.selection_box = {{-1.5, -2.5},{1.5, 2.5}}
machine.crafting_categories = {name}
machine.crafting_speed = (1)
machine.ingredient_count = nil
--machine.collision_mask = {"item-layer", "object-layer", "water-tile"}
machine.allowed_effects = {"consumption", "speed", "pollution"}
machine.module_specification =nil
machine.minable = {result = name, mining_time = 1}
machine.flags = {"placeable-neutral", "player-creation"}
machine.fluid_boxes =
{
  {
    production_type = "output",
    pipe_picture = nil,
    pipe_covers = nil,
    base_area = 1,
    base_level = 1,
    pipe_connections = {{ type="output", position = {0, -2.6} }},
  },
  off_when_no_fluid_recipe = false
}
machine.scale_entity_info_icon = true
machine.energy_usage = "1W"
machine.gui_title_key = "mining-depot-choose-resource"
machine.energy_source =
{
  type = "void",
  usage_priority = "secondary-input",
  emissions_per_second_per_watt = 0
}
machine.icon = util.path("data/entities/mining_depot/depot-icon.png")
machine.icon_size = 216

local base = function(shift)
  return
  {
    filename = util.path("data/entities/mining_depot/depot-base.png"),
    width = 474,
    height = 335,
    frame_count = 1,
    scale = 0.45,
    shift = shift
  }
end

local h_chest = function(shift)
  return
  {
    filename = util.path("data/entities/mining_depot/depot-chest-h.png"),
    width = 190,
    height = 126,
    frame_count = 1,
    scale = 0.5,
    shift = shift
  }
end
local h_shadow = function(shift)
  return
  {
    filename = util.path("data/entities/mining_depot/depot-chest-h-shadow.png"),
    width = 192,
    height = 99,
    frame_count = 1,
    scale = 0.5,
    shift = shift,
    draw_as_shadow = true
  }
end

local v_chest = function(shift)
  return
  {
    filename = util.path("data/entities/mining_depot/depot-chest-v.png"),
    width = 136,
    height = 189,
    frame_count = 1,
    scale = 0.4,
    shift = shift
  }
end

local v_shadow = function(shift)
  return
  {
    filename = util.path("data/entities/mining_depot/depot-chest-v-shadow.png"),
    width = 150,
    height = 155,
    frame_count = 1,
    scale = 0.4,
    shift = shift,
    draw_as_shadow = true
  }
end

machine.animation =
{
  north =
  {
    layers =
    {
      base{0, -0.5},
      h_shadow{0.2, 1.5},
      h_chest{0, 1.5},

    }
  },
  south =
  {
    layers =
    {
      h_shadow{0.2, -1.5},
      h_chest{0, -1.5},
      base{0, 1},
    }
  },
  east =
  {
    layers =
    {
      v_shadow{-1.3, 0},
      v_chest{-1.5, 0},
      base{0.5, 0.2},
    }
  },
  west =
  {
    layers =
    {
      v_shadow{1.7, 0},
      v_chest{1.5, 0},
      base{-0.5, 0.2},
    }
  },
}

local item = {
  type = "item",
  name = name,
  icon = machine.icon,
  icon_size = machine.icon_size,
  flags = {},
  subgroup = "extraction-machine",
  order = "za"..name,
  place_result = name,
  stack_size = 50
}

local category = {
  type = "recipe-category",
  name = name
}

local subgroup =
{
  type = "item-subgroup",
  name = "mining-drone",
  group = "combat",
  order = "y"
}

local recipe = {
  type = "recipe",
  name = name,
  localised_name = {name},
  enabled = true,
  ingredients =
  {
    {"iron-plate", 50},
    {"iron-gear-wheel", 80},
    {"iron-stick", 50},
  },
  energy_required = 100,
  result = name
}

local chest_h =
{
  type = "container",
  name = names.mining_depot_chest_h,
  inventory_size = 19,
  picture = util.empty_sprite(),
  collision_box = {{-1.5, -1}, {1.5, 1}},
  selection_box = {{-1.5, -1}, {1.5, 1}},
  selection_priority = 100
}

local chest_v =
{
  type = "container",
  name = names.mining_depot_chest_v,
  inventory_size = 19,
  picture = util.empty_sprite(),
  collision_box = {{-1, -1.5}, {1, 1.5}},
  selection_box = {{-1, -1.5}, {1, 1.5}},
  selection_priority = 100
}

local caution_sprite =
{
  type = "sprite",
  name = "caution-sprite",
  filename = util.path("data/entities/mining_depot/depot-caution.png"),
  width = 101,
  height = 72,
  frame_count = 1,
  scale = 0.5,
  shift = shift,
  draw_as_shadow = false,
  flags = {"terrain"}
}

data:extend
{
  machine,
  item,
  category,
  subgroup,
  recipe,
  chest_h,
  chest_v,
  caution_sprite
}

local recipes = data.raw.recipe
local make_depot_recipe = function(item_prototype)
  local recipe_name = "mine-"..item_prototype.name
  if recipe[recipe_name] then return end
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
    category = name,
    subgroup = "mining-drone",
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



--error(count)