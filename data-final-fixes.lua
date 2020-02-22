util = require "data/tf_util/tf_util"
names = require("shared")
shared = require("shared")

require("data/entities/attack_proxy/attack_proxy")


for name, unit in pairs(data.raw.unit) do
  if name:find(shared.drone_name, 0, true) then
    unit.loot = nil
  end
  if name:find(shared.attack_proxy_name, 0, true) then
    unit.loot = nil
  end
end