local mining_drone = require("script/mining_drone")
local depot_update_rate = 60
local mining_depot = {}
local depot_metatable = {__index = mining_depot}
local depot_range = 40
local max_spawn_per_update = 5

local script_data =
{
  depots = {},
  path_requests = {},
  global_taken = {},
  depot_highlights = {}
}

local main_products = {}
local get_main_product = function(entity)
  local cached = main_products[entity.name]
  if cached then return cached end

  cached = entity.prototype.mineable_properties.products[1]
  main_products[entity.name] = cached
  return cached

end

local min = math.min
local random = math.random
local get_product_amount = function(entity, randomize_ore)

  if entity.type == "item-entity" then
    return entity.stack.count
  end

  local product = get_main_product(entity)

  if entity.type == "resource" then
    local amount = (product.amount or (product.amount_min + product.amount_max) / 2) * 5
    if randomize_ore then return min(random(amount - 2, amount + 2), entity.amount) end
    return min(amount, entity.amount)
  end

  return product.amount or (product.amount_min + product.amount_max) / 2

end

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
    path_requests = {},
    surface_index = entity.surface.index,
    item = nil
  }

  script_data.global_taken[depot.surface_index] = script_data.global_taken[depot.surface_index] or {}

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

local random = math.random
local get_drone_speed = function()
  return 0.05 * (1 + (random() - 0.5) / 2)
end

function mining_depot:spawn_drone()
  local entity = self.entity

  local spawn_entity_data = {name = names.drone_name, position = self:get_spawn_position(), force = entity.force}
  local surface = entity.surface
  if not surface.can_place_entity(spawn_entity_data) then return end

  local unit = surface.create_entity(spawn_entity_data)
  if not unit then return end

  unit.orientation = (entity.direction / 8)
  unit.ai_settings.do_separation = false

  --self:get_drone_inventory().remove({name = names.drone_name, count = 1})


  local drone = mining_drone.new(unit)
  self.drones[unit.unit_number] = drone

  drone:set_depot(self)

  self:update_sticker()
  return drone
end

local draw_text = rendering.draw_text
local destroy = rendering.destroy

function mining_depot:update_sticker()


  if self.rendering then
    rendering.set_text(self.rendering, self:get_active_drone_count().."/"..self:get_drone_item_count())
    return
  end

  if not self.item then return end

  self.rendering = draw_text
  {
    surface = self.surface_index,
    target = self.entity,
    text = self:get_active_drone_count().."/"..self:get_drone_item_count(),
    only_in_alt_mode = true,
    forces = {self.entity.force},
    color = {r = 1, g = 1, b = 1},
    alignment = "center",
    scale = 1.5
  }


end

function mining_depot:desired_item_changed()
  self.item = self:get_desired_item()
  for k, drone in pairs(self.drones) do
    drone:cancel_command()
  end
  self:find_potential_items()
  if self.rendering then
    rendering.destroy(self.rendering)
    self.rendering = nil
  end
end

local alert_data = {type = "item", name = shared.mining_depot}
local target_offset = {0, -0.5}
function mining_depot:add_no_items_alert(string)

  for k, player in pairs (self.entity.force.connected_players) do
    player.add_custom_alert(self.entity, alert_data, "Mining depot out of mining targets.", true)
  end

  rendering.draw_sprite
  {
    surface = self.surface_index,
    target = self.entity,
    sprite = "utility/warning_icon",
    forces = {self.entity.force},
    time_to_live = 30,
    target_offset = target_offset,
    render_layer = "entity-info-icon-above"
  }
end

function mining_depot:add_spawn_blocked_alert(string)

  for k, player in pairs (self.entity.force.connected_players) do
    player.add_custom_alert(self.entity, alert_data, "Mining depot spawn blocked.", true)
  end
  rendering.draw_sprite
  {
    surface = self.surface_index,
    target = self.entity,
    sprite = "utility/warning_icon",
    forces = {self.entity.force},
    time_to_live = 30,
    target_offset = offsets[self.entity.direction],
    x_scale = 0.5,
    y_scale = 0.5,
    render_layer = "entity-info-icon-above"
  }
end

local min = math.min
function mining_depot:update()

  local entity = self.entity
  if not (entity and entity.valid) then return end


  local item = self:get_desired_item()
  if item ~= self.item then
    self:desired_item_changed()
    self:update_sticker()
    return
  end

  if not item then return end

  if not next(self.potential) then
    --Nothing to mine, nothing to do...
    if next(self.drones) then
      --Drones are still mining, so they can be holding the targets.
      return
    end
    if not self.had_rescan then
      self.had_rescan = true
      self:find_potential_items()
      return
    end
    self:add_no_items_alert()
    return
  end

  if self:is_spawn_blocked() then
    self:add_spawn_blocked_alert()
    return
  end

  --self:adopt_idle_drones()


  if self:is_full() then
    return
  end

  local count = self:get_drone_item_count() - self:get_active_drone_count()

  if count > 0 then
    local output_space = self:get_output_space()
    for k = 1, (min(count, max_spawn_per_update)) do

      if output_space - self.estimated_count <= 0 then break end

      local entity = self:find_entity_to_mine()
      if not entity then return end

      self:attempt_to_mine(entity)

    end
  elseif count < 0 then
    for k = count, 0, 1 do
      local index, drone = next(self.drones)
      if drone then
        drone:cancel_command()
      end
    end
  end

end

function mining_depot:adopt_idle_drones()

  local idle_drones = mining_drone.get_idle_drones()
  if not next(idle_drones) then return end

  local space = self:get_drone_item_count() - self:get_active_drone_count()

  if space < 1 then return end

  for unit_number, drone in pairs (idle_drones) do
    self:take_drone(drone)
    drone:return_to_depot()
    idle_drones[unit_number] = nil
    space = space - 1
    if space < 1 then break end
  end

end

function mining_depot:get_drone_item_count()
  return self.entity.get_item_count(shared.drone_name)
end

function mining_depot:get_can_spawn_count()
  return self:get_drone_item_count() - self:get_active_drone_count()
end

function mining_depot:is_spawn_blocked()
  return not self.entity.surface.can_place_entity{name = names.drone_name, position = self:get_spawn_position()}
end

function mining_depot:can_spawn_drone()
  return not self:is_spawn_blocked() and self.get_drone_item_count() > self:get_active_drone_count()
end

local unique_index = function(entity)
  local unit_number = entity.unit_number
  if unit_number then return unit_number end
  local position = entity.position
  return (position.x * 10000000) + position.y
end

local insert = table.insert
local get_entities_for_products = function(item)
  local names = {}
  for name, prototype in pairs(game.entity_prototypes) do
    local properties = prototype.mineable_properties
    if properties.minable and properties.products then
      for k, product in pairs (properties.products) do
        if product.name == item then
          insert(names, name)
          break
        end
      end
    end
  end
  return names
end

local directions =
{
  [defines.direction.north] = {0, -(depot_range + 2.5)},
  [defines.direction.south] = {0, (depot_range + 2.5)},
  [defines.direction.east] = {(depot_range + 2.5), 0},
  [defines.direction.west] = {-(depot_range + 2.5), 0},
}

local get_depot_area = function(entity)
  local origin = entity.position
  local direction = directions[entity.direction]
  origin.x = origin.x + direction[1]
  origin.y = origin.y + direction[2]
  return util.area(origin, depot_range)
end

function mining_depot:get_area()
  return get_depot_area(self.entity)
end



local abs = math.abs
local insert = table.insert

function mining_depot:add_to_potential_sorted(entity)
  error("Don't use me?")
  local origin = self.entity.position
  local x, y = origin.x, origin.y

  local distance = function(position)
    return abs(x - position.x) + abs(y - position.y)
  end

  local length = distance(entity.position)
  local entities = self.potential

  for index, other_entity in pairs (entities) do
    if not other_entity.valid then
      entities[index] = nil
    else
      if length <= distance(other_entity.position) then
        insert(entities, index, entity)
        return
      end
    end
  end

  insert(entities, entity)

end

function mining_depot:sort_by_distance(entities)
  local profiler = game.create_profiler()

  local origin = self.entity.position
  local x, y = origin.x, origin.y

  local distance = function(position)
    return abs(x - position.x) + abs(y - position.y)
  end

  local sorted = {}

  local distance_cache = {}

  for k, entity in pairs (entities) do

    local length = distance(entity.position)
    distance_cache[entity] = length
    local added = false
    for index, other_entity in pairs (sorted) do
      if length <= distance_cache[other_entity] then
        insert(sorted, index, entity)
        added = true
        break
      end
    end

    if not added then
      insert(sorted, entity)
    end

  end

  distance_cache = nil

  game.print{"", "sorted ", #sorted, " ", profiler}

  return sorted

end

function mining_depot:find_potential_items()


  local item = self.item
  if not item then self.potential = {} return end

  local unsorted = {}

  local area = self:get_area()
  local find_entities_filtered = self.entity.surface.find_entities_filtered

  for k, entity in pairs(find_entities_filtered{area = area, name = get_entities_for_products(item)}) do
    insert(unsorted, entity)
  end

  for k, entity in pairs(find_entities_filtered{area = area, type = "item-entity"}) do
    if entity.stack.name == item then
      insert(unsorted, entity)
    end
  end

  self.potential = self:sort_by_distance(unsorted)

end

local insert = table.insert
function mining_depot:find_entity_to_mine()

  local entities = self.potential
  if not next(entities) then return end

  local taken = script_data.global_taken[self.surface_index]

  for k, entity in pairs (entities) do
    if entity.valid then
      local index = unique_index(entity)
      --entity.surface.create_entity{name = "flying-text", text = k, position = entity.position}
      if taken[index] then
        insert(taken[index], {depot = self, entity = entity, index = k})
      else
        taken[index] = {{depot = self, entity = entity, index = k}}
        return entity
      end
    end
    entities[k] = nil
  end

end

function mining_depot:remove_drone(drone, remove_item)

  if remove_item then
    self:get_drone_inventory().remove{name = names.drone_name, count = 1}
  end

  if drone.estimated_count then
    self.estimated_count = self.estimated_count - drone.estimated_count
    drone.estimated_count = nil
  end

  local mining_target = drone.mining_target
  if mining_target and mining_target.valid then
    self:add_mining_target(mining_target)
  end
  drone.mining_target = nil

  self.drones[drone.entity.unit_number] = nil
  self:update_sticker()
end

--self.potential[drone.desired_item][unique_index(target)] = target

function mining_depot:order_drone(drone, entity)

  local product_amount = get_product_amount(entity, true)
  local mining_count = 1
  if entity.type == "resource" then
    mining_count = product_amount
  end
  self.estimated_count = self.estimated_count + product_amount
  drone.estimated_count = product_amount

  drone.entity.speed = get_drone_speed()
  drone:mine_entity(entity, mining_count)

end

function mining_depot:handle_order_request(drone)

  if not (drone.mining_target and drone.mining_target.valid) then
    self:return_drone(drone)
    return
  end

  if self:is_full() or self:get_active_drone_count() > self:get_drone_item_count() then
    self:return_drone(drone)
    return
  end

  self:order_drone(drone, drone.mining_target)

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

function mining_depot:get_output_space()
  local inventory = self:get_output_inventory()
  local item = self:get_desired_item()
  if not item then return 0 end
  local prototype = game.item_prototypes[item]
  return (prototype.stack_size * (#inventory - 2)) - inventory.get_item_count(item)
end

function mining_depot:is_full()
  return (self:get_output_space() - self.estimated_count) <= 0
end

function mining_depot:handle_path_request_finished(event)
  local entity = self.path_requests[event.id]
  if not (entity and entity.valid) then return end
  self.path_requests[event.id] = nil

  local product_amount = get_product_amount(entity)
  self.estimated_count = self.estimated_count - product_amount

  if not event.path then
    --we can't reach it, don't spawn any miners.
    self:add_mining_target(entity, true)
    return
  end

  local drone = self:spawn_drone()
  self:order_drone(drone, entity)

end

function mining_depot:return_drone(drone)
  self:remove_drone(drone)
  drone:remove_from_list()
  drone.entity.destroy()
  self:update_sticker()
end

local insert = table.insert
function mining_depot:add_mining_target(entity, ignore_self)
  local taken = script_data.global_taken[self.surface_index]
  local index = unique_index(entity)
  local listening_depots = taken[index]

  for k, unlock_depot in pairs(listening_depots) do
    local depot = unlock_depot.depot
    if not ignore_self or depot ~= self then
      local entity = unlock_depot.entity
      if entity.valid and depot.entity.valid then
        depot.potential[unlock_depot.index] = entity
      end
    end
  end

  taken[index] = nil
end

function mining_depot:notify_global_unlock(unlock_data)

end

function mining_depot:remove_from_list()
  local unit_number = self.entity.unit_number
  script_data.depots[unit_number % depot_update_rate][unit_number] = nil
end

function mining_depot:handle_depot_deletion()
  for unit_number, drone in pairs (self.drones) do
    drone:cancel_command()
  end
end

function mining_depot:take_drone(drone)
  self.drones[drone.entity.unit_number] = drone
  drone:set_depot(self)

  --drone:say("Assigned to a new depot!")
  if drone:is_returning_to_depot() then
    drone:return_to_depot()
  end
end

function mining_depot:get_all_depots()
  local depots = {}
  for k, bucket in pairs (script_data.depots) do
    for unit_number, depot in pairs (bucket) do
      if not depot.entity.valid then
        error("HI idk if I should happen")
        --depot:handle_depot_deletion(unit_number)
        bucket[unit_number] = nil
      else
        depots[unit_number] = depot
      end
    end
  end
  return depots
end

function mining_depot:get_active_drone_count()
  return table_size(self.drones)
end

function mining_depot:can_accept_drone()
  return self:get_drone_item_count() > self:get_active_drone_count()
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

local box, mask
local get_box_and_mask = function()
  if not (box and mask) then
    local prototype = game.entity_prototypes[names.drone_name]
    box = prototype.collision_box
    mask = prototype.collision_mask
  end
  return box, mask
end

local flags = {cache = false, low_priority = false}
function mining_depot:attempt_to_mine(entity)

  --Will make a path request, and if it passes, send a drone to go mine it.
  local box, mask = get_box_and_mask()
  local path_request_id = self.entity.surface.request_path
  {
    bounding_box = box,
    collision_mask = mask,
    start = self:get_spawn_position(),
    goal = entity.position,
    force = self.entity.force,
    radius = entity.get_radius() + 0.5,
    can_open_gates = true,
    pathfind_flags = flags
  }

  script_data.path_requests[path_request_id] = self
  self.path_requests[path_request_id] = entity

  local product_amount = get_product_amount(entity)

  self.estimated_count = self.estimated_count + product_amount

end

local on_script_path_request_finished = function(event)
  --game.print(event.tick.." - "..event.id)
  local depot = script_data.path_requests[event.id]
  if not depot then return end
  script_data.path_requests[event.id] = nil
  depot:handle_path_request_finished(event)
end

local on_entity_removed = function(event)
  local entity = event.entity
  if not (entity and entity.valid) then
    return
  end
  local unit_number = entity.unit_number
  if not unit_number then return end

  local bucket = script_data.depots[unit_number % depot_update_rate]
  if not bucket then return end
  local depot = bucket[unit_number]
  if not depot then return end
  depot:handle_depot_deletion(unit_number)

end

local on_selected_entity_changed = function(event)
  local player = game.get_player(event.player_index)

  local highlight = script_data.depot_highlights[event.player_index]
  if highlight then
    rendering.destroy(highlight)
    script_data.depot_highlights[event.player_index] = nil
  end

  local entity = player.selected
  if not (entity and entity.valid) then return end

  if entity.name ~= names.mining_depot then return end

  local area = get_depot_area(entity)
  script_data.depot_highlights[event.player_index] = rendering.draw_rectangle
  {
    surface = entity.surface,
    players = {player},
    filled = true,
    color = {r = 0, g = 0.1, b = 0, a = 0.1},
    draw_on_ground = true,
    target = entity,
    only_in_alt_mode = false,
    left_top = area[1],
    right_bottom = area[2]
  }




end

local lib = {}

lib.events =
{
  [defines.events.on_built_entity] = on_built_entity,
  [defines.events.on_robot_built_entity] = on_built_entity,
  [defines.events.script_raised_revive] = on_built_entity,
  [defines.events.script_raised_built] = on_built_entity,

  [defines.events.on_script_path_request_finished] = on_script_path_request_finished,

  [defines.events.on_player_mined_entity] = on_entity_removed,
  [defines.events.on_robot_mined_entity] = on_entity_removed,

  [defines.events.on_entity_died] = on_entity_removed,
  [defines.events.script_raised_destroy] = on_entity_removed,

  [defines.events.on_tick] = on_tick,

  [defines.events.on_selected_entity_changed] = on_selected_entity_changed,

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