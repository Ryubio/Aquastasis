extends Node
## I18n (autoload): the single source of every user-visible string (tr / en / ru).
## Usage: I18n.t("hud.year", {"year": "2031"}) fills {year}. set_language() switches live,
## persists to user://settings.cfg and emits EventBus.language_changed.

const LANGS := ["tr", "en", "ru"]
const FALLBACK := "en"
const SETTINGS_PATH := "user://settings.cfg"

## key -> {"tr": ..., "en": ..., "ru": ...}. Uppercase variants are separate keys:
## never call to_upper()/to_lower() on translated text (Turkish i/İ, ı/I).
## Style: Turkish uses informal "sen" and the Turkish percent form (%60); Russian uses
## "вы" and avoids number-dependent plurals ("Осталось лет: 12"). Decimals keep a dot so
## prose matches the numbers the HUD formats in code.
const STRINGS := {
	# --- Language names (always shown in their own language) ---
	"lang.native.tr": {"tr": "Türkçe", "en": "Türkçe", "ru": "Türkçe"},
	"lang.native.en": {"tr": "English", "en": "English", "ru": "English"},
	"lang.native.ru": {"tr": "Русский", "en": "Русский", "ru": "Русский"},

	# --- Number formats (code-built values; Turkish puts the percent sign first) ---
	"fmt.pct": {"tr": "%{v}", "en": "{v}%", "ru": "{v}%"},

	# --- Title ---
	"game.title": {"tr": "AQUASTASIS", "en": "AQUASTASIS", "ru": "AQUASTASIS"},
	"game.subtitle": {
		"tr": "COP31 Antalya — Akdeniz Ekosistem Savunması",
		"en": "COP31 Antalya — Mediterranean Ecosystem Defense",
		"ru": "COP31 Анталья — Защита экосистемы Средиземноморья",
	},

	# --- Main menu ---
	"ui.menu.tagline": {
		"tr": "Akdeniz havzası çöküyor. Sen COP31 Deniz Koalisyonusun.",
		"en": "The basin is collapsing. You are the COP31 Marine Coalition.",
		"ru": "Средиземноморье на грани коллапса. Вы — Морская коалиция COP31.",
	},
	"ui.menu.briefing": {
		"tr": "Deniz Sağlığı Krizini tüm Akdeniz'e yayılmadan durdur. 2046'ya kadar Deniz Sağlığı Endeksini %60'a çıkar ya da her bölgedeki krizi %25'in altına indir. Isınma +4.0°C'ye ulaşırsa, Deniz Sağlığı %10'un altına düşerse ya da bütçe ve siyasi destek birlikte tükenirse kaybedersin.",
		"en": "Stop the Marine Health Crisis before it spreads across the Mediterranean. Reach a Sea Health Index of 60% by 2046, or push every region's crisis below 25%. You lose if warming hits +4.0°C, Sea Health falls under 10%, or both budget and political support run out.",
		"ru": "Остановите экологический кризис, пока он не охватил всё Средиземноморье. Доведите индекс здоровья моря до 60% к 2046 году или снизьте уровень кризиса во всех регионах ниже 25%. Поражение: потепление до +4.0°C, здоровье моря ниже 10% или потеря и бюджета, и политической поддержки.",
	},
	"ui.menu.start": {"tr": "Yeni Oyun", "en": "New Game", "ru": "Новая игра"},
	"ui.menu.language": {"tr": "Dil", "en": "Language", "ru": "Язык"},
	"ui.menu.quit": {"tr": "Çıkış", "en": "Quit", "ru": "Выход"},
	"ui.menu.event_line": {
		"tr": "GameUP Türkiye Oyun Hackathonu · COP31 Türkiye – Antalya",
		"en": "GameUP Türkiye Game Hackathon · COP31 Türkiye – Antalya",
		"ru": "Игровой хакатон GameUP Türkiye · COP31, Анталья, Турция",
	},
	"ui.menu.controls": {
		"tr": "Bölge seçmek için denize tıkla · Boşluk: duraklat · 1 / 2 / 3: hız · Esc: menü",
		"en": "Click a sea region to select it · Space: pause · 1 / 2 / 3: speed · Esc: menu",
		"ru": "Выбор региона: щелчок по морю · Пробел: пауза · 1 / 2 / 3: скорость · Esc: меню",
	},

	# --- Pause menu ---
	"ui.pause.title": {"tr": "DURAKLATILDI", "en": "PAUSED", "ru": "ПАУЗА"},
	"ui.pause.resume": {"tr": "Devam Et", "en": "Resume", "ru": "Продолжить"},
	"ui.pause.restart": {"tr": "Yeniden Başlat", "en": "Restart", "ru": "Начать заново"},
	"ui.pause.main_menu": {"tr": "Ana Menü", "en": "Main Menu", "ru": "Главное меню"},
	"ui.pause.quit": {"tr": "Masaüstüne Çık", "en": "Quit to Desktop", "ru": "Выйти на рабочий стол"},

	# --- HUD: time and speed ---
	"hud.year": {"tr": "Yıl: {year}", "en": "Year: {year}", "ru": "Год: {year}"},
	"hud.years_left": {"tr": "Kalan yıl: {n}", "en": "Years left: {n}", "ru": "Осталось лет: {n}"},
	"hud.speed.pause": {"tr": "Duraklat", "en": "Pause", "ru": "Пауза"},
	"hud.speed.x1": {"tr": "Normal hız", "en": "Normal speed", "ru": "Обычная скорость"},
	"hud.speed.x2": {"tr": "Hızlı", "en": "Fast", "ru": "Быстро"},
	"hud.speed.x4": {"tr": "Çok hızlı", "en": "Very fast", "ru": "Очень быстро"},

	# --- HUD: resources and global indicators ---
	"hud.budget": {"tr": "Bütçe", "en": "Budget", "ru": "Бюджет"},
	"hud.political": {"tr": "Siyasi Destek", "en": "Political Support", "ru": "Политическая поддержка"},
	"hud.science": {"tr": "Bilim", "en": "Science", "ru": "Наука"},
	"hud.global_title": {"tr": "HAVZA DURUMU", "en": "BASIN STATUS", "ru": "СОСТОЯНИЕ АКВАТОРИИ"},
	"hud.sea_health": {"tr": "Deniz Sağlığı Endeksi", "en": "Sea Health Index", "ru": "Индекс здоровья моря"},
	"hud.crisis": {"tr": "Kriz Seviyesi", "en": "Crisis Level", "ru": "Уровень кризиса"},
	"hud.temperature": {"tr": "Küresel Isınma", "en": "Global Warming", "ru": "Глобальное потепление"},
	"hud.awareness": {"tr": "Kamuoyu Farkındalığı", "en": "Public Awareness", "ru": "Осведомлённость общества"},
	"hud.goal": {
		"tr": "Hedef: 2046'da Deniz Sağlığı ≥ %60",
		"en": "Goal: Sea Health ≥ 60% by 2046",
		"ru": "Цель: здоровье моря ≥ 60% к 2046 году",
	},
	"hud.temp_limit": {"tr": "Sınır: +4.0°C", "en": "Limit: +4.0°C", "ru": "Предел: +4.0°C"},

	# --- HUD: region panel ---
	"hud.region_title": {"tr": "BÖLGE", "en": "REGION", "ru": "РЕГИОН"},
	"hud.region.none": {
		"tr": "Haritadan bir deniz bölgesi seç.",
		"en": "Select a sea region on the map.",
		"ru": "Выберите морской регион на карте.",
	},
	"hud.region.pollution": {"tr": "Kirlilik", "en": "Pollution", "ru": "Загрязнение"},
	"hud.region.coral": {"tr": "Mercan Sağlığı", "en": "Coral Health", "ru": "Здоровье кораллов"},
	"hud.region.seagrass": {"tr": "Posidonia Çayırları", "en": "Posidonia Seagrass", "ru": "Луга посидонии"},
	"hud.region.fish": {"tr": "Balık Stoku", "en": "Fish Stock", "ru": "Рыбные запасы"},
	"hud.region.awareness": {"tr": "Farkındalık", "en": "Awareness", "ru": "Осведомлённость"},
	"hud.region.protection": {"tr": "Koruma", "en": "Protection", "ru": "Охрана"},
	"hud.region.crisis": {"tr": "Kriz", "en": "Crisis", "ru": "Кризис"},
	"hud.region.coastal_pop": {
		"tr": "Kıyı Nüfusu Baskısı",
		"en": "Coastal Population Pressure",
		"ru": "Антропогенная нагрузка",
	},
	# Status words are gender-neutral in Russian (they label regions of any gender).
	"hud.status.healthy": {"tr": "SAĞLIKLI", "en": "HEALTHY", "ru": "В НОРМЕ"},
	"hud.status.stressed": {"tr": "BASKI ALTINDA", "en": "STRESSED", "ru": "ПОД УГРОЗОЙ"},
	"hud.status.critical": {"tr": "KRİTİK", "en": "CRITICAL", "ru": "КРИТИЧНО"},
	"hud.status.collapsed": {"tr": "ÇÖKÜYOR", "en": "COLLAPSING", "ru": "КОЛЛАПС"},

	# --- HUD: field operations ---
	"hud.actions_title": {"tr": "SAHA OPERASYONLARI", "en": "FIELD OPERATIONS", "ru": "ПОЛЕВЫЕ ОПЕРАЦИИ"},
	"hud.cost": {"tr": "Maliyet", "en": "Cost", "ru": "Стоимость"},
	"hud.cost_line": {"tr": "Maliyet: {list}", "en": "Cost: {list}", "ru": "Стоимость: {list}"},
	"hud.action.unavailable": {"tr": "Kullanılamaz", "en": "Unavailable", "ru": "Недоступно"},
	"hud.action.ready": {"tr": "Hazır", "en": "Ready", "ru": "Готово"},
	"hud.action.cooldown": {"tr": "Hazırlanıyor: {n} sn", "en": "Ready in: {n} s", "ru": "Готово через: {n} с"},
	"hud.action.no_funds": {"tr": "Yetersiz kaynak", "en": "Not enough resources", "ru": "Не хватает ресурсов"},
	# Shown in a clipped single-line label: avoid a leading capital with a diacritic (Ö).
	"hud.action.select_region": {"tr": "Bölge seç", "en": "Select a region first", "ru": "Сначала выберите регион"},
	"action.cleanup.name": {"tr": "Temizlik Operasyonu", "en": "Cleanup Operation", "ru": "Операция по очистке"},
	"action.cleanup.desc": {
		"tr": "Temizlik tekneleri ve dalgıçlar atıkları toplar. Bu bölgedeki kirliliği azaltır.",
		"en": "Skimmer vessels and divers remove waste. Cuts pollution in this region.",
		"ru": "Суда-сборщики и водолазы убирают мусор. Снижает загрязнение в этом регионе.",
	},
	"action.patrol.name": {"tr": "Deniz Devriyesi", "en": "Marine Patrol", "ru": "Морской патруль"},
	"action.patrol.desc": {
		"tr": "Avlanmaya kapalı alanları denetler, yasa dışı balıkçılığı engeller. Korumayı artırır.",
		"en": "Enforce no-take zones and stop illegal fishing. Raises protection.",
		"ru": "Контроль зон запрета лова и пресечение браконьерства. Повышает охрану.",
	},
	"action.campaign.name": {"tr": "Farkındalık Kampanyası", "en": "Awareness Campaign", "ru": "Просветительская кампания"},
	"action.campaign.desc": {
		"tr": "Kıyı halkıyla buluşmalar ve medya çalışmaları. Burada ve komşu bölgelerde farkındalığı artırır.",
		"en": "Coastal outreach and media. Raises awareness here and in neighbouring regions.",
		"ru": "Работа с жителями побережья и СМИ. Повышает осведомлённость здесь и в соседних регионах.",
	},

	# --- Regions and map ---
	"region.western.name": {"tr": "Batı Akdeniz", "en": "Western Med", "ru": "Западное Средиземноморье"},
	# Russian drops the English hints in parentheses: the full names already wrap to two
	# lines on the map labels, so a third line would cover the region.
	"region.central.name": {
		"tr": "Orta Akdeniz (Sicilya Boğazı)",
		"en": "Central Med (Sicily Strait)",
		"ru": "Центральное Средиземноморье",
	},
	"region.adriatic.name": {"tr": "Adriyatik", "en": "Adriatic", "ru": "Адриатика"},
	"region.aegean.name": {"tr": "Ege Kıyıları", "en": "Aegean Coast", "ru": "Эгейское побережье"},
	"region.marmara.name": {"tr": "Marmara İç Denizi", "en": "Marmara Inland Sea", "ru": "Мраморное море"},
	"region.blacksea.name": {"tr": "Karadeniz Girişi", "en": "Black Sea Entrance", "ru": "Вход в Чёрное море"},
	"region.antalya.name": {"tr": "Antalya Körfezi", "en": "Antalya Gulf", "ru": "Анталийский залив"},
	"region.levant.name": {"tr": "Levant (Doğu Akdeniz)", "en": "Levant (Eastern Med)", "ru": "Левант"},
	"map.hero_label": {"tr": "ANTALYA · COP31", "en": "ANTALYA · COP31", "ru": "АНТАЛЬЯ · COP31"},

	# --- Toasts ---
	"toast.game_start": {
		"tr": "COP31 Deniz Koalisyonu göreve başladı. Havza artık sana emanet.",
		"en": "COP31 Marine Coalition activated. The basin is in your hands.",
		"ru": "Морская коалиция COP31 приступила к работе. Судьба моря — в ваших руках.",
	},
	"toast.spread": {"tr": "Kriz yayılıyor: {from} → {to}", "en": "Crisis spreading: {from} → {to}", "ru": "Кризис распространяется: {from} → {to}"},
	"toast.region_critical": {
		"tr": "{region}: ekosistem kritik durumda!",
		"en": "{region}: ecosystem in critical condition!",
		"ru": "{region}: экосистема в критическом состоянии!",
	},
	"toast.region_recovering": {"tr": "{region} toparlanıyor.", "en": "{region} is recovering.", "ru": "{region} восстанавливается."},
	"toast.action.cleanup": {
		"tr": "Temizlik operasyonu başladı: {region}.",
		"en": "Cleanup operation launched: {region}.",
		"ru": "Начата операция по очистке: {region}.",
	},
	"toast.action.patrol": {
		"tr": "Deniz devriyesi görevde: {region}.",
		"en": "Marine patrol deployed: {region}.",
		"ru": "Морской патруль развёрнут: {region}.",
	},
	"toast.action.campaign": {
		"tr": "Farkındalık kampanyası başladı: {region}.",
		"en": "Awareness campaign started: {region}.",
		"ru": "Запущена просветительская кампания: {region}.",
	},
	"toast.temp_warning": {
		"tr": "Küresel ısınma +{temp}°C seviyesine ulaştı.",
		"en": "Global warming reached +{temp}°C.",
		"ru": "Глобальное потепление достигло +{temp}°C.",
	},
	"toast.low_resources": {
		"tr": "Bütçe ve siyasi destek tükenmek üzere!",
		"en": "Budget and political support are running low!",
		"ru": "Бюджет и политическая поддержка на исходе!",
	},
	"toast.depleted": {
		"tr": "Bütçe ve siyasi destek tükendi! Kaynak gelmezse koalisyon dağılacak.",
		"en": "Budget and political support exhausted! The coalition collapses unless funds return.",
		"ru": "Бюджет и политическая поддержка исчерпаны! Без средств коалиция распадётся.",
	},

	# --- End screens ---
	"end.win.title": {"tr": "HAVZA KURTARILDI", "en": "BASIN RESTORED", "ru": "МОРЕ ВОЗРОЖДЕНО"},
	"end.win.health.text": {
		"tr": "Akdeniz yeniden nefes alıyor. {year} yılına kadar Deniz Sağlığı %{health} seviyesine ulaştı.",
		"en": "The Mediterranean breathes again. Sea Health reached {health}% by {year}.",
		"ru": "Средиземное море снова дышит. К {year} году здоровье моря достигло {health}%.",
	},
	"end.win.crisis.text": {
		"tr": "Tüm bölgeler kriz eşiğinin altında. Tersine pandemi kontrol altına alındı.",
		"en": "Every region is below the crisis threshold. The reverse pandemic is contained.",
		"ru": "Уровень кризиса во всех регионах ниже порога. Морская пандемия остановлена.",
	},
	"end.lose.temperature.title": {"tr": "KIRILMA NOKTASI", "en": "TIPPING POINT", "ru": "ТОЧКА НЕВОЗВРАТА"},
	"end.lose.temperature.text": {
		"tr": "Küresel ısınma +4.0°C'ye ulaştı. Deniz ekosistemleri geri dönülmez biçimde çöktü.",
		"en": "Global warming hit +4.0°C. Marine ecosystems collapsed beyond recovery.",
		"ru": "Глобальное потепление достигло +4.0°C. Морские экосистемы разрушены безвозвратно.",
	},
	"end.lose.health.title": {"tr": "ÖLÜ DENİZ", "en": "DEAD SEA", "ru": "МЁРТВОЕ МОРЕ"},
	"end.lose.health.text": {
		"tr": "Deniz Sağlığı %10'un altına düştü. Havza artık yaşamı sürdüremiyor.",
		"en": "Sea Health fell below 10%. The basin can no longer sustain life.",
		"ru": "Здоровье моря упало ниже 10%. Море больше не способно поддерживать жизнь.",
	},
	"end.lose.resources.title": {"tr": "KOALİSYON DAĞILDI", "en": "COALITION COLLAPSED", "ru": "КОАЛИЦИЯ РАСПАЛАСЬ"},
	"end.lose.resources.text": {
		"tr": "Ne bütçe kaldı ne de siyasi destek. Koalisyon fiilen sona erdi.",
		"en": "Budget and political support are both gone. The coalition has dissolved.",
		"ru": "Не осталось ни бюджета, ни политической поддержки. Коалиция прекратила существование.",
	},
	"end.lose.time.title": {"tr": "SÜRE DOLDU", "en": "TIME RAN OUT", "ru": "ВРЕМЯ ВЫШЛО"},
	"end.lose.time.text": {
		"tr": "2046 geldi, havza hâlâ hasta. Deniz Sağlığı: %{health}.",
		"en": "2046 has arrived and the basin is still sick. Sea Health: {health}%.",
		"ru": "Наступил 2046 год, а море так и не оправилось. Здоровье моря: {health}%.",
	},
	"end.stat.health": {"tr": "Deniz Sağlığı Endeksi: %{v}", "en": "Sea Health Index: {v}%", "ru": "Индекс здоровья моря: {v}%"},
	"end.stat.temp": {"tr": "Küresel ısınma: +{v}°C", "en": "Global warming: +{v}°C", "ru": "Глобальное потепление: +{v}°C"},
	"end.stat.year": {"tr": "Bitiş yılı: {v}", "en": "Final year: {v}", "ru": "Год окончания: {v}"},
	"end.stat.actions": {"tr": "Başlatılan operasyon: {v}", "en": "Operations launched: {v}", "ru": "Проведено операций: {v}"},
	"end.play_again": {"tr": "Tekrar Oyna", "en": "Play Again", "ru": "Играть снова"},
	"end.main_menu": {"tr": "Ana Menü", "en": "Main Menu", "ru": "Главное меню"},
}

## Phase 2 string tables, one per content domain so modules can be written and translated in
## parallel. Each file holds `const STRINGS := {key: {"tr", "en", "ru"}}`; lookups still go
## through this autoload only. Keys must be unique across all tables.
const TABLES := [
	preload("res://scripts/i18n_tree.gd"),     # policy tree nodes, branches, evolutions
	preload("res://scripts/i18n_events.gd"),   # decision event cards
	preload("res://scripts/i18n_sim.gd"),      # simulation toasts and news headlines
	preload("res://scripts/i18n_ui_tree.gd"),  # tree modal and event card chrome
	preload("res://scripts/i18n_hud.gd"),      # HUD additions, news ticker, bubbles
]

var lang: String = FALLBACK
var _warned: Dictionary = {}
var _all: Dictionary = {}   # STRINGS merged with every table in TABLES


func _ready() -> void:
	lang = _load_saved_language()
	_ensure_tables()


## Merges the domain tables into _all once (also on first lookup, in case another autoload
## asks for text before this one is ready).
func _ensure_tables() -> void:
	if not _all.is_empty():
		return
	_all = STRINGS.duplicate()
	for t_script in TABLES:
		var table: GDScript = t_script
		var consts: Dictionary = table.get_script_constant_map()
		var strings: Dictionary = consts.get("STRINGS", {})
		for k in strings:
			if _all.has(k):
				push_warning("I18n: duplicate key '%s' in %s" % [str(k), table.resource_path])
			_all[k] = strings[k]


## Translated text for key in the current language, with {name} placeholders filled from
## args. Falls back to English, then to the key itself (and warns once).
func t(key: String, args: Dictionary = {}) -> String:
	_ensure_tables()
	var text: String = key
	if _all.has(key):
		var entry: Dictionary = _all[key]
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
	_ensure_tables()
	return _all.has(key)


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
