local path = util.path("data/units/smg_guy/")
local name = names.drone_name

local base = util.copy(data.raw.character.character)

local item = {
  type = "item",
  name = name,
  localised_name = {name},
  icon = "__Mining_Drones__/data/icons/mining_drone.png",
  icon_size = 64,
  flags = {},
  subgroup = "extraction-machine",
  order = "zb"..name,
  stack_size = 20,
  --place_result = name
}

local recipe = {
  type = "recipe",
  name = name,
  localised_name = {name},
  --category = ,
  enabled = true,
  ingredients =
  {
    {"iron-plate", 10},
    {"iron-gear-wheel", 5},
    {"iron-stick", 10}
  },
  energy_required = 2,
  result = name
}

data:extend
{
  item,
  recipe
}
