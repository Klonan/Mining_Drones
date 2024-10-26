util = require "data/tf_util/tf_util"
names = require("shared")
shared = require("shared")

require "data/entities/entities"
require "data/technologies/mining_speed"
require "data/technologies/mining_productivity"

--data.raw["gui-style"].default.machine_outputs_scroll_pane.maximal_height = 150

--local drone_layer = collision_util.get_first_unused_layer()
local drone_layer = { type = "collision-layer", order = "42", name = "mining_drone" }
data:extend{drone_layer}
