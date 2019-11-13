local drone_manager = require("script/mining_drone_manager")
local depot_update_rate = 60
local mining_depot = {}
local depot_metatable = {__index = mining_depot}

local script_data =
{
  depots = {},
  path_requests = {}
}

local names = require("shared")

local offsets = 
{
  [defines.direction.north] = {0, -3},
  [defines.direction.south] = {0, 3},
  [defines.direction.east] = {3, 0},
  [defines.direction.west] = {-3, 0},
}

function mining_depot.new(entity)

  local depot = 
  {
    entity = entity,
    drones = {},
    potential = {},
    estimated_count = 0,
    path_requests = {}
  }
  
  setmetatable(depot, depot_metatable)
  
  rendering.draw_sprite
  {
    sprite = "caution-sprite",
    surface = entity.surface,
    scale = 0.5,
    render_layer = "decorative",
    target = entity,
    target_offset = offsets[entity.direction]
  }
  
  local unit_number = entity.unit_number
  local depots = script_data.depots
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

function mining_depot:get_spawn_position()
  local offset = offsets[self.entity.direction]
  local position = self.entity.position
  position.x = position.x + offset[1]
  position.y = position.y + offset[2]
  return position
end

function mining_depot:spawn_drone()
  local entity = self.entity
  if not entity.surface.can_place_entity{name = names.drone_name, position = self:get_spawn_position()} then return end
  local unit = entity.surface.create_entity{name = names.drone_name, position = self:get_spawn_position(), force = entity.force}
  if not unit then return end

  unit.orientation = (entity.direction / 8)

  self:get_drone_inventory().remove({name = names.drone_name, count = 1})

  self.drones[unit.unit_number] = drone

  local drone = drone_manager.new(unit)

  drone:set_depot(self)

  return drone
end

function mining_depot:update()
  local entity = self.entity
  if not (entity and entity.valid) then return end
  if table_size(self.drones) >= 10 then return end
  
  local recipe = entity.get_recipe()
  if not recipe then return end

  if self:is_full() then return end
  if self:is_spawn_blocked() then

    return
  end
  if not self:can_spawn_drone() then return end

  local entity = self:find_entity_to_mine()
  if not entity then return end

  self:attempt_to_mine(entity)

end

function mining_depot:is_spawn_blocked()
  return not self.entity.surface.can_place_entity{name = names.drone_name, position = self:get_spawn_position()}
end

function mining_depot:attempt_to_mine(entity)

  --Will make a path request, and if it passes, send a drone to go mine it.

  local prototype = game.entity_prototypes[names.drone_name]
  local path_request_id = self.entity.surface.request_path
  {
    bounding_box = prototype.collision_box,
    collision_mask = prototype.collision_mask,
    start = self:get_spawn_position(),
    goal = entity.position,
    force = self.entity.force,
    radius = (entity.get_radius() * 2) + 1,
    can_open_gates = true,
    pathfind_flags = {cache = false}
  }

  script_data.path_requests[path_request_id] = self
  self.path_requests[path_request_id] = entity
end

function mining_depot:can_spawn_drone()
  return not (self:get_drone_inventory().is_empty() or self:is_spawn_blocked())
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
  if not potential[item] then 

    potential[item] = {}
    
    for k, entity in pairs (self.entity.surface.find_entities_filtered{position = self.entity.position, radius = 100}) do
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
  else
    for unit_number, entity in pairs (potential[item]) do
      if not entity.valid then
        potential[item][unit_number] = nil
      end
    end
  end
  --game.print(serpent.block(potential))
  return potential[item]

end

function mining_depot:find_entity_to_mine()

  local entities = self:find_entities_to_mine()
  if not next(entities) then
    self.potential = {}
    return
  end

  local closest = self.entity.surface.get_closest(self.entity.position, entities)
  entities[unique_index(closest)] = nil

  return closest
  
end

function mining_depot:remove_drone(drone)
  self.drones[drone.entity.unit_number] = nil
  drone.entity.destroy()
  self:get_drone_inventory().insert{name = names.drone_name, count = 1}
end

--self.potential[drone.desired_item][unique_index(target)] = target

function mining_depot:order_drone(drone, entity)

  if entity.type == "resource" then
    drone:mine_entity(entity, 5)
    self.estimated_count = self.estimated_count + 5
    return
  end

  self.estimated_count = self.estimated_count + (entity.prototype.mineable_properties.products[1].amount or entity.prototype.mineable_properties.products[1].amount_min)
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
  local item = self:get_desired_item()
  local prototype = game.item_prototypes[item]
  local count = self.estimated_count + inventory.get_item_count(item)
  return count >= (prototype.stack_size * 4) -- leave 2 stacks as overflow.
end

function mining_depot:handle_path_request_finished(event)
  local entity = self.path_requests[event.id]
  if not (entity and entity.valid) then return end

  if not event.path then
    --we can't reach it, don't spawn any miners.
    game.print("HUH")
    return
  end

  local drone = self:spawn_drone()
  self:order_drone(drone, entity)

end

function mining_depot:return_drone(drone)
  self:remove_drone(drone)
end

function mining_depot:add_mining_target(entity)
  self.potential[self:get_desired_item()][unique_index(entity)] = entity
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

local on_script_path_request_finished = function(event)
  local depot = script_data.path_requests[event.id]
  if not depot then return end
  depot:handle_path_request_finished(event)
end

local lib = {}

lib.events =
{
  [defines.events.on_built_entity] = on_built_entity,
  [defines.events.on_robot_built_entity] = on_built_entity,
  [defines.events.script_raised_revive] = on_built_entity,
  [defines.events.script_raised_built] = on_built_entity,

  [defines.events.on_script_path_request_finished] = on_script_path_request_finished,

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