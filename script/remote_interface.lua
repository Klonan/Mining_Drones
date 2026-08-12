local mining_drone = require("script/mining_drone")
local mining_depot = require("script/mining_depot")
local mining_technologies = require("script/mining_technologies")

local interface =
{
  get_drone_count = function()
    return mining_drone.get_drone_count()
  end,

  --The bonuses the mod technologies currently grant to the given force.
  get_bonuses = function(force_index)
    return
    {
      mining_speed = mining_technologies.get_mining_speed_bonus(force_index),
      walking_speed = mining_technologies.get_walking_speed_bonus(force_index),
      cargo_size = mining_technologies.get_cargo_size_bonus(force_index),
      productivity = mining_technologies.get_productivity_bonus(force_index)
    }
  end,

  get_depot_count = function()
    return mining_depot.get_depot_count()
  end,

  --Same as the /mining-depots-rescan command: recall every drone and rebuild the target lists.
  reset_depots = function()
    mining_depot.reset_all_depots()
  end
}

local lib = {}

lib.add_remote_interface = function()
  if not remote.interfaces["mining_drones"] then
    remote.add_interface("mining_drones", interface)
  end
end

return lib
