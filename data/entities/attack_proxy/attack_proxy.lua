local make_proxy = function(size)

  local attack_proxy =
  {
    type = "simple-entity",
    name = shared.attack_proxy_name..size,
    icon = "__base__/graphics/icons/ship-wreck/small-ship-wreck.png",
    icon_size = 32,
    flags = {"placeable-neutral", "placeable-off-grid", "not-on-map"},
    order = "d[remnants]-d[ship-wreck]-c[small]-a",
    max_health = shared.mining_damage * 1000000,
    collision_box = {{-size/2, -size/2}, {size/2, size/2}},
    collision_mask = {},
    selection_box = nil,
    pictures =
    {
      {
        filename = "__base__/graphics/entity/ship-wreck/small-ship-wreck-a.png",
        width = 1,
        height= 1
      },
    }
  }

  data:extend{attack_proxy}
end

for k = 1, 10 do
  make_proxy(k)
end