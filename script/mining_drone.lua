local proxy_inventory = function()
  local chest = game.surfaces[1].create_entity{name = shared.proxy_chest_name, position = {1000000, 1000000}, force = "neutral"}
  return chest.get_output_inventory()
end

local taken = {}

local unique_index = function(entity)
  local index = entity.unit_number or entity.surface.index..math.floor(entity.position.x).."-"..math.floor(entity.position.y)
  return index
end

local mining_speed = 0.55
local interval = shared.mining_interval
local damage = shared.mining_damage
local ceil = math.ceil
local max = math.max
local min = math.min

local attack_proxy = function(entity)

  local size = min(ceil((max(entity.get_radius() - 0.1, 0.25)) * 2), 10)

  --Health is set so it will take just enough damage at exactly the right time

  local mining_time = entity.prototype.mineable_properties.mining_time

  local number_of_ticks = (mining_time / mining_speed) * 60
  local number_of_hits = math.ceil(number_of_ticks / interval)

  local proxy = entity.surface.create_entity{name = shared.attack_proxy_name..size, position = entity.position, force = "neutral"}
  proxy.health = number_of_hits * damage
  return proxy
end

local states =
{
  mining_entity = 1,
  drop_at_depot = 2
}

local product_amount = util.product_amount

local mining_drone = {}

mining_drone.metatable = {__index = mining_drone}

mining_drone.new = function(entity)
  if entity.name ~= shared.drone_name then error("what are you playing at") end
  local new_drone = {}
  new_drone.entity = entity
  entity.ai_settings.path_resolution_modifier = 0
  new_drone.inventory = proxy_inventory()


  rendering.draw_light
  {
    sprite = "mining-drone-light",
    oriented = true,
    target = entity,
    target_offset = {0, 0},
    surface = entity.surface,
    minimum_darkness = 0.3,
    intensity = 0.6,
    scale = 2
  }

  rendering.draw_light
  {
    sprite = "utility/light_medium",
    oriented = false,
    target = entity,
    target_offset = {0, 0},
    surface = entity.surface,
    minimum_darkness = 0.3,
    intensity = 0.4,
    scale = 2.5,
  }


  setmetatable(new_drone, mining_drone.metatable)
  return new_drone
end

function mining_drone:process_mining()

  local target = self.mining_target
  if not (target and target.valid) then
    --cancel command or something.
    return self.depot:order_drone(self)
  end

  local mineable_properties = target.prototype.mineable_properties

  for k, product in pairs (mineable_properties.products) do
    local amount = self.inventory.insert({name = product.name, count = product_amount(product)})
  end

  self:update_sticker()

  if target.type == "resource" and target.amount > 1 then
    target.amount = target.amount - 1
  else
    target.destroy()
  end
  
  self.mining_count = self.mining_count - 1

  if not target.valid or self.mining_count <= 0 then
    self.state = states.drop_at_depot
    self:go_to_position(self.depot:get_spawn_position(), 1)
    return
  end
  
  return self:mine_entity(target, self.mining_count)


end

function mining_drone:has_desired_count()
  local contents = self.inventory.get_contents()
  local have = contents[self.desired_item] or 0
  return have >= self.desired_count
end

function mining_drone:request_order()
  local depot = self.depot
  depot:order_drone(self)
end

function mining_drone:process_drop_at_depot()
  local depot = self.depot
  if not (depot and depot.entity.valid) then return end
  local inventory = self.inventory
  local destination_inventory
  if depot.entity.type == "assembling-machine" then
    destination_inventory = depot.entity.get_output_inventory()
  end
  for k = 1, #inventory do
    local stack = inventory[k]
    if (stack and stack.valid and stack.valid_for_read) then
      depot.estimated_count = depot.estimated_count - destination_inventory.insert(stack)
      stack.clear()
    else
      break
    end
  end
  self:update_sticker()
  self:request_order()
end

function mining_drone:update(event)
  if event.result ~= defines.behavior_result.success then
    --self:say("FAIL BLOG.ORG")
    self.entity.set_command
    {
      type = defines.command.stop,
      ticks_to_wait = math.random(200, 400)
    }
    return
  end
  if self.state == states.mining_entity then
    self:process_mining()
    return
  end

  if self.state == states.drop_at_depot then
    self:process_drop_at_depot()
    return
  end
end

function mining_drone:say(text)
  self.entity.surface.create_entity{name = "flying-text", position = self.entity.position, text = text}
end

function mining_drone:mine_entity(entity, count)
  self.mining_count = count or 1
  self.mining_target = entity
  self.state = states.mining_entity
  local attack_proxy = attack_proxy(entity)
  local command = {}

  self.entity.set_command
  {
    type = defines.command.attack,
    target = attack_proxy,
    distraction = defines.distraction.by_damage
  }
end

function mining_drone:set_desired_item(item)
  if not game.item_prototypes[item] then error("What you playing at? "..item) end
  self.desired_item = item
end

function mining_drone:find_desired_item()
  local potential = {}
  for k, entity in pairs (self.entity.surface.find_entities_filtered{position = self.entity.position, radius = 32}) do
    if not taken[unique_index(entity)] then
      local properties = entity.prototype.mineable_properties
      if properties.minable and properties.products then
        for k, product in pairs (properties.products) do
          if product.name == self.desired_item then
            table.insert(potential, entity)
            break
          end
        end
      end
    end
  end
  if not next(potential) then return end
  local closest = self.entity.surface.get_closest(self.entity.position, potential)
  assert(taken[unique_index(closest)] == nil, "wtf pal")
  taken[unique_index(closest)] = true
  return closest
end

function mining_drone:set_depot(depot_data)
  self.depot = depot_data
end

function mining_drone:set_desired_amount(count)
  self.desired_count = count
end

function mining_drone:go_to_position(position, radius)
  self.entity.set_command
  {
    type = defines.command.go_to_location,
    destination = position,
    radius = radius or 1
  }
end

function mining_drone:go_to_entity(entity, radius)
  self.entity.set_command
  {
    type = defines.command.go_to_location,
    destination_entity = entity,
    radius = radius or 5
  }
end

local insert = table.insert

function mining_drone:update_sticker()

  local renderings = self.renderings
  if renderings then
    for k, v in pairs (renderings) do
      rendering.destroy(v)
    end
    self  .renderings = nil
  end

  local inventory = self.inventory

  local contents = inventory.get_contents()

  if not next(contents) then return end

  local number = table_size(contents)

  local drone = self.entity
  local surface = drone.surface
  local forces = {drone.force}

  local renderings = {}
  self.renderings = renderings

  insert(renderings, rendering.draw_sprite
  {
    sprite = "utility/entity_info_dark_background",
    target = drone,
    surface = surface,
    forces = forces,
    only_in_alt_mode = true,
    target_offset = {0, -0.5},
    x_scale = 0.5,
    y_scale = 0.5,
  })

  if number == 1 then
    insert(renderings, rendering.draw_sprite
    {
      sprite = "item/"..next(contents),
      target = drone,
      surface = surface,
      forces = forces,
      only_in_alt_mode = true,
      target_offset = {0, -0.5},
      x_scale = 0.5,
      y_scale = 0.5,
    })
    return
  end

  local offset_index = 1

  for name, count in pairs (contents) do
    local offset = offsets[offset_index]
    insert(renderings, rendering.draw_sprite
    {
      sprite = "item/"..name,
      target = drone,
      surface = surface,
      forces = forces,
      only_in_alt_mode = true,
      target_offset = {-0.125 + offset[1], -0.5 + offset[2]},
      x_scale = 0.25,
      y_scale = 0.25,
    })
    offset_index = offset_index + 1
  end


end

return mining_drone