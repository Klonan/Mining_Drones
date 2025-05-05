local name = shared.mining_drone_technology

local technology =
{
  name = name,
  localised_name = {name},
  type = "technology",
  icons =
  {
     {
       icon = "__Mining_Drones__/data/technologies/mining_drones_tech.png",
       icon_size = 256,
       icon_mipmaps = 0,
     }
  },
  upgrade = false,
  effects =
  {
    {
      type = "unlock-recipe",
      recipe = "mining-depot",
    },
    {
      type = "unlock-recipe",
      recipe = "mining-drone",
    },
    {
      type = "unlock-recipe",
      recipe = "iron-stick",
    },
  },
  research_trigger =
  {
    type = "craft-item",
    item = "iron-plate",
    count = 50
  },
  order = name
}

data:extend{technology}
