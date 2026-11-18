# Petal & Profit

A small first-person flower-growing and delivery prototype for **Godot 4.7** (GDScript only,
no .NET needed). Everything in the world is generated from primitives at runtime.

## Running it

Open `project.godot` in Godot 4.7 and press **F5**, or:

```
Godot_v4.7.2-stable_mono_win64.exe --path . 
```

The game runs in Forward+ (D3D12 by default on Windows). A run autosaves every 60 seconds,
on quit, and from the pause menu. **New run** in the pause menu wipes the save.

## Controls

| Key | Action |
| --- | --- |
| `WASD` | Move |
| `Shift` | Sprint |
| `Mouse` | Look |
| `E` | Context interact (plant / water / harvest / sell / read / pack / refill) |
| `1`–`8` | Select hotbar slot |
| `G` | Drop the selected stack |
| `Esc` | Pause menu (or close the open window) |

## The loop

1. **Plant.** Pick a seed packet with `1`–`8`, look at an empty planter and press `E`.
   Only one seed is consumed per pot.
2. **Water.** Pots start watered and dry out around 75 % growth. Select the watering can
   and press `E` at a dry pot. The can holds 6 charges; refill free at the tap in the
   greenhouse's back-left corner.
3. **Harvest.** When a plant is fully grown (`Bloom`) press `E` to cut it. Press `E` again
   to clear the spent pot and replant.
4. **Sell.** Four neighbours buy loose blooms. Each pays a **+30 % bonus for their
   favourite flower** and **−20 % for anything else**, and pays more as trust grows:
   - **Rosa** – park bench, east of the houses · daisy, tulip
   - **Marcus** – stoop of No. 14 · sunflower, marigold
   - **Ivy** – Flora & Feed storefront · orchid, rose
   - **Dennis** – bus shelter, greenhouse side · marigold
5. **Orders.** The board on the west wall of the greenhouse lists three standing orders.
   Grow the flowers, then pack them at the bench next to the board. A packed order becomes
   one **Order Box** in your hotbar (one slot per box). Deliver it to the named customer
   for the reward and a trust bump.
6. **Progress.** Earning money unlocks better flowers: **$250** unlocks tulip and
   sunflower, **$900** unlocks orchid and rose. Buy seeds at the counter on the right.

Flowers are the only thing that takes time: growth is real-time wall-clock and keeps
running while you walk around town or sit in a menu.

## Flower table

| Flower | Grow | Seed | Sells from | Unlock |
| --- | --- | --- | --- | --- |
| Wildflower | 60 s | $1 | $3 | always — the broke-run safety net |
| Daisy | 75 s | $4 | $8 | start |
| Marigold | 100 s | $6 | $11 | start |
| Tulip | 200 s | $12 | $24 | $250 earned |
| Sunflower | 240 s | $15 | $30 | $250 earned |
| Orchid | 300 s | $25 | $52 | $900 earned |
| Rose | 420 s | $35 | $74 | $900 earned |

## Project layout

```
scenes/            main, player, hud
scripts/autoload/  event_bus, game_state, inventory, customer_system, order_system, save_system
scripts/data/      flower_db, item_db, customer_db
scripts/gameplay/  interactable, plant_pot, plant_visual, item_pickup, water_tap,
                   shop_counter, buyer, order_board, packing_station
scripts/ui/        hud.gd
scripts/util/      palette, build
scripts/world/     world_builder
scripts/debug/     test_suite
```

## Development hooks

Run headless checks:

```
godot --headless --path . -- --test     # 74 logic checks
godot --headless --path . -- --tour     # walks the player to every interactable
godot --path . -- --demo --shot         # demo pots + debug_shot.png after 3 s
```

`--demo` also accepts `--stage`, `--aim`, `--aim-x=`, `--at=x,y,z`, `--look=deg`,
`--modal=sell|board|pack|pause|shop` and `--prepack`.
