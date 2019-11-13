local path = util.path("data/units/smg_guy/")
local name = names.drone_name

local base = util.copy(data.raw.character.character)
--for k, layer in pairs (base.animations[1].idle_with_gun.layers) do
--  layer.frame_count = 1
--end

util.recursive_hack_animation_speed(base.animations[1].mining_with_tool, 1/0.9)

local attack_range = 16
local bot =
{
  type = "unit",
  name = name,
  localised_name = {name},
  icon = base.icon,
  icon_size = base.icon_size,
  icons = base.icons,
  flags = util.unit_flags(),
  map_color = {b = 0.5, g = 1},
  enemy_map_color = {r = 1},
  max_health = 150,
  radar_range = 1,
  order="i-a",
  --subgroup = "iron-units",
  healing_per_tick = 0.1,
  minable = {result = name, mining_time = 2},
  collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
  collision_mask = util.ground_unit_collision_mask(),
  max_pursue_distance = 64,
  resistances = nil,
  min_persue_time = 60 * 15,
  selection_box = {{-0.5, -1.6}, {0.5, 0.3}},
  sticker_box = {{-0.3, -1}, {0.2, 0.3}},
  distraction_cooldown = (15),
  move_while_shooting = false,
  can_open_gates = true,
  ai_settings =
  {
    do_separation = true
  },
  attack_parameters =
  {
    type = "projectile",
    ammo_category = "bullet",
    warmup = 19,
    cooldown = 26 - 19,
    range = 1,
    --min_attack_distance = 1,
    --projectile_creation_distance = 0.5,
    --lead_target_for_projectile_speed = 1,
    sound =
    {
      variations =
      {
        {
          filename = "__core__/sound/axe-mining-ore-1.ogg",
          volume = 0.75
        },
        {
          filename = "__core__/sound/axe-mining-ore-2.ogg",
          volume = 0.75
        },
        {
          filename = "__core__/sound/axe-mining-ore-3.ogg",
          volume = 0.75
        },
        {
          filename = "__core__/sound/axe-mining-ore-4.ogg",
          volume = 0.75
        },
        {
          filename = "__core__/sound/axe-mining-ore-5.ogg",
          volume = 0.75
        }
      },
      aggregation =
      {
        max_count = 2,
        remove = true,
        count_already_playing = true
      }
    },
    ammo_type =
    {
      category = util.ammo_category("mining-drone"),
      target_type = "entity",
      action =
      {
        type = "direct",
        action_delivery =
        {
          {
            type = "instant",
            target_effects =
            {
              {
                type = "damage",
                damage = {amount = shared.mining_damage , type = util.damage_type("physical")}
              }
            }
          }
        }
      }
    },
    animation = base.animations[1].mining_with_tool
  },
  vision_distance = 16,
  has_belt_immunity = false,
  affected_by_tiles = true,
  movement_speed = 0.12,
  distance_per_frame = 0.08,
  pollution_to_join_attack = 1000000,
  corpse = base.character_corpse,
  run_animation = base.animations[1].running,
  rotation_speed = 1
}

local item = {
  type = "item",
  name = name,
  localised_name = {name},
  icon = bot.icon,
  icon_size = bot.icon_size,
  flags = {},
  --subgroup = "iron-units",
  order = "b-"..name,
  stack_size = 20,
  place_result = name
}

local recipe = {
  type = "recipe",
  name = name,
  localised_name = {name},
  --category = ,
  enabled = true,
  ingredients =
  {
    {"iron-plate", 15},
    {"iron-gear-wheel", 10},
    {"iron-stick", 10}
  },
  energy_required = 15,
  result = name
}


local light =
{
  type = "sprite",
  name = "mining-drone-light",
  filename = util.path("data/entities/mining_drone/drone-light-cone.png"),
  priority = "extra-high",
  flags = {"light"},
  width = 200,
  height = 430,
  --shift = {0, -200/32}
}


data:extend
{
  bot,
  item,
  recipe,
  light,
}
