--Bonuses granted by the mod technologies.
--
--Nothing is kept in storage: the levels are derived from the force technologies, so the
--cache below is purely a runtime memo which rebuilds itself lazily after a load, and after
--anything that can change technology state. This means the bonuses can never drift out of
--sync with the force (technology reset, force merge, migration, /reset-technology-effects...).

local finite_levels = shared.technology_levels
local infinite_index = finite_levels + 1

local speed_technology = shared.mining_speed_technology
local productivity_technology = shared.mining_productivity_technology

local cache = {}

local get_technology_level = function(force, base_name)

  local technologies = force.technologies
  local level = 0

  for k = 1, finite_levels do
    local technology = technologies[base_name.."-"..k]
    if not (technology and technology.researched) then
      return level
    end
    level = k
  end

  local infinite = technologies[base_name.."-"..infinite_index]
  if infinite then
    --For an infinite technology, 'level' is the level that will be researched next,
    --so the number of completed levels is the difference from where it started.
    level = level + (infinite.level - infinite_index)
  end

  return level

end

local get_bonuses = function(force_index)

  local bonuses = cache[force_index]
  if bonuses then return bonuses end

  local force = game.forces[force_index]
  if not (force and force.valid) then
    --Shouldn't happen, but don't poison the cache with it either.
    return {speed = 0, productivity = 0}
  end

  local speed_level = get_technology_level(force, speed_technology)

  bonuses =
  {
    speed = speed_level,
    productivity = get_technology_level(force, productivity_technology)
  }

  cache[force_index] = bonuses
  return bonuses

end

local lib = {}

lib.get_walking_speed_bonus = function(force_index)
  return get_bonuses(force_index).speed * 0.2
end

lib.get_mining_speed_bonus = function(force_index)
  return get_bonuses(force_index).speed * 0.2
end

lib.get_cargo_size_bonus = function(force_index)
  return get_bonuses(force_index).speed
end

lib.get_productivity_bonus = function(force_index)
  return get_bonuses(force_index).productivity * 0.1
end

local clear_cache = function()
  cache = {}
end

local on_force_changed = function(event)
  local force = event.force or event.research and event.research.force
  if force and force.valid then
    cache[force.index] = nil
    return
  end
  clear_cache()
end

lib.events =
{
  [defines.events.on_research_finished] = on_force_changed,
  [defines.events.on_research_reversed] = on_force_changed,
  [defines.events.on_technology_effects_reset] = on_force_changed,
  [defines.events.on_force_reset] = on_force_changed,
  [defines.events.on_force_created] = on_force_changed,
  [defines.events.on_forces_merged] = clear_cache,
}

lib.on_load = clear_cache
lib.on_init = clear_cache

lib.on_configuration_changed = function()
  --Used to hold a copy of the bonuses, which is now derived on demand instead.
  storage.mining_technologies = nil
  clear_cache()
end

return lib
