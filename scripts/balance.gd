extends Node
## Balance (autoload): every tunable number of the game lives here, nothing else.
## crisis_sim.gd and region.gd read it via preload (works headless without autoloads);
## other scripts may use the Balance singleton. Tune values freely; keep names stable.

# --- Time ---------------------------------------------------------------------
const TICK_SECONDS := 2.5          # real seconds per monthly simulation tick at 1x
const TOTAL_TICKS := 240           # 2026 -> 2046 at 1x is 240 months (12 ticks = 1 yr)
const TICKS_PER_YEAR := 12
const START_YEAR := 2026
const END_YEAR := 2046
const SPEEDS := [0.0, 1.0, 2.0, 4.0]   # index 0 = pause, 1 = 1x, 2 = 2x, 3 = 4x
const MAX_TICKS_PER_FRAME := 8     # guard against frame spikes at 4x
const DEFAULT_SEED := 31

# --- Global climate -------------------------------------------------------------
const TEMP_START := 1.5            # degrees C above pre-industrial
const TEMP_LOSE := 4.0
const TEMP_BASE_RISE_PER_TICK := 0.0016
const TEMP_CRISIS_RISE_PER_TICK := 0.0135   # multiplied by average crisis / 100
const TEMP_STRESS_COEFF := 0.045     # extra pollution / stress per tick per degree above TEMP_START
const TEMP_MILESTONES := [2.0, 2.5, 3.0, 3.5]  # toast when warming crosses each value
const TEMP_ALARM_MILESTONE := 3.0  # milestones from here on are alarms (severity 3)

# --- Crisis level of a region (weights sum to 1) --------------------------------
const CRISIS_W_POLLUTION := 0.4
const CRISIS_W_CORAL := 0.2
const CRISIS_W_SEAGRASS := 0.2
const CRISIS_W_FISH := 0.2
const STATUS_STRESSED := 30.0      # crisis >= this -> "stressed"
const STATUS_CRITICAL := 55.0      # crisis >= this -> "critical"
const STATUS_COLLAPSED := 75.0     # crisis >= this -> "collapsed"

# --- Per-tick regional dynamics (all values are 0-100 scales) -------------------
const BASE_POLLUTION_RATE := 0.060
const SOURCE_INFLOW_COEFF := 0.120      # x coastal_pop: rivers, sewage, plastic inflow
const NEIGHBOR_PRESSURE_COEFF := 0.00048  # x neighbour pollution x route weight x kind mult
const PROTECT_COEFF := 0.0042          # x protection: pollution reduction (at LEVER_POLLUTION_REF)
const AWARE_COEFF := 0.0090             # x awareness: pollution reduction (at LEVER_POLLUTION_REF)
const LEVER_POLLUTION_REF := 50.0      # lever reductions scale with pollution / this
const BIO_SAFE_POLLUTION := 30.0       # below: clean water lets life regrow; above: damage
const BIO_ROOM_EXPONENT := 2.3         # coral / seagrass recovery x (1 - value / 100) ^ this
const BIO_DIRTY_RECOVERY_CUT := 0.6    # protection-driven recovery x (1 - dirtiness x this)
const CORAL_POLLUTION_DAMAGE := 0.20   # per tick at pollution 100 (0 at BIO_SAFE_POLLUTION)
const CORAL_HEAT_DAMAGE := 0.048       # per tick per degree above TEMP_START
const CORAL_RECOVERY := 2.0            # x protection / 100 x clean-water factor x room to grow
const CORAL_CLEAN_REGROWTH := 0.04     # x cleanliness below BIO_SAFE_POLLUTION x room to grow
const SEAGRASS_POLLUTION_DAMAGE := 0.20
const SEAGRASS_HEAT_DAMAGE := 0.032
const SEAGRASS_RECOVERY := 2.0          # same rules as coral (Posidonia meadows)
const SEAGRASS_CLEAN_REGROWTH := 0.04
const FISHING_PRESSURE := 0.48         # catch per tick at stock 50, cut by no-take zones
const FISH_PROTECT_MULT := 1.3         # no-take share = protection / 100 x this (capped at 1)
const FISH_POLLUTION_DAMAGE := 0.08    # x pollution / 100
const FISH_REGEN := 0.40                # logistic regrowth per tick at stock 50
const FISH_SEED_STOCK := 2.0           # migrants: lets an emptied stock restart
const FISH_HABITAT_WEIGHT := 0.5       # share of fish regrowth that needs seagrass nurseries
const AWARENESS_DECAY_PER_TICK := 0.016   # flat part
const AWARENESS_DECAY_RATE := 0.012     # proportional part (x awareness)
const PROTECTION_DECAY_PER_TICK := 0.016  # flat part
const PROTECTION_DECAY_RATE := 0.012     # proportional part (x protection)
const AWARE_PROTECTION_HOLD := 0.6     # x awareness / 100: protection decays this much slower
const AWARE_FISHING_CUT := 0.4         # x awareness / 100: fishing demand drops this much

# --- Spread along routes ----------------------------------------------------------
const CURRENT_WEIGHT_MULT := 1.0
const SHIPPING_WEIGHT_MULT := 0.8
const SPREAD_THRESHOLD := 45.0         # source crisis needed before it can spread
const SPREAD_CHANCE_PER_TICK := 0.08   # x route weight x source crisis / 100
const SPREAD_POLLUTION_BUMP := 5.0       # pollution added to the target (x shield)
const SPREAD_BIO_DAMAGE := 1.8         # coral / seagrass / fish hit on the target
const SPREAD_PROTECTION_SHIELD := 0.8  # x target protection / 100: chance and damage cut
const SPREAD_ROUTE_COOLDOWN_TICKS := 10

# --- Resources ------------------------------------------------------------------
const BUDGET_START := 240.0
const POLITICAL_START := 75.0
const SCIENCE_START := 25.0
const BUDGET_INCOME_PER_TICK := 5.5    # at sea health BUDGET_REF_HEALTH (linear in sea health)
const BUDGET_REF_HEALTH := 50.0
const BUDGET_BREAKEVEN_HEALTH := 22.0  # below this the sea economy costs money
const POLITICAL_INCOME_PER_TICK := 1.4  # at average awareness POLITICAL_REF_AWARENESS
const POLITICAL_REF_AWARENESS := 25.0
const POLITICAL_BREAKEVEN_AWARENESS := 8.0  # below this lobbies erode support
const SCIENCE_INCOME_PER_TICK := 0.38  # monthly science trickle; bubbles and satellites add more
const RESOURCE_CAP := 999.0
const DEPLETED_THRESHOLD := 1.0        # both budget and political below this -> lose
const DEPLETED_GRACE_TICKS := 5        # ... for this many consecutive ticks
const LOW_BUDGET_WARN := 20.0          # warning toast when budget AND political are below
const LOW_POLITICAL_WARN := 4.0
const LOW_RESOURCE_TOAST_GAP_TICKS := 15

# --- Win / lose -------------------------------------------------------------------
const WIN_SEA_HEALTH := 60.0           # checked at END_YEAR
const WIN_ALL_CRISIS_BELOW := 25.0     # checked every tick: early win
const LOSE_SEA_HEALTH := 10.0

# --- Toast thresholds ---------------------------------------------------------------
const REGION_CRITICAL_CRISIS := 66.0
const REGION_RECOVERED_CRISIS := 35.0
const ALERT_HYSTERESIS := 8.0          # crisis must move this far back before re-alerting
const TOAST_MIN_GAP_TICKS := 2         # at most one toast per kind per this many ticks

# --- Field operations (per region) ---------------------------------------
const ACTIONS := {
	"cleanup": {
		"branch": "source",
		"cost": {"budget": 40.0},
		"cooldown_ticks": 3,
		"icon": "cleanup",
		"name_key": "action.cleanup.name",
		"desc_key": "action.cleanup.desc",
		"toast_key": "toast.action.cleanup",
	},
	"patrol": {
		"branch": "protect",
		"cost": {"political": 12.0},
		"cooldown_ticks": 4,
		"icon": "patrol",
		"name_key": "action.patrol.name",
		"desc_key": "action.patrol.desc",
		"toast_key": "toast.action.patrol",
	},
	"campaign": {
		"branch": "science",
		"cost": {"budget": 20.0, "political": 4.0},
		"cooldown_ticks": 5,
		"icon": "campaign",
		"name_key": "action.campaign.name",
		"desc_key": "action.campaign.desc",
		"toast_key": "toast.action.campaign",
	},
}
const ACTION_ORDER := ["cleanup", "patrol", "campaign"]
const CLEANUP_POLLUTION_DROP := 15.0   # at pollution CLEANUP_REF_POLLUTION
const CLEANUP_REF_POLLUTION := 50.0    # cleanup scales with pollution / this ...
const CLEANUP_MIN_SCALE := 0.6         # ... clamped to this range
const CLEANUP_MAX_SCALE := 1.4
const PATROL_PROTECTION_GAIN := 20.0   # x (1 - protection / 100 x PATROL_SATURATION)
const PATROL_SATURATION := 0.8
const CAMPAIGN_AWARENESS_GAIN := 18.0  # x (1 - awareness / 100 x CAMPAIGN_SATURATION)
const CAMPAIGN_SATURATION := 1.0
const CAMPAIGN_NEIGHBOR_SHARE := 0.5

# --- Policy tree economy & Repeatable Science Projects ---------------------------------
const BLUE_CARBON_SEAGRASS := 60.0     # "blue_carbon" pays per tick per region with seagrass above this
const HISTORY_EVERY := 3              # live chart: one sample per this many ticks (every quarter)
const SCIENCE_CURE_COST := 30.0        # Science Points required to synthesize counter-strategy and cure mutation
const PROJECT_BIO_ALGAE_COST := 40.0   # Science cost
const PROJECT_BIO_ALGAE_BUDGET := 25.0 # Operational Budget cost
const PROJECT_BIO_ALGAE_CD_TICKS := 15 # 37.5 seconds at 1x
const PROJECT_DRONE_SWARM_COST := 30.0 # Science cost
const PROJECT_DRONE_SWARM_BUDGET := 20.0 # Operational Budget cost
const PROJECT_DRONE_SWARM_CD_TICKS := 12 # 30 seconds at 1x

# --- Crisis evolution (docs/ARCHITECTURE.md 11.4) ----------------------------
const EVO_WINDOW := 12                 # the crisis remembers this many recent player moves
const EVO_MIN_MOVES := 8               # ... and reads a strategy only once it has this many
const EVO_SHARE := 0.52                # one branch with at least this share evolves its resistance ...
const EVO_ADAPT_TICKS := 26            # ~65 s at 1x
const EVO_ADAPT_DECAY := 1.0           # adaptation lost per tick while the strategy is diverse again
const EVO_WARN_AT := 0.5               # "crisis is adapting" toast at this share of EVO_ADAPT_TICKS
const EVO_HEAT_TEMP := 2.50            # marine_heatwave evolves at this warming
const EVO_SPREAD_COUNT := 8            # invasive_species evolves after this many spreads

# --- Decision events (11.5) -----------------------------------------------------
const EVENT_FIRST_MIN := 14            # first random card between these ticks (~14-20 months)
const EVENT_FIRST_MAX := 20
const EVENT_INTERVAL_MIN := 24        # then one every 24..34 ticks (~2-3 years)
const EVENT_INTERVAL_MAX := 34
const EVENT_SUMMIT_GAP_TICKS := 8     # no random card this close before or after a COP31 summit

# --- Data bubbles (11.6) ----------------------------------------------------------
const BUBBLE_CHANCE_PER_TICK := 0.45   # ~4-7 seconds interval at 2.5s ticks
const BUBBLES_MAX := 4                 # alive at once
const BUBBLE_TTL_TICKS := 8            # 20 s at 1x
const BUBBLE_POLITICAL_SHARE := 0.25   # the rest are science bubbles
const BUBBLE_SCIENCE_MIN := 5          # amount range before bubble_value_mult
const BUBBLE_SCIENCE_MAX := 9
const BUBBLE_POLITICAL_MIN := 3
const BUBBLE_POLITICAL_MAX := 6
const BUBBLE_AWARENESS_WEIGHT := 5.0   # political bubbles: region weight = awareness + this

# --- News headlines (11.7) -----------------------------------------------------------
const NEWS_SPREAD_GAP_TICKS := 10      # at most one spread headline per this many ticks
const NEWS_ALERT_GAP_TICKS := 3       # region alarm / recovery headlines

# --- Starting state per region (0-100) -----------------------------------------------
const REGION_START := {
	"western": {"pollution": 52.0, "coral_health": 52.0, "seagrass": 48.0, "fish_stock": 42.0, "awareness": 32.0, "protection": 12.0},
	"central": {"pollution": 40.0, "coral_health": 60.0, "seagrass": 55.0, "fish_stock": 45.0, "awareness": 18.0, "protection": 8.0},
	"adriatic": {"pollution": 48.0, "coral_health": 58.0, "seagrass": 50.0, "fish_stock": 48.0, "awareness": 28.0, "protection": 10.0},
	"aegean": {"pollution": 32.0, "coral_health": 66.0, "seagrass": 62.0, "fish_stock": 52.0, "awareness": 24.0, "protection": 12.0},
	"marmara": {"pollution": 66.0, "coral_health": 40.0, "seagrass": 34.0, "fish_stock": 32.0, "awareness": 16.0, "protection": 4.0},
	"blacksea": {"pollution": 55.0, "coral_health": 50.0, "seagrass": 45.0, "fish_stock": 40.0, "awareness": 15.0, "protection": 5.0},
	"antalya": {"pollution": 24.0, "coral_health": 72.0, "seagrass": 70.0, "fish_stock": 60.0, "awareness": 35.0, "protection": 15.0},
	"levant": {"pollution": 58.0, "coral_health": 46.0, "seagrass": 42.0, "fish_stock": 36.0, "awareness": 14.0, "protection": 5.0},
}

# --- Difficulty Levels --------------------------------------------------------
const DIFFICULTY_CADET := "cadet"
const DIFFICULTY_COMMANDER := "commander"
const DIFFICULTY_ADMIRAL := "admiral"

const DIFFICULTIES := {
	"cadet": {
		"id": "cadet",
		"name_key": "diff.cadet.name",
		"desc_key": "diff.cadet.desc",
		"badge": "🟢 CADET",
		"resource_mult": 1.5,
		"spread_mult": 0.70,
		"temp_rise_mult": 0.70,
		"evo_threshold_mult": 1.25,
		"antalya_collapse_limit": 85.0,
		"pollution_mult": 0.85
	},
	"commander": {
		"id": "commander",
		"name_key": "diff.commander.name",
		"desc_key": "diff.commander.desc",
		"badge": "🟡 COMMANDER",
		"resource_mult": 1.0,
		"spread_mult": 1.0,
		"temp_rise_mult": 1.0,
		"evo_threshold_mult": 1.0,
		"antalya_collapse_limit": 75.0,
		"pollution_mult": 1.0
	},
	"admiral": {
		"id": "admiral",
		"name_key": "diff.admiral.name",
		"desc_key": "diff.admiral.desc",
		"badge": "🔴 ADMIRAL",
		"resource_mult": 0.8,
		"spread_mult": 1.35,
		"temp_rise_mult": 1.35,
		"evo_threshold_mult": 0.85,
		"antalya_collapse_limit": 65.0,
		"pollution_mult": 1.20
	}
}

# --- COP31 Mediterranean Summits (every 5 years: 2031, 2036, 2041) ------------
const SUMMIT_TICKS := [60, 120, 180]

# --- Antalya Coalition HQ Rule ------------------------------------------------
const ANTALYA_HQ_COLLAPSE_DEFAULT := 75.0
