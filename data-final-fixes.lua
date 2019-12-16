shared = require("shared")

for name, unit in pairs(data.raw.unit) do
  if name:find(shared.drone_name, 0, true) then
    unit.loot = nil
  end
  if name:find(shared.attack_proxy_name, 0, true) then
    unit.loot = nil
  end
end