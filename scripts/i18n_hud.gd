extends RefCounted
## String table (HUD additions, news ticker templates and ambient headlines, bubble labels. Owner: HUD module (en), localization (tr/ru)) merged by the I18n autoload; never read directly by game code.
## Format: key -> {"tr": ..., "en": ..., "ru": ...}. Keys are unique across all tables.

const STRINGS := {
	# --- HUD: net income per year beside each resource ---
	"hud.rate": {"tr": "{v}/yıl", "en": "{v}/yr", "ru": "{v}/год"},
	"hud.rate.tip": {"tr": "Harcamalardan önceki net yıllık gelir.", "en": "Net income per year, before spending.", "ru": "Чистый годовой доход до расходов."},
	"hud.rate.tip_negative": {
		"tr": "Gelir dengesi negatif: ölen bir deniz koalisyon bütçesini tüketir. Tersine çevirmek için Deniz Sağlığını yükselt.",
		"en": "Income is negative: a dying sea costs the coalition money. Restore Sea Health to turn it around.",
		"ru": "Доход отрицательный: умирающее море истощает казну. Восстановите здоровье моря.",
	},
	"hud.toast.income_negative": {
		"tr": "Gelir dengesi negatife döndü! Kriz bütçeyi tüketiyor.",
		"en": "Income balance turned negative! The dying sea is draining the budget.",
		"ru": "Баланс доходов стал отрицательным! Умирающее море истощает бюджет.",
	},

	# --- HUD: live chart ---
	"hud.chart.title": {"tr": "CANLI EĞİLİM", "en": "LIVE TREND", "ru": "ЖИВОЙ ТРЕНД"},
	"hud.chart.health": {"tr": "Deniz Sağlığı", "en": "Sea Health", "ru": "Здоровье моря"},
	"hud.chart.crisis": {"tr": "Kriz Seviyesi", "en": "Crisis Level", "ru": "Уровень кризиса"},
	"hud.chart.goal": {"tr": "Hedef", "en": "Goal", "ru": "Цель"},

	# --- HUD: crisis resistances and evolution pressure ---
	"hud.resist.title": {"tr": "KRİZ DİRENÇLERİ", "en": "CRISIS RESISTANCES", "ru": "СОПРОТИВЛЕНИЯ КРИЗИСА"},
	"hud.resist.none": {"tr": "Henüz yok. Stratejini çeşitli tutarak böyle kalmasını sağla.", "en": "None yet. Keep your strategy varied to keep it that way.", "ru": "Пока нет. Разнообразьте стратегию, чтобы избежать мутаций."},
	"hud.resist.counter": {"tr": "Karşı politika: {list}", "en": "Countered by: {list}", "ru": "Нейтрализуется: {list}"},
	"hud.resist.counter_unknown": {"tr": "Politika Ağacı'ndaki uygun politikalarla önlenir.", "en": "Countered by matching policies in the Policy Tree.", "ru": "Нейтрализуется политиками в Древе."},
	"hud.resist.more": {"tr": "Ayrıca aktif: {n}", "en": "Also active: {n}", "ru": "Также активно: {n}"},
	"hud.pressure.warn": {"tr": "Kriz direnç geliştiriyor: {branch}", "en": "Crisis adapting to: {branch}", "ru": "Кризис вырабатывает стойкость: {branch}"},
	"hud.pressure.hint": {"tr": "Hamlelerini çeşitlendir, aksi takdirde kriz direnç geliştirecek.", "en": "Diversify your moves or it evolves a resistance.", "ru": "Разнообразьте действия, иначе кризис разовьет сопротивление."},
	"hud.branch.protect": {"tr": "Koruma", "en": "Protection", "ru": "Охрана"},
	"hud.branch.source": {"tr": "Kaynak Kesme", "en": "Source Cutting", "ru": "Устранение источников"},
	"hud.branch.science": {"tr": "Bilim ve Toplum", "en": "Science & Public", "ru": "Наука и общество"},
	"hud.branch.economy": {"tr": "Ekonomi ve Diplomasi", "en": "Economy & Diplomacy", "ru": "Экономика и дипломатия"},

	# --- HUD: policy tree button and key hints ---
	"hud.tree.button": {"tr": "POLİTİKA AĞACI", "en": "POLICY TREE", "ru": "ДРЕВО ПОЛИТИК"},
	"hud.tree.available": {"tr": "Kabul edilebilir: {n}", "en": "Ready to adopt: {n}", "ru": "Доступно к принятию: {n}"},
	"hud.tree.none": {"tr": "Sonraki politikanı planla", "en": "Plan your next policy", "ru": "Планируйте следующую политику"},
	"hud.tree.tip": {
		"tr": "Bütçe, Siyasi Destek ve Bilim ile finanse edilen kalıcı politikalar. Her biri bir kriz direncini kırar.",
		"en": "Permanent policies paid with Budget, Political Support and Science. Each one also counters a crisis resistance.",
		"ru": "Постоянные политики, оплачиваемые Бюджетом, Поддержкой и Наукой. Каждая нейтрализует стойкость кризиса.",
	},
	"hud.key_hint": {"tr": "Kısayol: {key}", "en": "Hotkey: {key}", "ru": "Горячая клавиша: {key}"},

	# --- Data bubbles ---
	"fx.bubble.collect": {"tr": "Toplamak için tıkla", "en": "Click to collect", "ru": "Нажмите для сбора"},

	# --- News ticker chrome ---
	"news.tag": {"tr": "HAVZA HABERLERİ", "en": "BASIN NEWS", "ru": "НОВОСТИ БАССЕЙНА"},
	"news.chip.breaking": {"tr": "SON DAKİKA", "en": "BREAKING", "ru": "СРОЧНО"},
	"news.chip.good": {"tr": "İYİ HABER", "en": "GOOD NEWS", "ru": "ХОРОШИЕ НОВОСТИ"},
	"news.chip.fact": {"tr": "BİLGİ", "en": "FACT", "ru": "ФАКТ"},
	"news.chip.tip": {"tr": "İPUCU", "en": "TIP", "ru": "СОВЕТ"},
	"news.welcome": {"tr": "AQUASTASIS: Deniz Koalisyonu Akdeniz havzasının kontrolünü devraldı", "en": "AQUASTASIS: the Marine Coalition takes command of the Mediterranean basin", "ru": "AQUASTASIS: Морская коалиция берет под контроль Средиземноморский бассейн"},

	# --- Ambient headlines: a region in trouble ---
	"news.amb.pollution": {"tr": "{region}: kirlilik %{v} seviyesine ulaştı, yüzücülere uyarı yapıldı", "en": "{region}: pollution readings climb to {v}%, swimmers warned off the beaches", "ru": "{region}: загрязнение достигло {v}%, купание не рекомендуется"},
	"news.amb.coral": {"tr": "{region}: resiflerde ağarma yayılıyor, mercan sağlığı %{v} seviyesinde", "en": "{region}: bleaching spreads across the reefs, coral health down to {v}%", "ru": "{region}: обесцвечивание рифов, здоровье кораллов упало до {v}%"},
	"news.amb.seagrass": {"tr": "{region}: Posidonia çayırları seyrekleşiyor, kapsama alanı %{v}", "en": "{region}: Posidonia meadows thinning, coverage down to {v}%", "ru": "{region}: луга посидонии редеют, покрытие упало до {v}%"},
	"news.amb.fish": {"tr": "{region}: balıkçılar boş ağlarla dönüyor, balık stoku %{v}", "en": "{region}: fishers return with empty nets, fish stock at {v}%", "ru": "{region}: рыбаки возвращаются без улова, запасы рыбы: {v}%"},
	"news.amb.collapse": {"tr": "{region}: bilim insanları ekosistemin çökmekte olduğunu belirtiyor", "en": "{region}: scientists warn the ecosystem is collapsing", "ru": "{region}: ученые заявляют об угрозе коллапса экосистемы"},
	"news.amb.worsening": {"tr": "{region}: kriz derinleşiyor, seviye şu an %{v}", "en": "{region}: the crisis deepens, level now {v}%", "ru": "{region}: кризис усугубляется, уровень достиг {v}%"},

	# --- Ambient headlines: a region recovering ---
	"news.amb.clean": {"tr": "{region}: berrak sular geri dönüyor, kriz %{v} seviyesine indi", "en": "{region}: clear water returns, crisis level down to {v}%", "ru": "{region}: вода очищается, уровень кризиса упал до {v}%"},
	"news.amb.seagrass_good": {"tr": "{region}: Posidonia çayırları %{v} seviyesinde, mavi karbon depolanıyor", "en": "{region}: Posidonia meadows thrive at {v}%, locking away blue carbon", "ru": "{region}: луга посидонии процветают ({v}%), накапливая синий углерод"},
	"news.amb.fish_good": {"tr": "{region}: balık stoku %{v} seviyesine yükseldi, verimli av bildirildi", "en": "{region}: fish stock rebounds to {v}%, cooperatives report better catches", "ru": "{region}: запасы рыбы восстановились до {v}%, уловы растут"},
	"news.amb.coral_good": {"tr": "{region}: dalgıçlar canlı resifleri kaydetti, mercan sağlığı %{v}", "en": "{region}: divers film vibrant reefs, coral health at {v}%", "ru": "{region}: дайверы наблюдают живые рифы, здоровье кораллов {v}%"},
	"news.amb.protected": {"tr": "{region}: devriyeler koruma alanlarını güvenceye aldı, koruma %{v}", "en": "{region}: patrols enforce no-take zones, protection at {v}%", "ru": "{region}: заповедные зоны патрулируются, защита {v}%"},
	"news.amb.aware": {"tr": "{region}: sahil temizliğine katılım rekor kırdı, farkındalık %{v}", "en": "{region}: volunteers flock to beach clean-ups, awareness at {v}%", "ru": "{region}: волонтеры очищают пляжи, осведомленность {v}%"},
	"news.amb.improving": {"tr": "{region}: toparlanma başladı, kriz %{v} seviyesine geriledi", "en": "{region}: the crisis eases to {v}% as recovery takes hold", "ru": "{region}: кризис спадает до {v}% благодаря защитным мерам"},

	# --- Ambient headlines: the whole basin ---
	"news.amb.health_up": {"tr": "Deniz Sağlığı Endeksi %{v} seviyesine yükseldi: havza yanıt veriyor", "en": "Sea Health Index climbs to {v}%: the basin is responding", "ru": "Индекс здоровья моря вырос до {v}%: бассейн восстанавливается"},
	"news.amb.health_down": {"tr": "Deniz Sağlığı Endeksi %{v} seviyesine düştü: acil eylem gerekiyor", "en": "Sea Health Index slips to {v}%: analysts urge faster action", "ru": "Индекс здоровья моря упал до {v}%: требуются срочные меры"},
	"news.amb.temp": {"tr": "Küresel ısınma +{v}°C: Akdeniz dünya ortalamasından daha hızlı ısınıyor", "en": "Global warming at +{v}°C; the Mediterranean heats up faster than the world average", "ru": "Потепление достигло +{v}°C; Средиземноморье нагревается быстрее среднемирового"},
	"news.amb.temp_high": {"tr": "Sıcaklık alarmı: +{v}°C ısınma, denizel sıcak dalgaları sıklaşıyor", "en": "Heat alarm: warming at +{v}°C, marine heatwaves are becoming routine", "ru": "Климатическая тревога: потепление +{v}°C, морские волны тепла стали нормой"},
	"news.amb.goal": {"tr": "COP31 hedefi: 2046'ya kadar %60 Deniz Sağlığı. Kalan yıl: {n}", "en": "COP31 target: Sea Health 60% by 2046. Years left: {n}", "ru": "Цель COP31: здоровье моря 60% к 2046 году. Осталось лет: {n}"},
	"news.amb.goal_near": {"tr": "Deniz Sağlığı %{v}: COP31'in %60 hedefine çok az kaldı", "en": "Sea Health at {v}%: the COP31 goal of 60% is within reach", "ru": "Здоровье моря {v}%: цель COP31 в 60% уже близка"},
	"news.amb.income_negative": {"tr": "Hazine alarmı: çöken deniz ekonomisi bütçeyi tüketiyor", "en": "Treasury alarm: the failing sea economy is now draining coalition funds", "ru": "Казначейство: кризис моря опустошает финансовый фонд коалиции"},
	"news.amb.resistance": {"tr": "Analistler: kriz direnç geliştirdi ({name}). Yeni politikalar şart", "en": "Analysts: the crisis has adapted ({name}). New policies are needed", "ru": "Аналитики: кризис адаптировался ({name}). Необходимы новые политики"},
	"news.amb.spreads": {"tr": "2026'dan bu yana kaydedilen kriz yayılma olayları: {n}", "en": "Crisis spread events logged since 2026: {n}", "ru": "Вспышек распространения кризиса с 2026 года: {n}"},
	"news.amb.policies": {"tr": "Yürürlükteki koalisyon politikaları: {n}", "en": "Coalition policies in force: {n}", "ru": "Действующих политик коалиции: {n}"},

	# --- Tips (shown once each per game) ---
	"news.tip.bubbles": {"tr": "Bilim ve Siyasi Destek toplamak için denizdeki veri baloncuklarına tıkla", "en": "Click the glowing data bubbles over the sea to collect Science and Political Support", "ru": "Собирайте светящиеся сферы над морем для получения Науки и Поддержки"},
	"news.tip.tree": {"tr": "Kalıcı politikalar kabul etmek için T tuşuna basarak Politika Ağacını aç", "en": "Press T to open the Policy Tree and adopt lasting policies", "ru": "Нажмите T, чтобы открыть Древо политик и принять долгосрочные меры"},
	"news.tip.keys": {"tr": "Bölge seçtikten sonra saha operasyonu başlatmak için Q, W veya E'ye bas", "en": "Select a region, then press Q, W or E to launch field operations", "ru": "Выберите регион и нажмите Q, W или E для полевых операций"},
	"news.tip.pause": {"tr": "Plan yapmak için Boşluk tuşuyla duraklat: operasyonlar zaman dururken de çalışır", "en": "Press Space to pause and plan: operations still work while time stands still", "ru": "Нажмите Пробел для паузы: вы можете отдавать приказы во время остановки времени"},
	"news.tip.diversify": {"tr": "Tek yönlü stratejiler krizin direnç geliştirmesine yol açar. Hamlelerini çeşitlendir", "en": "A one-sided strategy lets the crisis evolve resistances. Mix your moves", "ru": "Односторонняя тактика ускоряет адаптацию кризиса. Чередуйте действия"},

	# --- Real Mediterranean facts ---
	"news.fact.biodiversity": {"tr": "Akdeniz, dünya okyanuslarının %1'inden azını kaplar ancak deniz türlerinin %18'ine ev sahipliği yapar", "en": "The Mediterranean is under 1% of the world ocean, yet hosts up to 18% of known marine species", "ru": "Средиземное море составляет менее 1% площади океанов, но содержит до 18% морских видов"},
	"news.fact.warming": {"tr": "Akdeniz, küresel ortalamadan yaklaşık %20 daha hızlı ısınıyor", "en": "The Mediterranean is warming about 20% faster than the global average", "ru": "Средиземное море нагревается примерно на 20% быстрее среднемирового уровня"},
	"news.fact.plastic": {"tr": "Her yıl Akdeniz'e yaklaşık 230.000 ton plastik atık karışıyor (IUCN)", "en": "Roughly 230,000 tonnes of plastic leak into the Mediterranean every year (IUCN)", "ru": "Ежегодно в Средиземное море попадает около 230 000 тонн пластика (МСОП)"},
	"news.fact.posidonia": {"tr": "Posidonia çayırları karbonu deniz tabanında binlerce yıl boyunca hapseder", "en": "Posidonia meadows store carbon in their seabed mats for thousands of years", "ru": "Луга посидонии удерживают углерод в донных отложениях тысячелетиями"},
	"news.fact.posidonia_loss": {"tr": "Akdeniz'deki Posidonia çayırları son 50 yılda üçte bir oranında azaldı", "en": "Mediterranean Posidonia meadows have shrunk by about a third in the last 50 years", "ru": "За последние 50 лет средиземноморские луга посидонии сократились на треть"},
	"news.fact.caretta": {"tr": "Caretta caretta kaplumbağaları Dalyan'dan Belek ve Antalya kıyılarına kadar yuvalar", "en": "Loggerhead turtles nest on Turkish beaches from Dalyan to Belek, near Antalya", "ru": "Черепахи каретта гнездятся на пляжах Турции от Дальяна до Белека близ Антальи"},
	"news.fact.monk_seal": {"tr": "Akdeniz foklarının hayatta kalan sayısı binden azdır; bazıları Türkiye kıyılarında yaşar", "en": "Fewer than a thousand Mediterranean monk seals survive, some in sea caves on Türkiye's coast", "ru": "В живых осталось менее тысячи тюленей-монахов, часть обитает у берегов Турции"},
	"news.fact.lionfish": {"tr": "Aslan balığı Süveyş Kanalı'ndan girdi ve şimdi Türkiye kıyıları boyunca yayılıyor", "en": "Lionfish entered through the Suez Canal and now spread along the Levant and Turkish coasts", "ru": "Рыба-крылатка проникла через Суэцкий канал и расселяется вдоль побережья"},
	"news.fact.mucilage": {"tr": "2021 yılında deniz salyası olarak bilinen devasa müsilaj Marmara Denizi'ni kapladı", "en": "In 2021 a vast mucilage outbreak, known as sea snot, blanketed the Sea of Marmara", "ru": "В 2021 году гигантские массы слизи (морских соплей) покрыли Мраморное море"},
	"news.fact.overfishing": {"tr": "Değerlendirilen Akdeniz balık stoklarının çoğu aşırı avlanmaya maruz kalıyor (FAO)", "en": "Most assessed Mediterranean fish stocks are fished beyond sustainable limits (FAO)", "ru": "Большинство запасов промысловых рыб истощены чрезмерным выловом (ФАО)"},
	"news.fact.renewal": {"tr": "Akdeniz suyunun Cebelitarık Boğazı yoluyla tamamen yenilenmesi yaklaşık yüz yıl sürer", "en": "Mediterranean water takes around a century to renew through the Strait of Gibraltar", "ru": "Водам Средиземного моря требуется около ста лет для обновления через Гибралтар"},
	"news.fact.barcelona": {"tr": "1976 Barselona Sözleşmesi, UNEP'in Bölgesel Denizler anlaşmalarının ilkiydi", "en": "The 1976 Barcelona Convention was the first of UNEP's Regional Seas agreements", "ru": "Барселонская конвенция 1976 года стала первым соглашением ЮНЕП по региональным морям"},
	"news.fact.cop31": {"tr": "Antalya'daki COP31 Zirvesi, denizleri küresel iklim gündeminin merkezine taşıyor", "en": "COP31 in Antalya puts oceans and seas at the heart of the climate talks", "ru": "COP31 в Анталье ставит защиту морей в центр климатических переговоров"},

	# --- Onboarding Directives ---
	"onboarding.title": {"tr": "TAKTİK DİREKTİFLER", "en": "TACTICAL DIRECTIVES", "ru": "ТАКТИЧЕСКИЕ ЗАДАЧИ"},
	"onboarding.step1": {"tr": "1. Haritada bir denizi seç [Tıkla]", "en": "1. Select a sea region [Click]", "ru": "1. Выберите регион моря [Клик]"},
	"onboarding.step2": {"tr": "2. Bir Veri Baloncuğu topla [Tıkla]", "en": "2. Pop a Data Bubble [Click]", "ru": "2. Соберите сферу данных [Клик]"},
	"onboarding.step3": {"tr": "3. Politika Ağacından karar kabul et [T]", "en": "3. Adopt a Policy in Tree [T]", "ru": "3. Примите политику в древе [T]"},
	"onboarding.step4": {"tr": "4. Zaman akışını başlat (1x) [Boşluk]", "en": "4. Unpause simulation (1x) [SPACE]", "ru": "4. Запустите время (1x) [Пробел]"},
	"onboarding.done": {"tr": "TÜM DİREKTİFLER TAMAMLANDI!", "en": "ALL DIRECTIVES COMPLETED!", "ru": "ВСЕ ЗАДАЧИ ВЫПОЛНЕНЫ!"},
	"onboarding.dismiss": {"tr": "Kapat", "en": "Dismiss", "ru": "Закрыть"},

	# --- Monthly pacing & Income ---
	"hud.month_fmt": {"tr": "{year} / {month}", "en": "{year} / {month}", "ru": "{year} / {month}"},
	"hud.rate.monthly": {"tr": "{v}/ay", "en": "{v}/mo", "ru": "{v}/мес"},
	"hud.rate.monthly_tip": {
		"tr": "Aylık net kaynak dengesi (gelir - giderler).",
		"en": "Net monthly balance (income minus maintenance).",
		"ru": "Чистый ежемесячный доход (поступления минус расходы)."
	},

	# --- Resource Tooltips ---
	"res.budget.tip": {
		"tr": "[b]BÜTÇE[/b]\n[color=#38bdf8]Nasıl Kazanılır:[/color] Sağlıklı balık stokları ve sürdürülebilir ekonomi politikalarından gelen aylık koalisyon katkıları.\n[color=#f59e0b]Kullanım Alanı:[/color] Fiziksel altyapı, Deniz Koruma Alanları, atık filtreleri ve bölgesel acil temizlikler.",
		"en": "[b]BUDGET[/b]\n[color=#38bdf8]How to Earn:[/color] Monthly coalition tax income scaling with healthy fish stocks & blue economy policies.\n[color=#f59e0b]Used For:[/color] Physical infrastructure, Marine Protected Areas, wastewater filtration, and regional cleanups.",
		"ru": "[b]БЮДЖЕТ[/b]\n[color=#38bdf8]Как заработать:[/color] Ежемесячные взносы коалиции, зависящие от запасов рыбы и мер синей экономики.\n[color=#f59e0b]На что тратить:[/color] Инфраструктура, морские заповедники, фильтры стоков и локальная очистка."
	},
	"res.political.tip": {
		"tr": "[b]POLİTİK DESTEK[/b]\n[color=#38bdf8]Nasıl Kazanılır:[/color] Kehribar baloncukları toplama, yüksek bölgesel farkındalık ve diplomatik kararlar.\n[color=#f59e0b]Kullanım Alanı:[/color] Yasaklar (tek kullanımlık plastik yasağı), uluslararası antlaşmalar ve denetim kotaları.",
		"en": "[b]POLITICAL SUPPORT[/b]\n[color=#38bdf8]How to Earn:[/color] Popping amber data bubbles, high regional public awareness, and diplomatic summit choices.\n[color=#f59e0b]Used For:[/color] Enacting bans (single-use plastics), international treaties, and coastal patrol quotas.",
		"ru": "[b]ПОЛИТИЧЕСКАЯ ПОДДЕРЖКА[/b]\n[color=#38bdf8]Как заработать:[/color] Сбор янтарных сфер, высокая осведомленность регионов и дипломатические решения.\n[color=#f59e0b]На что тратить:[/color] Запреты (одноразовый пластик), международные соглашения и квоты патрулей."
	},
	"res.science.tip": {
		"tr": "[b]BİLİM PUANI[/b]\n[color=#38bdf8]Nasıl Kazanılır:[/color] Denizde beliren camgöbeği araştırma baloncuklarını toplama ve uydu izleme ağları.\n[color=#f59e0b]Kullanım Alanı:[/color] İleri kademe teknolojileri açma, Kriz Dirençlerini nötralize etme ve derin deniz projeleri.",
		"en": "[b]SCIENCE POINTS[/b]\n[color=#38bdf8]How to Earn:[/color] Collecting cyan research bubbles across the sea and satellite monitoring nodes.\n[color=#f59e0b]Used For:[/color] Unlocking advanced tier-2/3 tech, synthesizing counter-strategies against mutations, and deep-sea projects.",
		"ru": "[b]ОЧКИ НАУКИ[/b]\n[color=#38bdf8]Как заработать:[/color] Сбор бирюзовых научных сфер в море и спутниковые сети мониторинга.\n[color=#f59e0b]На что тратить:[/color] Передовые технологии 2-го/3-го уровней, нейтрализация мутаций кризиса и глубоководные проекты."
	},

	# --- 3-Card Tactical Briefing Modal ---
	"briefing.modal_title": {"tr": "COP31 TAKTİK HAREKÂT BRİFİNGİ", "en": "COP31 TACTICAL MISSION BRIEFING", "ru": "ТАКТИЧЕСКИЙ БРИФИНГ МИССИИ COP31"},
	"briefing.card1.title": {"tr": "1. TEHDİT: AKDENİZ'İN ÇÖKÜŞÜ", "en": "1. THE THREAT: BASIN COLLAPSE", "ru": "1. УГРОЗА: КОЛЛАПС БАССЕЙНА"},
	"briefing.card1.text": {
		"tr": "Kirlilik, aşırı ısınma ve habitat kaybı Akdeniz akıntıları ve yoğun gemi hatları boyunca hızla yayılıyor.\n\n• [color=#f87171]Kayıp Şartı:[/color] Küresel ısınma +4.0°C'ye ulaşırsa veya Havza Deniz Sağlığı %10'un altına düşerse Akdeniz çöker!\n• [color=#4ade80]Kazanma Şartı:[/color] 2046 yılına kadar Deniz Sağlığını en az %60'a ulaştırın ya da her bölgedeki krizi %25'in altına çekin.",
		"en": "Pollution, extreme heating, and habitat loss spread rapidly along Mediterranean currents and shipping lanes.\n\n• [color=#f87171]Defeat:[/color] If warming reaches +4.0°C or Basin Sea Health falls below 10%, the ecosystem collapses!\n• [color=#4ade80]Victory:[/color] Raise Sea Health to at least 60% by 2046, or push crisis below 25% across every single region.",
		"ru": "Загрязнение, перегрев и гибель биоты стремительно разносятся течениями и судоходными маршрутами.\n\n• [color=#f87171]Поражение:[/color] Потепление до +4.0°C или падение здоровья моря ниже 10% разрушит экосистему!\n• [color=#4ade80]Победа:[/color] Достигните 60% здоровья моря к 2046 году или снизьте кризис ниже 25% во всех регионах."
	},
	"briefing.card2.title": {"tr": "2. ÜÇ STRATEJİK KAYNAK", "en": "2. THREE CORE RESOURCES", "ru": "2. ТРИ КЛЮЧЕВЫХ РЕСУРСА"},
	"briefing.card2.text": {
		"tr": "Başarı için 3 kaynağı dengeli yönetmelisiniz:\n\n• [color=#38bdf8]BÜTÇE:[/color] Sağlıklı balık stoklarından aylık akar. Filtreler, koruma alanları ve temizlik ekipleri finanse eder.\n• [color=#f59e0b]POLİTİK DESTEK:[/color] Halk farkındalığından beslenir. Yasaklar, balıkçılık kotaları ve antlaşmalar için zorunludur.\n• [color=#2dd4bf]BİLİM PUANI:[/color] Denizdeki araştırma baloncuklarından toplanır. İleri teknolojileri açar ve mutasyonları kırar.",
		"en": "Manage three core resources in harmony:\n\n• [color=#38bdf8]BUDGET:[/color] Flows monthly from healthy fish stocks. Builds wastewater filters, MPAs, and cleanup teams.\n• [color=#f59e0b]POLITICAL SUPPORT:[/color] Driven by public awareness. Enacts plastic bans, fishing quotas, and international treaties.\n• [color=#2dd4bf]SCIENCE:[/color] Collected from marine data bubbles. Unlocks high-tech nodes and synthesizes counter-cures.",
		"ru": "Сбалансируйте использование трех ключевых ресурсов:\n\n• [color=#38bdf8]БЮДЖЕТ:[/color] Поступает от рыбных запасов. Строит фильтры стоков, заповедники и команды очистки.\n• [color=#f59e0b]ПОДДЕРЖКА:[/color] Растет от осведомленности. Принимает законы, квоты вылова и соглашения.\n• [color=#2dd4bf]НАУКА:[/color] Сбор морских сфер данных. Открывает технологии и нейтрализует мутации."
	},
	"briefing.card3.title": {"tr": "3. TAKTİKLER & KRİZ DİRENCİ", "en": "3. TACTICS & CRISIS MUTATION", "ru": "3. ТАКТИКА И МУТАЦИИ КРИЗИСА"},
	"briefing.card3.text": {
		"tr": "• [b]Bölge Teşhisi:[/b] Haritada bir denize tıklayarak kriz kaynaklarını ve aylık akıntı baskısını inceleyin.\n• [b]Politika Ağacı [T]:[/b] Kalıcı çözümler devreye alın. İleri kademeler Bilim Puanı da gerektirir.\n• [b]Kriz Adaptasyonu (DNA):[/b] Sadece tek bir yönteme (örneğin sadece temizlik) yüklenirseniz Kriz direnç geliştirir! Çeşitli stratejiler uygulayın veya Direnci Bilim ile sentezleyerek yok edin.",
		"en": "• [b]Regional Diagnosis:[/b] Click any sea on the map to inspect its crisis drivers and monthly current pressure.\n• [b]Policy Tree [T]:[/b] Enact lasting reforms. Advanced tiers require hybrid Science Points.\n• [b]Crisis Adaptation (DNA):[/b] Relying solely on one method (e.g. only cleanups) causes the crisis to evolve resistance! Diversify your moves or spend Science to synthesize counter-cures.",
		"ru": "• [b]Диагностика:[/b] Кликните на регион, чтобы изучить источники кризиса и давление течений.\n• [b]Древо политик [T]:[/b] Принимайте долгосрочные меры. Старшие уровни требуют очков науки.\n• [b]Мутации кризиса (ДНК):[/b] Спам одного действия провоцирует мутацию кризиса! Чередуйте тактики или синтезируйте вакцины за очки науки."
	},
	"briefing.btn.next": {"tr": "İleri →", "en": "Next →", "ru": "Далее →"},
	"briefing.btn.prev": {"tr": "← Geri", "en": "← Back", "ru": "← Назад"},
	"briefing.btn.start": {"tr": "GÖREVE BAŞLA", "en": "START MISSION", "ru": "НАЧАТЬ МИССИЮ"},
	"briefing.btn.skip": {"tr": "Brifingi Geç", "en": "Skip Briefing", "ru": "Пропустить"},
	"briefing.step_fmt": {"tr": "{cur} / {total}", "en": "{cur} / {total}", "ru": "{cur} / {total}"},

	# --- Regional Crisis Traits ---
	"region.trait.title": {"tr": "BÖLGESEL KRİZ NİTELİĞİ", "en": "REGIONAL CRISIS TRAIT", "ru": "ОСОБЕННОСТЬ РЕГИОНА"},
	"region.western.trait": {"tr": "Cebelitarık Akıntı Girişi ve Yoğun Tanker Trafiği", "en": "Gibraltar Inflow Current & Heavy Tanker Traffic", "ru": "Гибралтарский приток и тяжелый танкерный трафик"},
	"region.central.trait": {"tr": "Pelagos Balina Koruma Alanı ve Ada Hatları", "en": "Pelagos Cetacean Sanctuary & Island Ferry Routes", "ru": "Заповедник китообразных Пелагос и паромные линии"},
	"region.adriatic.trait": {"tr": "Sığ Lagünler ve Tarımsal Gübre Akıntısı", "en": "Shallow Lagoons & Intensive Agricultural Runoff", "ru": "Мелководные лагуны и сельскохозяйственные стоки"},
	"region.aegean.trait": {"tr": "Ada Turizmi ve Aşırı Kıyı Balıkçılığı", "en": "Island Tourism Surge & Intense Coastal Fishing", "ru": "Островной туризм и интенсивный прибрежный вылов"},
	"region.marmara.trait": {"tr": "Ağır Sanayi, Plastik ve Müsilaj Tehdidi", "en": "Heavy Industry, Plastic Waste & Mucilage Threat", "ru": "Тяжелая промышленность, пластик и угроза слизи"},
	"region.blacksea.trait": {"tr": "Tuna ve Dinyeper Nehir Havzası Kirlilik Girişi", "en": "Danube & Dnieper River Basin Nutrient Inflow", "ru": "Приток загрязнений из бассейнов Дуная и Днепра"},
	"region.antalya.trait": {"tr": "COP31 Ev Sahibi, Turizm Baskısı ve Caretta Yuvaları", "en": "COP31 Host, Tourism Pressure & Sea Turtle Nesting", "ru": "Хозяин COP31, туристический пресс и гнезда черепах"},
	"region.levant.trait": {"tr": "Süveyş İstilacı Tür Koridoru ve Termal Isınma", "en": "Suez Invasive Species Corridor & Extreme Warming", "ru": "Суэцкий коридор инвазивных видов и сильный нагрев"},
	# Regional aliases
	"region.antalya_gulf.trait": {"tr": "COP31 Ev Sahibi, Turizm Baskısı ve Caretta Yuvaları", "en": "COP31 Host, Tourism Pressure & Sea Turtle Nesting", "ru": "Хозяин COP31, туристический пресс и гнезда черепах"},
	"region.north_aegean.trait": {"tr": "Aşırı Balıkçılık ve Nehir Havzası", "en": "Intense Fishing & River Basin Pressure", "ru": "Рыболовный промысел и речные бассейны"},
	"region.south_aegean.trait": {"tr": "Ada Turizmi ve Feribot Trafiği", "en": "Island Tourism & Ferry Traffic", "ru": "Островной туризм и паромные линии"},
	"region.cilicia.trait": {"tr": "Tarımsal Gübre Akıntısı ve Kıyı Plastikleri", "en": "Agricultural Runoff & Coastal Plastic", "ru": "Сельскохозяйственные стоки и пластик"},
	"region.cyprus.trait": {"tr": "İstilacı Tür Koridoru ve Termal Dalgalar", "en": "Invasive Species Corridor & Heatwaves", "ru": "Коридор инвазивных видов и тепловые волны"},
	"region.rhodes_trench.trait": {"tr": "Derin Deniz Çukuru ve Mikroplastik Tuzağı", "en": "Deep-Sea Trench & Microplastic Sink", "ru": "Глубоководный желоб и ловушка микропластика"},
	"region.levant_open.trait": {"tr": "Süveyş İstilacı Tür Koridoru ve Termal Isınma", "en": "Suez Invasive Species Corridor & Extreme Warming", "ru": "Суэцкий коридор инвазивных видов и сильный нагрев"},

	# --- Monthly Dynamics Breakdown ---
	"hud.breakdown.title": {"tr": "AYLIK DEĞİŞİM DİNAMİKLERİ", "en": "MONTHLY DYNAMICS BREAKDOWN", "ru": "ЕЖЕМЕСЯЧНАЯ ДИНАМИКА"},
	"hud.breakdown.shipping": {"tr": "Gemi Hatları Girişi", "en": "Shipping Lanes Inflow", "ru": "Судоходные маршруты"},
	"hud.breakdown.currents": {"tr": "Komşu Akıntı Baskısı", "en": "Neighbor Current Inflow", "ru": "Приток соседних течений"},
	"hud.breakdown.coastal": {"tr": "Yerel Kıyı Kaynakları", "en": "Local Coastal Sources", "ru": "Местные прибрежные стоки"},
	"hud.breakdown.heat": {"tr": "Termal İklim Stresi", "en": "Thermal Climate Stress", "ru": "Термический стресс"},
	"hud.breakdown.shield": {"tr": "Koruma ve Bilinç Kalkanı", "en": "Protection & Awareness Shield", "ru": "Защита и гражданский щит"},
	"hud.breakdown.net": {"tr": "Net Aylık Değişim", "en": "Net Monthly Change", "ru": "Чистое изменение"},

	# --- Repeatable Science Projects & Toasts ---
	"toast.project.bio_algae": {"tr": "Biyo-Alg Karbon Depolaması devreye alındı (-0.08°C, +%6 Posidonia)!", "en": "Bio-Algae Sequestration deployed (-0.08°C, +6% Posidonia)!", "ru": "Био-водоросли развернуты (-0.08°C, +6% посидонии)!"},
	"toast.project.drone_swarm": {"tr": "Otonom Temizlik Dron Filosu en kritik bölgeyi temizledi (-%12 Kirlilik)!", "en": "Autonomous Drone Swarm cleaned the worst crisis hotspot (-12% Pollution)!", "ru": "Рой дронов очистил критический очаг (-12% загрязнения)!"},
	"tree.counter_synth.btn": {"tr": "🧪 Sentezle (-{cost} Bilim)", "en": "🧪 Synthesize (-{cost} Science)", "ru": "🧪 Синтез (-{cost} науки)"},
	"tree.counter_synth.tip": {"tr": "Bu kriz mutasyonunu nötralize etmek ve kalıcı bağışıklık kazanmak için Bilim Puanı harca.", "en": "Spend Science Points to neutralize this crisis mutation and gain permanent immunity.", "ru": "Потратьте очки науки, чтобы нейтрализовать мутацию и получить иммунитет."},
	"tree.projects.title": {"tr": "TEKRARLANABİLİR BİLİM PROJELERİ", "en": "REPEATABLE SCIENCE PROJECTS", "ru": "ПОВТОРЯЕМЫЕ НАУЧНЫЕ ПРОЕКТЫ"},
	"tree.projects.ready": {"tr": "Hazır", "en": "Ready", "ru": "Готово"},
	"tree.projects.cooldown": {"tr": "Bekleme: {n} ay", "en": "Cooldown: {n} mo", "ru": "Перезарядка: {n} мес"},
	"project.bio_algae.name": {"tr": "Biyo-Alg Karbon Depolama", "en": "Bio-Algae Carbon Sequestration", "ru": "Связывание углерода водорослями"},
	"project.bio_algae.desc": {"tr": "Özel genetik alg suşları salarak deniz sıcaklığını 0.08°C düşürür ve tüm havzada Posidonia çayırlarını %6 yeniler.", "en": "Releases specialized algae to lower sea temp by 0.08°C and restore 6% Posidonia across all regions.", "ru": "Снижает температуру моря на 0.08°C и восстанавливает 6% посидонии во всех регионах."},
	"project.drone_swarm.name": {"tr": "Otonom Temizlik Dron Sürüsü", "en": "Autonomous Drone Swarms", "ru": "Автономные рои дронов-очистителей"},
	"project.drone_swarm.desc": {"tr": "En yüksek kirliliğe sahip bölgede kirliliği %12 azaltır; toplanan veriler +30 Bütçe ve +15 Politik Destek sağlar.", "en": "Cleans 12% pollution in the most damaged region, yielding +30 Budget and +15 Political Support.", "ru": "Устраняет 12% загрязнения в худшем регионе и приносит +30 бюджета и +15 поддержки."},
}
