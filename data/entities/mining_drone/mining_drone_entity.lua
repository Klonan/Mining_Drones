
function gaussian (mean, variance)
  return  math.sqrt(-2 * variance * math.log(math.random())) *
          math.cos(2 * math.pi * math.random()) + mean
end

local sound = data.raw.tile["grass-1"].walking_sound

local shuffle = function(n, v)
  --local n = n or 0.5
  --log("Shuffling: "..n..v)
  local variance = (math.random() - 0.5) * v
  return math.min(math.max(n + variance, 0), 1)
end

local make_drone = function(name, tint)
  log(serpent.block{name = name, tint = tint})
  local base = util.copy(data.raw.character.character)
  --for k, layer in pairs (base.animations[1].idle_with_gun.layers) do
  --  layer.frame_count = 1
  --end

  --util.recursive_hack_runtime_tint(base, false)
  local random_height = gaussian(90, 10) / 100


  local r, g, b = tint.r or tint[1], tint.g or tint[2], tint.b or tint[3]
  local mask_tint = {r, g, b, 0.5}

  util.recursive_hack_scale(base, random_height)

  util.recursive_hack_tint(base, mask_tint, true)

  util.recursive_hack_animation_speed(base.animations[1].mining_with_tool, 1/0.9)

  local random_mining_speed = 1.5 * 1 + ((math.random() - 0.5) / 4)

  util.recursive_hack_animation_speed(base.animations[1].mining_with_tool, 1 / random_mining_speed)

  local bot_name = name
  local attack_range = 16
  local bot =
  {
    type = "unit",
    name = bot_name,
    localised_name = {name},
    icon = base.icon,
    icon_size = base.icon_size,
    icons = base.icons,
    flags = {"placeable-off-grid", "hidden"},
    map_color = {r ^ 0.5, g ^ 0.5, b ^ 0.5, 0.5},
    enemy_map_color = {r = 1},
    max_health = 150,
    radar_range = 1,
    order="zzz-"..bot_name,
    --subgroup = "iron-units",
    healing_per_tick = 0.1,
    --minable = {result = name, mining_time = 2},
    collision_box = {{-0.15, -0.15}, {0.15, 0.15}},
    collision_mask = {"not-colliding-with-itself", "player-layer", "train-layer", "consider-tile-transitions"},
    max_pursue_distance = 64,
    resistances = nil,
    min_persue_time = 60 * 15,
    selection_box = {{-0.3, -1}, {0.3, 0.2}},
    sticker_box = {{-0.3, -1}, {0.2, 0.3}},
    distraction_cooldown = (15),
    move_while_shooting = false,
    can_open_gates = true,
    ai_settings =
    {
      do_separation = false
    },
    attack_parameters =
    {
      type = "projectile",
      ammo_category = "bullet",
      warmup = math.floor(19 * random_mining_speed),
      cooldown = math.floor((26 - 19) * random_mining_speed),
      range = 0.5,
      --min_attack_distance = 1,
      --projectile_creation_distance = 0.5,
      --lead_target_for_projectile_speed = 1,
      old_sound =
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
    vision_distance = 100,
    has_belt_immunity = true,
    affected_by_tiles = true,
    movement_speed = 0.05 * random_height,
    distance_per_frame = 0.05 / random_height,
    pollution_to_join_attack = 1000000,
    corpse = bot_name.."-corpse",
    run_animation = base.animations[1].running,
    rotation_speed = 0.05 / random_height,
    light =
    {
      {
        minimum_darkness = 0.3,
        intensity = 0.4,
        size = 15 * random_height,
        color = {r=1.0, g=1.0, b=1.0}
      },
      {
        type = "oriented",
        minimum_darkness = 0.3,
        picture =
        {
          filename = "__core__/graphics/light-cone.png",
          priority = "extra-high",
          flags = { "light" },
          scale = 2,
          width = 200,
          height = 200
        },
        shift = {0, -7 * random_height},
        size = 1 * random_height,
        intensity = 0.6,
        color = {r=1.0, g=1.0, b=1.0}
      }
    },
    running_sound_animation_positions = {5, 16},
    walking_sound =
    {
      aggregation =
      {
        max_count = 2,
        remove = true
      },
      variations = sound
    }
  }
--error(serpent.block(base.animations[1].running))

  local corpse = util.copy(data.raw["character-corpse"]["character-corpse"])

  util.recursive_hack_tint(corpse, tint, true)
  util.recursive_hack_scale(corpse, random_height)

  corpse.name = bot_name.."-corpse"
  corpse.selectable_in_game = false
  corpse.selection_box = nil
  corpse.render_layer = "remnants"
  corpse.order = "zzz-"..bot_name


  data:extend
  {
    bot,
    corpse
  }

end

return make_drone