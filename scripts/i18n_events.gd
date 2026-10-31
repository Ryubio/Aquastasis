extends RefCounted
## String table (decision event cards: titles, texts, choice labels, result texts. Owner: content module (en), localization (tr/ru)) merged by the I18n autoload; never read directly by game code.
## Format: key -> {"tr": ..., "en": ..., "ru": ...}. Keys are unique across all tables.

const STRINGS := {
	# --- Oil spill ---
	"event.oil_spill.title": {"tr": "{region} Yakınında Tanker Kazası", "en": "Tanker Spill near {region}", "ru": "Разлив нефти близ региона {region}"},
	"event.oil_spill.text": {"tr": "Hasar gören bir tanker {region} açıklarında ham petrol sızdırıyor. Tabaka sahillere ve balıkçılık alanlarına doğru ilerliyor.", "en": "A damaged tanker is leaking crude oil off {region}. The slick is drifting toward beaches and fishing grounds.", "ru": "Поврежденный танкер сбрасывает нефть у берегов {region}. Пятно движется к пляжам и рыболовным зонам."},
	"event.oil_spill.a.label": {"tr": "Bariyerler ve toplayıcı tekneler konuşlandır", "en": "Deploy booms and skimmers", "ru": "Установить боны и привлечь скиммеры"},
	"event.oil_spill.a.result": {"tr": "Petrolün büyük kısmı zamanında temizlendi. {region}: kirlilik sadece +4, farkındalık +5.", "en": "Most of the oil was skimmed in time. {region}: pollution only +4, awareness +5.", "ru": "Большую часть нефти удалось собрать вовремя. {region}: загрязнение всего +4, осведомленность +5."},
	"event.oil_spill.b.label": {"tr": "Kendi kendine dağılmasını bekle", "en": "Let it disperse", "ru": "Позволить пятну рассеяться самому"},
	"event.oil_spill.b.result": {"tr": "Petrol sahile vurdu. {region}: kirlilik +14, balık stoku -8.", "en": "The slick washed ashore. {region}: pollution +14, fish stock -8.", "ru": "Мазут осел на пляжах. {region}: загрязнение +14, запасы рыбы -8."},

	# --- Marine heatwave ---
	"event.heatwave.title": {"tr": "{region} Bölgesinde Sıcak Dalga", "en": "Marine Heatwave in {region}", "ru": "Морская волна тепла в {region}"},
	"event.heatwave.text": {"tr": "{region} açıklarında deniz suyu sıcaklığı rekor seviyeye ulaştı. Mercanlar ve deniz çayırları ölmeye başlıyor.", "en": "Sea temperatures off {region} hit record highs. Corals and seagrass are starting to die.", "ru": "Температура воды близ {region} бьет рекорды. Начинается гибель кораллов и донной растительности."},
	"event.heatwave.a.label": {"tr": "Sensörler yerleştir, dalış noktalarını kapat", "en": "Deploy sensors, close dive sites", "ru": "Развернуть датчики, закрыть дайвинг"},
	"event.heatwave.a.result": {"tr": "Hızlı önlemler resifleri korudu: 2 yıl boyunca havza genelinde mercan ısı hasarı yarıya indi. {region}: mercan sağlığı sadece -3.", "en": "Sensors guide fast closures: coral heat damage is halved basin-wide for two years. {region}: coral health only -3.", "ru": "Быстрые меры защитили рифы: урон кораллам снижен вдвое на 2 года. {region}: здоровье кораллов всего -3."},
	"event.heatwave.b.label": {"tr": "Müdahale etme, geçmesini bekle", "en": "Ride it out", "ru": "Ничего не предпринимать"},
	"event.heatwave.b.result": {"tr": "Kitlesel ölüm yaşandı. {region}: mercan sağlığı -12, deniz çayırları -6.", "en": "Mass die-off. {region}: coral health -12, seagrass -6.", "ru": "Массовая гибель морской флоры и фауны. {region}: здоровье кораллов -12, луга посидонии -6."},

	# --- Lobby pressure ---
	"event.lobby_pressure.title": {"tr": "Sanayi Lobisi Kapıda", "en": "Industry Lobby at the Door", "ru": "Давление промышленного лобби"},
	"event.lobby_pressure.text": {"tr": "Plastik ve nakliye lobileri yeni kuralların dondurulmasını talep ediyor. İstihdam vadedip medyayla tehdit ediyorlar.", "en": "Plastics and shipping lobbies demand a freeze on new rules. They promise jobs and threaten headlines.", "ru": "Лоббисты требуют заморозить экологические ограничения, угрожая скандалами в прессе."},
	"event.lobby_pressure.a.label": {"tr": "Geri adım atma", "en": "Stand firm", "ru": "Проявить твердость"},
	"event.lobby_pressure.a.result": {"tr": "Taviz vermedin ve kamuoyu arkanda durdu: tüm bölgelerde farkındalık +5.", "en": "You held the line and the public rallied: +5 awareness in every region.", "ru": "Вы устояли, и общество вас поддержало: +5 к осведомленности во всех регионах."},
	"event.lobby_pressure.b.label": {"tr": "'Gönüllü' taahhütleri kabul et", "en": "Accept a 'voluntary' deal", "ru": "Принять 'добровольное' соглашение"},
	"event.lobby_pressure.b.result": {"tr": "Sanayi +60 bütçe ödedi ancak taahhütler yetersiz kaldı: 4 yıl boyunca kaynak kirliliği +%20.", "en": "Industry pays +60 budget, but its voluntary pledges leak: source inflow +20% for four years.", "ru": "Бизнес выплатил +60 бюджета, но приток загрязнения вырос на 20% на 4 года."},

	# --- Greenwashing scandal ---
	"event.greenwashing.title": {"tr": "Yeşil Aklama Skandalı", "en": "Greenwashing Scandal", "ru": "Скандал с гринвошингом"},
	"event.greenwashing.text": {"tr": "Gazeteciler, bir koalisyon sponsoru şirketin 'mavi okyanus' reklamları yaparken denize atık döktüğünü ortaya çıkardı. Güven çöküyor.", "en": "Reporters reveal that a coalition sponsor dumped waste while running 'blue ocean' ads. Trust is collapsing.", "ru": "Журналисты выяснили, что спонсор коалиции тайком сливал отходы в море под прикрытием эко-рекламы."},
	"event.greenwashing.a.label": {"tr": "İlişkileri kes ve denetim raporu yayımla", "en": "Cut ties and publish an audit", "ru": "Разорвать связи и опубликовать аудит"},
	"event.greenwashing.a.result": {"tr": "Şeffaflık güven tazeledi: +15 siyasi destek ve tüm bölgelerde +4 farkındalık.", "en": "Radical transparency pays off: +15 political support and +4 awareness in every region.", "ru": "Открытость оправдала себя: +15 к политической поддержке и +4 к осведомленности везде."},
	"event.greenwashing.b.label": {"tr": "Sessiz kal", "en": "Stay quiet", "ru": "Замять скандал"},
	"event.greenwashing.b.result": {"tr": "Haber haftalarca gündemde kaldı: -15 siyasi destek ve 3 yıl boyunca farkındalık %50 daha hızlı siliniyor.", "en": "The story runs for weeks: -15 political support, and awareness fades 50% faster for three years.", "ru": "Удар по репутации: -15 поддержки, а осведомленность падает на 50% быстрее в течение 3 лет."},

	# --- Fishers' cooperative ---
	"event.fishers_coop.title": {"tr": "Balıkçı Kooperatifi Teklifi", "en": "Fishers' Cooperative Offer", "ru": "Предложение рыбацкого кооператива"},
	"event.fishers_coop.text": {"tr": "{region} bölgesindeki balıkçı kooperatifi, koalisyon seçici ağları finanse ederse av miktarını azaltmayı teklif ediyor.", "en": "A fishers' cooperative in {region} will cut its catch if the coalition pays for selective nets.", "ru": "Кооператив в регионе {region} согласен снизить вылов, если коалиция оплатит экологичные снасти."},
	"event.fishers_coop.a.label": {"tr": "Yeni ağları finanse et", "en": "Fund the new gear", "ru": "Оплатить новое снаряжение"},
	"event.fishers_coop.a.result": {"tr": "Seçici ağlar sayesinde yavru balıklar kurtuldu. {region}: balık stoku +8, 4 yıl boyunca av baskısı havza genelinde %10 azaldı.", "en": "New nets, less bycatch. {region}: fish stock +8, and fishing pressure falls 10% basin-wide for four years.", "ru": "Меньше прилова: в регионе {region} запасы рыбы +8, промысловое давление снизилось на 10% на 4 года."},
	"event.fishers_coop.b.label": {"tr": "Teklifi reddet", "en": "Decline the offer", "ru": "Отклонить предложение"},
	"event.fishers_coop.b.result": {"tr": "Balıkçılar eski ağlarla aşırı avlanmaya devam ediyor. {region}: balık stoku -5.", "en": "The fishers keep their old nets and their old catch. {region}: fish stock -5.", "ru": "Рыбаки продолжили истощать биоресурсы старыми сетями. {region}: запасы рыбы -5."},

	# --- Tourism season surge ---
	"event.tourism_surge.title": {"tr": "Rekor Turizm Sezonu", "en": "Record Tourist Season", "ru": "Рекордный туристический сезон"},
	"event.tourism_surge.text": {"tr": "{region} otelleri ve kruvaziyer gemileri tamamen dolu. Atıklar ve demir atan yatlar Posidonia çayırlarını eziyor.", "en": "Hotels and cruise ships in {region} are fully booked. Waste, sewage and anchors pile onto the seagrass.", "ru": "Отели региона {region} переполнены. Стоки и якорные стоянки катеров разрушают донные луга."},
	"event.tourism_surge.a.label": {"tr": "Kruvaziyerleri sınırla, demirlemeyi yasakla", "en": "Cap cruises, ban anchoring", "ru": "Ограничить круизы, запретить якоря"},
	"event.tourism_surge.a.result": {"tr": "Kotalar denizi korudu. {region}: deniz çayırları +4, kirlilik -4, farkındalık +4.", "en": "Quotas hold the line. {region}: seagrass +4, pollution -4, awareness +4.", "ru": "Строгие квоты спасли луга. {region}: посидония +4, загрязнение -4, осведомленность +4."},
	"event.tourism_surge.b.label": {"tr": "Turizm patlamasına izin ver", "en": "Let the boom run", "ru": "Не мешать турпотоку"},
	"event.tourism_surge.b.result": {"tr": "Turizm +70 bütçe sağladı ancak çapalar çayırları söktü. {region}: deniz çayırları -10, kirlilik +8.", "en": "The boom brings +70 budget, but anchors tear up the meadows. {region}: seagrass -10, pollution +8.", "ru": "Доходы выросли на +70 бюджета, но якоря уничтожили луга. {region}: посидония -10, загрязнение +8."},

	# --- Marmara mucilage ---
	"event.mucilage.title": {"tr": "{region} Bölgesinde Müsilaj Patlaması", "en": "Mucilage Outbreak in {region}", "ru": "Вспышка слизи в регионе {region}"},
	"event.mucilage.text": {"tr": "{region} sularını kaplayan deniz salyası balıkları ve deniz tabanını boğuyor. Yüksek sıcaklık ve arıtılmamış atıklar bunu besliyor.", "en": "A slimy blanket of sea snot spreads across {region}, smothering fish and seabed life. Warm water and sewage feed it.", "ru": "Густая пелена морской слизи душит рыбу и донные организмы в {region}. Причина — тепло и сточные воды."},
	"event.mucilage.a.label": {"tr": "Bariyerler ve toplayıcı tekneler sevk et", "en": "Barriers and skimmers", "ru": "Задействовать очистные барьеры"},
	"event.mucilage.a.result": {"tr": "Ekipler yüzeydeki salyayı topladı. {region}: kirlilik -14.", "en": "Crews lift the slime off the surface. {region}: pollution -14.", "ru": "Поверхность очищена специальными катерами. {region}: загрязнение -14."},
	"event.mucilage.b.label": {"tr": "Araştır, müdahaleyi ertele", "en": "Study it, act later", "ru": "Изучить феномен в лаборатории"},
	"event.mucilage.b.result": {"tr": "Bilim insanları numunelerden +15 bilim elde etti ancak müsilaj yayıldı. {region}: kirlilik +6, balık stoku -6.", "en": "Scientists bank +15 science in samples while the slime spreads. {region}: pollution +6, fish stock -6.", "ru": "Получено +15 очков науки, но слизь нанесла урон фауне. {region}: загрязнение +6, рыба -6."},

	# --- Foreign trawlers ---
	"event.foreign_trawlers.title": {"tr": "Kaçak Troller Tespit Edildi", "en": "Dark Trawlers Spotted", "ru": "Обнаружены браконьерские траулеры"},
	"event.foreign_trawlers.text": {"tr": "Konum cihazlarını kapatmış endüstriyel troller {region} açıklarında deniz tabanını kazıyarak yağmalıyor.", "en": "Industrial trawlers with their transponders switched off are raking the seabed off {region}.", "ru": "Суда с отключенными маячками AIS ведут хищнический донный траловый лов в {region}."},
	"event.foreign_trawlers.a.label": {"tr": "Sahil Güvenlik devriyesi gönder", "en": "Send a patrol", "ru": "Выслать патрульные катера"},
	"event.foreign_trawlers.a.result": {"tr": "Devriye botları kaçak gemileri uzaklaştırdı. {region}: koruma +10.", "en": "Patrol boats escort the trawlers out. {region}: protection +10.", "ru": "Патруль выдворил нарушителей. {region}: уровень защиты +10."},
	"event.foreign_trawlers.b.label": {"tr": "Diplomatik nota gönder", "en": "Send a diplomatic note", "ru": "Ограничиться дипломатической нотой"},
	"event.foreign_trawlers.b.result": {"tr": "Notalar yazılırken troller deniz tabanını çıplak bıraktı. {region}: balık stoku -15, deniz çayırları -5.", "en": "While notes are exchanged, the trawlers strip the seabed. {region}: fish stock -15, seagrass -5.", "ru": "Пока велась переписка, траулеры опустошили дно. {region}: запасы рыбы -15, посидония -5."},

	# --- Caretta caretta nesting season ---
	"event.caretta_nesting.title": {"tr": "Kaplumbağa Yuvalama Sezonu", "en": "Turtle Nesting Season", "ru": "Сезон гнездования черепах"},
	"event.caretta_nesting.text": {"tr": "Caretta caretta deniz kaplumbağaları {region} kumsallarında şezlongların ve barların hemen yanına yuva yapıyor.", "en": "Loggerhead turtles are nesting on the beaches of {region}, right next to sunbeds and beach bars.", "ru": "Морские черепахи откладывают яйца на пляжах {region} рядом с шезлонгами и шумными барами."},
	"event.caretta_nesting.a.label": {"tr": "Yuvaları korumaya al", "en": "Guard the nests", "ru": "Взять кладки под круглосуточную охрану"},
	"event.caretta_nesting.a.result": {"tr": "Gönüllüler yuvaları korudu ve yavrular güvenle denize ulaştı. {region}: farkındalık +8, koruma +6.", "en": "Volunteers guard the nests and the hatchlings reach the sea. {region}: awareness +8, protection +6.", "ru": "Волонтеры защитили гнезда, черепашата вышли в море. {region}: осведомленность +8, защита +6."},
	"event.caretta_nesting.b.label": {"tr": "Plajları tamamen açık tut", "en": "Keep the beaches open", "ru": "Не ограничивать бизнес и отдых"},
	"event.caretta_nesting.b.result": {"tr": "Turizm +30 bütçe kazandırdı ancak ışıklar yavru kaplumbağaları denizden uzaklaştırdı. {region}: farkındalık -5.", "en": "Tourism earns +30 budget, but beach lights lure hatchlings away from the sea. {region}: awareness -5.", "ru": "Пляжи принесли +30 бюджета, но огни погубили молодняк. {region}: осведомленность -5."},

	# --- COP31 summit 2031 ---
	"event.cop31_2031.title": {"tr": "COP31 Ara Zirvesi: 2031", "en": "COP31 Review Summit: 2031", "ru": "Промежуточный саммит COP31: 2031"},
	"event.cop31_2031.text": {"tr": "Antalya'dan beş yıl sonra koalisyon Akdeniz taahhütlerini gözden geçiriyor. Delegeler ve bağışçılar izliyor.", "en": "Five years after Antalya, the coalition meets to review its Mediterranean pledge. Donors and delegates are watching.", "ru": "Спустя 5 лет после Антальи лидеры оценивают выполнение средиземноморских соглашений."},
	"event.cop31_2031.a.label": {"tr": "Bağlayıcı plastik sözleşmesini geçir", "en": "Push a binding plastics pact", "ru": "Принять строгий пакт по пластику"},
	"event.cop31_2031.a.result": {"tr": "Sözleşme kabul edildi: bir sonraki zirveye kadar havza genelinde kirlilik girdisi -%20 azaldı.", "en": "The pact passes: source inflow -20% basin-wide until the next summit.", "ru": "Пакт принят: сброс отходов снижен на 20% по всему морю до следующего саммита."},
	"event.cop31_2031.b.label": {"tr": "Bağışçı hibesini al", "en": "Take the donor grant", "ru": "Взять гранты инвесторов"},
	"event.cop31_2031.b.result": {"tr": "Bağışçılar +100 bütçe sağladı. Plastik sözleşmesi şimdilik rafa kaldırıldı.", "en": "Donors release +100 budget. The plastics pact is shelved for now.", "ru": "Получено +100 к бюджету. Соглашение по пластику отложено."},

	# --- COP31 summit 2036 ---
	"event.cop31_2036.title": {"tr": "COP31 Orta Dönem Zirvesi: 2036", "en": "COP31 Mid-Term Summit: 2036", "ru": "Саммит середины срока COP31: 2036"},
	"event.cop31_2036.text": {"tr": "2046 hedefine giden yolun yarısı. Delegeler yeni koruma alanları ile yeni iklim finansmanı arasında bölündü.", "en": "Halfway to 2046. Delegates are split between new marine reserves and a fresh round of climate finance.", "ru": "Половина пути до 2046 года. Дебаты между расширением заповедников и получением нового транша."},
	"event.cop31_2036.a.label": {"tr": "Korunan alanları genişlet", "en": "Expand protected areas", "ru": "Расширить морские заповедники"},
	"event.cop31_2036.a.result": {"tr": "Tüm havzada yeni rezervler ilan edildi: her bölgede koruma +10.", "en": "New reserves are declared across the basin: +10 protection in every region.", "ru": "Объявлены новые охраняемые зоны: +10 к защите во всех регионах."},
	"event.cop31_2036.b.label": {"tr": "İklim fonunu kasaya aktar", "en": "Bank the climate finance", "ru": "Принять финансовую помощь"},
	"event.cop31_2036.b.result": {"tr": "Fondan +80 bütçe ve +10 siyasi destek alındı ancak yeni koruma alanı açılmadı.", "en": "The fund pays out +80 budget and +10 political support, but no new reserves.", "ru": "Фонд выделил +80 бюджета и +10 поддержки, но новые заповедники не созданы."},

	# --- COP31 summit 2041 ---
	"event.cop31_2041.title": {"tr": "COP31 Final Zirvesi: 2041", "en": "COP31 Final Summit: 2041", "ru": "Финальный саммит COP31: 2041"},
	"event.cop31_2041.text": {"tr": "Hedefe son beş yıl. Dünya, Akdeniz koalisyonundan emisyonlar konusunda son bir kararlı hamle bekliyor.", "en": "Five years left. The world asks the Mediterranean coalition for one last push on emissions.", "ru": "Осталось всего 5 лет. Мир ждет от коалиции решительных мер по сокращению выбросов."},
	"event.cop31_2041.a.label": {"tr": "Hızlı karbon sınırlaması uygula", "en": "Fast-track a carbon cap", "ru": "Ввести жесткий углеродный лимит"},
	"event.cop31_2041.a.result": {"tr": "Sözleşme imzalandı: ısınma hemen 0.05°C düştü ve 2046'ya kadar %40 yavaşladı.", "en": "The cap is signed: warming drops by 0.05°C now and slows by 40% until 2046.", "ru": "Пакт подписан: потепление сразу снизилось на 0.05°C и замедлилось на 40% до 2046 года."},
	"event.cop31_2041.b.label": {"tr": "Ekonomik büyümeyi öncelik yap", "en": "Put growth first", "ru": "Поставить во главу рост экономики"},
	"event.cop31_2041.b.result": {"tr": "2046'ya kadar bütçe geliri +%20 arttı ancak küresel ısınma %10 hızlandı.", "en": "Budget income +20% until 2046, but warming speeds up by 10%.", "ru": "Доходы бюджета +20% до 2046 года, но потепление ускорилось на 10%."},
}
