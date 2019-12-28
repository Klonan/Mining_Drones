local names = require("shared")

local mining_drone = require("script/mining_drone")
local mining_technologies = require("script/mining_technologies")

local depot_update_rate = 60
local mining_depot = {}
local depot_metatable = {__index = mining_depot}
local depot_range = 40
local max_spawn_per_update = 5
local variation_count = shared.variation_count
local default_bot_name = names.drone_name

local script_data =
{
  depots = {},
  path_requests = {},
  global_taken = {},
  depot_highlights = {},
  migrate_corpse = true
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
local floor = math.floor
local random = math.random

function mining_depot:get_product_amount(entity, randomize_ore, ignore_productivity)

  --Minor issue: things like big rocks have coal and stone...

  if entity.type == "item-entity" then
    return entity.stack.count
  end

  local product = get_main_product(entity)

  local amount = product.amount or ((product.amount_min + product.amount_max) / 2)

  if entity.type == "resource" then
    amount = amount * 5
    local bonus = mining_technologies.get_cargo_size_bonus(self.force_index)
    amount = amount + bonus

    if randomize_ore then
      amount = math.ceil((random() + 0.5) * amount)
    end

    amount = min(amount, entity.amount)
  end

  if not ignore_productivity then
    local productivity = 1 + mining_technologies.get_productivity_bonus(self.force_index)
    amount = math.ceil(amount * productivity)
  end

  return amount

end


local offsets =
{
  [defines.direction.north] = {0, -2.75},
  [defines.direction.south] = {0, 2.75},
  [defines.direction.east] = {2.75, 0},
  [defines.direction.west] = {-2.75, 0},
}

local add_to_bucket = function(depot)
  local unit_number = depot.entity.unit_number
  local depots = script_data.depots
  local bucket = depots[unit_number % depot_update_rate]
  if not bucket then
    bucket = {}
    depots[unit_number % depot_update_rate] = bucket
  end
  bucket[unit_number] = depot
end

function mining_depot:add_corpse()

  if self.corpse and self.corpse.valid then
    error("HUH")
    return
  end

  local corpse = self.entity.surface.create_entity
  {
    name = "caution-corpse",
    position = self:get_spawn_position(),
    force = "neutral"
  }
  corpse.corpse_expires = false
  self.corpse = corpse
end

function mining_depot:remove_corpse()

  if self.corpse and self.corpse.valid then
    self.corpse.destroy()
    self.corpse = nil
  end

end

function mining_depot.new(entity)

  local depot =
  {
    entity = entity,
    drones = {},
    potential = {},
    path_requests = {},
    surface_index = entity.surface.index,
    force_index = entity.force.index,
    item = nil,
    fluid = nil
  }
  setmetatable(depot, depot_metatable)

  if not script_data.global_taken[depot.surface_index] then
    script_data.global_taken[depot.surface_index] = {}
  end

  depot:add_corpse()

  add_to_bucket(depot)

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
local get_speed_variance = function()
  return (1 + (random() - 0.5) / 3)
end

local drone_base_speed = 0.05

function mining_depot:get_drone_speed()
  return (drone_base_speed * (1 + mining_technologies.get_walking_speed_bonus(self.force_index))) * get_speed_variance()
end

function mining_depot:spawn_drone()
  local entity = self.entity


  local name = self.entity.get_recipe().name..names.drone_name..random(variation_count)

  local spawn_entity_data =
  {
    name = name,
    position = self:get_spawn_position(),
    force = entity.force,
    create_build_effect_smoke = false,
    raise_built = true
  }
  local surface = entity.surface
  if not surface.can_place_entity(spawn_entity_data) then return end

  local unit = surface.create_entity(spawn_entity_data)
  if not unit then return end

  unit.orientation = (entity.direction / 8)
  --unit.ai_settings.do_separation = false

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


  if self.rendering and rendering.is_valid(self.rendering) then
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
  self.fluid = self:get_required_fluid()
  self.had_rescan = nil

  for k, drone in pairs(self.drones) do
    drone:cancel_command()
  end

  self:find_potential_items()

  if self.rendering then
    rendering.destroy(self.rendering)
    self.rendering = nil
  end
end

function mining_depot:get_required_fluid()
  local recipe = self.entity.get_recipe()
  if not recipe then return end
  return recipe.ingredients[2]
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

  if not self:has_enough_fluid() then
    return
  end

  self:spawn_drones()

end

local stack_count = 60 - 3
local ceil = math.ceil
local floor = math.floor
local spawn_damping_ratio = 0.2

function mining_depot:get_should_spawn_drone_count(extra)

  local max_drones = self:get_drone_item_count()
  local active = self:get_active_drone_count() - (extra and 1 or 0)
  if active >= max_drones then return 0 end

  local should_be_spawned = math.min(max_drones, ceil(max_drones * (1 - self:get_full_ratio())))

  local should_spawn_count = should_be_spawned - active
  return ceil(should_spawn_count * spawn_damping_ratio)
end

function mining_depot:spawn_drones()

  local max_drones = self:get_drone_item_count()
  local active = self:get_active_drone_count()

  if active >= max_drones then
    return
  end

  local should_spawn_count = self:get_should_spawn_drone_count()

  if should_spawn_count <= 0 then return end

  for k = 1, should_spawn_count do
    local entity = self:find_entity_to_mine()
    if not entity then return end
    self:attempt_to_mine(entity)
  end

end

function mining_depot:has_enough_fluid()
  if not self.fluid then return true end
  local box = self:get_input_fluidbox()
  if not box then return false end

  return box.amount >= (self.fluid.amount / 10)

end

function mining_depot:get_input_fluidbox()
  return self.entity.fluidbox[1]
end

function mining_depot:get_drone_item_count()
  return self.entity.get_item_count(shared.drone_name)
end

function mining_depot:is_spawn_blocked()
  return not self.entity.surface.can_place_entity{name = default_bot_name, position = self:get_spawn_position()}
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

local insert = table.insert
function mining_depot:sort_by_distance(entities)

  local origin = self.entity.position
  local x, y = origin.x, origin.y

  local distance = function(position)
    return ((x - position.x) ^ 2 + (y - position.y) ^ 2)
  end

  for k, entity in pairs (entities) do
    entities[k] = {entity = entity, distance = distance(entity.position)}
  end

  table.sort(entities, function (k1, k2) return k1.distance < k2.distance end )

  for k = 1, #entities do
    entities[k] = entities[k].entity
  end

  return entities

end

function mining_depot:find_potential_items()

  local item = self.item
  if not item then self.potential = {} return end

  local area = self:get_area()
  local find_entities_filtered = self.entity.surface.find_entities_filtered

  local unsorted = find_entities_filtered{area = area, name = get_entities_for_products(item)}

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
    --game.print(k)
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

  local product_amount = self:get_product_amount(entity, true, true)
  local mining_count = 1
  if entity.type == "resource" then
    mining_count = product_amount
  end


  local productivity = 1 + mining_technologies.get_productivity_bonus(self.force_index)
  product_amount = math.ceil(product_amount * productivity)

  if self.fluid then
    local box = self:get_input_fluidbox()
    if not box then
      self:add_mining_target(entity)
      return
    end
    local needed_fluid = (self.fluid.amount / 100) * product_amount
    if box.amount < needed_fluid then
      local product_amount = math.floor(box.amount / (self.fluid.amount / 100))
      if product_amount == 0 then
        self:add_mining_target(entity)
        return
      end
      needed_fluid = (self.fluid.amount / 100) * product_amount
      mining_count = product_amount
    end
    self:take_fluid(needed_fluid)
  end

  drone.entity.speed = self:get_drone_speed()
  drone:mine_entity(entity, mining_count)

end

function mining_depot:take_fluid(amount)
  local box = self:get_input_fluidbox()
  if not box then game.print("Shouldn't happen?") return end
  local current = box.amount
  box.amount = box.amount - amount
  self.entity.force.fluid_production_statistics.on_flow(self.fluid.name, -amount)
  if box.amount == 0 then
    box = nil
  end
  self.entity.fluidbox[1] = box
end

function mining_depot:handle_order_request(drone)

  if not (drone.mining_target and drone.mining_target.valid) then
    self:return_drone(drone)
    return
  end

  local should_spawn_count = (self:get_should_spawn_drone_count(true))

  if should_spawn_count <= 0 or not self:has_enough_fluid() then
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
  local item = self.item
  if not item then return 0 end
  local prototype = game.item_prototypes[item]
  return (prototype.stack_size * (#inventory - 3)) - inventory.get_item_count(item)
end

function mining_depot:get_full_ratio()
  local inventory = self:get_output_inventory()
  local item = self.item
  if not item then return 1 end
  local prototype = game.item_prototypes[item]
  return inventory.get_item_count(item) / (prototype.stack_size * (#inventory - 3))
end

function mining_depot:handle_path_request_finished(event)

  if not self.entity.valid then
    self:add_mining_target(entity, true)
    return
  end

  local entity = self.path_requests[event.id]
  if not (entity and entity.valid) then return end
  self.path_requests[event.id] = nil

  local product_amount = self:get_product_amount(entity)

  if not event.path then
    --we can't reach it, don't spawn any miners.
    self:add_mining_target(entity, true)
    return
  end

  if self.fluid then
    local box = self:get_input_fluidbox()
    if not box then
      self:add_mining_target(entity)
      return
    end
    local needed_fluid = (self.fluid.amount / 100) * product_amount
    if box.amount < needed_fluid then
      local product_amount = math.floor(box.amount / (self.fluid.amount / 100))
      if product_amount == 0 then
        self:add_mining_target(entity)
        return
      end
    end
  end

  local drone = self:spawn_drone()
  self:order_drone(drone, entity)

end

function mining_depot:return_drone(drone)
  self:remove_drone(drone)
  drone:remove_from_list()
  drone:clear_inventory(true)
  drone.entity.destroy({raise_destroy = true})
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
  self:remove_corpse()
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
    local prototype = game.entity_prototypes[default_bot_name]
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

local highlight_color = {r = 0, g = 0.1, b = 0, a = 0.1}
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
    color = highlight_color,
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

  --[defines.events.on_selected_entity_changed] = on_selected_entity_changed,

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

lib.on_configuration_changed = function()
  if not script_data.migrate_corpse then
    script_data.migrate_corpse = true
    for k, bucket in pairs (script_data.depots) do
      for unit_number, depot in pairs (bucket) do
        depot:add_corpse()
      end
    end
  end
end

return lib