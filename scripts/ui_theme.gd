extends RefCounted
## UITheme: shared palette and the Theme factory for the terminal / DEFCON look.
## The PALETTE section is a frozen contract also used by the 3D map (map_builder.gd);
## the UI module owns everything below it and may extend freely.

# --- PALETTE (do not rename) ------------------------------------------------------
const BG := Color(0.0431, 0.0588, 0.0980)          # #0B0F19
const BG_PANEL := Color(0.0667, 0.0941, 0.1529)    # #111827
const HEALTHY := Color(0.0980, 0.9020, 0.7569)     # #19E6C1 bioluminescent turquoise
const CRISIS := Color(1.0, 0.2314, 0.1882)         # #FF3B30 toxic red
const WARNING := Color(1.0, 0.7843, 0.2392)        # #FFC83D warning yellow
const ASH := Color(0.4196, 0.4471, 0.5020)         # #6B7280 ash grey
const AMBER := Color(0.9098, 0.6392, 0.2392)       # #E8A33D UI accent
const TERRACOTTA := Color(0.7804, 0.3569, 0.2235)  # #C75B39 UI accent
const TEXT := Color(0.847, 0.890, 0.918)           # #D8E3EA
const TEXT_DIM := Color(0.498, 0.557, 0.639)       # #7F8EA3


## Health 0-1 -> crisis red ... warning yellow ... healthy turquoise.
static func health_color(health01: float) -> Color:
	var h: float = clampf(health01, 0.0, 1.0)
	if h < 0.5:
		return CRISIS.lerp(WARNING, h * 2.0)
	return WARNING.lerp(HEALTHY, (h - 0.5) * 2.0)
