## Mining Drones

![icon](/data/technologies/mining_drones_tech.png)

--------------------------------------

These guys mine for you, based from their mining depot.

Demonstration video: https://streamable.com/ymk8h

You can also mine things like Uranium, by inputting the required fluid into the back of the depot.
The mining depot has a small caution floor mat in front of where the drones spawn. If you block it, a warning will show, and drones won't be able to spawn.

The mining area is shown when hovering over a depot, it is a roughly 50x50 area in front of the depot.

The mining drones and mining depot is unlocked from the start of the game (so you can use it instead of mining drills), and they don't require any power.

There are 2 technologies related to the mining drones:
 - Mining drone speed: Increases walking speed, mining speed, and carry capacity.
 - Mining drone productivity: Gives a chance to produce extra products when mining.

If you change the recipe or mine the depot, all the 'connected' drones will die. Painfully. So lets try to avoid that.

Each depot can hold 100 drones, and more under some circumstances. Drones will automatically be deployed when the resources in the depot become low.

The mod should detect all modded resources, and work correctly with them.

As far as performance goes, obviously they will not be as good as mining drills for super mega bases, due to the units and the script update. With a running save with over 2,300 active mining drones, the script update was only about 0.4ms. So you can probably have upwards of 10,000 mining drones without any problem. And of course, performance will be better in 0.18.

--------------------------------------

### Remote interface

The mod registers a `mining_drones` remote interface:

| Call | Returns |
| --- | --- |
| `get_drone_count()` | number of drones currently out mining |
| `get_depot_count()` | number of registered mining depots |
| `get_bonuses(force_index)` | `{mining_speed, walking_speed, cargo_size, productivity}` |
| `reset_depots()` | recalls every drone and rebuilds all target lists |

--------------------------------------

### Self test

`script/self_test.lua` is a dev-only smoke test. It builds a private surface with seven depots on
it and checks that the generated prototypes are complete for every resource in the loaded mod set,
that drones deploy and ore actually arrives, that fluid gating works, that rotations, recipe
changes, force changes and status transitions are picked up, that the technologies apply, that a
full depot throttles itself, that the migration handlers do their job, that an unanswered path
request doesn't stall the mod, and that everything cleans up without leaking entities, script
inventories or resource registrations.

It is commented out in `control.lua` by default, because it builds entities on a running save.
To use it, uncomment its `handler.add_lib` line and then run:

```
factorio.exe --create test.zip
factorio.exe --benchmark test.zip --benchmark-ticks 37000
```

It logs one line per check and finishes with `SELF_TEST_RESULT: PASS` or `FAIL`. Comment the line
back out afterwards.
