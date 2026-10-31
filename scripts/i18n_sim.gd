extends RefCounted
## String table (simulation toasts and news headlines for adoptions, evolutions, events, bubbles. Owner: simulation module (en), localization (tr/ru)) merged by the I18n autoload; never read directly by game code.
## Format: key -> {"tr": ..., "en": ..., "ru": ...}. Keys are unique across all tables.

const STRINGS := {
	# --- Toasts ---
	"sim.toast.adopted": {"tr": "Politika kabul edildi: {name}", "en": "Policy adopted: {name}", "ru": "Принята политика: {name}"},
	"sim.toast.evolved": {"tr": "Kriz direnç geliştirdi: {name}", "en": "The crisis evolved: {name}", "ru": "Кризис мутировал: {name}"},
	"sim.toast.cured": {"tr": "Direnç kırıldı: {name}", "en": "Resistance cured: {name}", "ru": "Стойкость преодолена: {name}"},
	"sim.toast.immune": {"tr": "Direnç önlendi: kriz artık {name} geliştiremez", "en": "Resistance pre-empted: the crisis can no longer evolve {name}", "ru": "Стойкость предотвращена: кризис больше не разовьет {name}"},
	"sim.toast.adapting": {"tr": "Kriz tek yönlü stratejine ({branch}) uyum sağlıyor. Çeşitlendir!", "en": "The crisis is adapting to your one-sided strategy ({branch}). Diversify!", "ru": "Кризис привыкает к однотипным действиям ({branch}). Чередуйте тактику!"},

	# --- News: crisis spreading (variants) ---
	"sim.news.spread.0": {"tr": "{from} bölgesindeki kirlilik akıntısı {to} bölgesine sürüklendi", "en": "Pollution plume from {from} drifts into {to}", "ru": "Шлейф загрязнения из {from} дрейфует в сторону {to}"},
	"sim.news.spread.1": {"tr": "Akıntılar deniz krizini {from} bölgesinden {to} bölgesine taşıyor", "en": "Currents carry the marine crisis from {from} to {to}", "ru": "Течения переносят морской кризис из {from} в {to}"},
	"sim.news.spread.2": {"tr": "Gözlem şamandıraları: {to}, {from} kaynaklı kirlenmeden etkilendi", "en": "Monitoring buoys: {to} hit by contamination from {from}", "ru": "Буи слежения: акватория {to} загрязнена стоками из {from}"},

	# --- News: region alarms and recoveries (variants) ---
	"sim.news.critical.0": {"tr": "{region} ekolojik acil durum bölgesi ilan edildi", "en": "{region} declared an ecological emergency zone", "ru": "{region} объявлен зоной экологической катастрофы"},
	"sim.news.critical.1": {"tr": "{region} bölgesinde alarm: ekosistem çöküşün eşiğinde", "en": "Alarm in {region}: scientists warn the ecosystem is near collapse", "ru": "Тревога в {region}: ученые заявляют о риске коллапса экосистемы"},
	"sim.news.recovered.0": {"tr": "{region} dönüm noktasını aştı: toparlanma teyit edildi", "en": "{region} turns the corner: scientists confirm a recovery", "ru": "{region} идет на поправку: биологи подтверждают восстановление"},
	"sim.news.recovered.1": {"tr": "{region} bölgesinden iyi haber: berrak sular ve balıklar geri dönüyor", "en": "Good news from {region}: clear water and fish are returning", "ru": "Добрые вести из {region}: вода очищается, возвращается рыба"},

	# --- News: climate and economy ---
	"sim.news.temp": {"tr": "Isınma +{temp}°C seviyesini aştı: Akdeniz dünyadan daha hızlı ısınıyor", "en": "Warming passes +{temp}°C: the Mediterranean heats up faster than the world", "ru": "Потепление превысило +{temp}°C: Средиземноморье нагревается рекордными темпами"},
	"sim.news.temp_alarm": {"tr": "İklim alarmı: ısınma +{temp}°C üstünde, mercan resifleri tehlikede", "en": "Climate alarm: warming tops +{temp}°C, coral reefs in danger basin-wide", "ru": "Климатическая тревога: потепление выше +{temp}°C, рифы под угрозой"},
	"sim.news.depleted": {"tr": "Koalisyon kasası ve siyasi destek tükendi: misyon büyük tehlikede", "en": "Coalition coffers and political capital run dry: the mission is at risk", "ru": "Казна коалиции и политическая поддержка исчерпаны: миссия под угрозой"},

	# --- News: policy adoptions, by branch ---
	"sim.news.adopted.protect": {"tr": "Deniz için yeni koruma: koalisyon {name} politikasını kabul etti", "en": "New protection for the sea: the coalition adopts {name}", "ru": "Новая защита моря: коалиция утвердила политику {name}"},
	"sim.news.adopted.source": {"tr": "Kirlilik kaynağında kesildi: koalisyon {name} adımını attı", "en": "Pollution cut at the source: the coalition adopts {name}", "ru": "Загрязнение остановлено у истока: коалиция ввела {name}"},
	"sim.news.adopted.science": {"tr": "Bilimsel atılım: koalisyon {name} programını başlattı", "en": "Science push: the coalition launches {name}", "ru": "Научный прорыв: коалиция запускает программу {name}"},
	"sim.news.adopted.economy": {"tr": "Mavi ekonomi anlaşması: koalisyon {name} konusunda uzlaştı", "en": "Blue economy deal: the coalition agrees on {name}", "ru": "Сделка синей экономики: коалиция согласовала {name}"},

	# --- News: decision card outcomes ---
	"sim.news.event.oil_spill.a": {"tr": "Bariyerler tuttu: ekipler {region} açıklarındaki petrolü temizledi", "en": "Booms hold: crews skim the tanker spill off {region}", "ru": "Боны удержали нефть: службы ликвидировали разлив близ {region}"},
	"sim.news.event.oil_spill.b": {"tr": "Petrol tabakası {region} sahillerini karaya vurdu", "en": "Oil slick blackens the beaches of {region} as the response stalls", "ru": "Нефтяное пятно загрязнило побережье региона {region}"},
	"sim.news.event.heatwave.a": {"tr": "Sensörler ve dalış yasakları {region} resiflerini korudu", "en": "Sensors and dive-site closures shield the reefs of {region}", "ru": "Датчики и закрытие зон дайвинга спасли рифы в регионе {region}"},
	"sim.news.event.heatwave.b": {"tr": "Kitlesel ölüm: sıcak hava dalgası {region} deniz tabanını kavurdu", "en": "Mass die-off: a marine heatwave bleaches the seabed of {region}", "ru": "Массовая гибель: тепловая волна обесцветила дно в {region}"},
	"sim.news.event.lobby_pressure.a": {"tr": "Koalisyon plastik lobisine karşı geri adım atmadı", "en": "The coalition stands firm against the plastics lobby", "ru": "Коалиция выдержала давление промышленного лобби"},
	"sim.news.event.lobby_pressure.b": {"tr": "Sanayi anlaşması imzalandı: çevreciler kirlilik açığına karşı uyardı", "en": "Industry deal signed: green groups warn of a pollution loophole", "ru": "Подписана сделка с бизнесом: экологи предупреждают о лазейках"},
	"sim.news.event.greenwashing.a": {"tr": "Koalisyon 'yeşil aklama' yapan sponsoru bıraktı ve denetim raporunu yayımladı", "en": "The coalition drops its greenwashing sponsor and publishes a full audit", "ru": "Коалиция расторгла контракт с гринвошинг-спонсором и открыла аудит"},
	"sim.news.event.greenwashing.b": {"tr": "Koalisyon sessiz kaldıkça yeşil aklama skandalı büyüyor", "en": "Greenwashing scandal deepens as the coalition stays silent", "ru": "Скандал с псевдоэкологией разрастается из-за молчания властей"},
	"sim.news.event.fishers_coop.a": {"tr": "{region} balıkçıları fon desteğiyle seçici ağlara geçti", "en": "Fishers in {region} switch to selective nets with coalition funds", "ru": "Рыбаки региона {region} перешли на безопасные сети за счет субсидий"},
	"sim.news.event.fishers_coop.b": {"tr": "Müzakereler tıkandı, {region} balıkçıları eski ağları kullanmaya devam ediyor", "en": "Fishers in {region} keep their old nets after talks collapse", "ru": "Переговоры сорваны: рыбаки в {region} продолжают донный промысел"},
	"sim.news.event.tourism_surge.a": {"tr": "Kruvaziyer kotaları ve demirleme yasağı {region} çayırlarını korudu", "en": "Cruise caps and an anchoring ban protect the meadows of {region}", "ru": "Ограничения на круизы защитили донные луга в регионе {region}"},
	"sim.news.event.tourism_surge.b": {"tr": "{region} bölgesinde turist patlaması: rekor gelir, tahrip olan çayırlar", "en": "Tourist boom in {region}: record income, torn-up seagrass", "ru": "Туристический бум в {region}: рекордная выручка ценой гибели лугов"},
	"sim.news.event.mucilage.a": {"tr": "Bariyerler ve toplayıcı tekneler {region} müsilajını temizledi", "en": "Barriers and skimmers lift the sea snot off {region}", "ru": "Барьеры и очистные катера сняли слой слизи в акватории {region}"},
	"sim.news.event.mucilage.b": {"tr": "Numuneler laboratuvardayken müsilaj {region} geneline yayıldı", "en": "Mucilage spreads across {region} while samples go to the lab", "ru": "Слизь заполонила {region}, пока ученые исследовали пробы"},
	"sim.news.event.foreign_trawlers.a": {"tr": "Devriye botları kaçak trolleri {region} sularından çıkardı", "en": "Patrol boats escort dark trawlers out of {region}", "ru": "Патрульные суда выдворили браконьерские траулеры из {region}"},
	"sim.news.event.foreign_trawlers.b": {"tr": "Diplomasi sürerken kaçak troller {region} deniz tabanını talan etti", "en": "Dark trawlers strip the seabed off {region} during diplomatic talks", "ru": "Пока шли дипломатические ноты, траулеры опустошили дно в {region}"},
	"sim.news.event.caretta_nesting.a": {"tr": "Gönüllüler yuvaları korudu: yavru kaplumbağalar {region} denizine ulaştı", "en": "Volunteers guard turtle nests: hatchlings reach the sea in {region}", "ru": "Волонтеры спасли гнезда: черепашата вышли в море в регионе {region}"},
	"sim.news.event.caretta_nesting.b": {"tr": "Işık kirliliği {region} bölgesindeki yavru kaplumbağaları rotasından saptırdı", "en": "Beach lights lure turtle hatchlings away from the sea in {region}", "ru": "Огни пляжных баров дезориентировали черепашат в {region}"},
	"sim.news.event.cop31_2031.a": {"tr": "COP31 Ara Zirvesi: bağlayıcı plastik sözleşmesinde uzlaşıldı", "en": "COP31 review summit: a binding plastics pact is agreed", "ru": "Промежуточный саммит COP31: утвержден обязательный пакт по пластику"},
	"sim.news.event.cop31_2031.b": {"tr": "COP31 Ara Zirvesi: bağışlar alındı, plastik paktı rafa kaldırıldı", "en": "COP31 review summit: donors pay out, the plastics pact is shelved", "ru": "Саммит COP31: гранты получены, соглашение по пластику заморожено"},
	"sim.news.event.cop31_2036.a": {"tr": "COP31 Orta Dönem Zirvesi: tüm havzada yeni deniz rezervleri ilan edildi", "en": "COP31 mid-term summit: new marine reserves declared across the basin", "ru": "Саммит COP31: по всему бассейну объявлены новые морские заповедники"},
	"sim.news.event.cop31_2036.b": {"tr": "COP31 Orta Dönem Zirvesi: iklim fonu aktarıldı, yeni rezerv ilan edilmedi", "en": "COP31 mid-term summit: climate finance banked, no new reserves", "ru": "Саммит COP31: транш климатического фонда освоен без расширения зон охраны"},
	"sim.news.event.cop31_2041.a": {"tr": "COP31 Kapanış Zirvesi: son beş yıl için karbon sınırı imzalandı", "en": "COP31 final summit: a carbon cap is signed for the last five years", "ru": "Итоговый саммит COP31: подписано ограничение углеродных выбросов"},
	"sim.news.event.cop31_2041.b": {"tr": "COP31 Kapanış Zirvesi: büyüme öncelik oldu, emisyonlar artmaya devam ediyor", "en": "COP31 final summit: growth comes first and emissions keep rising", "ru": "Итоговый саммит COP31: рост экономики в приоритете, выбросы растут"},
}
