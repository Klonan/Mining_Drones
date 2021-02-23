local name = "mining-depot"
local depots = names.depots

local radius = depots["mining-depot"].radius
local drop_offset = depots["mining-depot"].drop_offset

local pad_layers = function(layers)
  for k = 1, 50 do
    table.insert(layers, 1, util.empty_sprite())
  end
  return layers
end

local sprite_width = 768
local sprite_height = 768
local sprite_scale = 0.5
local shift = {0, 0}
local sprite_path = "__Mining_Drones__/data/entities/mining_depot/Scene_layer-main/Scene_layer-main_"
local shadow_path = "__Mining_Drones__/data/entities/mining_depot/Scene_layer-shadow/Scene_layer-shadow_"
local shifts = shared.depots["mining-depot"].shifts

local duration = 70
local size = 768
local particle_path = "__Mining_Drones__/data/entities/mining_depot/Scene_layer-particle"


function mining_depot_pipes()
  return
  {
    north =
    {
      filename = "__Mining_Drones__/data/entities/mining_depot/pipes/mining-depot-3-pipe-N.png",
      priority = "extra-high",
      width = 35,
      height = 18,
      shift = util.by_pixel(2.5, 14),
      hr_version =
      {
        filename = "__Mining_Drones__/data/entities/mining_depot/pipes/hr-mining-depot-3-pipe-N.png",
        priority = "extra-high",
        width = 71,
        height = 100,
        shift = util.by_pixel(2.25, 13.5),
        scale = 0.5
      }
    },
    east =
    {
      filename = "__Mining_Drones__/data/entities/mining_depot/pipes/mining-depot-3-pipe-E.png",
      priority = "extra-high",
      width = 20,
      height = 38,
      shift = util.by_pixel(-25, 1),
      hr_version =
      {
        filename = "__Mining_Drones__/data/entities/mining_depot/pipes/hr-mining-depot-3-pipe-E.png",
        priority = "extra-high",
        width = 42,
        height = 76,
        shift = util.by_pixel(-24.5, 1),
        scale = 0.5
      }
    },
    south =
    {
      filename = "__Mining_Drones__/data/entities/mining_depot/pipes/mining-depot-3-pipe-S.png",
      priority = "extra-high",
      width = 44,
      height = 31,
      shift = util.by_pixel(0, -31.5),
      hr_version =
      {
        filename = "__Mining_Drones__/data/entities/mining_depot/pipes/hr-mining-depot-3-pipe-S.png",
        priority = "extra-high",
        width = 88,
        height = 99,
        shift = util.by_pixel(0, -31.25),
        scale = 0.5
      }
    },
    west =
    {
      filename = "__Mining_Drones__/data/entities/mining_depot/pipes/mining-depot-3-pipe-W.png",
      priority = "extra-high",
      width = 19,
      height = 37,
      shift = util.by_pixel(25.5, 1.5),
      hr_version =
      {
        filename = "__Mining_Drones__/data/entities/mining_depot/pipes/hr-mining-depot-3-pipe-W.png",
        priority = "extra-high",
        width = 39,
        height = 73,
        shift = util.by_pixel(25.75, 1.25),
        scale = 0.5
      }
    }
  }
end

local working_visualisations =
{
  {
    always_draw = true,
    render_layer = "object",
    --secondary_draw_order = 127,
    --north_position = {0, 2},
    --south_position = {0, 2},
    --east_position = {0, 2},
    --west_position = {0, 2},
    north_animation =
    {
      layers =
      {
        {
          filename = sprite_path.."0004.png",
          frame_count = 1,
          shift = shifts["north"],
          scale = sprite_scale,
          width = sprite_width,
          height = sprite_height,
        },
        {
          filename = shadow_path.."0004.png",
          frame_count = 1,
          scale = sprite_scale,
          shift = shifts["north"],
          width = sprite_width,
          height = sprite_height,
          draw_as_shadow = true
        },
      }
    },
    east_animation =
    {
      layers =
      {
        {
          filename = sprite_path.."0003.png",
          frame_count = 1,
          scale = sprite_scale,
          shift = shifts["east"],
          width = sprite_width,
          height = sprite_height,
        },
        {
          filename = shadow_path.."0003.png",
          frame_count = 1,
          scale = sprite_scale,
          shift = shifts["east"],
          width = sprite_width,
          height = sprite_height,
          draw_as_shadow = true
        },
      }
    },

    south_animation =
    {
      layers =
      {
        {
          filename = sprite_path.."0002.png",
          frame_count = 1,
          scale = sprite_scale,
          shift = shifts["south"],
          width = sprite_width,
          height = sprite_height,
        },
        {
          filename = shadow_path.."0002.png",
          frame_count = 1,
          scale = sprite_scale,
          shift = shifts["south"],
          width = sprite_width,
          height = sprite_height,
          draw_as_shadow = true
        },
      }
    },
    west_animation =
    {
      layers =
      {
        {
          filename = sprite_path.."0001.png",
          frame_count = 1,
          scale = sprite_scale,
          shift = shifts["west"],
          width = sprite_width,
          height = sprite_height,
        },
        {
          filename = shadow_path.."0001.png",
          frame_count = 1,
          scale = sprite_scale,
          shift = shifts["west"],
          width = sprite_width,
          height = sprite_height,
          draw_as_shadow = true
        },
      }
    }
  }
}

local mining_depot =
{
  name = "mining-depot",
  type = "assembling-machine",
  collision_box = {{ -2.25, -3.75}, { 2.25, 3.75}},
  selection_box = {{ -2.5, -4}, { 2.5, 4}},
  --alert_icon_shift = { -0.09375, -0.375},
  --entity_info_icon_shift = {0, -0.75},
  allowed_effects = {},
  close_sound =
  {
    {
      filename = "__base__/sound/machine-close.ogg",
      volume = 0.5
    }
  },
  old_collision_mask =
  {
    "item-layer",
    "object-layer",
    "water-tile",
    "resource-layer",
    "train-layer"
  },
  corpse = "depot-corpse",
  crafting_categories = {"mining-depot"},
  crafting_speed = depots["mining-depot"].capacity - 1,
  damaged_trigger_effect =
  {
    damage_type_filters = "fire",
    entity_name = "spark-explosion",
    offset_deviation = {{ -0.5, -0.5}, { 0.5, 0.5}},
    offsets = {{ 0, 1}},
    type = "create-entity"
  },
  drawing_box = {{ -1.5, -1.7}, { 1.5, 1.5}},
  dying_explosion = "assembling-machine-3-explosion",
  energy_source =
  {
    emissions_per_second_per_watt = 0.1,
    type = "void",
    usage_priority = "secondary-input"
  },
  energy_usage = "1W",
  fast_replaceable_group = "assembling-machine",
  flags =
  {
    "placeable-neutral",
    "player-creation"
  },
  fluid_boxes =
  {
    {
      production_type = "input",
      pipe_picture = mining_depot_pipes(),
      pipe_covers = pipecoverspictures(),
      base_area = 5,
      height = 2,
      base_level = -1,
      pipe_connections =
      {
        { type="input-output", position = {-3, -0.5} },
        { type="input-output", position = {3, -0.5} }
      },
      secondary_draw_orders =
      {
        north = -1,
        south = 100,
        east = 50,
        west = 50
      }
    },
    off_when_no_fluid_recipe = true,
  },
  gui_title_key = "mining-depot-choose-resource",
  icon = "__Mining_Drones__/data/technologies/mining_drones_tech.png",
  icon_size = 256,
  icon_mipmaps = 0,
  localised_name =  {"mining-depot"},
  max_health = 400,
  minable =
  {
    mining_time = 1,
    result = "mining-depot"
  },
  open_sound =
  {
    {
      filename = "__base__/sound/machine-open.ogg",
      volume = 0.5
    }
  },
  radius_visualisation_specification =
  {
    distance =  radius,
    offset = {drop_offset[1], (drop_offset[2] - radius) - 0.5},
    sprite =
    {
      filename = "__base__/graphics/entity/electric-mining-drill/electric-mining-drill-radius-visualization.png",
      height = 10,
      width = 10
    }
  },
  resistances =
  {
    {
      percent = 70,
      type = "fire"
    }
  },
  scale_entity_info_icon = true,
  vehicle_impact_sound =
  {
    {
      filename = "__base__/sound/car-metal-impact-2.ogg",
      volume = 0.5
    },
    {
      filename = "__base__/sound/car-metal-impact-3.ogg",
      volume = 0.5
    },
    {
      filename = "__base__/sound/car-metal-impact-4.ogg",
      volume = 0.5
    },
    {
      filename = "__base__/sound/car-metal-impact-5.ogg",
      volume = 0.5
    },
    {
      filename = "__base__/sound/car-metal-impact-6.ogg",
      volume = 0.5
    }
  },
  working_sound =
  {
    audible_distance_modifier = 0.5,
    fade_in_ticks = 4,
    fade_out_ticks = 20,
    sound =
    {
      {
        filename = "__base__/sound/assembling-machine-t3-1.ogg",
        volume = 0.45
      }
    }
  },
  working_visualisations = working_visualisations
}

local item =
{
  type = "item",
  name = name,
  icon = "__Mining_Drones__/data/icons/mining_depot.png",
  icon_size = 64,
  flags = {},
  subgroup = "extraction-machine",
  order = "za"..name,
  place_result = name,
  stack_size = 5
}

local category =
{
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

local empty = util.empty_sprite()
empty.direction_count = 1

local caution_corpse =
{
  type = "corpse",
  name = "caution-corpse",
  flags = {"placeable-off-grid"},
  animation = empty,
  remove_on_entity_placement = false,
  remove_on_tile_placement = false
}

local box =
{
  type = "highlight-box",
  name = "mining-depot-collision-box",
  localised_name = mining_depot.localised_name,
  collision_mask = {"player-layer"}
}

local corpse_path = "__Mining_Drones__/data/entities/mining_depot/corpse/Scene_layer-"

local depot_corpse =
{
  type = "corpse",
  name = "depot-corpse",
  flags = {"placeable-off-grid"},
  animation =
  {
    layers =
    {
      {
        filenames =
        {
          corpse_path.."main_0004.png",
          corpse_path.."main_0003.png",
          corpse_path.."main_0002.png",
          corpse_path.."main_0001.png",
        },
        slice = 1,
        frame_count = 1,
        direction_count = 4,
        shift = {0, 0.5},
        scale = sprite_scale,
        width = sprite_width,
        height = sprite_height,
        lines_per_file = 1
      },
      {
        filenames =
        {
          corpse_path.."shadow_0004.png",
          corpse_path.."shadow_0003.png",
          corpse_path.."shadow_0002.png",
          corpse_path.."shadow_0001.png",
        },
        slice = 1,
        frame_count = 1,
        direction_count = 4,
        shift = {0, 0.5},
        scale = sprite_scale,
        width = sprite_width,
        height = sprite_height,
        draw_as_shadow = true,
        lines_per_file = 1
      },
    }
  },
  final_render_layer = "lower-object-above-shadow",
  remove_on_entity_placement = true,
  remove_on_tile_placement = true
}

data:extend
{
  mining_depot,
  item,
  category,
  recipe,
  caution_corpse,
  box,
  depot_corpse
}

--error(count)
