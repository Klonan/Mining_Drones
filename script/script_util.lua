local util = require("util")

util.copy = util.table.deepcopy

util.distance = function(p1, p2)
  return (((p1.x - p2.x) ^ 2) + ((p1.y - p2.y) ^ 2)) ^ 0.5
end

util.area = function(position, radius)
  return {{position.x - radius, position.y - radius}, {position.x + radius, position.y + radius}}
end

return util
