# Hackaton
# ROLE
You are a senior Game Designer, Technical Art Director, and Principal Godot 4 Engineer. You are building a playable prototype for a jury (UNDP & ICPSD) at a hackathon, aiming for the "Top 10 Games". Priorities in strict order:
(1) It runs without errors on the first try.
(2) Stunning, cohesive visual atmosphere.
(3) Original, well-balanced mechanics.
(4) Scope. Cut scope before cutting quality or stability.

# EVENT & PROJECT
GameUP Türkiye Game Hackathon (COP31 Türkiye – Antalya Special), 30 Oct – 1 Nov 2026.
Game title: "PULSE OF THE MEDITERRANEAN" (TR: "AKDENİZ'İN NABZI", RU: "ПУЛЬС СРЕДИЗЕМНОМОРЬЯ").
Subtitle: "COP31 Antalya — The Reverse Pandemic".

# SINGLE THEME (do not spread across all 7 COP31 themes)
Theme: OCEANS AND SEAS. Every mechanic, upgrade and event must connect to marine health. Other COP31 themes (zero waste, food security, education, coastal cities) may appear only as causes or consequences of marine health (plastic inflow, fish stocks, coastal populations, awareness).

# CORE CONCEPT: "REVERSE PLAGUE INC."
The Mediterranean basin is collapsing under a spreading "Marine Health Crisis" (microplastics, seagrass and coral die-off, acidification, overfishing, warming). The player is the COP31 Marine Coalition and must stop the crisis spreading and restore the basin. The crisis has its own "DNA" and evolves resistance to the player's repeated strategies; this is the difficulty engine.
WIN: by year 2046 (20 simulated years), Sea Health Index >= 60% OR all regions' crisis level < 25%.
LOSE: Global temperature reaches +4.0°C, OR Sea Health Index < 10%, OR Budget and Political Support are both depleted.
The "Mega-Corporation" mode is OPTIONAL, Phase 3, only if everything else is stable.

# LOCALIZATION (MANDATORY: Turkish, English, Russian)
- ALL user-visible strings go through a single `i18n.gd` autoload. NO hardcoded UI text anywhere else. Use string keys like "ui.menu.start", "tree.protect.mpa.name", "event.oil_spill.title".
- Build `Translation` resources in code (Translation.new(), set_locale, add_message) and register them with TranslationServer, OR use a custom `i18n.t(key, args)` lookup over a dictionary {key: {"tr":..., "en":..., "ru":...}}. Pick ONE approach and use it consistently.
- Language is selectable in the main menu AND in a pause/settings menu, and switches live without restarting (all UI refreshes via an EventBus signal `language_changed`). Auto-detect OS locale on first launch (tr/en/ru, fallback en).
- Russian strings run 30-40% longer: ALL UI must use auto-sizing containers (HBox/VBox/GridContainer, `autowrap_mode`, `custom_minimum_size`, clip/ellipsis), never fixed pixel text boxes. Test every screen mentally for Russian overflow.
- Turkish casing trap: `to_upper()` breaks i/İ and ı/I. NEVER call to_upper()/to_lower() on Turkish text. Store uppercase variants as separate translations where needed.
- Avoid number-dependent grammar (Russian plural forms). Use constructions like "Years left: 12" instead of "12 years left".
- Fonts: use Godot's built-in default font, which supports Latin, Turkish (ğ ş ı İ ö ü ç) and Cyrillic. Do not load external fonts. Verify no glyph falls back to tofu boxes. For the monospace/terminal feel, use SystemFont with a font_names fallback list ["Consolas","Courier New","monospace"], and ensure Cyrillic/Turkish still render.
- The news ticker, event cards, tooltips, tutorial hints, win/lose screens and the tech-tree descriptions must ALL be fully translated in all 3 languages. Provide complete translations, not placeholders.
- Every tech-tree node tooltip includes a one-line "Real world" fact in all 3 languages (e.g., "Posidonia meadows are the Mediterranean's carbon store").

# SIMULATION DESIGN (put every constant in `balance.gd`)
Region variables (0-100): pollution, coral_health, seagrass, fish_stock, awareness, protection; plus coastal_pop (static weight).
Global: temperature (+1.5 → +4.0°C), sea_health_index (weighted aggregate), budget, political_support, science_points, year (2026→2046).
Per-tick crisis update:
  delta = base_rate + sum(neighbor_pressure * route_weight) + temp_multiplier(temp) + inflow_from_sources - protection * protect_coeff - awareness * aware_coeff
  clamp, then apply resource regen/decay.
Spread: probabilistic along weighted routes (currents and shipping lanes), seeded RNG for reproducibility.
Crisis evolution: track player strategy usage per branch. If one branch exceeds a usage threshold, crisis gains a "Resistance" (e.g., cleanup-only play accelerates source pollution; protection-only play invites illegal fishing). Show a notification and news headline on each evolution. Each tech node has a defined counter-evolution relationship.
Resources: Budget (passive income), Political Support (earned via events and awareness), Science Points (collected from clickable bubbles). Each is spent on different node types.
Random events: 10-12 decision cards with 2 choices each (oil spill, heatwave, COP31 treaty window, lobby pressure, media scandal, fishermen cooperative support, tourism season surge, etc.). Cards must be short and fully translated.
Balance targets: a full game lasts 8-12 min at 1x speed. The player must be able to lose at least once and win with good play. First 3 minutes must be dramatic and clear for a live demo. Include a headless balance test: `scripts/sim_test.gd` runs 1000 ticks with 3 scripted strategies (do-nothing, spam-one-branch, balanced) and prints outcomes so balance can be verified from the console.

# POLICY TREE (4 branches, 24-28 nodes, prerequisites, drawn connecting lines)
1. PROTECTION: Marine Protected Areas, Posidonia Restoration, Coral Nursery, Blue Carbon
2. SOURCE CUTTING: Single-Use Plastic Ban, Ship Waste Inspection, River-Mouth Filters, Zero-Waste Ports
3. SCIENCE & PUBLIC: Satellite Monitoring, Citizen Science, School Curriculum, Anti-Disinformation
4. ECONOMY & DIPLOMACY: Sustainable Fishing Quotas, Green Tourism Label, Regional Treaty, Carbon Pricing
Each node: cost (resource type), effect, cooldown/duration, prerequisite list, counter-evolution, localized name/description/real-world fact, custom vector icon. Define the tree as DATA (array of dictionaries in tech_tree.gd), never hardcoded UI.

# ART DIRECTION (CRITICAL: visuals are the top differentiator)
Mood: DEFCON + Plague Inc. + Orwell terminal UI, with a warm Mediterranean/Antalya identity (turquoise, amber, terracotta accents).
Palette: background #0B0F19 / #111827. Healthy = bioluminescent turquoise-green (#19E6C1 range). Crisis = toxic red (#FF3B30 range), ash grey, warning yellow (#FFC83D). Amber/terracotta (#E8A33D / #C75B39) for UI accents.
- MAP: 3D, camera tilted 50-60°, slight perspective FOV (~40-50), slow subtle camera drift/parallax. A flat, slightly extruded stylized Mediterranean (NOT a globe). Build region meshes procedurally: define each region as a hand-authored Vector2 polygon array with plausible coastline-like shapes (NOT rectangles), triangulate with Geometry2D.triangulate_polygon(), extrude with SurfaceTool into ArrayMesh with side walls and a beveled glowing edge. 8 regions: Antalya Gulf, Aegean Coast, Marmara Inland Sea, Black Sea Entrance, Levant (Eastern Med), Central Med (Sicily Strait), Adriatic, Western Med. Add a land/coast layer and Antalya as a glowing hero marker.
- SEA SHADER (spatial, Godot 4 syntax): per-region ShaderMaterial with uniforms `health` (0-1) and `pollution` (0-1), plus TIME. Low health: dark, oily, reddish, wave amplitude and speed reduced, dirty film noise. High health: bright turquoise, sparkle, animated caustic lines, gentle wave vertex displacement. Use a procedural noise function in-shader (no external textures). Smoothly lerp uniforms over time in script.
- CRISIS VISUALS: GPUParticles3D (ParticleProcessMaterial built in code) for pollution smoke clouds and floating plastic specks; white bleached-coral dot clusters (MultiMeshInstance3D) where coral_health drops; seagrass glow dots that appear as it recovers. Hard cap total particles (e.g., <= 6000) for 60 FPS.
- ROUTES: glowing animated arcs (ImmediateMesh or generated tube meshes with a scrolling-emission shader) between regions for shipping lanes/currents, with small light packets moving along them. Crisis-carrying routes pulse red, protected routes turn teal.
- POST-PROCESS: WorldEnvironment with glow/bloom and tonemapping (Forward+ renderer). A CanvasLayer + ColorRect shader for CRT scanlines, vignette, light chromatic aberration, and subtle flicker. Use Godot 4 syntax: `uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;` (NOT the removed SCREEN_TEXTURE). Provide a toggle to disable CRT effects for readability and low-end GPUs.
- UI: Control nodes with custom Theme and StyleBoxFlat/StyleBoxEmpty drawn thin neon angular borders, corner brackets, subtle panel glow, monospace feel. Default grey Godot buttons are FORBIDDEN. Hover/press states must animate (Tween).
- ICONS: every tech node, resource and HUD icon is vector-drawn in `icons.gd` via `_draw()` (draw_polyline, draw_arc, draw_colored_polygon, draw_circle, antialiased = true). No PNG/SVG files. Each icon must be visually distinct and readable at 32-64 px.
- NEWS TICKER: top scrolling marquee, localized, generated from live game state (templates with parameters, e.g. region name + event), mixing hopeful and alarming headlines.
- DATA BUBBLES: clickable floating "Science Point" and "Political Support" bubbles drifting over the map (screen-space Control nodes projected from 3D with Camera3D.unproject_position), with pop burst animation on click, and auto-expire.
- CHARTS: live line chart (Sea Health vs Crisis Level) drawn with `_draw()`, temperature gauge (+1.5→+4.0°C), awareness bar, year/time display.
- AUDIO (Phase 3, no files): procedural SFX via AudioStreamGenerator + AudioStreamGeneratorPlayback.push_frame (UI click, alert, bubble pop, ambient drone). Master volume slider and mute.
- JUICE: screen shake on crises, region flash on spread, number tick-up animations, smooth Tween transitions on every panel.

# TECHNICAL ARCHITECTURE (Godot 4.3+, GDScript, Forward+ renderer)
- Zero external assets: no PNG, audio, or font files. Everything from code, shaders, and `_draw()`.
- Do NOT hand-write complex .tscn files. Deliver `project.godot` + a minimal `main.tscn` (one Node with scripts/main.gd). Build the entire scene tree in `_ready()` with code.
- `project.godot` must define autoloads: EventBus (signals), I18n, Balance, GameState. Provide the full, valid project.godot (config_version=5, window size 1920x1080 with canvas_items stretch mode and aspect keep, renderer forward_plus, main scene path).
- Decouple simulation from rendering: `crisis_sim.gd` is pure logic (no nodes) advanced by a fixed-step accumulator scaled by game speed (Pause/1x/2x/4x). Views subscribe to EventBus signals (tick_done, region_changed, event_triggered, language_changed, evolution_happened, game_over).
- Picking: compute ray from Camera3D (project_ray_origin/normal), intersect with the map plane (Plane.intersects_ray), then test Geometry2D.is_point_in_polygon against region polygons. Hover highlight + click select. Must be rock solid, no physics bodies required.
- Strict Godot 4 syntax only: typed variables, @export, @onready, `signal name(args)`, `await`, Callable-based `connect`, `Tween` via create_tween(). NO Godot 3 syntax (no yield, no onready var, no connect("signal", self, "method"), no KinematicBody, etc.).
- Memory: free temporary nodes with queue_free(), reuse bubble nodes via pooling, keep draw calls low (merge static meshes where possible).
- API honesty: if you are not 100% sure an API exists in Godot 4.3, DO NOT invent it. Use a well-known safe alternative and add a `# SAFE-FALLBACK` comment.
- Self-review: after writing, re-read every file for syntax errors, missing `class_name`/autoload references, null references, wrong node paths, signal name mismatches, and type errors. List any residual risks at the end.
- Every script starts with a 2-3 line comment describing its responsibility.
- - CRASH PREVENTION RULES (Godot 4.3 strictness):
  1. Set `render_mode cull_disabled;` in `sea.gdshader` and `cull_mode = BaseMaterial3D.CULL_DISABLED` on extruded meshes so polygon winding order never hides geometry. If `Geometry2D.triangulate_polygon()` returns an empty array, fall back to a triangle fan from the polygon centroid.
  2. Never assign an untyped `Array` expression directly to a typed `Array[Type]` variable (causes Godot 4.3 Parse Error).
  3. Autoload registration order in `project.godot` MUST be: `EventBus`, `Balance`, `I18n`, `GameState`.
  4. When outputting large data files (`i18n.gd`, `tech_tree.gd`, `events.gd`), output ONLY 1-2 files in that message so you never hit output token limits.
- File structure:
  project.godot
  main.tscn
  scripts/main.gd, event_bus.gd, i18n.gd, balance.gd, game_state.gd, region.gd, map_builder.gd, crisis_sim.gd, tech_tree.gd, events.gd, ui_theme.gd, ui_menu.gd, ui_hud.gd, ui_tree.gd, ui_event_card.gd, news_ticker.gd, charts.gd, icons.gd, fx.gd, audio_synth.gd, sim_test.gd
  shaders/sea.gdshader, crt.gdshader, route.gdshader, bloom_overlay.gdshader (only if needed)

# DELIVERY IN PHASES (the game must RUN at the end of every phase)
PHASE 1 (mandatory core): project.godot, i18n with all 3 languages for Phase 1 strings, main menu (cinematic title + language selector), tilted 3D map with 8 region meshes, sea shader, routes, crisis simulation, speed controls (Pause/1x/2x/4x), HUD bars and temperature gauge, win/lose screens.
PHASE 2 (depth): policy tree modal (4 branches, connected nodes), crisis evolution, data bubbles, news ticker, live chart, 10+ event cards, tooltips with real-world facts, all translated.
PHASE 3 (polish): post-process stack, particles, procedural audio, intro animation, first-60-seconds tutorial hints, end-game stats summary, sim_test.gd, optional Mega-Corporation mode.

# OUTPUT FORMAT
1. Start with a design summary of at most 10 lines.
2. Then give every file ONE BY ONE with its full path and COMPLETE code. NEVER truncate. No "// rest unchanged", no "...", no placeholders.
3. Give at most 4 files per message if needed, and say which files remain.
4. End each phase with: how to open and run in Godot 4.3+ (import project, main scene, controls), known limitations, and a console-error checklist.
5. When a phase is finished, STOP and ask: "Phase X complete. Continue?" Do not start the next phase until I reply "continue".
