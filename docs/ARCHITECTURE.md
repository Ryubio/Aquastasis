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
# single screenshots at chosen frames (much lighter than --write-movie); args after -- also reach main.gd
"$G" --path . --resolution 1920x1080 --fixed-fps 30 res://tools/shot.tscn -- --autostart --speed=3 --select=antalya --shot=300:shots/game.png
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

**Snapshot** (`GameState.get_snapshot()`, `tick_done`): `tick:int, year:float, year_int:int, years_left:int, progress:float(0-1), temperature:float(°C above pre-industrial, 1.5→4.0), sea_health:float(0-100), crisis:float(0-100 avg), awareness:float(0-100 avg), budget:float, political:float, science:float, actions_used:int, spreads:int, speed_index:int`.

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
- Refinements in the implementation: protection/awareness pollution reduction scales with pollution / 50 (regions settle instead of running to 0/100); cleanup removes `15 × clamp(pollution / 50, 0.6, 1.4)`; patrol/campaign gains shrink as protection/awareness fill up; `lose_resources` needs both resources depleted for `DEPLETED_GRACE_TICKS` (15) consecutive ticks; loses are checked before wins on the same tick; spread rolls once per route per tick from the sicker to the healthier end.
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

## 11. Phase 2 contract (policy tree, crisis evolution, decision events, data bubbles, news, live chart)

Phase 2 scope (README "DELIVERY IN PHASES"): policy tree modal (4 branches, connected nodes), crisis evolution, data bubbles, news ticker, live chart, 10+ event cards, tooltips with real-world facts, all translated. Teammate ideas from `Fikr` that are in scope are folded in below (mucilage / tourism / trawler cards, COP31 summits in 2031/2036/2041, Q/W/E hotkeys, blue-carbon income, negative-income warning).

### 11.1 Modules and file ownership

| Module | Owns | Starts |
|---|---|---|
| content | `scripts/tech_tree.gd` (NODES, EVOLUTIONS), `scripts/events.gd` (EVENTS), `scripts/i18n_tree.gd`, `scripts/i18n_events.gd` (English) | first |
| simulation | `scripts/crisis_sim.gd`, `scripts/balance.gd`, `scripts/sim_test.gd`, `scripts/i18n_sim.gd`; internals of `scripts/game_state.gd` (public API frozen). After content finishes it may also tune values and the matching English text in the four content files | after content |
| tree UI | `scripts/ui_tree.gd`, `scripts/ui_event_card.gd`, `scripts/icons.gd`, `scripts/i18n_ui_tree.gd` | after content |
| HUD | `scripts/ui_hud.gd`, `scripts/news_ticker.gd`, `scripts/fx.gd`, `scripts/charts.gd`, `scripts/ui_theme.gd` (append only; PALETTE frozen), `scripts/i18n_hud.gd` | first |
| integration | `main.gd`, `event_bus.gd`, `i18n.gd`, `region.gd`, `map_builder.gd`, shaders, docs | - |

Already written and frozen: EventBus signals (section 4 plus the Phase 2 block in `event_bus.gd`); the GameState Phase 2 API in `scripts/game_state.gd` (pause reasons; `node_state/node_ramp/node_cost/can_adopt/adopt_node/adopted_nodes`; `active_evolutions/evolution_pressure`; `current_event/can_choose/resolve_event/debug_force_event`; `active_bubbles/collect_bubble`; `get_history`); CrisisSim Phase 2 stubs (end of `crisis_sim.gd`, incl. `force_event`); the API stubs of `ui_tree.gd` (`open/close/toggle/is_open`), `ui_event_card.gd` (`is_open/close_now`), `fx.gd` (`map`, `clear_all`), `news_ticker.gd` (`clear`); and `main.gd` wiring: CanvasLayers FX 1, HUD 2, tree 3, event card 4, menu 5; hotkeys T (tree), Q/W/E (field operations on the selected region), Esc closes the tree first; user args `--tree` and `--event=<id>` (dev/screenshot hooks).

Modal pause: the tree calls `GameState.set_pause_reason("tree", on)`; an event card is paused by GameState itself (`"event"`) until `resolve_event()`. While a card waits, field operations and adoptions are refused.

### 11.2 Effect vocabulary (nodes, evolutions, event choices)

Each effect is a Dictionary:
- `{"op": "mul", "key": <MUL key>, "value": 0.8}` - persistent multiplier (1.0 = no change) while the node is adopted (scaled by its ramp: `1 + (value - 1) * ramp`), while the evolution is active, or for `"ticks": N` after an event choice.
- `{"op": "add", "key": <ADD key>, "value": 0.05}` - persistent additive term, same lifetime rules.
- `{"op": "region", "stat": "pollution" | "coral_health" | "seagrass" | "fish_stock" | "awareness" | "protection", "value": -12, "target": "all" | "event" | "worst" | "best" | "hero" | <region id>}` - one-shot change ("event" = the card's region; worst/best by crisis).
- `{"op": "resource", "key": "budget" | "political" | "science", "value": 40}` - one-shot.
- `{"op": "temperature", "value": -0.05}` - one-shot.

MUL keys (default 1.0): `inflow_mult` (coastal/river source inflow), `base_pollution_mult`, `neighbor_pressure_mult`, `spread_chance_mult`, `spread_damage_mult`, `heat_stress_mult`, `temp_rise_mult`, `coral_heat_mult`, `coral_recovery_mult`, `seagrass_recovery_mult`, `fishing_mult`, `fish_regen_mult`, `protect_effect_mult`, `aware_effect_mult`, `protect_decay_mult`, `awareness_decay_mult`, `budget_income_mult`, `political_income_mult`, `science_income_mult`, `cleanup_power_mult`, `patrol_power_mult`, `campaign_power_mult`, `action_cost_mult`, `node_cost_mult`, `bubble_rate_mult`, `bubble_value_mult`.
ADD keys (default 0.0): `budget_per_tick`, `political_per_tick`, `science_per_tick`, `blue_carbon` (budget per tick per region whose seagrass is above `Balance.BLUE_CARBON_SEAGRASS`), `protection_floor`, `awareness_floor` (minimum level kept in every region).

The simulation recomputes the whole modifier set every tick from scratch (adopted nodes with ramp, active evolutions, live timed event effects), so effects never stack by accident.

### 11.3 Policy tree data (`tech_tree.gd` NODES, 24-28 nodes)

Node schema: `{"id": "protect_mpa", "branch": "protect", "tier": 1-4, "slot": 0-1, "cost": {"budget": 0, "political": 25, "science": 0}, "requires": [ids], "ramp_ticks": 30, "effects": [...], "counters": [evolution id], "icon": "<icon id>", "name_key": "tree.protect_mpa.name", "desc_key": "tree.protect_mpa.desc", "fact_key": "tree.protect_mpa.fact"}`. Node ids are `<branch>_<name>`; keys follow `tree.<id>.name|desc|fact`. States: locked (requirements missing), available, adopted (permanent; effect ramps in over `ramp_ticks`).

Branches and main currency (README: each resource is spent on different node types):
- PROTECTION, political support (+ budget on late tiers): Marine Protected Areas, Posidonia Restoration, Coral Nursery, Blue Carbon, plus 2-3 more (e.g. Monk Seal and Caretta Sanctuaries, No-Take Zones).
- SOURCE CUTTING, budget: Single-Use Plastic Ban, Ship Waste Inspection, River-Mouth Filters, Zero-Waste Ports, plus 2-3 more (e.g. Ghost-Net Recovery, Wastewater Upgrade).
- SCIENCE & PUBLIC, science points: Satellite Monitoring, Citizen Science, School Curriculum, Anti-Disinformation, plus 2-3 more (e.g. Mucilage Early Warning for Marmara, Ocean Data Hub).
- ECONOMY & DIPLOMACY, political support + budget: Sustainable Fishing Quotas, Green Tourism Label, Regional Treaty, Carbon Pricing, plus 2-3 more (e.g. Blue Bonds, Fishers Transition Fund).

Each tier needs the previous tier of its branch; tiers 3-4 may also require one node of another branch. The `desc_key` text states the effect in plain words with the same numbers as the data. The `fact_key` text is one real, verifiable sentence used as the "Real world" line.

Counter-evolution relationship (README): every node lists one evolution in `counters`. Adopting it cures that evolution if active and makes the crisis immune to it afterwards. Every evolution has 2-4 counter nodes, at least one outside the branch that provokes it.

### 11.4 Crisis evolution (`tech_tree.gd` EVOLUTIONS)

The simulation keeps the last `EVO_WINDOW` player moves (field operations by `Balance.ACTIONS[].branch`, adoptions by node branch). After `EVO_MIN_MOVES` moves, if one branch's share is at least `EVO_SHARE`, the crisis evolves that branch's resistance (once). Six resistances:
- `source_surge` (branch source: cleanup-only play): production shifts upstream, `inflow_mult` up.
- `illegal_fishing` (branch protect: protection-only play): poachers move in, `fishing_mult` up.
- `disinformation` (branch science): campaign fatigue and fake news, `awareness_decay_mult` up, `political_income_mult` down.
- `lobby_backlash` (branch economy): industry pushes back, `node_cost_mult` up, `political_income_mult` down.
- `marine_heatwave` (trigger "heat": temperature at least `EVO_HEAT_TEMP`): `coral_heat_mult` and `heat_stress_mult` up.
- `invasive_species` (trigger "spread": spread count at least `EVO_SPREAD_COUNT`; Suez and ballast water): `spread_chance_mult` up.

Each evolution produces a toast (severity 3), a news headline (`news_key`) and `EventBus.evolution_happened`; curing produces `cured_news_key` and `EventBus.evolution_cured`. `evolution_pressure()` lets the UI warn before it happens.

### 11.5 Decision events (`events.gd` EVENTS, 10-12 cards)

Schema in `events.gd`. Two choices each; a choice whose cost is unaffordable is disabled; at least one choice per card costs nothing. Text may use `{region}` (the card's region name). Cards: oil spill, marine heatwave, COP31 summits (scheduled `at_tick` 250 / 500 / 750 = 2031 / 2036 / 2041), lobby pressure, media scandal (greenwashing), fishers' cooperative, tourism season surge (Antalya / Aegean), Marmara mucilage outbreak, foreign trawlers, ghost-net discovery, Caretta caretta nesting season, invasive lionfish from Suez. Random cards: first around tick 60-80, then every `EVENT_INTERVAL_MIN..MAX` ticks (target 9-12 cards per game including summits). The simulation picks the region by `region_rule`, applies the chosen effects, and emits a result toast plus a news headline.

### 11.6 Data bubbles

The simulation rolls bubbles each tick (`BUBBLE_CHANCE_PER_TICK x bubble_rate_mult`, at most `BUBBLES_MAX` alive): kind `"science"` (most) or `"political"`, a region (political weighted toward high awareness), `amount`, `ttl` ticks. `step()` returns `bubbles_spawned` / `bubbles_expired`; `collect_bubble(id)` pays `amount x bubble_value_mult`. `fx.gd` draws them as pooled screen-space Controls at `map.unproject_region(region)` plus a per-bubble offset, bobbing; click = `GameState.collect_bubble(id)`, pop burst and a floating "+N" label; fade on expiry. Bubbles are the main science income.

### 11.7 News ticker

Headlines come from `EventBus.news(key, args, tone)` (simulation: spreads, alarms, recoveries, temperature milestones, adoptions, evolutions, event outcomes) and from ambient templates the ticker generates every few seconds from live state (region stats, trends, real Mediterranean facts), mixing hopeful and alarming items. Items are stored as key + args and re-rendered on `language_changed`. Marquee in the HUD's 32 px top strip, tone-colored, continuous scroll.

### 11.8 Live chart and HUD additions

`GameState.get_history()` returns `[[tick, sea_health, crisis], ...]` sampled every `Balance.HISTORY_EVERY` (10) ticks. `charts.gd` adds a line chart (Sea Health vs Crisis, 2026-2046 x-axis, goal line at 60) placed in the BASIN STATUS panel. The HUD also adds: a POLICY TREE button with hotkey hint (emits `EventBus.tree_toggle_requested`), an active-resistances list with counter hints, an evolution-pressure warning, net income per year next to each resource with a red pulse when budget income is negative (the "death spiral" warning; snapshot keys `budget_rate`, `political_rate`, `science_rate` = net income per tick before spending), and Q/W/E hints on the field-operation buttons.

### 11.9 Layout reservations (1920x1080)

Ticker strip y 0-32 (HUD); top bar y 32-92; left panel x 16-356 from y 106 (status, gauge, then live chart, then resistances); right panel x 1500-1904 (region, field operations, then the tree button); toasts bottom-left; bubbles over the map area only. Tree modal: centered about 1600x860 over a dimmed backdrop (4 branch columns, node grid with drawn prerequisite links, a details pane with name, cost, effect text, counter evolution and "Real world" fact, an ADOPT button, an evolution-pressure strip). Event card: centered, about 760 px wide.

### 11.10 Icons

The tree UI module owns `icons.gd` and adds: one distinct icon per node (`icon` field), one per branch (`branch_protect`, `branch_source`, `branch_science`, `branch_economy`), one per evolution and per event, plus `tree`, `evolution`, `event`, `news`, `bubble_science`, `bubble_political` for the HUD.

### 11.11 String tables

`i18n.gd` merges `STRINGS` with `i18n_tree.gd`, `i18n_events.gd`, `i18n_sim.gd`, `i18n_ui_tree.gd`, `i18n_hud.gd` (owners in 11.1). Builders write `"en"`; the localization pass adds `"tr"` and `"ru"` to every key. Keys must be unique across tables (I18n warns on duplicates).

### 11.12 Phase 2 balance targets (sim_test)

All Phase 1 targets still hold with the new systems on. Bots now also adopt nodes, answer cards and collect about 60% of bubbles. Do-nothing loses 2040-2045. Spamming one branch (operations plus nodes) triggers its resistance within about 3-5 minutes of game time and does not win. Balanced play (diversified operations and adoptions, sensible card choices) wins with sea health about 60-75%. 9-12 cards per game; the first evolution of a one-sided bot around 2030-2033; a balanced bot adopts roughly 14-20 nodes by 2046 (not all).
