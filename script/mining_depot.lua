local names = require("shared")

local chest_data =
{
  [defines.direction.north] = {name = names.mining_depot_chest_h, offset = {0, 1}},
  [defines.direction.south] = {name = names.mining_depot_chest_h, offset = {0, -2}},
  [defines.direction.east] = {name = names.mining_depot_chest_v, offset = {-2, 0}},
  [defines.direction.west] = {name = names.mining_depot_chest_v, offset = {1, 0}},
}

local on_built_entity = function(event)
  local entity = event.entity or event.created_entity
  if not (entity and entity.valid) then return end
  if entity.name ~= names.mining_depot then return end
  game.print("hi")
  local chest_info = chest_data[entity.direction]
  local position = entity.position
  entity.surface.create_entity{name = chest_info.name, position = {position.x + chest_info.offset[1], position.y + chest_info.offset[2]}, force = entity.force}
end

local lib = {}

lib.events =
{
  [defines.events.on_built_entity] = on_built_entity,
  [defines.events.on_robot_built_entity] = on_built_entity,
  [defines.events.script_raised_revive] = on_built_entity,
  [defines.events.script_raised_built] = on_built_entity,
}

return lib