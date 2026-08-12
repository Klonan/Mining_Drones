--Self test for the Mining Drones mod.
--
--Run it with scripts/run-self-test.sh, which converts this scenario into a map (so on_init and a
--save/load round trip are exercised) and then benchmarks it headless for long enough to let the
--drones make a few full mining runs. Every check writes a line to the log and the run ends with a
--"SELFTEST | RESULT PASS" or "... FAIL" line.

local surface_name = "mining-drones-self-test"
local depot_name = "mining-depot"
local drone_item = "mining-drone"

local report = function(text)
  log("SELFTEST | "..text)
end

local state

local check = function(condition, description)
  state.checks = state.checks + 1
  if condition then
    report("  pass  "..description)
  else
    state.failures = state.failures + 1
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

local get_surface = function()
  return game.surfaces[surface_name]
end

local call = function(name, ...)
  return remote.call("mining_drones", name, ...)
end

---------------------------------------------------------------------------------------------------
-- World setup
---------------------------------------------------------------------------------------------------

--A depot mines out of its open side, so a north facing depot mines everything above itself.
local facing =
{
  [defines.direction.north] = {0, -1},
  [defines.direction.south] = {0, 1},
  [defines.direction.east] = {1, 0},
  [defines.direction.west] = {-1, 0}
}

--Every depot gets its own well separated plot so the tests never have two depots fighting over
--the same ore.
local plots =
{
  main = {position = {x = 0, y = 0}, direction = defines.direction.north},
  fluid = {position = {x = 100, y = 0}, direction = defines.direction.north},
  north = {position = {x = -100, y = 0}, direction = defines.direction.north},
  south = {position = {x = -100, y = 100}, direction = defines.direction.south},
  east = {position = {x = 0, y = 100}, direction = defines.direction.east},
  west = {position = {x = 100, y = 100}, direction = defines.direction.west}
}

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

local place_resource_field = function(surface, name, plot, amount)
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
      if surface.create_entity{name = name, position = {x, y}, amount = amount} then
        created = created + 1
      end
    end
  end
  return created
end

local build_depot = function(surface, plot)
  return surface.create_entity
  {
    name = depot_name,
    position = plot.position,
    direction = plot.direction,
    force = "player",
    raise_built = true
  }
end

local count_on_surface = function(surface, name)
  return surface.count_entities_filtered{name = name}
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

---------------------------------------------------------------------------------------------------
-- Steps
---------------------------------------------------------------------------------------------------

local steps =
{
  {
    name = "prototypes and interface",
    run = function()

      check(prototypes.entity[depot_name] ~= nil, "mining depot prototype exists")
      check(prototypes.item[drone_item] ~= nil, "mining drone item prototype exists")
      check(prototypes.recipe["mine-iron-ore"] ~= nil, "iron ore mining recipe was generated")
      check(prototypes.recipe["mine-uranium-ore"] ~= nil, "uranium ore mining recipe was generated")
      check(prototypes.entity["mining-drone-attack-proxy-newiron-ore"] ~= nil, "per resource attack proxy was generated")
      check(remote.interfaces["mining_drones"] ~= nil, "remote interface is registered")
      check(commands.commands["mining-depots-rescan"] ~= nil, "rescan command is registered")

      local has_fluid = false
      for k, ingredient in pairs (prototypes.recipe["mine-uranium-ore"].ingredients) do
        if ingredient.type == "fluid" then has_fluid = true end
      end
      check(has_fluid, "uranium ore recipe requires a fluid ingredient")

      --The drones must not share an ammo category with anything the player can research,
      --or damage upgrades would silently change mining speed.
      local drone = prototypes.entity["iron-ore"..drone_item.."1"]
      check(drone ~= nil, "a resource specific drone prototype was generated")
      if drone then
        local categories = drone.attack_parameters.ammo_categories
        check_equal(#categories, 1, "drones have exactly one ammo category")
        check_equal(categories[1], "mining-drone", "drones use their own ammo category")
      end

    end
  },

  {
    name = "test surface",
    run = function()
      local surface = make_surface()
      check(surface ~= nil and surface.valid, "test surface was created")
      check(surface.count_tiles_filtered{name = "grass-1", limit = 1} > 0, "test surface has walkable ground")

      local created = place_resource_field(surface, "iron-ore", plots.main, 5000)
      check(created > 50, "iron ore field was placed ("..created.." entities)")
    end
  },

  {
    name = "build depot",
    run = function()
      local surface = get_surface()
      local depot = build_depot(surface, plots.main)
      check(depot ~= nil and depot.valid, "depot entity was created")
      state.depot = depot

      check_equal(call("get_depot_count"), 1, "mod registered the depot")
      check(depot.custom_status ~= nil, "depot reports a custom status")
      check_equal(count_on_surface(surface, "mining-depot-collision-box"), 3, "three collision walls were built")
      check_equal(count_on_surface(surface, "caution-corpse"), 2, "drop and spawn markers were built")
    end
  },

  {
    name = "collision walls survive",
    ticks = 120,
    run = function()
      --Highlight boxes delete themselves on their first update unless they are disabled.
      check_equal(count_on_surface(get_surface(), "mining-depot-collision-box"), 3, "collision walls still exist after two seconds")
    end
  },

  {
    name = "set recipe and load drones",
    run = function()
      local depot = state.depot
      depot.set_recipe("mine-iron-ore")
      check_equal(depot.insert{name = drone_item, count = 10}, 10, "ten drones were inserted into the depot")
      check_equal(depot.get_item_count(drone_item), 10, "depot reports its drone count")
    end
  },

  {
    name = "drones deploy",
    ticks = 900,
    run = function()
      check(state.peak_drone_count > 0, "drones were deployed ("..state.peak_drone_count.." at peak)")
      check(state.peak_drone_count <= 10, "never deployed more drones than the depot holds")
    end
  },

  {
    name = "ore is delivered",
    ticks = 3600,
    run = function()
      local produced = state.depot.get_output_inventory().get_item_count("iron-ore")
      check(produced > 0, "iron ore was delivered to the depot ("..produced..")")
      state.base_production = produced
      check_equal(state.depot.get_item_count(drone_item), 10, "no drone items were lost while mining")
      check(call("get_targeted_resource_count") > 0, "resources are tracked as mining targets")
      check(state.depot.custom_status.diode == defines.entity_status_diode.green, "depot status is green while working")
    end
  },

  {
    name = "technology bonuses",
    run = function()
      local force = game.forces.player
      local bonuses = call("get_bonuses", force.index)
      check_equal(bonuses.productivity, 0, "no productivity bonus before research")
      check_equal(bonuses.cargo_size, 0, "no cargo bonus before research")

      for k = 1, 5 do
        force.technologies["mining-drone-productivity-"..k].researched = true
        force.technologies["mining-drone-mining-speed-"..k].researched = true
      end

      bonuses = call("get_bonuses", force.index)
      check_close(bonuses.productivity, 0.5, "productivity bonus after five levels")
      check_equal(bonuses.cargo_size, 5, "cargo bonus after five levels")
      check_close(bonuses.mining_speed, 1.0, "mining speed bonus after five levels")
      check_close(bonuses.walking_speed, 1.0, "walking speed bonus after five levels")

      --The sixth technology in each chain is the infinite continuation.
      local infinite = force.technologies["mining-drone-productivity-6"]
      infinite.level = infinite.level + 1
      check_close(call("get_bonuses", force.index).productivity, 0.6, "an infinite level adds a further 0.1 productivity")

      force.reset_technology_effects()
      check_close(call("get_bonuses", force.index).productivity, 0.6, "bonuses survive a technology effects reset")

      force.technologies["mining-drone-productivity-3"].researched = false
      check_close(call("get_bonuses", force.index).productivity, 0.2, "un-researching a level lowers the bonus")

      for k = 1, 5 do
        force.technologies["mining-drone-productivity-"..k].researched = true
      end
      check_close(call("get_bonuses", force.index).productivity, 0.6, "bonus is restored")
    end
  },

  {
    name = "production continues with bonuses",
    ticks = 3600,
    run = function()
      local produced = state.depot.get_output_inventory().get_item_count("iron-ore")
      check(produced > state.base_production, "the depot kept producing after research ("..produced..")")
    end
  },

  {
    name = "fluid depot setup",
    run = function()
      local surface = get_surface()
      local created = place_resource_field(surface, "uranium-ore", plots.fluid, 5000)
      check(created > 50, "uranium ore field was placed ("..created.." entities)")

      local depot = build_depot(surface, plots.fluid)
      check(depot ~= nil and depot.valid, "fluid depot was created")
      depot.set_recipe("mine-uranium-ore")
      depot.insert{name = drone_item, count = 5}
      state.fluid_depot = depot
    end
  },

  {
    name = "nothing is mined without fluid",
    ticks = 900,
    run = function()
      local depot = state.fluid_depot
      check_equal(depot.get_output_inventory().get_item_count("uranium-ore"), 0, "no ore mined while the fluid is missing")
      check_equal(depot.custom_status.diode, defines.entity_status_diode.yellow, "depot reports a warning status")
      check(depot.insert_fluid{name = "sulfuric-acid", amount = 1000} > 0, "sulfuric acid was inserted")
    end
  },

  {
    name = "mining resumes with fluid",
    ticks = 4800,
    run = function()
      local depot = state.fluid_depot
      check(depot.get_output_inventory().get_item_count("uranium-ore") > 0, "uranium ore is mined once fluid is available")
      check(depot.get_fluid_count("sulfuric-acid") < 1000, "sulfuric acid was consumed")
      check(depot.get_fluid_count("sulfuric-acid") > 0, "sulfuric acid was not over consumed")
    end
  },

  {
    name = "all four directions",
    run = function()
      local surface = get_surface()
      state.direction_depots = {}
      for name, plot in pairs (plots) do
        if name ~= "main" and name ~= "fluid" then
          place_resource_field(surface, "copper-ore", plot, 5000)
          local depot = build_depot(surface, plot)
          depot.set_recipe("mine-copper-ore")
          depot.insert{name = drone_item, count = 5}
          state.direction_depots[name] = depot
        end
      end
      check_equal(call("get_depot_count"), 6, "all six depots are registered")
      check_equal(count_on_surface(surface, "mining-depot-collision-box"), 18, "every depot walled off its bay")
    end
  },

  {
    name = "every direction produces",
    ticks = 6000,
    run = function()
      for name, depot in pairs (state.direction_depots) do
        check(depot.get_output_inventory().get_item_count("copper-ore") > 0,
              "depot facing "..name.." delivered copper ore")
      end
    end
  },

  {
    name = "reset recalls every drone",
    run = function()
      state.drones_before_reset = call("get_drone_count")
      check(state.drones_before_reset > 0, "drones were active before the reset")
      call("reset_depots")
      check_equal(call("get_drone_count"), 0, "reset cancelled every active drone")
    end
  },

  {
    name = "recovers after reset",
    ticks = 3000,
    run = function()
      check(call("get_drone_count") > 0, "drones are deployed again after the reset")
    end
  },

  {
    name = "changing the recipe",
    run = function()
      --The main plot only has iron ore, so asking for copper leaves the depot with nothing to do.
      state.depot.set_recipe("mine-copper-ore")
    end
  },

  {
    name = "recipe change settled",
    ticks = 600,
    run = function()
      local surface = get_surface()
      check_equal(state.depot.get_recipe().name, "mine-copper-ore", "recipe change took effect")
      check_equal(count_on_surface(surface, "mining-depot-collision-box"), 18, "collision walls were not duplicated")
      check_equal(count_on_surface(surface, "caution-corpse"), 12, "markers were not duplicated")
      check_equal(state.depot.custom_status.diode, defines.entity_status_diode.red,
                  "depot reports that it has no targets for the new resource")
      state.depot.set_recipe("mine-iron-ore")
    end
  },

  {
    name = "rotating a depot",
    ticks = 600,
    run = function()
      check_equal(state.depot.custom_status.diode, defines.entity_status_diode.green, "depot went back to work on iron ore")

      --The engine only lets a crafting machine with this shape turn around while its fluid box
      --is in use, so the uranium depot is the one that can actually be rotated in game.
      local depot = state.fluid_depot
      state.production_before_rotation = depot.get_output_inventory().get_item_count("uranium-ore")

      depot.direction = defines.direction.south
      check_equal(depot.direction, defines.direction.south, "the depot turned around")
    end
  },

  {
    name = "rotation was picked up",
    ticks = 300,
    run = function()
      local surface = get_surface()
      local depot = state.fluid_depot

      check_equal(count_on_surface(surface, "mining-depot-collision-box"), 18, "rotation rebuilt the walls without leaking any")
      check_equal(count_on_surface(surface, "caution-corpse"), 12, "rotation rebuilt the drop marker without leaking any")
      check_equal(depot.custom_status.diode, defines.entity_status_diode.red, "rotated depot noticed its new area is empty")

      depot.direction = defines.direction.north
      --Turning a machine around empties its fluid box, so it needs topping up again.
      depot.insert_fluid{name = "sulfuric-acid", amount = 1000}
    end
  },

  {
    name = "rotated back and mining again",
    ticks = 4800,
    run = function()
      local depot = state.fluid_depot
      local produced = depot.get_output_inventory().get_item_count("uranium-ore")
      check(produced > state.production_before_rotation,
            "the depot mines again after being rotated back ("..produced..", was "..state.production_before_rotation..
            ", acid "..depot.get_fluid_count("sulfuric-acid")..", status "..tostring(depot.custom_status.diode)..")")
    end
  },

  {
    name = "removing depots cleans up",
    run = function()
      local surface = get_surface()

      state.depot.destroy{raise_destroy = true}
      state.fluid_depot.destroy{raise_destroy = true}
      for name, depot in pairs (state.direction_depots) do
        depot.destroy{raise_destroy = true}
      end

      check_equal(call("get_depot_count"), 0, "no depots are registered after removal")
      check_equal(count_on_surface(surface, "mining-depot-collision-box"), 0, "collision walls were removed")
      check_equal(count_on_surface(surface, "caution-corpse"), 0, "drop and spawn markers were removed")
      check_equal(call("get_drone_count"), 0, "no drones are left registered")
    end
  },

  {
    name = "no orphans left behind",
    ticks = 600,
    run = function()
      local surface = get_surface()
      check_equal(surface.count_entities_filtered{type = "unit"}, 0, "no drone or proxy units are left on the surface")

      local inventories = script_inventory_count()
      local pooled = call("get_pooled_inventory_count")
      check_equal(inventories, pooled, "every script inventory is accounted for in the pool")
      check(pooled <= 50, "the inventory pool is capped ("..pooled..")")
    end
  },

  {
    name = "resource registrations are released",
    run = function()
      local surface = get_surface()
      check(call("get_targeted_resource_count") > 0, "resources are still tracked before they are mined out")
      for k, entity in pairs (surface.find_entities_filtered{type = "resource"}) do
        entity.destroy()
      end
    end
  },

  {
    name = "tracking table is empty",
    ticks = 120,
    run = function()
      check_equal(call("get_targeted_resource_count"), 0, "no resources are still tracked as mining targets")
    end
  }
}

---------------------------------------------------------------------------------------------------
-- Runner
---------------------------------------------------------------------------------------------------

script.on_init(function()
  storage.state =
  {
    step = 1,
    next_tick = 10,
    checks = 0,
    failures = 0,
    peak_drone_count = 0,
    finished = false
  }
  state = storage.state
  report("started")
end)

script.on_load(function()
  state = storage.state
end)

script.on_event(defines.events.on_tick, function(event)

  if state.finished then return end

  local drone_count = call("get_drone_count")
  if drone_count > state.peak_drone_count then
    state.peak_drone_count = drone_count
  end

  if event.tick < state.next_tick then return end

  local step = steps[state.step]

  if not step then
    state.finished = true
    report("checks: "..state.checks.."  failures: "..state.failures)
    report("RESULT "..(state.failures == 0 and "PASS" or "FAIL"))
    return
  end

  report("step "..state.step.." - "..step.name)

  local ok, err = pcall(step.run)
  if not ok then
    state.failures = state.failures + 1
    state.checks = state.checks + 1
    report("  FAIL  step '"..step.name.."' raised: "..tostring(err))
  end

  state.step = state.step + 1

  --A step's 'ticks' is how long the world should be left running before that step checks it.
  local next_step = steps[state.step]
  state.next_tick = event.tick + ((next_step and next_step.ticks) or 1)

end)
