-- Dev-only smoke test: builds a private surface with six mining depots on it (one per facing,
-- one on a fluid gated resource, one that gets its recipe swapped around), then checks over time
-- that drones deploy, ore actually arrives, and that everything cleans itself up again without
-- leaking entities, script inventories or resource registrations.
--
-- Not wired into the mod by default - it builds entities on a running save, so it must only run
-- against a disposable test map. To use it: uncomment the `handler.add_lib` for this file in
-- control.lua, then run
--   factorio.exe --create test.zip
--   factorio.exe --benchmark test.zip --benchmark-ticks 37000
-- and check the log for "SELF_TEST_RESULT". Re-comment it out again afterwards.
--
-- Because it lives inside the mod it shares the mod's Lua state, so it can poke at storage and
-- call the on_configuration_changed handlers directly to exercise the migration path.
local self_test = {}

local mining_depot = require("script/mining_depot")
local mining_drone = require("script/mining_drone")
local mining_technologies = require("script/mining_technologies")

local surface_name = "mining-drones-self-test"
local depot_name = shared.mining_depot
local drone_item = shared.drone_name

local checks = 0
local failures = 0

local report = function(text)
  log("SELF_TEST: "..text)
end

local check = function(condition, description)
  checks = checks + 1
  if condition then
    report("  pass  "..description)
  else
    failures = failures + 1
    report("  FAIL  "..description)
  end
  return condition
end

local check_equal = function(actual, expected, description)
  return check(actual == expected, description.." (expected "..tostring(expected)..", got "..tostring(actual)..")")
end

local check_close = function(actual, expected, description)
  return check(type(actual) == "number" and math.abs(actual - expected) < 0.0001,
               description.." (expected "..tostring(expected)..", got "..tostring(actual)..")")
end

---------------------------------------------------------------------------------------------------
-- World setup
---------------------------------------------------------------------------------------------------

-- A depot mines out of its open side, so a north facing depot mines everything above itself.
local facing =
{
  [defines.direction.north] = {0, -1},
  [defines.direction.south] = {0, 1},
  [defines.direction.east] = {1, 0},
  [defines.direction.west] = {-1, 0}
}

-- Every depot gets its own well separated plot, so no two of them ever compete for the same ore.
local plots =
{
  main = {position = {x = 0, y = 0}, direction = defines.direction.north, resource = "iron-ore"},
  fluid = {position = {x = 100, y = 0}, direction = defines.direction.north, resource = "uranium-ore"},
  north = {position = {x = -100, y = 0}, direction = defines.direction.north, resource = "copper-ore"},
  south = {position = {x = -100, y = 100}, direction = defines.direction.south, resource = "copper-ore"},
  east = {position = {x = 0, y = 100}, direction = defines.direction.east, resource = "copper-ore"},
  west = {position = {x = 100, y = 100}, direction = defines.direction.west, resource = "copper-ore"},
  --Built with neither a recipe nor any drones in it, so the status transitions can be watched
  --all the way from "nothing to do" to "working" and back again.
  idle = {position = {x = 0, y = -100}, direction = defines.direction.north, resource = "stone", deferred = true}
}

local refs
local setup_ok = false

--The depots live in buckets keyed by update slot, which is an implementation detail, so they are
--looked up by scanning rather than by recomputing the bucket the mod would have used.
local depot_object = function(entity)
  for k, bucket in pairs (storage.mining_depot.depots) do
    local depot = bucket[entity.unit_number]
    if depot then return depot end
  end
end

local flatten = function(surface, position)
  local tiles = {}
  for x = -20, 20 do
    for y = -20, 20 do
      tiles[#tiles + 1] = {name = "grass-1", position = {position.x + x, position.y + y}}
    end
  end
  surface.set_tiles(tiles)
end

local make_surface = function()

  local surface = game.create_surface(surface_name,
  {
    default_enable_all_autoplace_controls = false,
    autoplace_settings =
    {
      tile = {treat_missing_as_default = false, settings = {["grass-1"] = {}}},
      decorative = {treat_missing_as_default = false, settings = {}},
      entity = {treat_missing_as_default = false, settings = {}}
    },
    property_expression_names = {elevation = "100"}
  })

  surface.always_day = true

  for name, plot in pairs (plots) do
    surface.request_to_generate_chunks(plot.position, 2)
  end
  surface.force_generate_chunk_requests()

  for name, plot in pairs (plots) do
    flatten(surface, plot.position)
  end

  return surface

end

local place_resource_field = function(surface, plot)
  local offset = facing[plot.direction]
  local origin = plot.position
  local created = 0
  for across = -4, 4 do
    for along = 6, 14 do
      local x, y
      if offset[1] == 0 then
        x, y = origin.x + across, origin.y + (offset[2] * along)
      else
        x, y = origin.x + (offset[1] * along), origin.y + across
      end
      if surface.create_entity{name = plot.resource, position = {x, y}, amount = 5000} then
        created = created + 1
      end
    end
  end
  return created
end

local build_depot = function(surface, plot, force)
  local depot = surface.create_entity
  {
    name = depot_name,
    position = plot.position,
    direction = plot.direction,
    force = force,
    raise_built = true
  }
  if not (depot and depot.valid) then error("failed to build a depot at "..plot.position.x..","..plot.position.y) end
  if not plot.deferred then
    depot.set_recipe("mine-"..plot.resource)
    depot.insert{name = drone_item, count = 10}
  end
  return depot
end

local count_on_surface = function(name)
  return refs.surface.count_entities_filtered{name = name}
end

local script_inventory_count = function()
  local count = 0
  for mod_name, inventories in pairs (game.get_script_inventories("Mining_Drones")) do
    for k, inventory in pairs (inventories) do
      count = count + 1
    end
  end
  return count
end

local produced = function(key)
  local depot = refs.depots[key]
  return depot.get_output_inventory().get_item_count(plots[key].resource)
end

local diode = function(key)
  return refs.depots[key].custom_status.diode
end

---------------------------------------------------------------------------------------------------
-- Phases
---------------------------------------------------------------------------------------------------

-- Everything the mod generates for a resource has to be generated for every resource, or a
-- depot set to that recipe crashes the moment it tries to build a proxy, drone or pot animation.
-- Run against a modded install this covers the mod set that is actually loaded.
local check_generated_prototypes = function()

  check(prototypes.recipe["mine-iron-ore"] ~= nil, "iron ore mining recipe was generated")
  check(prototypes.recipe["mine-uranium-ore"] ~= nil, "uranium ore mining recipe was generated")
  check(prototypes.entity[shared.attack_proxy_name.."iron-ore"] ~= nil, "per resource attack proxy was generated")

  local has_fluid = false
  for k, ingredient in pairs (prototypes.recipe["mine-uranium-ore"].ingredients) do
    if ingredient.type == "fluid" then has_fluid = true end
  end
  check(has_fluid, "uranium ore recipe requires a fluid ingredient")

  local depot_categories = prototypes.entity[depot_name].crafting_categories

  local recipes = 0
  local missing_recipe, missing_proxy, missing_drone = 0, 0, 0
  local unmineable_recipe, wrong_category, non_item_product = 0, 0, 0

  for name, resource in pairs (prototypes.get_entity_filtered{{filter = "type", type = "resource"}}) do

    local products = resource.mineable_properties.products
    local mines_an_item = false
    for k, product in pairs (products or {}) do
      if product.type == "item" then mines_an_item = true end
    end

    local recipe = prototypes.recipe["mine-"..name]

    if mines_an_item and not recipe then
      missing_recipe = missing_recipe + 1
    end

    -- A resource that only yields fluid, crude oil being the obvious one, can't be put in the
    -- depot's output inventory and must not generate anything at all.
    if recipe and not mines_an_item then
      unmineable_recipe = unmineable_recipe + 1
    end

    if recipe then
      recipes = recipes + 1

      local craftable = false
      for k, category in pairs (recipe.categories) do
        if depot_categories[category] then craftable = true end
      end
      if not craftable then wrong_category = wrong_category + 1 end

      for k, product in pairs (recipe.products) do
        if product.type ~= "item" then non_item_product = non_item_product + 1 end
      end

      if not prototypes.entity[shared.attack_proxy_name..name] then
        missing_proxy = missing_proxy + 1
      end

      for k = 1, shared.variation_count do
        if not prototypes.entity[name..drone_item..k] then
          missing_drone = missing_drone + 1
        end
      end
    end
  end

  check(recipes > 0, "mining recipes were generated ("..recipes..")")
  check_equal(missing_recipe, 0, "every resource that mines into an item got a mining recipe")
  check_equal(unmineable_recipe, 0, "resources that only yield fluid got no mining recipe")
  check_equal(non_item_product, 0, "no mining recipe produces something the depot can't store")
  check_equal(wrong_category, 0, "every mining recipe is in a category the depot can craft")
  check_equal(missing_proxy, 0, "every mining recipe has its attack proxy")
  check_equal(missing_drone, 0, "every mining recipe has all of its drone variations")

  -- Drones must not share an ammo category with anything the player can research, or damage
  -- upgrades would silently change how fast they mine.
  local categories = prototypes.entity["iron-ore"..drone_item.."1"].attack_parameters.ammo_categories
  check_equal(#categories, 1, "drones have exactly one ammo category")
  check_equal(categories[1], shared.ammo_category, "drones use their own ammo category")

end

local setup = function()

  check(remote.interfaces["mining_drones"] ~= nil, "remote interface is registered")
  check(commands.commands["mining-depots-rescan"] ~= nil, "rescan command is registered")

  check_generated_prototypes()

  local surface = make_surface()
  local force = game.forces.player

  local depots = {}
  local depot_count = 0
  for name, plot in pairs (plots) do
    check(place_resource_field(surface, plot) > 50, "placed the "..name.." "..plot.resource.." field")
    depots[name] = build_depot(surface, plot, force)
    depot_count = depot_count + 1
  end

  refs = {surface = surface, force = force, depots = depots, depot_count = depot_count}

  check_equal(mining_depot.get_depot_count(), depot_count, "every depot was registered")
  check_equal(count_on_surface("mining-depot-collision-box"), depot_count * 3, "every depot walled off its bay")
  check_equal(count_on_surface("caution-corpse"), depot_count * 2, "every depot placed its drop and spawn markers")

  report("setup complete")
end

local check_deployment = function()
  -- Highlight boxes delete themselves on their first update unless they are disabled.
  check_equal(count_on_surface("mining-depot-collision-box"), refs.depot_count * 3, "collision walls survived their first update")
  check(mining_drone.get_drone_count() > 0, "drones were deployed ("..mining_drone.get_drone_count()..")")
  check(mining_drone.get_drone_count() <= 60, "no more drones than the depots hold")
  check(mining_depot.get_targeted_resource_count() > 0, "resources are tracked as mining targets")
  check_equal(diode("main"), defines.entity_status_diode.green, "a working depot reports a green status")
end

---------------------------------------------------------------------------------------------------
-- The idle depot walks through every status the depot can report.
---------------------------------------------------------------------------------------------------

local check_idle_has_no_recipe = function()
  check_equal(diode("idle"), defines.entity_status_diode.red, "a depot without a recipe reports a red status")
  check_equal(produced("idle"), 0, "a depot without a recipe mined nothing")
  refs.depots.idle.set_recipe("mine-"..plots.idle.resource)
end

local check_idle_has_no_drones = function()
  check_equal(diode("idle"), defines.entity_status_diode.yellow, "a depot with a recipe but no drones reports a warning")
  check_equal(produced("idle"), 0, "a depot with no drones mined nothing")
  refs.depots.idle.insert{name = drone_item, count = 10}
end

local check_idle_is_working = function()
  check_equal(diode("idle"), defines.entity_status_diode.green, "the depot starts working once it has drones")
end

-- Taking the drone items away while drones are still out in the field must not confuse the
-- depot's accounting, and it must stop sending new ones.
local drain_idle_drones = function()
  local produced_so_far = produced("idle")
  check(produced_so_far > 0, "the idle depot delivered stone once it had drones ("..produced_so_far..")")
  refs.idle_active = table_size(depot_object(refs.depots.idle).drones)

  local removed = refs.depots.idle.get_inventory(defines.inventory.crafter_input).remove{name = drone_item, count = 100}
  check(removed > 0, "the drone items were taken back out of the depot ("..removed..")")
end

local check_idle_drained = function()
  check_equal(diode("idle"), defines.entity_status_diode.yellow, "the depot warns again once its drones are gone")
  check_equal(refs.depots.idle.get_item_count(drone_item), 0, "no drone items came back from nowhere")
  check(table_size(depot_object(refs.depots.idle).drones) <= refs.idle_active,
        "no new drones were sent out once the drone items were gone")
end

local check_technologies = function()
  local force = refs.force
  local index = force.index

  check_equal(mining_technologies.get_productivity_bonus(index), 0, "no productivity bonus before research")
  check_equal(mining_technologies.get_cargo_size_bonus(index), 0, "no cargo bonus before research")

  for k = 1, shared.technology_levels do
    force.technologies[shared.mining_productivity_technology.."-"..k].researched = true
    force.technologies[shared.mining_speed_technology.."-"..k].researched = true
  end

  check_close(mining_technologies.get_productivity_bonus(index), 0.5, "productivity bonus after five levels")
  check_equal(mining_technologies.get_cargo_size_bonus(index), 5, "cargo bonus after five levels")
  check_close(mining_technologies.get_mining_speed_bonus(index), 1.0, "mining speed bonus after five levels")
  check_close(mining_technologies.get_walking_speed_bonus(index), 1.0, "walking speed bonus after five levels")

  -- The level after the finite ones is the infinite continuation.
  local infinite = force.technologies[shared.mining_productivity_technology.."-"..(shared.technology_levels + 1)]
  infinite.level = infinite.level + 1
  check_close(mining_technologies.get_productivity_bonus(index), 0.6, "an infinite level adds a further 0.1 productivity")

  force.reset_technology_effects()
  check_close(mining_technologies.get_productivity_bonus(index), 0.6, "bonuses survive a technology effects reset")

  force.technologies[shared.mining_productivity_technology.."-3"].researched = false
  check_close(mining_technologies.get_productivity_bonus(index), 0.2, "un-researching a level lowers the bonus")

  for k = 1, shared.technology_levels do
    force.technologies[shared.mining_productivity_technology.."-"..k].researched = true
  end
  check_close(mining_technologies.get_productivity_bonus(index), 0.6, "the bonus is restored")
end

local check_first_production = function()

  refs.iron_produced = produced("main")
  check(refs.iron_produced > 0, "iron ore was delivered ("..refs.iron_produced..")")
  check_equal(refs.depots.main.get_item_count(drone_item), 10, "no drone items were lost while mining")

  for name, plot in pairs (plots) do
    if name ~= "main" and name ~= "fluid" and not plot.deferred then
      check(produced(name) > 0, "the depot facing "..name.." delivered copper ore ("..produced(name)..")")
    end
  end

  -- The fluid gated depot must not have mined a single thing without its acid.
  check_equal(produced("fluid"), 0, "no uranium was mined while the required fluid was missing")
  check_equal(diode("fluid"), defines.entity_status_diode.yellow, "the fluid depot reports a warning status")

  -- Researching has to come first: resetting technology effects re-evaluates recipes, which
  -- empties the fluid box of a machine whose fluid boxes depend on its recipe.
  check_technologies()

  refs.acid = refs.depots.fluid.insert_fluid{name = "sulfuric-acid", amount = 2000}
  check(refs.acid > 0, "sulfuric acid was inserted ("..refs.acid..")")
end

local check_fluid_production = function()
  local depot = refs.depots.fluid
  local mined = produced("fluid")
  check(mined > 0, "uranium ore is mined once fluid is available ("..mined..")")
  check(depot.get_fluid_count("sulfuric-acid") < refs.acid, "sulfuric acid was consumed")
  -- One acid pays for one ore, and productivity can at most double what that ore turns into,
  -- so anything past this means the fluid accounting is handing out free mining.
  check(mined <= refs.acid * 2, "no more ore was mined than the fluid could pay for")
  check(produced("main") > refs.iron_produced, "the iron depot kept producing after the research")
end

-- The engine only lets a crafting machine with this shape turn around while its fluid box is in
-- use, so the uranium depot is the only one that can actually be rotated in game.
local rotate_depot = function()
  local depot = refs.depots.fluid
  refs.uranium_before_rotation = produced("fluid")
  depot.direction = defines.direction.south
  check_equal(depot.direction, defines.direction.south, "the depot turned around")
end

local check_rotation = function()
  local depot = refs.depots.fluid
  check_equal(count_on_surface("mining-depot-collision-box"), refs.depot_count * 3, "rotation rebuilt the walls without leaking any")
  check_equal(count_on_surface("caution-corpse"), refs.depot_count * 2, "rotation rebuilt the drop marker without leaking any")
  check_equal(diode("fluid"), defines.entity_status_diode.red, "the rotated depot noticed its new area is empty")

  depot.direction = defines.direction.north
  -- Turning a machine around empties its fluid box, so it needs topping up again.
  refs.acid = depot.insert_fluid{name = "sulfuric-acid", amount = 2000}
end

local check_rotated_back = function()
  check(produced("fluid") > refs.uranium_before_rotation,
        "the depot mines again after being rotated back ("..produced("fluid")..", was "..refs.uranium_before_rotation..")")
end

local change_recipe = function()
  -- The main plot only holds iron ore, so asking for copper leaves that depot with nothing to do.
  refs.depots.main.set_recipe("mine-copper-ore")
end

-- Fold the tracking table back into the shape it had before this version and run the mod's own
-- configuration changed handlers over it, the way loading an older save does.
local check_migration = function()

  check_equal(diode("main"), defines.entity_status_diode.red, "the depot reports no targets for the new resource")
  refs.depots.main.set_recipe("mine-iron-ore")

  local script_data = storage.mining_depot
  local tracked = 0
  local by_surface = {}
  for index, target_data in pairs (script_data.targeted_resources) do
    if target_data.entity.valid then
      tracked = tracked + 1
      local surface_index = target_data.entity.surface.index
      by_surface[surface_index] = by_surface[surface_index] or {}
      by_surface[surface_index][index] = target_data
    end
  end
  script_data.targeted_resources = by_surface
  check(tracked > 0, "there are tracked resources to migrate ("..tracked..")")

  -- The technology bonuses used to live in storage too.
  storage.mining_technologies = {walking_speed = {}, mining_speed = {}, cargo_size = {}, productivity_bonus = {}}

  -- A mod update can change what a recipe needs without renaming it, so the fluid requirement
  -- has to be worked out again rather than kept from when the recipe was first seen.
  local fluid_depot = depot_object(refs.depots.fluid)
  check(fluid_depot.fluid ~= nil, "the fluid depot knows it needs a fluid")
  fluid_depot.fluid = nil

  mining_depot.on_configuration_changed()
  mining_drone.on_configuration_changed()
  mining_technologies.on_configuration_changed()

  check(fluid_depot.fluid ~= nil and fluid_depot.fluid.name == "sulfuric-acid",
        "the fluid requirement was worked out again on a configuration change")
  check_equal(table_size(script_data.targeted_resources), tracked, "the tracking table was flattened without losing entries")
  local flat = true
  for index, target_data in pairs (script_data.targeted_resources) do
    if not target_data.entity then flat = false end
  end
  check(flat, "every migrated entry is a target rather than a surface bucket")
  check_equal(storage.mining_technologies, nil, "the stale technology storage was dropped")
  check_close(mining_technologies.get_productivity_bonus(refs.force.index), 0.6, "bonuses are still correct after migration")
end

local check_after_migration = function()
  check(produced("main") > refs.iron_produced, "the depot mines again after the migration ("..produced("main")..")")
  refs.iron_produced = produced("main")
end

local reset_depots = function()
  check(mining_drone.get_drone_count() > 0, "drones were active before the reset")
  mining_depot.reset_all_depots()
  check_equal(mining_drone.get_drone_count(), 0, "the reset cancelled every active drone")
end

local check_recovered = function()
  check(mining_drone.get_drone_count() > 0, "drones are deployed again after the reset")
end

-- A depot can end up on a different force than the one it was built on, so it must never keep
-- using the force it happened to be created with.
local change_force = function()

  local entity = refs.depots.north
  local depot = depot_object(entity)

  if not check(depot ~= nil, "the north depot is registered") then return end

  -- Nothing is taking the ore away, so by now every depot has filled its output past a full
  -- load and throttled itself back rather than piling up more.
  check(depot:get_max_output_amount() >= depot:get_target_item_count(), "the depot filled its output")
  check_equal(depot:get_should_spawn_drone_count(), 0, "a full depot stops sending drones out")

  local force = game.create_force("mining-drones-self-test")
  refs.new_force = force
  entity.force = force

  check_equal(depot:get_force_index(), force.index, "the depot reads its force back off the entity")
  check_equal(mining_technologies.get_cargo_size_bonus(force.index), 0, "the new force has no mining research")

  -- The player force is at 0.6 productivity by now, the new force at nothing, so the depot's
  -- idea of a full load has to drop back to the unresearched amount.
  check_equal(depot:get_target_item_count(), 100 * depot:get_drone_item_count(),
              "the depot sizes its load from the force it is on now")

  entity.get_output_inventory().clear()
  check(depot:get_should_spawn_drone_count() > 0, "emptying the output puts the depot back to work")
  refs.copper_before_force_change = produced("north")
end

local check_force_change = function()
  check(produced("north") > refs.copper_before_force_change,
        "the depot keeps mining after being moved to another force ("..produced("north")..")")
end

-- Only one path request is ever in flight, and the engine drops script path requests without an
-- answer when their surface goes away, so an unanswered one must not stall the mod forever.
local stall_path_requests = function()
  local script_data = storage.mining_depot
  refs.stalled_id = -1
  refs.depots.south.get_output_inventory().clear()
  refs.copper_before_stall = produced("south")
  script_data.path_requests[refs.stalled_id] = depot_object(refs.depots.south)
  script_data.last_path_request_tick = game.tick - (60 * 30) - 1
  check(script_data.path_requests[refs.stalled_id] ~= nil, "a path request that will never be answered is outstanding")
end

local check_path_requests_recovered = function()
  local script_data = storage.mining_depot
  check_equal(script_data.path_requests[refs.stalled_id], nil, "the unanswered path request was given up on")
  check(produced("south") > refs.copper_before_stall,
        "depots kept mining through an unanswered path request ("..produced("south")..")")
end

-- Entities can be removed by a script without raising anything, in which case on_object_destroyed
-- is the only notice the mod gets.
local silent_destroy = function()

  local victim
  for unit_number, drone in pairs (storage.mining_drone.drones) do
    if drone.entity.valid then
      victim = drone
      break
    end
  end

  if check(victim ~= nil, "there is a drone out in the field to destroy") then
    refs.destroyed_drone = victim.unit_number
    victim.entity.destroy()
  end

  refs.destroyed_depot = refs.depots.idle.unit_number
  refs.depots.idle.destroy()
  refs.depots.idle = nil
  refs.depot_count = refs.depot_count - 1
end

-- on_object_destroyed is raised at the end of the tick, so the clean up can only be checked
-- from a later one. Both are looked up by unit number, because the rest of the depots carry on
-- spawning and retiring drones in the meantime.
local check_silent_destroy = function()
  check_equal(storage.mining_drone.drones[refs.destroyed_drone], nil, "a silently destroyed drone unregisters itself")
  check_equal(depot_object{unit_number = refs.destroyed_depot}, nil, "a silently destroyed depot unregisters itself")
  check_equal(count_on_surface("mining-depot-collision-box"), refs.depot_count * 3, "its collision walls went with it")
  check_equal(count_on_surface("caution-corpse"), refs.depot_count * 2, "its markers went with it")
end

local tear_down = function()
  for name, depot in pairs (refs.depots) do
    depot.destroy{raise_destroy = true}
  end

  check_equal(mining_depot.get_depot_count(), 0, "no depots are registered after removal")
  check_equal(count_on_surface("mining-depot-collision-box"), 0, "collision walls were removed")
  check_equal(count_on_surface("caution-corpse"), 0, "drop and spawn markers were removed")
  check_equal(mining_drone.get_drone_count(), 0, "no drones are left registered")
end

local check_no_orphans = function()
  check_equal(refs.surface.count_entities_filtered{type = "unit"}, 0, "no drone or proxy units are left on the surface")

  local inventories = script_inventory_count()
  local pooled = mining_drone.get_pooled_inventory_count()
  check_equal(inventories, pooled, "every script inventory is accounted for in the pool ("..inventories..")")
  check(pooled <= 50, "the inventory pool is capped ("..pooled..")")

  check(mining_depot.get_targeted_resource_count() > 0, "resources are still tracked before they are mined out")
  for k, entity in pairs (refs.surface.find_entities_filtered{type = "resource"}) do
    entity.destroy()
  end
end

local check_registrations_released = function()
  check_equal(mining_depot.get_targeted_resource_count(), 0, "no resources are still tracked as mining targets")
end

---------------------------------------------------------------------------------------------------
-- Runner
---------------------------------------------------------------------------------------------------

local phases =
{
  {tick =    60, name = "setup",              run = setup},
  {tick =  1800, name = "deployment",         run = check_deployment},
  {tick =  2400, name = "idle no recipe",     run = check_idle_has_no_recipe},
  {tick =  3000, name = "idle no drones",     run = check_idle_has_no_drones},
  {tick =  4200, name = "idle working",       run = check_idle_is_working},
  {tick =  5400, name = "first production",   run = check_first_production},
  {tick =  7200, name = "drain idle",         run = drain_idle_drones},
  {tick =  7800, name = "idle drained",       run = check_idle_drained},
  {tick = 11400, name = "fluid production",   run = check_fluid_production},
  {tick = 12000, name = "rotate",             run = rotate_depot},
  {tick = 12600, name = "rotation",           run = check_rotation},
  {tick = 18600, name = "rotated back",       run = check_rotated_back},
  {tick = 19200, name = "change recipe",      run = change_recipe},
  {tick = 19800, name = "migration",          run = check_migration},
  {tick = 23400, name = "after migration",    run = check_after_migration},
  {tick = 24000, name = "reset",              run = reset_depots},
  {tick = 27000, name = "recovered",          run = check_recovered},
  {tick = 27600, name = "change force",       run = change_force},
  {tick = 30600, name = "force changed",      run = check_force_change},
  {tick = 31200, name = "stall path request", run = stall_path_requests},
  {tick = 33600, name = "path recovered",     run = check_path_requests_recovered},
  {tick = 34200, name = "silent destroy",     run = silent_destroy},
  {tick = 34260, name = "silently destroyed", run = check_silent_destroy},
  {tick = 34800, name = "tear down",          run = tear_down},
  {tick = 35400, name = "no orphans",         run = check_no_orphans},
  {tick = 36000, name = "registrations",      run = check_registrations_released}
}

local final_tick = phases[#phases].tick + 60

local by_tick = {}
for k, phase in pairs (phases) do
  by_tick[phase.tick] = phase
end

local announce = function(text)
  log(text)
  game.print(text)
end

local tick_handler = function(event)

  local tick = event.tick

  if tick == phases[1].tick then
    local ok, err = xpcall(setup, debug.traceback)
    setup_ok = ok
    if not ok then
      announce("SELF_TEST_RESULT: SETUP_FAIL - "..tostring(err))
    end
    return
  end

  if not setup_ok then return end

  local phase = by_tick[tick]
  if phase then
    report("phase "..phase.name)
    local ok, err = xpcall(phase.run, debug.traceback)
    if not ok then
      checks = checks + 1
      failures = failures + 1
      report("  FAIL  phase '"..phase.name.."' raised: "..tostring(err))
    end
  end

  if tick == final_tick then
    announce(string.format("SELF_TEST_RESULT: %s - %d checks, %d failures",
                           failures == 0 and "PASS" or "FAIL", checks, failures))
  end

end

self_test.events =
{
  [defines.events.on_tick] = tick_handler
}

return self_test
