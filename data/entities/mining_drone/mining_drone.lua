local name = shared.drone_name

local item =
{
  type = "item",
  name = name,
  localised_name = {name},
  icon = "__Mining_Drones__/data/icons/mining_drone.png",
  icon_size = 64,
  flags = {},
  subgroup = "extraction-machine",
  order = "zb"..name,
  stack_size = 20
}

local recipe =
{
  type = "recipe",
  name = name,
  localised_name = {name},
  enabled = true,
  ingredients =
  {
    {type = "item", name = "light-armor", amount = 1},
    {type = "item", name = "iron-plate", amount = 2},
    {type = "item", name = "iron-gear-wheel", amount = 4},
  },
  energy_required = 2,
  results = {{type = "item", name = name, amount = 1}}
}

data:extend
{
  item,
  recipe
}
