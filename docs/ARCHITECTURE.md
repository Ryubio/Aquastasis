# Architecture contract — Pulse of the Mediterranean

The game spec is [README.md](../README.md) (read its ROLE, ART DIRECTION, LOCALIZATION, TECHNICAL ARCHITECTURE and CRASH PREVENTION sections). This file pins down the interfaces between modules so they can be built in parallel and still fit. **Public APIs marked "frozen" must not change**; add to them freely.

Target: Godot **4.3+** (code must stay 4.3-compatible), verified locally on Godot **4.7.2** (Forward+, RTX 4060).

## 1. Files and owners

| File | Owner module | Status |
|---|---|---|
| `project.godot`, `main.tscn`, `scripts/main.gd` | integration | written, frozen |
| `scripts/event_bus.gd` | integration | written, frozen (add signals only) |
| `scripts/balance.gd` | simulation | written; tune values, keep names, add constants |
| `scripts/region.gd` | integration (polygons/anchors: map) | written; map may refine `polygon`/`anchor` values, nothing else |
| `scripts/i18n.gd` | localization | written (API frozen); STRINGS filled by localization |
| `scripts/game_state.gd` | simulation | written (API frozen); may change internals |
| `scripts/crisis_sim.gd` | simulation | STUB → implement |
| `scripts/sim_test.gd` | simulation | to write (headless balance test, see §7) |
| `scripts/map_builder.gd` | map | STUB → implement |
| `shaders/sea.gdshader`, `shaders/route.gdshader` (+ `shaders/grid.gdshader` if useful) | map | to write |
| `scripts/ui_theme.gd` | UI (PALETTE section frozen) | extend |
| `scripts/ui_hud.gd`, `scripts/ui_menu.gd` | UI | STUB → implement |
| `scripts/icons.gd`, `scripts/charts.gd` | UI | to write |
| `tools/check.gd`, `tools/check.tscn` | dev tool | compile checker, not part of the game |

Never edit a file owned by another module. If you need something from another module, code against the API below and report the need.

## 2. Hard GDScript rules (each one has bitten us; the checker treats several as errors)

1. **No `class_name` anywhere.** Reference other scripts with `const X := preload("res://scripts/x.gd")` (a preloaded script constant works as a type: `var sim: CrisisSim`). Autoloads are used by name: `EventBus`, `Balance`, `I18n`, `GameState`. Autoload scripts never declare `class_name`.
2. **Never use `:=` on a Variant expression.** Dictionary/untyped-array element access, untyped function returns, `max/min/clamp/lerp/abs/sign/snapped` all return Variant → *parse error* in 4.7. Write `var v: float = d["k"]`, and use typed math: `maxf minf clampf lerpf absf signf maxi mini clampi snappedf`.
3. **Never assign an untyped `Array` expression to an `Array[T]` variable** (README crash rule 2). Prefer plain `Array`; if you need typed, use `typed_arr.assign(untyped)`.
4. Godot 4 syntax only: `signal x(a: int)`, `sig.connect(callable)`, `create_tween()`, `await`, typed vars. No `yield`, no string-based `connect`, no Godot 3 classes.
5. Every script starts with a 2–3 line `##` comment describing its responsibility.
6. **No user-visible text outside `i18n.gd`.** Everything goes through `I18n.t(key, args)`. Allowed literals: numbers, units/symbols (`%`, `°C`, `+`, `x`, `1x`, `→`). Never `to_upper()`/`to_lower()` on translated text. Avoid number-dependent grammar ("Years left: 12", not "12 years left").
7. Every UI that shows text re-renders on `EventBus.language_changed`.
8. Russian is 30–40% longer: containers only (`HBoxContainer`/`VBoxContainer`/`GridContainer`/`MarginContainer`), `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART` on body text, `custom_minimum_size` instead of fixed sizes, `clip_text`/`text_overrun_behavior` on single lines.
9. Input: full-screen layout Controls use `mouse_filter = MOUSE_FILTER_IGNORE`; only real panels/buttons use STOP, so clicks on empty screen reach the map's `_unhandled_input`. All buttons use `focus_mode = FOCUS_NONE` (Space is a hotkey).
10. No external assets (no png/svg/ogg/wav/ttf). Fonts: Godot's default font, or `SystemFont` with `font_names = ["Consolas", "Courier New", "monospace"]` for the terminal look.
11. Don't declare members named like inherited properties (`name`, `position`, `scale`, `size`, `visible`, `rotation`, `owner` ...). Prefix parameters that collide with globals (`p_seed`, not `seed`).
12. API honesty: if you are not sure an API exists in Godot 4.3, use a known-safe alternative and mark it `# SAFE-FALLBACK`.
13. Free temporary nodes with `queue_free()`. Keep draw calls low.

## 3. Verify your work (mandatory before you finish)

```bash
G="/c/Users/HARUN BERKE ÖZTÜRK/OneDrive/Masaüstü/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe"
cd "/c/Users/HARUN BERKE ÖZTÜRK/OneDrive/Masaüstü/Cop31 Game"
# compile every script with autoloads available (exit code = number of failures)
"$G" --headless --path . res://tools/check.tscn
# compile only some scripts
"$G" --headless --path . res://tools/check.tscn -- res://scripts/map_builder.gd
# run the real game headless for 300 frames, skipping the menu, at 4x
"$G" --headless --path . --quit-after 300 -- --autostart --speed=3
# render real frames (shaders only compile with a GPU; opens a window briefly).
# Writes shots/frame00000000.png ... ; view a frame with the Read tool.
"$G" --path . --resolution 1920x1080 --write-movie shots/frame.png --fixed-fps 30 --quit-after 90 -- --autostart --speed=3 --select=antalya
```
`--check-only -s` does NOT work for scripts that use autoloads; use `tools/check.tscn`. Headless runs do not compile shaders: render real frames to see shader errors (they print to stdout) and to look at the result. Put screenshots under `shots/` (git-ignored) and delete what you don't need. Any `SCRIPT ERROR`, `Parse Error`, `ERROR:` or shader compile error in the output is a failure.

## 4. Signals and payloads (EventBus, frozen)

```gdscript
signal game_started()
signal game_over(won: bool, reason: String, stats: Dictionary)   # stats = Snapshot + "reason"
signal paused_changed(paused: bool)
signal speed_changed(speed_index: int)                           # 0 pause, 1 1x, 2 2x, 3 4x
signal tick_done(snapshot: Dictionary)                           # every tick, after region_changed
signal region_changed(region_id: String, data: Dictionary)        # every tick, all 8 regions
signal spread_happened(from_id: String, to_id: String)            # flash target region / route
signal resources_changed(budget: float, political: float, science: float)
signal action_performed(action_id: String, region_id: String)
signal region_hovered(region_id: String)                          # "" = none (map emits)
signal region_selected(region_id: String)                         # "" = deselect (map emits; --select too)
signal toast(text_key: String, args: Dictionary, severity: int)   # 0 info, 1 good, 2 warning, 3 alarm
signal language_changed(lang: String)
signal event_triggered(event_id: String)                          # Phase 2
signal evolution_happened(evolution_id: String)                   # Phase 2
```

**Toast args convention:** values that are i18n keys (e.g. region name keys `"region.levant.name"`) are translated by the displayer: for each arg value `v` that is a String with `I18n.has_key(v)`, use `I18n.t(v)`; numbers are pre-formatted strings. Severity 3 also makes the map shake.

**Snapshot** (`GameState.get_snapshot()`, `tick_done`): `tick:int, year:float, year_int:int, years_left:int, progress:float(0-1), temperature:float(°C above pre-industrial, 1.5→4.0), sea_health:float(0-100), crisis:float(0-100 avg), awareness:float(0-100 avg), budget:float, political:float, science:float, actions_used:int, speed_index:int`.

**Region dictionary** (`region_changed`, `GameState.get_region(id)`): `id, name_key, pollution, coral_health, seagrass, fish_stock, awareness, protection, coastal_pop (0-1 weight), crisis (0-100), health (0-100), status ("healthy"|"stressed"|"critical"|"collapsed")`.

**Game over reasons:** `win_health`, `win_crisis`, `lose_temperature`, `lose_health`, `lose_resources`, `lose_time`.

## 5. Module APIs (frozen)

**GameState** (autoload, `scripts/game_state.gd`, already written): `running:bool`, `menu_paused:bool`, `speed_index:int`, `selected_region:String`, `new_game(p_seed:=-1)`, `stop_game()`, `set_speed(i)`, `toggle_pause()`, `set_menu_paused(on)`, `is_paused()->bool`, `can_perform(action_id, region_id)->bool`, `can_afford(action_id)->bool`, `action_cost(action_id)->Dictionary` (keys budget/political/science), `action_cooldown_left(action_id, region_id)->float` (seconds), `action_cooldown_fraction(...)->float` (0-1), `perform_action(action_id, region_id)->bool`, `get_snapshot()->Dictionary`, `get_region(id)->Dictionary`, `region_ids()->Array`. Actions are allowed while speed is 0 (strategic pause). Action ids/costs/cooldowns/icon ids/i18n keys: `Balance.ACTIONS`, display order `Balance.ACTION_ORDER`.

**CrisisSim** (`scripts/crisis_sim.gd`, RefCounted, no nodes, no autoloads, uses `preload` for balance.gd/region.gd): `regions:Dictionary(id→RegionData)`, `tick`, `temperature`, `budget`, `political`, `science`, `actions_used`, `branch_usage:Dictionary`, `over`, `won`, `reason`, `rng:RandomNumberGenerator`; `_init(p_seed)`, `reset(p_seed)`, `step()->Dictionary {"spreads": [[from,to]...], "toasts": [[key, args, severity]...], "game_over": bool, "won": bool, "reason": String}`, `year()->float`, `sea_health()`, `avg_crisis()`, `avg_awareness()`, `snapshot()`, `region_dict(id)`, `can_afford(action_id)`, `can_perform(action_id, region_id)`, `cooldown_left_ticks(action_id, region_id)->int`, `perform(action_id, region_id)->Dictionary {"ok", "spreads", "toasts"}`.

**RegionData** (`scripts/region.gd`): statics `IDS`, `HERO_ID`, `DEFS`, `ROUTES` (`{"a","b","kind":"current"|"shipping","weight"}`), `polygon_of(id)`, `anchor_of(id)`, `name_key_of(id)`, `neighbors_of(id)`, `region_at(point:Vector2)->String`, `centroid(poly)`; instance state `pollution coral_health seagrass fish_stock awareness protection` (0-100) + `crisis_level()`, `health()`, `status()`, `to_dict()`, `clamp_all()`, `reset()`. Map plane: x = east, y = south; 3D position `Vector3(x, 0, y)`; map spans roughly x −20…22, y −9…11.

**MapBuilder** (`scripts/map_builder.gd`, `extends Node3D`, created by main.gd with `.new()`): `camera: Camera3D`, `set_menu_mode(on:bool)` (true: cinematic idle camera, picking off; false: gameplay framing, picking on), `shake(strength:float)`, `unproject_region(id)->Vector2`. It builds its whole subtree in `_ready()` and listens to EventBus itself.

**UIHud** (`scripts/ui_hud.gd`, `extends Control`, inside CanvasLayer 1): `show_hud()`, `hide_hud()` (animated). Listens to EventBus itself.

**UIMenu** (`scripts/ui_menu.gd`, `extends Control`, inside CanvasLayer 5): signals `start_requested, resume_requested, restart_requested, main_menu_requested, quit_requested`; methods `show_main()`, `show_pause()`, `show_end(won, reason, stats)`, `hide_all()`, `is_open()->bool`, `is_pause_open()->bool`.

**UITheme** (`scripts/ui_theme.gd`, RefCounted): PALETTE consts `BG BG_PANEL HEALTHY CRISIS WARNING ASH AMBER TERRACOTTA TEXT TEXT_DIM` and `health_color(h01)`; map_builder.gd may preload it for colors.

**I18n** (autoload): `t(key, args={})`, `has_key(key)`, `lang`, `LANGS`, `lang_name(code)`, `set_language(code)`.

**main.gd** (written): creates Map, HUD (CanvasLayer 1), Menu (CanvasLayer 5); hotkeys Esc (pause menu), Space (pause toggle), 1/2/3 (1x/2x/4x); user args `--autostart`, `--speed=N`, `--select=id`. Phase 3 adds a CRT CanvasLayer above everything (layer 10).

## 6. Game flow

Main menu (map in menu mode behind a dark overlay) → *New Game* → `GameState.new_game()` + speed 1, HUD in, map gameplay mode → Esc opens pause menu (`set_menu_paused(true)`) → game over: `EventBus.game_over` → main hides HUD, map menu mode, `menu.show_end(...)` → *Play Again* (`restart_requested`) or *Main Menu*.

## 7. Simulation design (module: simulation)

- One tick = `Balance.TICK_SECONDS` (0.6 s) at 1x; `TOTAL_TICKS` = 1000 ticks = 2026→2046 = 10 min at 1x.
- Per region per tick: `delta_pollution = base_rate + Σ(neighbor_pollution × route_weight × coeff) + temp_multiplier(temp) + coastal_pop × inflow − protection × protect_coeff − awareness × aware_coeff`; clamp; then coral / seagrass / fish respond to pollution, heat and protection; awareness and protection decay; resources regenerate (budget scaled by sea health, political by awareness, science trickle).
- Spread: per route per tick, if source crisis > threshold, chance ∝ weight × crisis → bump target pollution, return it in `spreads`, toast `toast.spread` (args `from`/`to` = region name keys), per-route cooldown. Seeded `rng` only — never global `randf()`.
- Temperature: base rise + rise × average crisis; toasts at +2.0/+2.5/+3.0/+3.5.
- Toasts for regions crossing `REGION_CRITICAL_CRISIS` (severity 3) and recovering below `REGION_RECOVERED_CRISIS` (severity 1), low resources (severity 2). Rate-limit: no more than ~1 toast per 3 ticks per kind.
- Win: any tick all regions crisis < 25 → `win_crisis`; at the final tick sea health ≥ 60 → `win_health`, otherwise `lose_time`. Lose any tick: temperature ≥ 4.0, sea health < 10, budget and political both < `DEPLETED_THRESHOLD`.
- Actions (`Balance.ACTIONS`): cleanup (budget → pollution −14), patrol (political → protection +22), campaign (budget+political → awareness +18 here, ×0.35 to route neighbours). Per (action, region) cooldown in ticks. Track `branch_usage[branch] += 1` (Phase 2 evolution input).
- Balance targets: full game 8–12 min at 1x; do-nothing loses (temperature or health) around 2040–2045; spamming one action type does not win; balanced play (an action every ~6–10 s at 1x, spread across regions) wins with sea health ≈ 60–70% in 2046. First 3 minutes dramatic: visible spreads within the first ~20 s and a critical-region alarm within ~60 s.
- `scripts/sim_test.gd` (`extends SceneTree`, run `"$G" --headless --path . -s res://scripts/sim_test.gd`): 1000 ticks × 3 scripted strategies (do-nothing, spam-one-branch, balanced) on fixed seeds; prints a table of outcome, reason, end year, sea health, temperature. It must not touch autoloads (they are absent in `-s` mode).

## 8. Map design (module: map)

- Camera3D: tilt 50–60°, FOV 40–50, frames the whole basin between the HUD side panels (~360 px left, ~420 px right, ~90 px top, ~40 px bottom at 1920×1080); slow subtle drift (position/yaw sine sway) + slight mouse parallax; `set_menu_mode(true)` = slower wider cinematic drift. `shake()` decays over ~0.4 s.
- WorldEnvironment: background `#0B0F19`, glow/bloom on (HDR threshold so only emissive parts bloom), filmic or ACES tonemap, subtle ambient. One DirectionalLight3D.
- Base: dark deep-sea plane under everything with a faint tactical grid (lat/lon lines), optional vignette falloff.
- Land/coast layer: hand-authored stylized land polygons (Iberia, France, Italy + Sicily + Sardinia/Corsica, Balkans, Greece + Crete, Anatolia, Cyprus, Levant coast, North Africa, Black Sea coasts) extruded slightly above the sea surface, dark slate with thin amber/terracotta coastline glow. Land may overlap sea polygons slightly (it renders on top) — use that to make coastlines read naturally.
- Regions: per region a MeshInstance3D built procedurally from `RegionData.polygon_of(id)`: top surface subdivided for waves (boundary + interior grid points → `Geometry2D.triangulate_delaunay()` → keep triangles whose centroid is inside the polygon; if empty, `Geometry2D.triangulate_polygon()`; if still empty, centroid triangle fan — README crash rule 1), side walls down to the base, and an emissive beveled edge ribbon. `cull_mode = CULL_DISABLED` on every material of extruded meshes; `render_mode cull_disabled;` in sea.gdshader.
- `shaders/sea.gdshader` (spatial): uniforms `health` (0-1), `pollution` (0-1), `highlight` (hover 0-1), `selected` (0-1), `flash` (0-1, spread hit), uses TIME and an in-shader procedural noise (no textures). Low health: dark, oily, reddish, damped slow waves, dirty film. High health: bright turquoise, sparkle, animated caustic lines, gentle vertex waves. Script lerps uniforms smoothly toward targets from `region_changed`.
- Routes (`shaders/route.gdshader`): glowing tube/ribbon arcs (quadratic Bézier lifted above the sea) between region anchors for every `RegionData.ROUTES` entry, scrolling emission with small light packets moving along; uniform color: red pulse when it carries crisis (endpoint crisis high), teal when both ends are protected/healthy; shipping vs current visually distinct (e.g. dashed vs smooth).
- Antalya hero marker: glowing amber beam + pulsing ring + `Label3D` with `I18n.t("map.hero_label")`. Region name `Label3D`s at anchors (billboard, no depth test, outline), text via I18n and refreshed on `language_changed`.
- Picking (no physics): ray from `camera.project_ray_origin/normal`, `Plane(Vector3.UP, 0).intersects_ray()` (returns null or Vector3), `RegionData.region_at(Vector2(hit.x, hit.z))`. Hover → `region_hovered`, left click → `region_selected` (click on empty sea/land = `""`). Only in gameplay mode, in `_unhandled_input`.
- Feedback: hover/selected uniforms, flash on `spread_happened`, `shake(0.6)` on toasts with severity 3, subtle pulse on `action_performed` at that region.
- Before the first `region_changed`, show regions using `Balance.REGION_START` values so the menu backdrop already looks alive.

## 9. UI design (module: UI)

- `ui_theme.gd`: `build_theme() -> Theme` with StyleBoxFlat panels (`#111827` at ~0.9 alpha, 1–2 px neon borders, small corner radius 0–2, subtle glow via shadow), angular buttons (normal/hover/pressed/disabled/focus styles; **no default grey buttons**), ProgressBar styles, Tooltip styles, mono `SystemFont` for numbers/labels, larger title font; helpers for animated hover/press (Tween scale/modulate) and a corner-bracket frame drawn in `_draw()`.
- `icons.gd` (`extends Control`): `icon_id` + `color`, drawn in `_draw()` with antialiased primitives, readable at 32–64 px: budget, political, science, temperature, sea_health, crisis, awareness, pollution, coral, seagrass, fish, protection, pause, play, fast, faster, cleanup, patrol, campaign, globe/language, warning.
- `charts.gd`: temperature gauge (+1.5 → +4.0 °C arc gauge, danger zone, animated needle), segmented stat bar with number tick-up animation (reusable for global and region stats). (The Phase 2 live line chart may be added here later.)
- `ui_hud.gd`: top bar (year, years left, progress, speed buttons with icons II/1x/2x/4x and active state, resource counters with icons and tick-up numbers); left panel "BASIN STATUS" (sea health, crisis, awareness bars, temperature gauge, goal and limit lines); right panel "REGION" (selected region name + status badge + six stat bars + crisis; FIELD OPERATIONS buttons from `Balance.ACTION_ORDER` with icon, name, cost, cooldown progress, disabled when unaffordable/cooling down, tooltip = desc; hint when nothing selected); toast feed (last ~4, slide/fade, color by severity). Reserve a ~32 px strip at the very top for the Phase 2 news ticker. Everything updates from EventBus, re-translates on `language_changed`.
- `ui_menu.gd`: cinematic main menu over the live map (dark gradient overlay, title fade/letter-spacing tween, subtitle, tagline, briefing, *New Game*, language selector = three toggle buttons with native names, *Quit*, event line and controls line); pause menu (title, Resume, Restart, language selector, Main Menu, Quit to Desktop); end screen (won/lost title + text by reason, stats from the stats dict, Play Again, Main Menu). Panels fade/slide with Tweens. All re-translate on `language_changed`.

## 10. Localization

`i18n.gd` holds every key with `en` text; the localization module completes `tr` and `ru` for all keys (natural, concise game UI language; Turkish uppercase variants spelled correctly: İ/I, e.g. "AKDENİZ'İN NABZI"). If you add a key in your module, report it with its English text; the localization pass adds it to `i18n.gd`.
