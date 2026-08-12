local names = require("shared")

local mining_drone = require("script/mining_drone")
local mining_technologies = require("script/mining_technologies")

local depot_update_rate = 60
local path_queue_rate = 13
local mining_depot = {}
mining_depot.metatable = {__index = mining_depot}

script.register_metatable("mining_depot", mining_depot.metatable)
local variation_count = names.variation_count
local default_bot_name = names.drone_name

local script_data =
{
  depots = {},
  path_requests = {},
  --Keyed by the registration number of the resource entity, which is unique across all surfaces.
  targeted_resources = {},
  request_queue = {}
}

local min = math.min
local max = math.max
local floor = math.floor
local ceil = math.ceil
local random = math.random
local insert = table.insert

local get_mining_depot = function(unit_number)
  local bucket = script_data.depots[unit_number % depot_update_rate]
  return bucket and bucket[unit_number]
end

mining_drone.get_mining_depot = get_mining_depot

--Registering the same entity again always returns the same registration number,
--so this doubles as a stable per-entity key.
local unique_index = function(entity)
  return script.register_on_object_destroyed(entity)
end

--The depot can change force after it was built (script, force merge, capture), so the index is
--always read back off the entity rather than trusting the one it was created with.
function mining_depot:get_force_index()
  return self.entity.force.index
end

function mining_depot:get_mining_count(entity)
  local bonus = mining_technologies.get_cargo_size_bonus(self:get_force_index())
  return min(3 + random(2 + bonus), entity.amount)
end

local offsets = {}
local radius_offsets = {}
for name, depot in pairs (names.depots) do
  local offset = {depot.drop_offset[1], depot.drop_offset[2]}
  local depot_offset = {}
  local radius_offset = {}
  local shifts = depot.shifts
  depot_offset[defines.direction.north] = {offset[1] + shifts["north"][1], offset[2] + shifts["north"][2]}
  depot_offset[defines.direction.south] = {-offset[1] + shifts["south"][1], -offset[2] + shifts["south"][2]}
  depot_offset[defines.direction.east] = {-offset[2] + shifts["east"][1], -offset[1] + shifts["east"][2]}
  depot_offset[defines.direction.west] = {offset[2] + shifts["west"][1], offset[1] + shifts["west"][2]}
  offsets[name] = depot_offset

  radius_offset[defines.direction.north] = {offset[1], offset[2] - 0.5}
  radius_offset[defines.direction.south] = {-offset[1], -offset[2] + 0.5}
  radius_offset[defines.direction.east] = {-offset[2] + 0.5, -offset[1]}
  radius_offset[defines.direction.west] = {offset[2] - 0.5, offset[1]}
  radius_offsets[name] = radius_offset
end

local custom_drop_offsets =
{
  [defines.direction.north] = {0, 0.5},
  [defines.direction.east] = {0, 0.5},
  [defines.direction.south] = {0, -0.5},
  [defines.direction.west] = {0, 0.5},
}

function mining_depot:get_drop_offset()
  local offset = radius_offsets[self.entity.name][self.entity.direction]
  local x = offset[1] + custom_drop_offsets[self.entity.direction][1]
  local y = offset[2] + custom_drop_offsets[self.entity.direction][2]
  return {x, y}
end

function mining_depot:get_radius_offset()
  return radius_offsets[self.entity.name][self.entity.direction]
end

local add_to_bucket = function(depot)
  local unit_number = depot.unit_number
  local depots = script_data.depots
  local bucket = depots[unit_number % depot_update_rate]
  if not bucket then
    bucket = {}
    depots[unit_number % depot_update_rate] = bucket
  end
  bucket[unit_number] = depot
end

local wall_thickness = 1.25
local box_name = "mining-depot-collision-box"
--Rendering the collision boxes for a player index that will never exist keeps them invisible.
local render_player_index = 42069

function mining_depot:add_wall()

  --The depot doesn't collide with drones (see data-final-fixes), so that they can drive in
  --and out of the bay. These highlight boxes wall off everything except the open side.
  local direction = self.entity.direction
  local box = self.entity.bounding_box
  if direction == defines.direction.north then
    box.left_top.y = box.left_top.y + 1
  elseif direction == defines.direction.east then
    box.right_bottom.x = box.right_bottom.x - 1
  elseif direction == defines.direction.south then
    box.right_bottom.y = box.right_bottom.y - 1
  else
    box.left_top.x = box.left_top.x + 1
  end
  local position = {0, 0}
  local boxes = {}
  local surface = self.entity.surface

  if direction ~= defines.direction.north then
    insert(boxes, surface.create_entity
    {
      name = box_name,
      bounding_box =
      {
        {box.left_top.x, box.left_top.y},
        {box.right_bottom.x, box.left_top.y + wall_thickness},
      },
      position = position,
      render_player_index = render_player_index
    })
  end

  if direction ~= defines.direction.east then
    insert(boxes, surface.create_entity
    {
      name = box_name,
      bounding_box =
      {
        {box.right_bottom.x - wall_thickness, box.left_top.y},
        {box.right_bottom.x, box.right_bottom.y},
      },
      position = position,
      render_player_index = render_player_index
    })
  end

  if direction ~= defines.direction.south then
    insert(boxes, surface.create_entity
    {
      name = box_name,
      bounding_box =
      {
        {box.left_top.x, box.right_bottom.y - wall_thickness},
        {box.right_bottom.x, box.right_bottom.y},
      },
      position = position,
      render_player_index = render_player_index
    })
  end

  if direction ~= defines.direction.west then
    insert(boxes, surface.create_entity
    {
      name = box_name,
      bounding_box =
      {
        {box.left_top.x, box.left_top.y},
        {box.left_top.x + wall_thickness, box.right_bottom.y},
      },
      position = position,
      render_player_index = render_player_index
    })
  end

  for k, entity in pairs (boxes) do
    --Highlight boxes destroy themselves once their (zero) time to live runs out.
    entity.disabled_by_script = true
  end

  self.boxes = boxes

end

function mining_depot:clear_wall()
  if not self.boxes then return end
  for k, entity in pairs (self.boxes) do
    if entity.valid then
      entity.destroy()
    end
  end
  self.boxes = nil
end

function mining_depot:add_corpse()

  if self.corpse and self.corpse.valid then return end

  local corpse = self.entity.surface.create_entity
  {
    name = "caution-corpse",
    position = self:get_drop_position(),
    force = "neutral"
  }
  corpse.corpse_expires = false
  self.corpse = corpse
end

function mining_depot:remove_corpse()

  if self.corpse and self.corpse.valid then
    self.corpse.destroy()
  end
  self.corpse = nil

end

function mining_depot:add_spawn_corpse()

  if self.spawn_corpse and self.spawn_corpse.valid then return end

  local spawn_corpse = self.entity.surface.create_entity
  {
    name = "caution-corpse",
    position = self.entity.position,
    force = "neutral"
  }

  spawn_corpse.corpse_expires = false
  self.spawn_corpse = spawn_corpse
end

function mining_depot:remove_spawn_corpse()

  if self.spawn_corpse and self.spawn_corpse.valid then
    self.spawn_corpse.destroy()
  end
  self.spawn_corpse = nil

end

local status_ok = "working"
local status_no_recipe = "no-recipe"
local status_no_targets = "no-targets"
local status_no_fluid = "no-fluid"
local status_no_drones = "no-drones"

local custom_statuses =
{
  [status_ok] = {diode = defines.entity_status_diode.green, label = {"mining-depot-status-working"}},
  [status_no_recipe] = {diode = defines.entity_status_diode.red, label = {"mining-depot-status-no-recipe"}},
  [status_no_targets] = {diode = defines.entity_status_diode.red, label = {"mining-depot-status-no-targets"}},
  [status_no_fluid] = {diode = defines.entity_status_diode.yellow, label = {"mining-depot-status-no-fluid"}},
  [status_no_drones] = {diode = defines.entity_status_diode.yellow, label = {"mining-depot-status-no-drones"}},
}

function mining_depot:set_status(status)
  if self.status == status then return end
  self.status = status
  self.entity.custom_status = custom_statuses[status]
end

function mining_depot.new(entity)
  script.register_on_object_destroyed(entity)

  local depot =
  {
    entity = entity,
    drones = {},
    potential = {},
    recent = {},
    path_requests = {},
    surface_index = entity.surface.index,
    unit_number = entity.unit_number,
    direction = entity.direction,
    fluid = nil
  }
  setmetatable(depot, mining_depot.metatable)

  depot:add_corpse()
  depot:add_spawn_corpse()
  depot:add_wall()

  add_to_bucket(depot)

  entity.disabled_by_script = true
  depot:set_status(status_no_recipe)

  return depot
end

local on_built_entity = function(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end

  if entity.name ~= names.mining_depot then return end

  mining_depot.new(entity)

end

local on_entity_cloned = function(event)
  local entity = event.destination
  if not (entity and entity.valid) then return end

  if entity.name ~= names.mining_depot then return end

  --The clone brings along whatever the source had, but none of it is registered to the copy.
  if get_mining_depot(entity.unit_number) then return end

  mining_depot.new(entity)

end

--Rotating the depot moves the bay, the drop off point and the mining area, so everything that
--was built for the old direction has to be rebuilt.
function mining_depot:on_rotated()

  self.direction = self.entity.direction

  self:cancel_all_orders()
  self:clear_path_requests()
  self:clear_request_queue()

  self:clear_wall()
  self:add_wall()

  --The spawn marker sits on the depot itself, only the drop off marker moves.
  self:remove_corpse()
  self:add_corpse()

  if self.pot_animation and self.pot_animation.valid then
    self.pot_animation.destroy()
  end
  self.pot_animation = nil

  self:find_potential_targets()

end

local on_entity_rotated = function(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end

  if entity.name ~= names.mining_depot then return end

  local depot = get_mining_depot(entity.unit_number)
  if not depot then return end

  depot:on_rotated()
end

function mining_depot:get_drop_position()
  local offset = self:get_drop_offset()
  local position = self.entity.position
  position.x = position.x + offset[1]
  position.y = position.y + offset[2]
  return position
end

local get_speed_variance = function()
  return (1 + (random() - 0.5) / 3)
end

local drone_base_speed = 0.05

function mining_depot:get_drone_speed()
  return (drone_base_speed * (1 + mining_technologies.get_walking_speed_bonus(self:get_force_index()))) * get_speed_variance()
end

local direction_names =
{
  [defines.direction.north] = "north",
  [defines.direction.east] = "east",
  [defines.direction.south] = "south",
  [defines.direction.west] = "west"
}

function mining_depot:get_spawn_corpse()
  if self.spawn_corpse and self.spawn_corpse.valid then
    return self.spawn_corpse
  end
  self:add_spawn_corpse()
  return self.spawn_corpse
end

function mining_depot:get_corpse()
  if self.corpse and self.corpse.valid then
    return self.corpse
  end
  self:add_corpse()
  return self.corpse
end

function mining_depot:spawn_drone()

  if self:get_active_drone_count() >= self:get_drone_item_count() then
    return
  end

  local entity = self.entity
  local spawn_entity_data =
  {
    name = self.target_resource_name..default_bot_name..random(variation_count),
    position = entity.position,
    force = entity.force,
    create_build_effect_smoke = false
  }

  local surface = entity.surface
  if not surface.can_place_entity(spawn_entity_data) then return end

  local unit = surface.create_entity(spawn_entity_data)
  if not unit then return end

  --There are 16 directions, and orientation is a fraction of a full turn.
  unit.orientation = entity.direction / 16

  local drone = mining_drone.new(unit, self)
  self.drones[unit.unit_number] = true

  self:update_sticker()
  return drone
end

local draw_text = rendering.draw_text

function mining_depot:update_sticker()

  --Defensive: when a drone and its depot are destroyed in the same tick, today the depot is
  --always cleaned up first, but that rests on undocumented event ordering - so the drone paths
  --into here must survive a depot object whose entity is already gone.
  if not self.entity.valid then return end

  if self.rendering and self.rendering.valid then
    self.rendering.text = self:get_active_drone_count() .. "/" .. self:get_drone_item_count()
    return
  end

  if not self.target_resource_name then return end

  self.rendering = draw_text
  {
    surface = self.surface_index,
    target = self.entity,
    target_offset = {0, -0.5},
    text = self:get_active_drone_count().."/"..self:get_drone_item_count(),
    only_in_alt_mode = true,
    forces = {self.entity.force},
    color = {r = 1, g = 1, b = 1},
    alignment = "center",
    scale = 1.5
  }

end

function mining_depot:cancel_all_orders()
  for unit_number, bool in pairs(self.drones) do
    local drone = mining_drone.get_drone(unit_number)
    if drone then
      drone:cancel_command()
    end
  end
  self.drones = {}
end

function mining_depot:target_name_changed()

  self.target_resource_name = self:get_target_resource_name()
  self.fluid = self:get_required_fluid()

  self:clear_path_requests()
  self:clear_request_queue()
  self:cancel_all_orders()

  self:find_potential_targets()

  if self.rendering and self.rendering.valid then
    self.rendering.destroy()
  end
  self.rendering = nil

  if self.pot_animation and self.pot_animation.valid then
    self.pot_animation.destroy()
  end
  self.pot_animation = nil

end

function mining_depot:get_required_fluid()
  local recipe = self.entity.get_recipe()
  if not recipe then return end
  for k, ingredient in pairs (recipe.ingredients) do
    if ingredient.type == "fluid" then
      return {name = ingredient.name, amount = ingredient.amount}
    end
  end
end

local alert_data = {type = "item", name = names.mining_depot}
local alert_message = {"mining-depot-no-targets-alert"}
local target_offset = {0, -0.5}
function mining_depot:add_no_items_alert()

  self.entity.force.add_custom_alert(self.entity, alert_data, alert_message, true)

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

function mining_depot:update()

  local entity = self.entity
  if not (entity and entity.valid) then return end

  --Catches rotations that don't come with an event, for instance from another script.
  if self.direction ~= entity.direction then
    self:on_rotated()
    return
  end

  self:update_sticker()

  local item = self:get_target_resource_name()
  if item ~= self.target_resource_name then
    self:target_name_changed()
  end

  if not item then
    self:set_status(status_no_recipe)
    return
  end

  self:update_pot()

  if not self:has_mining_targets() then
    --Nothing to mine, nothing to do...

    if next(self.drones) then
      --Drones are still mining, so they can be holding the targets.
      return
    end

    if not self.mined_any then
      -- Last time we rescanned, and we didn't mine anything, so lets give up.
      self:set_status(status_no_targets)
      self:add_no_items_alert()
      return
    end

    self:find_potential_targets()

    if not self:has_mining_targets() then
      self:set_status(status_no_targets)
      return
    end

  end

  if not self:has_enough_fluid() then
    self:set_status(status_no_fluid)
    return
  end

  if self:get_drone_item_count() == 0 then
    self:set_status(status_no_drones)
    return
  end

  self:set_status(status_ok)

  self:try_to_mine_targets()

end

local target_amount_per_drone = 100
local max_target_amount = 65000 / 250

function mining_depot:get_target_item_count()
  local productivity = 1 + mining_technologies.get_productivity_bonus(self:get_force_index())
  return min(productivity * target_amount_per_drone, max_target_amount) * self:get_drone_item_count()
end

function mining_depot:get_full_ratio()

  local current_item_count = self:get_max_output_amount()
  if current_item_count == 0 then return 0 end

  return current_item_count / self:get_target_item_count()
end

function mining_depot:get_should_spawn_drone_count(extra)

  local max_drones = self:get_drone_item_count()
  if max_drones <= 0 then return 0 end

  --Path finds in progress, don't over achieve
  local path_requests = table_size(self.path_requests)
  local request_queue = script_data.request_queue[self.unit_number]
  if request_queue then
    path_requests = path_requests + table_size(request_queue)
  end

  local active = (self:get_active_drone_count() - (extra and 1 or 0)) + path_requests

  if active >= max_drones then return 0 end

  local ratio = 1 - ((self:get_max_output_amount() / self:get_target_item_count()) ^ 2)

  return min(ceil(ratio * max_drones) - active, ceil(depot_update_rate / path_queue_rate))

end

function mining_depot:try_to_mine_targets()

  if self:get_active_drone_count() >= self:get_drone_item_count() then
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

function mining_depot:has_mining_targets()
  return next(self.recent) or next(self.potential)
end

function mining_depot:has_enough_fluid()
  if not self.fluid then return true end
  return self.entity.get_fluid_count(self.fluid.name) >= (self.fluid.amount / 10)
end

function mining_depot:get_drone_item_count()
  return self.entity.get_item_count(default_bot_name)
end

function mining_depot:get_radius()
  local depot = names.depots[self.entity.name]
  return depot.radius
end

local directions =
{
  [defines.direction.north] = {0, -1},
  [defines.direction.south] = {0, 1},
  [defines.direction.east] = {1, 0},
  [defines.direction.west] = {-1, 0},
}

function mining_depot:get_area()
  local origin = self.entity.position
  local drop_offset = self:get_radius_offset()
  local radius = self:get_radius()
  local direction = directions[self.entity.direction]
  local radius_offset = {direction[1] * radius, direction[2] * radius}
  origin.x = origin.x + drop_offset[1] + radius_offset[1]
  origin.y = origin.y + drop_offset[2] + radius_offset[2]
  return util.area(origin, radius)
end

function mining_depot:sort_by_distance(entities)

  local origin = self.entity.position
  local x, y = origin.x, origin.y

  local distance = function(position)
    return ((x - position.x) ^ 2 + (y - position.y) ^ 2)
  end

  local targeted_resources = script_data.targeted_resources

  for k, entity in pairs (entities) do
    local index = unique_index(entity)
    if not targeted_resources[index] then
      targeted_resources[index] =
      {
        entity = entity,
        depots = {},
        max_mining = ceil(entity.get_radius() ^ 2),
        mining = 0
      }
    end
    entities[k] = {distance = distance(entity.position), index = index}
  end

  table.sort(entities, function (k1, k2) return k1.distance > k2.distance end )

  for k = 1, #entities do
    entities[k] = entities[k].index
  end

  return entities

end

function mining_depot:find_potential_targets()

  local target_name = self.target_resource_name
  if not target_name then
    self.potential = {}
    self.recent = {}
    self.mined_any = nil
    return
  end

  local unsorted = self.entity.surface.find_entities_filtered
  {
    type = "resource",
    area = self:get_area(),
    name = target_name
  }

  self.potential = self:sort_by_distance(unsorted)
  self.recent = {}
  self.mined_any = nil

end

function mining_depot:find_entity_to_mine()

  local targeted_resources = script_data.targeted_resources

  local recent = self.recent

  for entity_index, bool in pairs (recent) do
    local target_data = targeted_resources[entity_index]
    if target_data and target_data.entity.valid then
      target_data.depots[self.unit_number] = true
      if target_data.mining < target_data.max_mining then
        target_data.mining = target_data.mining + 1
        if target_data.mining >= target_data.max_mining then
          recent[entity_index] = nil
        end
        return target_data.entity
      end
    end
    recent[entity_index] = nil
  end

  local entities = self.potential
  if not entities[1] then return end

  local size = #entities
  while true do

    local entity_index = entities[size]
    if not entity_index then break end

    local target_data = targeted_resources[entity_index]
    if target_data and target_data.entity.valid then
      target_data.depots[self.unit_number] = true
      if target_data.mining < target_data.max_mining then
        target_data.mining = target_data.mining + 1
        if target_data.mining >= target_data.max_mining then
          entities[size] = nil
        end
        return target_data.entity
      end
    end

    entities[size] = nil

    size = size - 1

  end

end

function mining_depot:remove_drone(drone, remove_item)

  --Defensive, see update_sticker.
  if remove_item and self.entity.valid then
    local inventory = self:get_drone_inventory()
    if inventory and inventory.valid then
      inventory.remove{name = default_bot_name, count = 1}
    end
  end

  local mining_target = drone.mining_target
  if mining_target and mining_target.valid then
    self:add_mining_target(mining_target)
  end

  drone.mining_target = nil

  self.drones[drone.unit_number] = nil
  self:update_sticker()
end

function mining_depot:order_drone(drone, entity)

  if not self.mined_any then
    self.mined_any = true
  end

  local mining_count = self:get_mining_count(entity)

  if self.fluid then
    local available = self.entity.get_fluid_count(self.fluid.name)
    local fluid_per_mine = self.fluid.amount / 100
    local needed_fluid = fluid_per_mine * mining_count
    if available < needed_fluid then
      mining_count = floor(available / fluid_per_mine)
      if mining_count <= 0 then
        --Can't pay for a single mine: release the target and retire the drone, instead of
        --leaving it standing in the field forever with no command.
        self:add_mining_target(entity)
        drone.mining_target = nil
        self:return_drone(drone)
        return
      end
      needed_fluid = fluid_per_mine * mining_count
    end
    self:take_fluid(needed_fluid)
  end

  drone.entity.speed = self:get_drone_speed()
  drone:mine_entity(entity, mining_count)

end

function mining_depot:take_fluid(amount)
  local removed = self.entity.extract_fluid{name = self.fluid.name, amount = amount}
  if removed > 0 then
    self.entity.force.get_fluid_production_statistics(self.entity.surface).on_flow(self.fluid.name, -removed)
  end
end

function mining_depot:handle_order_request(drone)

  if not (drone.mining_target and drone.mining_target.valid) then
    self:return_drone(drone)
    return
  end

  local should_spawn_count = self:get_should_spawn_drone_count(true)

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
  return self.entity.get_inventory(defines.inventory.crafter_input)
end

local mine_prefix_length = ("mine-"):len()
function mining_depot:get_target_resource_name()
  local recipe = self.entity.get_recipe()
  if not recipe then return end
  return recipe.name:sub(mine_prefix_length + 1)
end

function mining_depot:get_max_output_amount()
  local recipe = self.entity.get_recipe()
  if not recipe then return 0 end
  local inventory = self:get_output_inventory()
  local amount = 0
  for k, product in pairs (recipe.products) do
    amount = max(amount, inventory.get_item_count(product.name))
  end
  return amount
end

function mining_depot:handle_path_request_finished(event)

  local entity = self.path_requests[event.id]
  self.path_requests[event.id] = nil

  if not (entity and entity.valid) then return end

  if not self.entity.valid then
    self:add_mining_target(entity, true)
    return
  end

  if event.try_again_later then
    self:attempt_to_mine(entity)
    return
  end

  if not event.path then
    --we can't reach it, don't spawn any miners.
    self:add_mining_target(entity, true)
    return
  end

  if not self:has_enough_fluid() then
    --Dont have enough fluid to mine anything
    self:add_mining_target(entity)
    return
  end

  local drone = self:spawn_drone()

  if not drone then
    --For some reason, we can't spawn a drone
    self:add_mining_target(entity)
    return
  end

  self:order_drone(drone, entity)

end

function mining_depot:update_pot()

  if not self.target_resource_name then
    if (self.pot_animation and self.pot_animation.valid) then
      self.pot_animation.destroy()
      self.pot_animation = nil
    end
    return
  end

  if not (self.pot_animation and self.pot_animation.valid) then
    self.pot_animation = rendering.draw_animation
    {
      animation = "depot-pot-"..self.target_resource_name.."-"..direction_names[self.entity.direction],
      render_layer = "higher-object-under",
      target = self.entity,
      surface = self.entity.surface
    }
  end

  self.pot_animation.animation_offset = max(0, min(ceil(self:get_full_ratio() * 17) - 1, 16))
end

function mining_depot:on_resource_given()
  self.entity.surface.create_entity
  {
    name = "depot-smoke-"..self.target_resource_name.."-"..direction_names[self.entity.direction],
    position = self.entity.position
  }
end

function mining_depot:return_drone(drone)
  self:remove_drone(drone)
  drone:clear_things()
  drone.entity.destroy()
  self:update_sticker()
end

function mining_depot:add_mining_target(entity, ignore_self)
  local targeted_resources = script_data.targeted_resources
  local index = unique_index(entity)
  local target_data = targeted_resources[index]
  if not target_data then return end

  target_data.mining = max(0, target_data.mining - 1)

  for depot_index, bool in pairs(target_data.depots) do
    if not ignore_self or depot_index ~= self.unit_number then
      local depot = get_mining_depot(depot_index)
      if depot then
        depot.recent[index] = true
      else
        target_data.depots[depot_index] = nil
      end
    end
  end

end

function mining_depot:clear_path_requests()
  local global_requests = script_data.path_requests
  for k, entity in pairs (self.path_requests) do
    if entity.valid then
      self:add_mining_target(entity, true)
    end
    global_requests[k] = nil
  end
  self.path_requests = {}
end

function mining_depot:clear_request_queue()
  local queue = script_data.request_queue[self.unit_number]
  if not queue then return end
  for k, entity in pairs (queue) do
    if entity.valid then
      self:add_mining_target(entity, true)
    end
  end
  script_data.request_queue[self.unit_number] = nil
end

function mining_depot:handle_depot_deletion()
  self:cancel_all_orders()
  self.drones = {}
  self:clear_path_requests()
  self:clear_request_queue()
  self:remove_corpse()
  self:remove_spawn_corpse()
  self:clear_wall()
  if self.rendering and self.rendering.valid then
    self.rendering.destroy()
  end
  self.rendering = nil
  if self.pot_animation and self.pot_animation.valid then
    self.pot_animation.destroy()
  end
  self.pot_animation = nil
end

function mining_depot:get_active_drone_count()
  return table_size(self.drones)
end

--Only one path request is ever in flight, so a request that never comes back would stall every
--depot in the game forever. The engine drops script path requests without an answer when their
--surface is deleted, so anything this old is given up on and the reservations handed back.
local stale_path_request_timeout = 60 * 30

local abandon_path_requests = function()
  for id, depot in pairs (script_data.path_requests) do
    script_data.path_requests[id] = nil
    local requests = depot.path_requests
    local entity = requests and requests[id]
    if requests then
      requests[id] = nil
    end
    if entity and entity.valid then
      depot:add_mining_target(entity, true)
    end
  end
end

local process_request_queue = function()

  if next(script_data.path_requests) then
    local last = script_data.last_path_request_tick
    if last and (game.tick - last) < stale_path_request_timeout then return end
    abandon_path_requests()
  end

  for depot_unit_number, entities in pairs (script_data.request_queue) do
    local depot = get_mining_depot(depot_unit_number)
    if depot then
      local entity_index, entity = next(entities)
      if entity then
        if entity.valid then
          depot:request_path(entity)
        end
        entities[entity_index] = nil
      else
        script_data.request_queue[depot_unit_number] = nil
      end
    else
      script_data.request_queue[depot_unit_number] = nil
    end
  end
end

local remove_depot = function(bucket, unit_number, depot)
  depot:handle_depot_deletion()
  bucket[unit_number] = nil
end

local on_tick = function(event)

  local bucket = script_data.depots[event.tick % depot_update_rate]
  if bucket then
    for unit_number, depot in pairs (bucket) do
      if not (depot.entity.valid) then
        remove_depot(bucket, unit_number, depot)
      else
        depot:update()
      end
    end
  end

  if event.tick % path_queue_rate == 0 then
    process_request_queue()
  end

end

local box, mask
local get_box_and_mask = function()
  if not (box and mask) then
    local prototype = prototypes.entity[default_bot_name]
    box = prototype.collision_box
    mask = prototype.collision_mask
  end
  return box, mask
end

local flags = {cache = false, low_priority = false}

function mining_depot:attempt_to_mine(entity)

  local depot_queue = script_data.request_queue[self.unit_number]
  if not depot_queue then
    depot_queue = {}
    script_data.request_queue[self.unit_number] = depot_queue
  end

  insert(depot_queue, entity)

end

function mining_depot:request_path(entity)
  --Will make a path request, and if it passes, send a drone to go mine it.
  local box, mask = get_box_and_mask()
  local path_request_id = self.entity.surface.request_path
  {
    bounding_box = box,
    collision_mask = mask,
    start = self.entity.position,
    goal = entity.position,
    force = self.entity.force,
    radius = entity.get_radius() + 0.5,
    can_open_gates = true,
    pathfind_flags = flags
  }

  script_data.path_requests[path_request_id] = self
  script_data.last_path_request_tick = game.tick
  self.path_requests[path_request_id] = entity

end

local on_script_path_request_finished = function(event)
  local depot = script_data.path_requests[event.id]
  if not depot then return end
  script_data.path_requests[event.id] = nil
  depot:handle_path_request_finished(event)
end

local on_entity_removed = function(event)

  local entity = event.entity
  if not (entity and entity.valid) then return end

  local unit_number = entity.unit_number
  if not unit_number then return end

  local bucket = script_data.depots[unit_number % depot_update_rate]
  if not bucket then return end
  local depot = bucket[unit_number]
  if not depot then return end
  remove_depot(bucket, unit_number, depot)

end

function mining_depot:check_for_rescan()
  if self.target_resource_name == self:get_target_resource_name() then
    --The recipe kept its name, but a mod update can still have changed what it needs, so the
    --fluid requirement is always recalculated.
    self.fluid = self:get_required_fluid()
    return
  end
  self:target_name_changed()
end

local cancel_all_depots = function()
  for k, bucket in pairs (script_data.depots) do
    for unit_number, depot in pairs (bucket) do
      depot:cancel_all_orders()
      depot:update_sticker()
    end
  end
end

local rescan_all_depots = function()
  for k, bucket in pairs (script_data.depots) do
    for unit_number, depot in pairs (bucket) do
      depot:find_potential_targets()
    end
  end
end

local reset_all_depots = function()
  cancel_all_depots()
  rescan_all_depots()
end

local reset_all_depots_command = function()
  local profiler = helpers.create_profiler()
  reset_all_depots()
  game.print{"", "Mining drones: Rescanned mining targets. ", profiler}
end

local on_object_destroyed = function(event)
  if event.type ~= defines.target_type.entity then return end

  --Resources are keyed by their registration number, they have no unit number.
  script_data.targeted_resources[event.registration_number] = nil

  local unit_number = event.useful_id
  if not unit_number or unit_number == 0 then return end

  local bucket = script_data.depots[unit_number % depot_update_rate]
  if not bucket then return end
  local depot = bucket[unit_number]
  if not depot then return end
  remove_depot(bucket, unit_number, depot)
end

local lib = {}

lib.events =
{
  [defines.events.on_built_entity] = on_built_entity,
  [defines.events.on_robot_built_entity] = on_built_entity,
  [defines.events.script_raised_revive] = on_built_entity,
  [defines.events.script_raised_built] = on_built_entity,
  [defines.events.on_space_platform_built_entity] = on_built_entity,
  [defines.events.on_entity_cloned] = on_entity_cloned,

  [defines.events.on_player_rotated_entity] = on_entity_rotated,
  [defines.events.on_player_flipped_entity] = on_entity_rotated,

  [defines.events.on_script_path_request_finished] = on_script_path_request_finished,

  [defines.events.on_player_mined_entity] = on_entity_removed,
  [defines.events.on_robot_mined_entity] = on_entity_removed,
  [defines.events.on_space_platform_mined_entity] = on_entity_removed,

  [defines.events.on_entity_died] = on_entity_removed,
  [defines.events.script_raised_destroy] = on_entity_removed,
  [defines.events.on_object_destroyed] = on_object_destroyed,

  [defines.events.on_tick] = on_tick

}

lib.on_init = function()
  storage.mining_depot = storage.mining_depot or script_data
end

lib.on_load = function()
  script_data = storage.mining_depot or script_data
end

local migrate_targeted_resources = function()

  --Used to be keyed by surface index first, which meant nothing ever cleaned them up when the
  --resource was mined out. They are now flat, keyed by registration number (unique globally),
  --and removed by on_object_destroyed.
  local targeted_resources = script_data.targeted_resources
  local flat = {}
  local migrated = false

  for key, value in pairs (targeted_resources) do
    if value.entity then
      flat[key] = value
    else
      migrated = true
      for index, target_data in pairs (value) do
        flat[index] = target_data
      end
    end
  end

  if not migrated then return end

  script_data.targeted_resources = flat

end

lib.on_configuration_changed = function()

  migrate_targeted_resources()

  for index, target_data in pairs (script_data.targeted_resources) do
    if not target_data.entity.valid then
      script_data.targeted_resources[index] = nil
    end
  end

  for k, bucket in pairs (script_data.depots) do
    --Idk, things can happen, let the depots rescan if they want.
    for unit_number, depot in pairs (bucket) do
      if depot.entity.valid then
        depot.status = nil
        depot:check_for_rescan()
      else
        remove_depot(bucket, unit_number, depot)
      end
    end
  end

end

lib.add_commands = function()
  commands.add_command("mining-depots-rescan", {"mining-depots-rescan-command"}, reset_all_depots_command)
end

lib.reset_all_depots = reset_all_depots

lib.get_depot_count = function()
  local count = 0
  for k, bucket in pairs (script_data.depots) do
    count = count + table_size(bucket)
  end
  return count
end

lib.get_targeted_resource_count = function()
  return table_size(script_data.targeted_resources)
end

return lib
