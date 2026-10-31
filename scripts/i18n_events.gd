extends RefCounted
## String table (decision event cards: titles, texts, choice labels, result texts. Owner: content module (en), localization (tr/ru)) merged by the I18n autoload; never read directly by game code.
## Format: key -> {"tr": ..., "en": ..., "ru": ...}. Keys are unique across all tables.
## {region} = the card's region name (args {"region": <translated name>}). Result texts repeat
## the numbers in events.gd (50 ticks = 1 year); keep both in sync when tuning.

const STRINGS := {
	# --- Oil spill ---
	"event.oil_spill.title": {"en": "Tanker Spill near {region}"},
	"event.oil_spill.text": {"en": "A damaged tanker is leaking crude oil off {region}. The slick is drifting toward beaches and fishing grounds."},
	"event.oil_spill.a.label": {"en": "Deploy booms and skimmers"},
	"event.oil_spill.a.result": {"en": "Most of the oil was skimmed in time. {region}: pollution only +4, awareness +5."},
	"event.oil_spill.b.label": {"en": "Let it disperse"},
	"event.oil_spill.b.result": {"en": "The slick washed ashore. {region}: pollution +14, fish stock -8."},

	# --- Marine heatwave ---
	"event.heatwave.title": {"en": "Marine Heatwave in {region}"},
	"event.heatwave.text": {"en": "Sea temperatures off {region} hit record highs. Corals and seagrass are starting to die."},
	"event.heatwave.a.label": {"en": "Deploy sensors, close dive sites"},
	"event.heatwave.a.result": {"en": "Sensors guide fast closures: coral heat damage is halved basin-wide for two years. {region}: coral health only -3."},
	"event.heatwave.b.label": {"en": "Ride it out"},
	"event.heatwave.b.result": {"en": "Mass die-off. {region}: coral health -12, seagrass -6."},

	# --- Lobby pressure ---
	"event.lobby_pressure.title": {"en": "Industry Lobby at the Door"},
	"event.lobby_pressure.text": {"en": "Plastics and shipping lobbies demand a freeze on new rules. They promise jobs and threaten headlines."},
	"event.lobby_pressure.a.label": {"en": "Stand firm"},
	"event.lobby_pressure.a.result": {"en": "You held the line and the public rallied: +5 awareness in every region."},
	"event.lobby_pressure.b.label": {"en": "Accept a 'voluntary' deal"},
	"event.lobby_pressure.b.result": {"en": "Industry pays +60 budget, but its voluntary pledges leak: source inflow +20% for four years."},

	# --- Greenwashing scandal ---
	"event.greenwashing.title": {"en": "Greenwashing Scandal"},
	"event.greenwashing.text": {"en": "Reporters reveal that a coalition sponsor dumped waste while running 'blue ocean' ads. Trust is collapsing."},
	"event.greenwashing.a.label": {"en": "Cut ties and publish an audit"},
	"event.greenwashing.a.result": {"en": "Radical transparency pays off: +15 political support and +4 awareness in every region."},
	"event.greenwashing.b.label": {"en": "Stay quiet"},
	"event.greenwashing.b.result": {"en": "The story runs for weeks: -15 political support, and awareness fades 50% faster for three years."},

	# --- Fishers' cooperative ---
	"event.fishers_coop.title": {"en": "Fishers' Cooperative Offer"},
	"event.fishers_coop.text": {"en": "A fishers' cooperative in {region} will cut its catch if the coalition pays for selective nets."},
	"event.fishers_coop.a.label": {"en": "Fund the new gear"},
	"event.fishers_coop.a.result": {"en": "New nets, less bycatch. {region}: fish stock +8, and fishing pressure falls 10% basin-wide for four years."},
	"event.fishers_coop.b.label": {"en": "Decline the offer"},
	"event.fishers_coop.b.result": {"en": "The fishers keep their old nets and their old catch. {region}: fish stock -5."},

	# --- Tourism season surge ---
	"event.tourism_surge.title": {"en": "Record Tourist Season"},
	"event.tourism_surge.text": {"en": "Hotels and cruise ships in {region} are fully booked. Waste, sewage and anchors pile onto the seagrass."},
	"event.tourism_surge.a.label": {"en": "Cap cruises, ban anchoring"},
	"event.tourism_surge.a.result": {"en": "Quotas hold the line. {region}: seagrass +4, pollution -4, awareness +4."},
	"event.tourism_surge.b.label": {"en": "Let the boom run"},
	"event.tourism_surge.b.result": {"en": "The boom brings +70 budget, but anchors tear up the meadows. {region}: seagrass -10, pollution +8."},

	# --- Marmara mucilage ---
	"event.mucilage.title": {"en": "Mucilage Outbreak in {region}"},
	"event.mucilage.text": {"en": "A slimy blanket of sea snot spreads across {region}, smothering fish and seabed life. Warm water and sewage feed it."},
	"event.mucilage.a.label": {"en": "Barriers and skimmers"},
	"event.mucilage.a.result": {"en": "Crews lift the slime off the surface. {region}: pollution -14."},
	"event.mucilage.b.label": {"en": "Study it, act later"},
	"event.mucilage.b.result": {"en": "Scientists bank +15 science in samples while the slime spreads. {region}: pollution +6, fish stock -6."},

	# --- Foreign trawlers ---
	"event.foreign_trawlers.title": {"en": "Dark Trawlers Spotted"},
	"event.foreign_trawlers.text": {"en": "Industrial trawlers with their transponders switched off are raking the seabed off {region}."},
	"event.foreign_trawlers.a.label": {"en": "Send a patrol"},
	"event.foreign_trawlers.a.result": {"en": "Patrol boats escort the trawlers out. {region}: protection +10."},
	"event.foreign_trawlers.b.label": {"en": "Send a diplomatic note"},
	"event.foreign_trawlers.b.result": {"en": "While notes are exchanged, the trawlers strip the seabed. {region}: fish stock -15, seagrass -5."},

	# --- Caretta caretta nesting season ---
	"event.caretta_nesting.title": {"en": "Turtle Nesting Season"},
	"event.caretta_nesting.text": {"en": "Loggerhead turtles are nesting on the beaches of {region}, right next to sunbeds and beach bars."},
	"event.caretta_nesting.a.label": {"en": "Guard the nests"},
	"event.caretta_nesting.a.result": {"en": "Volunteers guard the nests and the hatchlings reach the sea. {region}: awareness +8, protection +6."},
	"event.caretta_nesting.b.label": {"en": "Keep the beaches open"},
	"event.caretta_nesting.b.result": {"en": "Tourism earns +30 budget, but beach lights lure hatchlings away from the sea. {region}: awareness -5."},

	# --- COP31 summit 2031 ---
	"event.cop31_2031.title": {"en": "COP31 Review Summit: 2031"},
	"event.cop31_2031.text": {"en": "Five years after Antalya, the coalition meets to review its Mediterranean pledge. Donors and delegates are watching."},
	"event.cop31_2031.a.label": {"en": "Push a binding plastics pact"},
	"event.cop31_2031.a.result": {"en": "The pact passes: source inflow -20% basin-wide until the next summit."},
	"event.cop31_2031.b.label": {"en": "Take the donor grant"},
	"event.cop31_2031.b.result": {"en": "Donors release +100 budget. The plastics pact is shelved for now."},

	# --- COP31 summit 2036 ---
	"event.cop31_2036.title": {"en": "COP31 Mid-Term Summit: 2036"},
	"event.cop31_2036.text": {"en": "Halfway to 2046. Delegates are split between new marine reserves and a fresh round of climate finance."},
	"event.cop31_2036.a.label": {"en": "Expand protected areas"},
	"event.cop31_2036.a.result": {"en": "New reserves are declared across the basin: +10 protection in every region."},
	"event.cop31_2036.b.label": {"en": "Bank the climate finance"},
	"event.cop31_2036.b.result": {"en": "The fund pays out +80 budget and +10 political support, but no new reserves."},

	# --- COP31 summit 2041 ---
	"event.cop31_2041.title": {"en": "COP31 Final Summit: 2041"},
	"event.cop31_2041.text": {"en": "Five years left. The world asks the Mediterranean coalition for one last push on emissions."},
	"event.cop31_2041.a.label": {"en": "Fast-track a carbon cap"},
	"event.cop31_2041.a.result": {"en": "The cap is signed: warming drops by 0.05°C now and slows by 40% until 2046."},
	"event.cop31_2041.b.label": {"en": "Put growth first"},
	"event.cop31_2041.b.result": {"en": "Budget income +20% until 2046, but warming speeds up by 10%."},
}
