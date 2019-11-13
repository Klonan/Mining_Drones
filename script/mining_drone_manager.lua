local Drone = require("script/mining_drone")

local script_data =
{
  drones = {}
}

local add_drone = function(drone)
  script_data.drones[drone.entity.unit_number] = drone
end

local remove_drone = function(drone)
  script_data.drones[drone.entity.unit_number] = nil
end

local on_built_entity = function(event)
  local entity = event.entity or event.created_entity
  if not (entity and entity.valid) then return end

  if entity.name ~= shared.drone_name then return end


end

local on_ai_command_completed = function(event)
  local drone = script_data.drones[event.unit_number]
  if not drone then return end
  if not (drone.entity and drone.entity.valid) then
    script_data.drones[event.unit_number] = nil
  end
  drone:update(event)
end

local lib = {}

lib.events =
{
  --[defines.events.on_built_entity] = on_built_entity,
  --[defines.events.on_robot_built_entity] = on_built_entity,
  --[defines.events.script_raised_revive] = on_built_entity,
  --[defines.events.script_raised_built] = on_built_entity,

  [defines.events.on_player_mined_entity] = on_entity_removed,
  [defines.events.on_robot_mined_entity] = on_entity_removed,

  [defines.events.on_entity_died] = on_entity_removed,
  [defines.events.script_raised_destroy] = on_entity_removed,

  [defines.events.on_ai_command_completed] = on_ai_command_completed,
}

lib.on_load = function()
  script_data = global.mining_drone_manager or script_data
  for unit_number, drone in pairs (script_data.drones) do
    setmetatable(drone, Drone.metatable)
  end
end

lib.on_init = function()
  global.mining_drone_manager = global.mining_drone_manager or script_data
end

lib.new = function(entity)
  local new_drone = Drone.new(entity)
  add_drone(new_drone)
  return new_drone
end

return lib