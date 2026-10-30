extends Node
## I18n (autoload): the single source of every user-visible string (tr / en / ru).
## Usage: I18n.t("hud.year", {"year": "2031"}) fills {year}. set_language() switches live,
## persists to user://settings.cfg and emits EventBus.language_changed.

const LANGS := ["tr", "en", "ru"]
const FALLBACK := "en"
const SETTINGS_PATH := "user://settings.cfg"

## key -> {"tr": ..., "en": ..., "ru": ...}. Uppercase variants are separate keys:
## never call to_upper()/to_lower() on translated text (Turkish i/İ, ı/I).
const STRINGS := {
	# --- Language names (always shown in their own language) ---
	"lang.native.tr": {"tr": "Türkçe", "en": "Türkçe", "ru": "Türkçe"},
	"lang.native.en": {"tr": "English", "en": "English", "ru": "English"},
	"lang.native.ru": {"tr": "Русский", "en": "Русский", "ru": "Русский"},

	# --- Title ---
	"game.title": {"tr": "AKDENİZ'İN NABZI", "en": "PULSE OF THE MEDITERRANEAN", "ru": "ПУЛЬС СРЕДИЗЕМНОМОРЬЯ"},
	"game.subtitle": {"en": "COP31 Antalya — The Reverse Pandemic"},

	# --- Main menu ---
	"ui.menu.tagline": {"en": "The basin is collapsing. You are the COP31 Marine Coalition."},
	"ui.menu.briefing": {"en": "Stop the Marine Health Crisis before it spreads across the Mediterranean. Reach a Sea Health Index of 60% by 2046, or push every region's crisis below 25%. You lose if warming hits +4.0°C, Sea Health falls under 10%, or both budget and political support run out."},
	"ui.menu.start": {"en": "New Game"},
	"ui.menu.language": {"en": "Language"},
	"ui.menu.quit": {"en": "Quit"},
	"ui.menu.event_line": {"en": "GameUP Türkiye Game Hackathon · COP31 Türkiye – Antalya"},
	"ui.menu.controls": {"en": "Click a sea region to select it · Space: pause · 1 / 2 / 3: speed · Esc: menu"},

	# --- Pause menu ---
	"ui.pause.title": {"en": "PAUSED"},
	"ui.pause.resume": {"en": "Resume"},
	"ui.pause.restart": {"en": "Restart"},
	"ui.pause.main_menu": {"en": "Main Menu"},
	"ui.pause.quit": {"en": "Quit to Desktop"},

	# --- HUD: time and speed ---
	"hud.year": {"en": "Year: {year}"},
	"hud.years_left": {"en": "Years left: {n}"},
	"hud.speed.pause": {"en": "Pause"},
	"hud.speed.x1": {"en": "Normal speed"},
	"hud.speed.x2": {"en": "Fast"},
	"hud.speed.x4": {"en": "Very fast"},

	# --- HUD: resources and global indicators ---
	"hud.budget": {"en": "Budget"},
	"hud.political": {"en": "Political Support"},
	"hud.science": {"en": "Science"},
	"hud.global_title": {"en": "BASIN STATUS"},
	"hud.sea_health": {"en": "Sea Health Index"},
	"hud.crisis": {"en": "Crisis Level"},
	"hud.temperature": {"en": "Global Warming"},
	"hud.awareness": {"en": "Public Awareness"},
	"hud.goal": {"en": "Goal: Sea Health ≥ 60% by 2046"},
	"hud.temp_limit": {"en": "Limit: +4.0°C"},

	# --- HUD: region panel ---
	"hud.region_title": {"en": "REGION"},
	"hud.region.none": {"en": "Select a sea region on the map."},
	"hud.region.pollution": {"en": "Pollution"},
	"hud.region.coral": {"en": "Coral Health"},
	"hud.region.seagrass": {"en": "Posidonia Seagrass"},
	"hud.region.fish": {"en": "Fish Stock"},
	"hud.region.awareness": {"en": "Awareness"},
	"hud.region.protection": {"en": "Protection"},
	"hud.region.crisis": {"en": "Crisis"},
	"hud.region.coastal_pop": {"en": "Coastal Population Pressure"},
	"hud.status.healthy": {"en": "HEALTHY"},
	"hud.status.stressed": {"en": "STRESSED"},
	"hud.status.critical": {"en": "CRITICAL"},
	"hud.status.collapsed": {"en": "COLLAPSING"},

	# --- HUD: field operations ---
	"hud.actions_title": {"en": "FIELD OPERATIONS"},
	"hud.cost": {"en": "Cost"},
	"hud.action.ready": {"en": "Ready"},
	"hud.action.cooldown": {"en": "Ready in: {n} s"},
	"hud.action.no_funds": {"en": "Not enough resources"},
	"hud.action.select_region": {"en": "Select a region first"},
	"action.cleanup.name": {"en": "Cleanup Operation"},
	"action.cleanup.desc": {"en": "Skimmer vessels and divers remove waste. Cuts pollution in this region."},
	"action.patrol.name": {"en": "Marine Patrol"},
	"action.patrol.desc": {"en": "Enforce no-take zones and stop illegal fishing. Raises protection."},
	"action.campaign.name": {"en": "Awareness Campaign"},
	"action.campaign.desc": {"en": "Coastal outreach and media. Raises awareness here and in neighbouring regions."},

	# --- Regions and map ---
	"region.western.name": {"en": "Western Med"},
	"region.central.name": {"en": "Central Med (Sicily Strait)"},
	"region.adriatic.name": {"en": "Adriatic"},
	"region.aegean.name": {"en": "Aegean Coast"},
	"region.marmara.name": {"en": "Marmara Inland Sea"},
	"region.blacksea.name": {"en": "Black Sea Entrance"},
	"region.antalya.name": {"en": "Antalya Gulf"},
	"region.levant.name": {"en": "Levant (Eastern Med)"},
	"map.hero_label": {"en": "ANTALYA · COP31"},

	# --- Toasts ---
	"toast.game_start": {"en": "COP31 Marine Coalition activated. The basin is in your hands."},
	"toast.spread": {"en": "Crisis spreading: {from} → {to}"},
	"toast.region_critical": {"en": "{region}: ecosystem in critical condition!"},
	"toast.region_recovering": {"en": "{region} is recovering."},
	"toast.action.cleanup": {"en": "Cleanup operation launched: {region}."},
	"toast.action.patrol": {"en": "Marine patrol deployed: {region}."},
	"toast.action.campaign": {"en": "Awareness campaign started: {region}."},
	"toast.temp_warning": {"en": "Global warming reached +{temp}°C."},
	"toast.low_resources": {"en": "Budget and political support are running low!"},

	# --- End screens ---
	"end.win.title": {"en": "BASIN RESTORED"},
	"end.win.health.text": {"en": "The Mediterranean breathes again. Sea Health reached {health}% by {year}."},
	"end.win.crisis.text": {"en": "Every region is below the crisis threshold. The reverse pandemic is contained."},
	"end.lose.temperature.title": {"en": "TIPPING POINT"},
	"end.lose.temperature.text": {"en": "Global warming hit +4.0°C. Marine ecosystems collapsed beyond recovery."},
	"end.lose.health.title": {"en": "DEAD SEA"},
	"end.lose.health.text": {"en": "Sea Health fell below 10%. The basin can no longer sustain life."},
	"end.lose.resources.title": {"en": "COALITION COLLAPSED"},
	"end.lose.resources.text": {"en": "Budget and political support are both gone. The coalition has dissolved."},
	"end.lose.time.title": {"en": "TIME RAN OUT"},
	"end.lose.time.text": {"en": "2046 has arrived and the basin is still sick. Sea Health: {health}%."},
	"end.stat.health": {"en": "Sea Health Index: {v}%"},
	"end.stat.temp": {"en": "Global warming: +{v}°C"},
	"end.stat.year": {"en": "Final year: {v}"},
	"end.stat.actions": {"en": "Operations launched: {v}"},
	"end.play_again": {"en": "Play Again"},
	"end.main_menu": {"en": "Main Menu"},
}

var lang: String = FALLBACK
var _warned: Dictionary = {}


func _ready() -> void:
	lang = _load_saved_language()


## Translated text for key in the current language, with {name} placeholders filled from
## args. Falls back to English, then to the key itself (and warns once).
func t(key: String, args: Dictionary = {}) -> String:
	var text: String = key
	if STRINGS.has(key):
		var entry: Dictionary = STRINGS[key]
		if entry.has(lang):
			text = entry[lang]
		elif entry.has(FALLBACK):
			text = entry[FALLBACK]
	elif not _warned.has(key):
		_warned[key] = true
		push_warning("I18n: missing key '%s'" % key)
	if not args.is_empty():
		text = text.format(args)
	return text


func has_key(key: String) -> bool:
	return STRINGS.has(key)


## Native display name of a language code ("Türkçe", "English", "Русский").
func lang_name(code: String) -> String:
	return t("lang.native." + code)


func set_language(code: String) -> void:
	if not LANGS.has(code) or code == lang:
		return
	lang = code
	_save_language()
	EventBus.language_changed.emit(lang)


func _load_saved_language() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var saved: String = str(cfg.get_value("general", "language", ""))
		if LANGS.has(saved):
			return saved
	var os_lang: String = OS.get_locale_language()
	if LANGS.has(os_lang):
		return os_lang
	return FALLBACK


func _save_language() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)  # keep other settings; a missing file is fine
	cfg.set_value("general", "language", lang)
	cfg.save(SETTINGS_PATH)
