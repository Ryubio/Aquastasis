extends RefCounted
## String table (policy tree modal and event card chrome (buttons, labels, states). Owner: tree UI module (en), localization (tr/ru)) merged by the I18n autoload; never read directly by game code.
## Format: key -> {"tr": ..., "en": ..., "ru": ...}. Keys are unique across all tables.

const STRINGS := {
	# --- Policy tree: header ---
	"ui.tree.title": {"tr": "POLİTİKA AĞACI", "en": "POLICY TREE", "ru": "ДРЕВО ПОЛИТИК"},
	"ui.tree.subtitle": {"tr": "COP31 Deniz Koalisyonu · kalıcı politikalar · zaman duraklatıldı", "en": "COP31 Marine Coalition · permanent policies · time is paused", "ru": "Морская коалиция COP31 · постоянные политики · время остановлено"},
	"ui.tree.adopted_count": {"tr": "Kabul Edilen: {n}/{total}", "en": "Adopted: {n}/{total}", "ru": "Принято: {n}/{total}"},
	"ui.tree.close": {"tr": "Kapat", "en": "Close", "ru": "Закрыть"},
	"ui.tree.hint": {"tr": "Ayrıntılar için tıkla · kabul etmek için çift tıkla", "en": "Click a policy for details · double-click to adopt", "ru": "Нажмите для деталей · двойной клик для принятия"},
	"ui.tree.tier": {"tr": "Kademe {n}", "en": "Tier {n}", "ru": "Уровень {n}"},

	# --- Policy tree: node states ---
	"ui.tree.state.locked": {"tr": "KİLİTLİ", "en": "LOCKED", "ru": "ЗАБЛОКИРОВАНО"},
	"ui.tree.state.available": {"tr": "UYGUN", "en": "AVAILABLE", "ru": "ДОСТУПНО"},
	"ui.tree.state.affordable": {"tr": "KABULE HAZIR", "en": "READY TO ADOPT", "ru": "ГОТОВО К ПРИНЯТИЮ"},
	"ui.tree.state.adopted": {"tr": "YÜRÜRLÜKTE", "en": "ADOPTED", "ru": "ПРИНЯТО"},
	"ui.tree.state.ramping": {"tr": "UYGULANIYOR: {pct}", "en": "IMPLEMENTING {pct}", "ru": "ВНЕДРЕНИЕ: {pct}"},

	# --- Policy tree: details pane ---
	"ui.tree.cost": {"tr": "MALİYET", "en": "COST", "ru": "СТОИМОСТЬ"},
	"ui.tree.free": {"tr": "Ücretsiz", "en": "Free", "ru": "Бесплатно"},
	"ui.tree.requires": {"tr": "GEREKSİNİMLER", "en": "REQUIRES", "ru": "ТРЕБУЕТСЯ"},
	"ui.tree.requires_none": {"tr": "Ön koşul yok: başlangıç politikası.", "en": "No prerequisites: a starting policy.", "ru": "Нет условий: базовая политика."},
	"ui.tree.effect": {"tr": "ETKİ", "en": "EFFECT", "ru": "ЭФФЕКТ"},
	"ui.tree.counters": {"tr": "DİRENCİ KIRAR", "en": "COUNTERS RESISTANCE", "ru": "НЕЙТРАЛИЗУЕТ СТОЙКОСТЬ"},
	"ui.tree.counter.active": {"tr": "Şu an aktif: bu politikayı kabul etmek onu iyileştirir.", "en": "Active now: adopting this policy cures it.", "ru": "Активно сейчас: принятие этой политики устранит кризис."},
	"ui.tree.counter.immune": {"tr": "Yürürlükte: kriz artık bu direnci geliştiremez.", "en": "In force: the crisis can no longer evolve this resistance.", "ru": "Действует: кризис больше не разовьет эту стойкость."},
	"ui.tree.counter.prevent": {"tr": "Henüz aktif değil. Kabul edildiğinde krizi buna karşı bağışık kılar.", "en": "Not active yet. Adopting this policy makes the crisis immune to it.", "ru": "Еще не активно. Принятие предотвратит развитие этой стойкости."},
	"ui.tree.real_world": {"tr": "GERÇEK DÜNYA", "en": "REAL WORLD", "ru": "РЕАЛЬНЫЙ МИР"},
	"ui.tree.adopt": {"tr": "POLİTİKAYI KABUL ET", "en": "ADOPT POLICY", "ru": "ПРИНЯТЬ ПОЛИТИКУ"},
	"ui.tree.adopted_button": {"tr": "POLİTİKA YÜRÜRLÜKTE", "en": "POLICY IN FORCE", "ru": "ПОЛИТИКА ДЕЙСТВУЕТ"},
	"ui.tree.locked_button": {"tr": "KİLİTLİ", "en": "LOCKED", "ru": "ЗАБЛОКИРОВАНО"},
	"ui.tree.why.ready": {"tr": "Harcama kalıcıdır. Etkisi zamanla devreye girer.", "en": "Spending is permanent. Its effect ramps in over time.", "ru": "Затраты необратимы. Эффект нарастает со временем."},
	"ui.tree.why.locked": {"tr": "Önce gerekli politikaları kabul et.", "en": "Adopt the required policies first.", "ru": "Сначала примите предварительные политики."},
	"ui.tree.why.cost": {"tr": "Yeterli kaynak yok. Veri baloncukları topla ve denizi temiz tut.", "en": "Not enough resources yet. Collect data bubbles and keep the sea healthy.", "ru": "Недостаточно ресурсов. Собирайте сферы и берегите море."},
	"ui.tree.why.event": {"tr": "Önce bekleyen karar kartını cevapla.", "en": "Answer the decision card first.", "ru": "Сначала решите кризисную карту."},
	"ui.tree.why.ramping": {"tr": "Uygulanma oranı: {pct}", "en": "Implementation: {pct}", "ru": "Внедрение: {pct}"},
	"ui.tree.why.done": {"tr": "Tamamen yürürlüğe girdi.", "en": "Fully implemented.", "ru": "Полностью внедрено."},
	"ui.tree.why.no_game": {"tr": "Politika kabul etmek için oyunu başlat.", "en": "Start a game to adopt policies.", "ru": "Начните игру, чтобы принимать политики."},
	"ui.tree.adopt_failed": {"tr": "Kabul reddedildi: maliyeti ve ön koşulları kontrol et.", "en": "Adoption refused: check the cost and prerequisites.", "ru": "Отказ: проверьте ресурсы и требования."},

	# --- Policy tree: evolution strip ---
	"ui.tree.evo.title": {"tr": "KRİZ ADAPTASYONU", "en": "CRISIS ADAPTATION", "ru": "АДАПТАЦИЯ КРИЗИСА"},
	"ui.tree.evo.hint": {"tr": "Son hamlelerinde tek bir dal baskın olursa, kriz ona karşı direnç geliştirir.", "en": "If one branch dominates your recent moves, the crisis evolves a resistance against it.", "ru": "Если преобладает одно направление действий, кризис выработает к нему иммунитет."},
	"ui.tree.evo.moves": {"tr": "Son hamleler: {n} · Eşik: {m}", "en": "Recent moves: {n} · evolves from {m}", "ru": "Действия: {n} · мутация с {m}"},
	"ui.tree.evo.limit": {"tr": "Limit: {pct}", "en": "Limit: {pct}", "ru": "Порог: {pct}"},
	"ui.tree.evo.active_tag": {"tr": "DİRENÇLİ", "en": "RESISTANT", "ru": "ИММУНИТЕТ"},
	"ui.tree.evo.resist_title": {"tr": "AKTİF DİRENÇLER", "en": "ACTIVE RESISTANCES", "ru": "АКТИВНЫЕ МУТАЦИИ"},
	"ui.tree.evo.none": {"tr": "Henüz yok. Dengeli strateji krizi zayıf tutar.", "en": "None so far. A varied strategy keeps it that way.", "ru": "Пока нет. Сбалансированная тактика сдерживает мутации."},
	"ui.tree.evo.cure": {"tr": "Çözüm:", "en": "Cure:", "ru": "Лечение:"},
	"ui.tree.evo.more": {"tr": "Ayrıca aktif: {n}", "en": "Also active: {n}", "ru": "Также активно: {n}"},

	# --- Decision card ---
	"ui.card.kind.alert": {"tr": "EKOLOJİK ALARM", "en": "ECOLOGICAL ALERT", "ru": "ЭКОЛОГИЧЕСКАЯ ТРЕВОГА"},
	"ui.card.kind.pressure": {"tr": "SİYASİ BASKI", "en": "POLITICAL PRESSURE", "ru": "ПОЛИТИЧЕСКОЕ ДАВЛЕНИЕ"},
	"ui.card.kind.opportunity": {"tr": "FIRSAT", "en": "OPPORTUNITY", "ru": "ВОЗМОЖНОСТЬ"},
	"ui.card.kind.summit": {"tr": "COP31 ZİRVESİ", "en": "COP31 SUMMIT", "ru": "САММИТ COP31"},
	"ui.card.decision": {"tr": "KARAR GEREKİYOR", "en": "DECISION REQUIRED", "ru": "ТРЕБУЕТСЯ РЕШЕНИЕ"},
	"ui.card.paused": {"tr": "Sen karar verene kadar zaman duraklatıldı.", "en": "Time is paused until you decide.", "ru": "Время остановлено до принятия решения."},
	"ui.card.basin_wide": {"tr": "Tüm havza", "en": "Whole basin", "ru": "Весь бассейн"},
	"ui.card.free": {"tr": "Maliyetsiz", "en": "No cost", "ru": "Бесплатно"},
	"ui.card.tone.pos": {"tr": "DENİZİ KORUR", "en": "PROTECTS THE SEA", "ru": "ЗАЩИЩАЕТ МОРЕ"},
	"ui.card.tone.neutral": {"tr": "UZLAŞI", "en": "TRADE-OFF", "ru": "КОМПРОМИСС"},
	"ui.card.tone.neg": {"tr": "RİSKLİ", "en": "RISKY", "ru": "РИСКОВАННО"},
	"ui.card.cant_afford": {"tr": "Yetersiz kaynak", "en": "Not enough resources", "ru": "Недостаточно ресурсов"},
	"ui.card.outcome": {"tr": "SONUÇ", "en": "OUTCOME", "ru": "ИТОГ"},
	"ui.card.you_chose": {"tr": "Kararın: {choice}", "en": "Decision: {choice}", "ru": "Выбор: {choice}"},
	"ui.card.continue": {"tr": "Devam Et", "en": "Continue", "ru": "Продолжить"},
	"ui.card.keys_choose": {"tr": "Seçim için 1 veya 2'ye bas", "en": "Press 1 or 2 to choose", "ru": "Нажмите 1 или 2 для выбора"},
	"ui.card.keys_continue": {"tr": "Enter: devam et", "en": "Enter: continue", "ru": "Enter: продолжить"},
	"ui.card.unknown_title": {"tr": "Beklenmedik Gelişme", "en": "Unexpected Development", "ru": "Неожиданное событие"},
	"ui.card.unknown_text": {"tr": "Havzada önemli bir durum meydana geldi. Koalisyonun nasıl yanıt vereceğini seç.", "en": "Something is happening in the basin. Choose how the coalition responds.", "ru": "В бассейне произошло важное событие. Выберите ответ коалиции."},
}
