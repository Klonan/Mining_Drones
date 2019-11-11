local names = require("shared")

local on_built_entity = function(event)
  local entity = event.entity or event.created_entity
  if not (entity and entity.valid) then return end
  if not entity.name == names.mining_depot then return end
  game.print("hi")
  entity.surface.create_entity{name = names.mining_depot_chest_h, position = entity.position, force = entity.force}
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