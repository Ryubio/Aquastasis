extends RefCounted
## String table (HUD additions, news ticker templates and ambient headlines, bubble labels. Owner: HUD module (en), localization (tr/ru)) merged by the I18n autoload; never read directly by game code.
## Format: key -> {"tr": ..., "en": ..., "ru": ...}. Keys are unique across all tables.

const STRINGS := {
	# --- HUD: net income per year beside each resource ---
	"hud.rate": {"en": "{v}/yr"},
	"hud.rate.tip": {"en": "Net income per year, before spending."},
	"hud.rate.tip_negative": {
		"en": "Income is negative: a dying sea costs the coalition money. Restore Sea Health to turn it around.",
	},
	"hud.toast.income_negative": {
		"en": "Income balance turned negative! The dying sea is draining the budget.",
	},

	# --- HUD: live chart ---
	"hud.chart.title": {"en": "LIVE TREND"},
	"hud.chart.health": {"en": "Sea Health"},
	"hud.chart.crisis": {"en": "Crisis Level"},
	"hud.chart.goal": {"en": "Goal"},

	# --- HUD: crisis resistances and evolution pressure ---
	"hud.resist.title": {"en": "CRISIS RESISTANCES"},
	"hud.resist.none": {"en": "None yet. Keep your strategy varied to keep it that way."},
	"hud.resist.counter": {"en": "Countered by: {list}"},
	"hud.resist.counter_unknown": {"en": "Countered by matching policies in the Policy Tree."},
	"hud.resist.more": {"en": "Also active: {n}"},
	"hud.pressure.warn": {"en": "Crisis adapting to: {branch}"},
	"hud.pressure.hint": {"en": "Diversify your moves or it evolves a resistance."},
	"hud.branch.protect": {"en": "Protection"},
	"hud.branch.source": {"en": "Source Cutting"},
	"hud.branch.science": {"en": "Science & Public"},
	"hud.branch.economy": {"en": "Economy & Diplomacy"},

	# --- HUD: policy tree button and key hints ---
	"hud.tree.button": {"en": "POLICY TREE"},
	"hud.tree.available": {"en": "Ready to adopt: {n}"},
	"hud.tree.none": {"en": "Plan your next policy"},
	"hud.tree.tip": {
		"en": "Permanent policies paid with Budget, Political Support and Science. Each one also counters a crisis resistance.",
	},
	"hud.key_hint": {"en": "Hotkey: {key}"},

	# --- Data bubbles ---
	"fx.bubble.collect": {"en": "Click to collect"},

	# --- News ticker chrome ---
	"news.tag": {"en": "BASIN NEWS"},
	"news.chip.breaking": {"en": "BREAKING"},
	"news.chip.good": {"en": "GOOD NEWS"},
	"news.chip.fact": {"en": "FACT"},
	"news.chip.tip": {"en": "TIP"},
	"news.welcome": {"en": "COP31 Antalya: the Marine Coalition takes command of the Mediterranean basin"},

	# --- Ambient headlines: a region in trouble ---
	"news.amb.pollution": {"en": "{region}: pollution readings climb to {v}%, swimmers warned off the beaches"},
	"news.amb.coral": {"en": "{region}: bleaching spreads across the reefs, coral health down to {v}%"},
	"news.amb.seagrass": {"en": "{region}: Posidonia meadows thinning, coverage down to {v}%"},
	"news.amb.fish": {"en": "{region}: fishers return with empty nets, fish stock at {v}%"},
	"news.amb.collapse": {"en": "{region}: scientists warn the ecosystem is collapsing"},
	"news.amb.worsening": {"en": "{region}: the crisis deepens, level now {v}%"},

	# --- Ambient headlines: a region recovering ---
	"news.amb.clean": {"en": "{region}: clear water returns, crisis level down to {v}%"},
	"news.amb.seagrass_good": {"en": "{region}: Posidonia meadows thrive at {v}%, locking away blue carbon"},
	"news.amb.fish_good": {"en": "{region}: fish stock rebounds to {v}%, cooperatives report better catches"},
	"news.amb.coral_good": {"en": "{region}: divers film vibrant reefs, coral health at {v}%"},
	"news.amb.protected": {"en": "{region}: patrols enforce no-take zones, protection at {v}%"},
	"news.amb.aware": {"en": "{region}: volunteers flock to beach clean-ups, awareness at {v}%"},
	"news.amb.improving": {"en": "{region}: the crisis eases to {v}% as recovery takes hold"},

	# --- Ambient headlines: the whole basin ---
	"news.amb.health_up": {"en": "Sea Health Index climbs to {v}%: the basin is responding"},
	"news.amb.health_down": {"en": "Sea Health Index slips to {v}%: analysts urge faster action"},
	"news.amb.temp": {"en": "Global warming at +{v}°C; the Mediterranean heats up faster than the world average"},
	"news.amb.temp_high": {"en": "Heat alarm: warming at +{v}°C, marine heatwaves are becoming routine"},
	"news.amb.goal": {"en": "COP31 target: Sea Health 60% by 2046. Years left: {n}"},
	"news.amb.goal_near": {"en": "Sea Health at {v}%: the COP31 goal of 60% is within reach"},
	"news.amb.income_negative": {"en": "Treasury alarm: the failing sea economy is now draining coalition funds"},
	"news.amb.resistance": {"en": "Analysts: the crisis has adapted ({name}). New policies are needed"},
	"news.amb.spreads": {"en": "Crisis spread events logged since 2026: {n}"},
	"news.amb.policies": {"en": "Coalition policies in force: {n}"},

	# --- Tips (shown once each per game) ---
	"news.tip.bubbles": {"en": "Click the glowing data bubbles over the sea to collect Science and Political Support"},
	"news.tip.tree": {"en": "Press T to open the Policy Tree and adopt lasting policies"},
	"news.tip.keys": {"en": "Select a region, then press Q, W or E to launch field operations"},
	"news.tip.pause": {"en": "Press Space to pause and plan: operations still work while time stands still"},
	"news.tip.diversify": {"en": "A one-sided strategy lets the crisis evolve resistances. Mix your moves"},

	# --- Real Mediterranean facts ---
	"news.fact.biodiversity": {"en": "The Mediterranean is under 1% of the world ocean, yet hosts up to 18% of known marine species"},
	"news.fact.warming": {"en": "The Mediterranean is warming about 20% faster than the global average"},
	"news.fact.plastic": {"en": "Roughly 230,000 tonnes of plastic leak into the Mediterranean every year (IUCN)"},
	"news.fact.posidonia": {"en": "Posidonia meadows store carbon in their seabed mats for thousands of years"},
	"news.fact.posidonia_loss": {"en": "Mediterranean Posidonia meadows have shrunk by about a third in the last 50 years"},
	"news.fact.caretta": {"en": "Loggerhead turtles nest on Turkish beaches from Dalyan to Belek, near Antalya"},
	"news.fact.monk_seal": {"en": "Fewer than a thousand Mediterranean monk seals survive, some in sea caves on Türkiye's coast"},
	"news.fact.lionfish": {"en": "Lionfish entered through the Suez Canal and now spread along the Levant and Turkish coasts"},
	"news.fact.mucilage": {"en": "In 2021 a vast mucilage outbreak, known as sea snot, blanketed the Sea of Marmara"},
	"news.fact.overfishing": {"en": "Most assessed Mediterranean fish stocks are fished beyond sustainable limits (FAO)"},
	"news.fact.renewal": {"en": "Mediterranean water takes around a century to renew through the Strait of Gibraltar"},
	"news.fact.barcelona": {"en": "The 1976 Barcelona Convention was the first of UNEP's Regional Seas agreements"},
	"news.fact.cop31": {"en": "COP31 in Antalya puts oceans and seas at the heart of the climate talks"},
}
