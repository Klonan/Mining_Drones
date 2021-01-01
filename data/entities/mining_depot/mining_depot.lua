local machine = util.copy(data.raw["assembling-machine"]["assembling-machine-3"])
local name = names.mining_depot
local depots = names.depots
machine.name = name
machine.localised_name = {name}
local scale = 2
util.recursive_hack_make_hr(machine)
util.recursive_hack_scale(machine, scale)
machine.collision_box = {{-1.25, -3.25},{1.25, 1.25}}
machine.selection_box = {{-1.5, -3.5},{1.5, 1.5}}
machine.crafting_categories = {name}
machine.crafting_speed = depots["mining-depot"].capacity - 1
machine.ingredient_count = nil
machine.collision_mask = {"item-layer", "object-layer", "water-tile", "resource-layer"}
machine.allowed_effects = {"consumption", "speed", "pollution"}
machine.module_specification =nil
machine.minable = {result = name, mining_time = 1}
machine.flags = {"placeable-neutral", "player-creation"}
machine.next_upgrade = nil
machine.fluid_boxes =
{
  --{
  --  production_type = "input",
  --  pipe_picture = assembler2pipepictures(),
  --  base_area = 10,
  --  base_level = -1,
  --  pipe_connections = {{ type="input-output", position = {0, 1.5} }},
  --  pipe_covers = pipecoverspictures(),
  --},
  off_when_no_fluid_recipe = false
}
machine.scale_entity_info_icon = true
machine.energy_usage = "1W"
machine.gui_title_key = "mining-depot-choose-resource"
machine.energy_source =
{
  type = "void",
  usage_priority = "secondary-input",
  emissions_per_second_per_watt = 0.1
}
machine.icon = util.path("data/entities/mining_depot/depot-icon.png")
machine.icon_size = 216
local radius = depots["mining-depot"].radius
local drop_offset = depots["mining-depot"].drop_offset
machine.radius_visualisation_specification =
{
  sprite =
  {
    filename = "__base__/graphics/entity/electric-mining-drill/electric-mining-drill-radius-visualization.png",
    width = 10,
    height = 10
  },
  distance =  radius,
  offset = {drop_offset[1], (drop_offset[2] - radius) - 0.5}
}

local animation =
{
  north =
  {
    layers =
    {
      {
        filename = util.path("data/entities/mining_depot/depot-north.png"),
        width = 3*64,
        height = 5*64,
        frame_count = 1,
        scale = 0.5,
        shift = {0, -1}
      }
    }
  },
  south =
  {
    layers =
    {
      {
        filename = util.path("data/entities/mining_depot/depot-south.png"),
        width = 3*64,
        height = 5*64,
        frame_count = 1,
        scale = 0.5,
        shift = {0, 1}
      }
    }
  },
  east =
  {
    layers =
    {
      {
        filename = util.path("data/entities/mining_depot/depot-east.png"),
        width = 5*64,
        height = 3*64,
        frame_count = 1,
        scale = 0.5,
        shift = {1, 0}
      }
    }
  },
  west =
  {
    layers =
    {
      {
        filename = util.path("data/entities/mining_depot/depot-west.png"),
        width = 5*64,
        height = 3*64,
        frame_count = 1,
        scale = 0.5,
        shift = {-1, 0}
      }
    }
  },
}

machine.animation = nil
machine.working_visualisations =
{
  {
    always_draw = true,
    render_layer = "floor",
    north_animation = animation.north,
    south_animation = animation.south,
    east_animation = animation.east,
    west_animation = animation.west,
  }
}

local item =
{
  type = "item",
  name = name,
  icon = machine.icon,
  icon_size = machine.icon_size,
  flags = {},
  subgroup = "extraction-machine",
  order = "za"..name,
  place_result = name,
  stack_size = 5
}

local category = {
  type = "recipe-category",
  name = name
}

local recipe =
{
  type = "recipe",
  name = name,
  localised_name = {name},
  enabled = true,
  ingredients =
  {
    {"iron-plate", 50},
    {"iron-gear-wheel", 10},
    {"iron-stick", 20},
  },
  energy_required = 5,
  result = name
}

local caution_sprite =
{
  type = "sprite",
  name = "caution-sprite",
  filename = util.path("data/entities/mining_depot/depot-caution.png"),
  width = 101,
  height = 72,
  frame_count = 1,
  scale = 0.5,
  shift = shift,
  direction_count =1,
  draw_as_shadow = false,
  flags = {"terrain"}
}

local caution_corpse =
{
  type = "corpse",
  name = "caution-corpse",
  flags = {"placeable-off-grid"},
  animation = caution_sprite,
  remove_on_entity_placement = false,
  remove_on_tile_placement = false
}

local box =
{
  type = "highlight-box",
  name = "mining-depot-collision-box",
  collision_mask = {"player-layer"}
}

data:extend
{
  machine,
  item,
  category,
  recipe,
  caution_sprite,
  caution_corpse,
  box
}

--error(count)