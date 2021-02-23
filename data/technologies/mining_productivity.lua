local name = shared.mining_productivity_technology

local levels =
{
  [1] =
  {
    {"automation-science-pack", 1},
  },
  [2] =
  {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
  },
  [3] =
  {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"chemical-science-pack", 1},
  },
  [4] =
  {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"chemical-science-pack", 1},
    {"production-science-pack", 1},
  },
  [5] =
  {
    {"automation-science-pack", 1},
    {"logistic-science-pack", 1},
    {"chemical-science-pack", 1},
    {"production-science-pack", 1},
    {"utility-science-pack", 1},
  }
}

for k, ingredients in pairs (levels) do

  local technology =
  {
    name = name.."-"..k,
    localised_name = {name},
    type = "technology",
    icons =
    {
      {
        icon = "__Mining_Drones__/data/technologies/mining_drones_tech.png",
        icon_size = 256,
        icon_mipmaps = 0,
      },
      {
        icon = "__core__/graphics/icons/technology/constants/constant-mining-productivity.png",
        icon_size = 128,
        --scale = 2,
        icon_mipmaps = 3,
        shift = {100, 100},
      }
    },
    upgrade = true,
    effects =
    {
      {
        type = "nothing",
        effect_description = "Mining drone productivity: +10%",
        icons =
        {
          {
            icon = "__Mining_Drones__/data/icons/mining_drone.png",
            icon_size = 64,
            icon_mipmaps = 0,
          },
          {
            icon = "__core__/graphics/icons/technology/constants/constant-mining-productivity.png",
            icon_size = 128,
            icon_mipmaps = 3,
            shift = {10, 10},
          }
        }
      }
    },
    prerequisites = k > 1 and {name.."-"..k - 1} or {},
    unit =
    {
      count = k * 250,
      ingredients = ingredients,
      time = 30
    },
    order = name
  }
  data:extend{technology}
end

local k = #levels + 1

local infinite =
{
  name = name.."-"..k,
  localised_name = {name},
  type = "technology",
  icons =
  {
    {
      icon = "__Mining_Drones__/data/technologies/mining_drones_tech.png",
      icon_size = 256,
      icon_mipmaps = 0,
    },
    {
      icon = "__core__/graphics/icons/technology/constants/constant-mining-productivity.png",
      icon_size = 128,
      --scale = 2,
      icon_mipmaps = 3,
      shift = {100, 100}
    }
  },
  upgrade = true,
  effects =
  {
    {
      type = "nothing",
      effect_description = "Mining drone productivity: +10%",
      icons =
      {
        {
          icon = "__Mining_Drones__/data/icons/mining_drone.png",
          icon_size = 64,
          icon_mipmaps = 0,
        },
        {
          icon = "__core__/graphics/icons/technology/constants/constant-mining-productivity.png",
          icon_size = 128,
          icon_mipmaps = 3,
          shift = {10, 10},
        }
      }
    }
  },
  prerequisites = k > 1 and {name.."-"..k - 1} or {},
  unit =
  {
    count_formula = "(L-5)*2500",
    ingredients =
    {
      {"automation-science-pack", 1},
      {"logistic-science-pack", 1},
      {"chemical-science-pack", 1},
      {"production-science-pack", 1},
      {"utility-science-pack", 1},
      {"space-science-pack", 1},
    },
    time = 30
  },
  order = name,
  max_level = "infinite"
}
data:extend{infinite}
