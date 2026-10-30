extends Node
## Balance (autoload): every tunable number of the game lives here, nothing else.
## crisis_sim.gd and region.gd read it via preload (works headless without autoloads);
## other scripts may use the Balance singleton. Tune values freely; keep names stable.

# --- Time ---------------------------------------------------------------------
const TICK_SECONDS := 0.6          # real seconds per simulation tick at 1x
const TOTAL_TICKS := 1000          # 2026 -> 2046 at 1x is 600 s = 10 minutes
const START_YEAR := 2026
const END_YEAR := 2046
const SPEEDS := [0.0, 1.0, 2.0, 4.0]   # index 0 = pause, 1 = 1x, 2 = 2x, 3 = 4x
const MAX_TICKS_PER_FRAME := 8     # guard against frame spikes at 4x
const DEFAULT_SEED := 31

# --- Global climate -------------------------------------------------------------
const TEMP_START := 1.5            # degrees C above pre-industrial
const TEMP_LOSE := 4.0
const TEMP_BASE_RISE_PER_TICK := 0.0008
const TEMP_CRISIS_RISE_PER_TICK := 0.0028   # multiplied by average crisis / 100
const TEMP_STRESS_COEFF := 0.05    # extra regional stress per tick per degree above TEMP_START

# --- Crisis level of a region (weights sum to 1) --------------------------------
const CRISIS_W_POLLUTION := 0.4
const CRISIS_W_CORAL := 0.2
const CRISIS_W_SEAGRASS := 0.2
const CRISIS_W_FISH := 0.2
const STATUS_STRESSED := 30.0      # crisis >= this -> "stressed"
const STATUS_CRITICAL := 55.0      # crisis >= this -> "critical"
const STATUS_COLLAPSED := 75.0     # crisis >= this -> "collapsed"

# --- Per-tick regional dynamics (all values are 0-100 scales) -------------------
const BASE_POLLUTION_RATE := 0.06
const SOURCE_INFLOW_COEFF := 0.05      # x coastal_pop: rivers, sewage, plastic inflow
const NEIGHBOR_PRESSURE_COEFF := 0.0012  # x neighbour pollution x route weight
const PROTECT_COEFF := 0.0015          # x protection: pollution reduction
const AWARE_COEFF := 0.0012            # x awareness: pollution reduction
const CORAL_POLLUTION_DAMAGE := 0.045  # x pollution / 100
const CORAL_HEAT_DAMAGE := 0.03        # x degrees above TEMP_START
const CORAL_RECOVERY := 0.05           # x protection / 100
const SEAGRASS_POLLUTION_DAMAGE := 0.05
const SEAGRASS_HEAT_DAMAGE := 0.02
const SEAGRASS_RECOVERY := 0.055
const FISHING_PRESSURE := 0.05         # x (1 - protection / 100)
const FISH_POLLUTION_DAMAGE := 0.03
const FISH_REGEN := 0.06               # logistic regrowth rate
const AWARENESS_DECAY_PER_TICK := 0.02
const PROTECTION_DECAY_PER_TICK := 0.03

# --- Spread along routes ----------------------------------------------------------
const CURRENT_WEIGHT_MULT := 1.0
const SHIPPING_WEIGHT_MULT := 0.8
const SPREAD_THRESHOLD := 45.0         # source crisis needed before it can spread
const SPREAD_CHANCE_PER_TICK := 0.02   # x route weight x source crisis / 100
const SPREAD_POLLUTION_BUMP := 6.0
const SPREAD_ROUTE_COOLDOWN_TICKS := 25

# --- Resources ------------------------------------------------------------------
const BUDGET_START := 220.0
const POLITICAL_START := 60.0
const SCIENCE_START := 10.0
const BUDGET_INCOME_PER_TICK := 1.4    # scaled by economy (sea health)
const POLITICAL_INCOME_PER_TICK := 0.15  # scaled by average awareness
const SCIENCE_INCOME_PER_TICK := 0.05  # Phase 1 passive trickle; bubbles add more in Phase 2
const RESOURCE_CAP := 999.0
const DEPLETED_THRESHOLD := 1.0        # both budget and political below this -> lose

# --- Win / lose -------------------------------------------------------------------
const WIN_SEA_HEALTH := 60.0           # checked at END_YEAR
const WIN_ALL_CRISIS_BELOW := 25.0     # checked every tick: early win
const LOSE_SEA_HEALTH := 10.0

# --- Toast thresholds ---------------------------------------------------------------
const REGION_CRITICAL_CRISIS := 70.0
const REGION_RECOVERED_CRISIS := 35.0

# --- Phase 1 field operations (per region) ---------------------------------------
## cost keys: "budget", "political", "science". branch feeds Phase 2 crisis evolution.
const ACTIONS := {
	"cleanup": {
		"branch": "source",
		"cost": {"budget": 40.0},
		"cooldown_ticks": 12,
		"icon": "cleanup",
		"name_key": "action.cleanup.name",
		"desc_key": "action.cleanup.desc",
		"toast_key": "toast.action.cleanup",
	},
	"patrol": {
		"branch": "protect",
		"cost": {"political": 12.0},
		"cooldown_ticks": 16,
		"icon": "patrol",
		"name_key": "action.patrol.name",
		"desc_key": "action.patrol.desc",
		"toast_key": "toast.action.patrol",
	},
	"campaign": {
		"branch": "science",
		"cost": {"budget": 20.0, "political": 4.0},
		"cooldown_ticks": 20,
		"icon": "campaign",
		"name_key": "action.campaign.name",
		"desc_key": "action.campaign.desc",
		"toast_key": "toast.action.campaign",
	},
}
const ACTION_ORDER := ["cleanup", "patrol", "campaign"]
const CLEANUP_POLLUTION_DROP := 14.0
const PATROL_PROTECTION_GAIN := 22.0
const CAMPAIGN_AWARENESS_GAIN := 18.0
const CAMPAIGN_NEIGHBOR_SHARE := 0.35

# --- Starting state per region (0-100) -----------------------------------------------
const REGION_START := {
	"western": {"pollution": 52.0, "coral_health": 52.0, "seagrass": 48.0, "fish_stock": 42.0, "awareness": 32.0, "protection": 12.0},
	"central": {"pollution": 40.0, "coral_health": 60.0, "seagrass": 55.0, "fish_stock": 45.0, "awareness": 18.0, "protection": 8.0},
	"adriatic": {"pollution": 48.0, "coral_health": 58.0, "seagrass": 50.0, "fish_stock": 48.0, "awareness": 28.0, "protection": 10.0},
	"aegean": {"pollution": 32.0, "coral_health": 66.0, "seagrass": 62.0, "fish_stock": 52.0, "awareness": 24.0, "protection": 12.0},
	"marmara": {"pollution": 66.0, "coral_health": 40.0, "seagrass": 34.0, "fish_stock": 32.0, "awareness": 20.0, "protection": 6.0},
	"blacksea": {"pollution": 55.0, "coral_health": 50.0, "seagrass": 45.0, "fish_stock": 40.0, "awareness": 15.0, "protection": 5.0},
	"antalya": {"pollution": 24.0, "coral_health": 72.0, "seagrass": 70.0, "fish_stock": 60.0, "awareness": 35.0, "protection": 15.0},
	"levant": {"pollution": 58.0, "coral_health": 46.0, "seagrass": 42.0, "fish_stock": 36.0, "awareness": 14.0, "protection": 5.0},
}
