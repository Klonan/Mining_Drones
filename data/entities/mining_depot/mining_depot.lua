local machine = util.copy(data.raw["assembling-machine"]["assembling-machine-3"])
local name = names.mining_depot
machine.name = name
machine.localised_name = {name}
local scale = 2
util.recursive_hack_make_hr(machine)
util.recursive_hack_scale(machine, scale)
machine.collision_box = {{-1.5, -2.5},{1.5, 2.5}}
machine.selection_box = {{-1.5, -2.5},{1.5, 2.5}}
machine.crafting_categories = {name}
machine.crafting_speed = (1)
machine.ingredient_count = nil
--machine.collision_mask = {"item-layer", "object-layer", "water-tile"}
machine.allowed_effects = {"consumption", "speed", "pollution"}
machine.module_specification =
{
  module_slots = 2
}
machine.minable = {result = name, mining_time = 1}
machine.flags = {"placeable-neutral", "player-creation", "no-automated-item-removal"}
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
machine.energy_usage = "400kW"
machine.energy_source =
{
  type = "electric",
  usage_priority = "secondary-input",
  emissions_per_second_per_watt = 1 / 180000
}
machine.is_deployer = true

local base = function(shift)
  return
  {
    filename = util.path("data/entities/mining_depot/depot-base.png"),
    width = 474,
    height = 335,
    frame_count = 1,
    scale = 0.5,
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

local v_chest = function(shift)
  return
  {
    filename = util.path("data/entities/mining_depot/depot-chest-v.png"),
    width = 136,
    height = 189,
    frame_count = 1,
    scale = 0.5,
    shift = shift
  }
end

machine.animation =
{
  north =
  {
    layers =
    {
      base({0, -1}),
      h_chest({0, 1.5})
    }
  },
  south =
  {
    layers =
    {
      h_chest({0, -1.5}),
      base({0, 1}),
    }
  },
  east =
  {
    layers =
    {
      v_chest({-1.5, 0}),
      base({1, 0}),
    }
  },
  west =
  {
    layers =
    {
      base({-1, 0}),
      v_chest{1.5, 0},
    }
  },
}

local item = {
  type = "item",
  name = name,
  icon = machine.icon,
  icon_size = machine.icon_size,
  flags = {},
  subgroup = "mining-drone",
  order = "aa"..name,
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

data:extend
{
  machine,
  item,
  category,
  subgroup,
  recipe
}