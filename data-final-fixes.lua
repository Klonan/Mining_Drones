util = require "data/tf_util/tf_util"
names = require("shared")
shared = require("shared")

local collision_util = require("collision-mask-util")

--local drone_layer = collision_util.get_first_unused_layer()
local drone_layer = { type = "collision-layer", order = "42", name = "mining_drone" }
data:extend{drone_layer}


for k, prototype in pairs (collision_util.collect_prototypes_with_layer("player")) do
  if prototype.name ~= "mining-depot" and prototype.type ~= "character" then
    local mask = collision_util.get_mask(prototype)
    mask.layers[drone_layer.name] = true
    prototype.collision_mask = mask
  end
end

shared.mining_drone_collision_mask =
{
  not_colliding_with_itself = true,
  consider_tile_transitions = true,
  layers =
  {
    mining_drone = true,
    doodad = true
  }
}

require("data/entities/attack_proxy/attack_proxy")

--[[

  for name, unit in pairs(data.raw.unit) do
    if name:find(shared.drone_name, 0, true) then
      unit.loot = nil
    end
    if name:find(shared.attack_proxy_name, 0, true) then
      unit.loot = nil
    end
  end
  ]]