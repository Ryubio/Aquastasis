extends RefCounted
## String table (simulation toasts and news headlines for adoptions, evolutions, events, bubbles. Owner: simulation module (en), localization (tr/ru)) merged by the I18n autoload; never read directly by game code.
## Format: key -> {"tr": ..., "en": ..., "ru": ...}. Keys are unique across all tables.
## Args: {region} / {from} / {to} are region name keys, {name} a node or evolution name key (the
## displayer translates them); {temp} is a pre-formatted number. Evolution headlines use the
## news_key / cured_news_key of tech_tree.gd; event result toasts use the result_key of events.gd.

const STRINGS := {
	# --- Toasts ---
	"sim.toast.adopted": {"en": "Policy adopted: {name}"},
	"sim.toast.evolved": {"en": "The crisis evolved: {name}"},
	"sim.toast.cured": {"en": "Resistance cured: {name}"},
	"sim.toast.immune": {"en": "Resistance pre-empted: the crisis can no longer evolve {name}"},
	"sim.toast.adapting": {"en": "The crisis is adapting to your one-sided strategy ({branch}). Diversify!"},

	# --- News: crisis spreading (variants) ---
	"sim.news.spread.0": {"en": "Pollution plume from {from} drifts into {to}"},
	"sim.news.spread.1": {"en": "Currents carry the marine crisis from {from} to {to}"},
	"sim.news.spread.2": {"en": "Monitoring buoys: {to} hit by contamination from {from}"},

	# --- News: region alarms and recoveries (variants) ---
	"sim.news.critical.0": {"en": "{region} declared an ecological emergency zone"},
	"sim.news.critical.1": {"en": "Alarm in {region}: scientists warn the ecosystem is near collapse"},
	"sim.news.recovered.0": {"en": "{region} turns the corner: scientists confirm a recovery"},
	"sim.news.recovered.1": {"en": "Good news from {region}: clear water and fish are returning"},

	# --- News: climate and economy ---
	"sim.news.temp": {"en": "Warming passes +{temp}°C: the Mediterranean heats up faster than the world"},
	"sim.news.temp_alarm": {"en": "Climate alarm: warming tops +{temp}°C, coral reefs in danger basin-wide"},
	"sim.news.depleted": {"en": "Coalition coffers and political capital run dry: the mission is at risk"},

	# --- News: policy adoptions, by branch ---
	"sim.news.adopted.protect": {"en": "New protection for the sea: the coalition adopts {name}"},
	"sim.news.adopted.source": {"en": "Pollution cut at the source: the coalition adopts {name}"},
	"sim.news.adopted.science": {"en": "Science push: the coalition launches {name}"},
	"sim.news.adopted.economy": {"en": "Blue economy deal: the coalition agrees on {name}"},

	# --- News: decision card outcomes (choice a = paid response, b = free choice) ---
	"sim.news.event.oil_spill.a": {"en": "Booms hold: crews skim the tanker spill off {region}"},
	"sim.news.event.oil_spill.b": {"en": "Oil slick blackens the beaches of {region} as the response stalls"},
	"sim.news.event.heatwave.a": {"en": "Sensors and dive-site closures shield the reefs of {region}"},
	"sim.news.event.heatwave.b": {"en": "Mass die-off: a marine heatwave bleaches the seabed of {region}"},
	"sim.news.event.lobby_pressure.a": {"en": "The coalition stands firm against the plastics lobby"},
	"sim.news.event.lobby_pressure.b": {"en": "Industry deal signed: green groups warn of a pollution loophole"},
	"sim.news.event.greenwashing.a": {"en": "The coalition drops its greenwashing sponsor and publishes a full audit"},
	"sim.news.event.greenwashing.b": {"en": "Greenwashing scandal deepens as the coalition stays silent"},
	"sim.news.event.fishers_coop.a": {"en": "Fishers in {region} switch to selective nets with coalition funds"},
	"sim.news.event.fishers_coop.b": {"en": "Fishers in {region} keep their old nets after talks collapse"},
	"sim.news.event.tourism_surge.a": {"en": "Cruise caps and an anchoring ban protect the meadows of {region}"},
	"sim.news.event.tourism_surge.b": {"en": "Tourist boom in {region}: record income, torn-up seagrass"},
	"sim.news.event.mucilage.a": {"en": "Barriers and skimmers lift the sea snot off {region}"},
	"sim.news.event.mucilage.b": {"en": "Mucilage spreads across {region} while samples go to the lab"},
	"sim.news.event.foreign_trawlers.a": {"en": "Patrol boats escort dark trawlers out of {region}"},
	"sim.news.event.foreign_trawlers.b": {"en": "Dark trawlers strip the seabed off {region} during diplomatic talks"},
	"sim.news.event.caretta_nesting.a": {"en": "Volunteers guard turtle nests: hatchlings reach the sea in {region}"},
	"sim.news.event.caretta_nesting.b": {"en": "Beach lights lure turtle hatchlings away from the sea in {region}"},
	"sim.news.event.cop31_2031.a": {"en": "COP31 review summit: a binding plastics pact is agreed"},
	"sim.news.event.cop31_2031.b": {"en": "COP31 review summit: donors pay out, the plastics pact is shelved"},
	"sim.news.event.cop31_2036.a": {"en": "COP31 mid-term summit: new marine reserves declared across the basin"},
	"sim.news.event.cop31_2036.b": {"en": "COP31 mid-term summit: climate finance banked, no new reserves"},
	"sim.news.event.cop31_2041.a": {"en": "COP31 final summit: a carbon cap is signed for the last five years"},
	"sim.news.event.cop31_2041.b": {"en": "COP31 final summit: growth comes first and emissions keep rising"},
}
