local drone_manager = require("script/mining_drone_manager")
local depot_update_rate = 60
local mining_depot = {}
local depot_metatable = {__index = mining_depot}

local script_data =
{
  depots = {}
}

local names = require("shared")

function mining_depot.new(entity)
  local depots = script_data.depots
  local depot = 
  {
    entity = entity,
    drones = {},
    potential = {}
  }
  setmetatable(depot, depot_metatable)
  local unit_number = entity.unit_number
  local bucket = depots[unit_number % depot_update_rate]
  if not bucket then
    bucket = {}
    depots[unit_number % depot_update_rate] = bucket
  end
  bucket[unit_number] = depot
  entity.active = false
  return depot
end

local on_built_entity = function(event)
  local entity = event.entity or event.created_entity
  if not (entity and entity.valid) then return end

  if entity.name ~= names.mining_depot then return end
  
  mining_depot.new(entity)

end

local offsets = 
{
  [defines.direction.north] = {0, -2.5},
  [defines.direction.south] = {0, 2.5},
  [defines.direction.east] = {2.5, 0},
  [defines.direction.west] = {-2.5, 0},
}

function mining_depot:spawn_drone()
  local entity = self.entity
  local offset = offsets[entity.direction]
  local position = entity.position
  position.x = position.x + offset[1]
  position.y = position.y + offset[2]
  local build_position = entity.surface.find_non_colliding_position(names.drone_name, position, 5, 0.5, false)
  if not build_position then return end
  local unit = entity.surface.create_entity{name = names.drone_name, position = build_position, force = entity.force}
  if not unit then return end

  self:get_drone_inventory().remove({name = names.drone_name, count = 1})

  self.drones[unit.unit_number] = drone

  local drone = drone_manager.new(unit)

  drone:set_depot(self)
  drone:set_desired_item(self:get_desired_item())
  drone:set_desired_amount(2)

  return drone
end

function mining_depot:update()
  local entity = self.entity
  if not (entity and entity.valid) then return end
  if table_size(self.drones) >= 10 then return end
  --entity.surface.create_entity{name = "flying-text", position = entity.position, text = entity.get_recipe() and entity.get_recipe().name or "No recipe"}
  local recipe = entity.get_recipe()
  if not recipe then return end

  --[[

    local drone = self:spawn_drone()
    drone:set_depot(self)
    drone:set_desired_item(recipe.products[1].name)
    drone:set_desired_amount(10)
    drone:try_to_mine()
    ]]

  if self:is_full() then return end
  if not self:can_spawn_drone() then return end

  local entity = self:find_entity_to_mine()
  if not entity then return end

  local drone = self:spawn_drone()
  drone:mine_entity(entity)

end

function mining_depot:can_spawn_drone()
  return not self:get_drone_inventory().is_empty()
end

local unique_index = function(entity)
  local unit_number = entity.unit_number
  if unit_number then return unit_number end
  local position = entity.position
  return entity.surface.index.."_"..position.x.."_"..position.y
end

function mining_depot:find_entities_to_mine()
  local item = self:get_desired_item()
  local potential = self.potential
  if potential[item] then return potential[item] end

  potential[item] = {}
  
  for k, entity in pairs (self.entity.surface.find_entities_filtered{position = self.entity.position, radius = 32}) do
    local properties = entity.prototype.mineable_properties
    if properties.minable and properties.products then
      for k, product in pairs (properties.products) do
        if product.name == item then
          potential[item][unique_index(entity)] = entity
          break
        end
      end
    end
  end
  --game.print(serpent.block(potential))
  return potential[item]

end

function mining_depot:find_entity_to_mine()

  local entities = self:find_entities_to_mine()
  if not next(entities) then return end

  local closest = self.entity.surface.get_closest(self.entity.position, entities)
  entities[unique_index(closest)] = nil

  return closest
  
end

function mining_depot:remove_drone(drone)
  self.drones[drone.entity.unit_number] = nil
  drone.entity.destroy()
  self:get_drone_inventory().insert{name = names.drone_name, count = 1}
end

function mining_depot:order_drone(drone)

  local target = drone.mining_target

  if self:is_full() then
    if target.valid then
      self.potential[drone.desired_item][unique_index(target)] = target
    end
    self:remove_drone(drone)
    if target.valid then
    end
    return
  end

  local entity = target.valid and target or self:find_entity_to_mine()
  if not entity then
    self:remove_drone(drone)
    return
  end
  drone:mine_entity(entity) 

end

function mining_depot:get_output_inventory()
  return self.entity.get_output_inventory()
end

function mining_depot:get_drone_inventory()
  return self.entity.get_inventory(defines.inventory.assembling_machine_input)
end

function mining_depot:get_desired_item()
  local recipe = self.entity.get_recipe()
  if not recipe then return end
  return recipe.products[1].name
end

function mining_depot:is_full()
  local inventory = self:get_output_inventory()
  local stack = inventory[1]
  if not (stack and stack.valid_for_read) then return false end
  return stack.prototype.stack_size == stack.count
end

local on_tick = function(event)
  local bucket = script_data.depots[event.tick % depot_update_rate]
  if bucket then
    for unit_number, depot in pairs (bucket) do
      if not (depot.entity.valid) then
        bucket[unit_number] = nil
      else
        depot:update()
      end
    end 
  end
end

local lib = {}

lib.events =
{
  [defines.events.on_built_entity] = on_built_entity,
  [defines.events.on_robot_built_entity] = on_built_entity,
  [defines.events.script_raised_revive] = on_built_entity,
  [defines.events.script_raised_built] = on_built_entity,

  [defines.events.on_tick] = on_tick,
}

lib.on_init = function()
  global.mining_depot = global.mining_depot or script_data
end

lib.on_load = function()
  script_data = global.mining_depot or script_data
  for k, bucket in pairs (script_data.depots) do
    for unit_number, depot in pairs (bucket) do
      setmetatable(depot, depot_metatable)
    end
  end
end

return lib