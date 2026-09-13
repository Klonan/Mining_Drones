local name = shared.mining_productivity_technology
local finite_levels = shared.technology_levels

local science_packs =
{
  "automation-science-pack",
  "logistic-science-pack",
  "chemical-science-pack",
  "production-science-pack",
  "utility-science-pack",
  "space-science-pack"
}

local ingredients_for_level = function(level)
  local ingredients = {}
  for k = 1, math.min(level, #science_packs) do
    ingredients[k] = {science_packs[k], 1}
  end
  return ingredients
end

local technology_icons = function()
  return
  {
    {
      icon = "__Mining_Drones__/data/technologies/mining_drones_tech.png",
      icon_size = 256
    },
    {
      icon = "__core__/graphics/icons/technology/constants/constant-mining-productivity.png",
      icon_size = 128,
      shift = {100, 100}
    }
  }
end

local effects = function()
  return
  {
    {
      type = "nothing",
      effect_description = {"mining-drone-productivity-description"},
      icons =
      {
        {
          icon = "__Mining_Drones__/data/icons/mining_drone.png",
          icon_size = 64
        },
        {
          icon = "__core__/graphics/icons/technology/constants/constant-mining-productivity.png",
          icon_size = 128,
          shift = {10, 10}
        }
      }
    }
  }
end

for k = 1, finite_levels do
  data:extend
  {
    {
      type = "technology",
      name = name.."-"..k,
      localised_name = {name},
      icons = technology_icons(),
      upgrade = true,
      effects = effects(),
      prerequisites = k > 1 and {name.."-"..(k - 1)} or {"automation-science-pack"},
      unit =
      {
        count = k * 250,
        ingredients = ingredients_for_level(k),
        time = 30
      },
      order = name
    }
  }
end

local infinite_level = finite_levels + 1

data:extend
{
  {
    type = "technology",
    name = name.."-"..infinite_level,
    localised_name = {name},
    icons = technology_icons(),
    upgrade = true,
    effects = effects(),
    prerequisites = {name.."-"..finite_levels},
    unit =
    {
      count_formula = "(L-5)*2500",
      ingredients = ingredients_for_level(#science_packs),
      time = 30
    },
    order = name,
    max_level = "infinite"
  }
}
