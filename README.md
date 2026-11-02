# 🌊 AQUASTASIS
### **COP31 Antalya — Akdeniz Ekosistem Savunması**
*GameUP Türkiye Oyun Hackathonu · COP31 Türkiye – Antalya Özel*

![Godot 4](https://img.shields.io/badge/Engine-Godot_4.x-478cbf?style=for-the-badge&logo=godot-engine&logoColor=white)
![Zero Asset](https://img.shields.io/badge/Mimari-%25100_Prosed%C3%BCrel_(S%C4%B1f%C4%B1r_Harici_Dosya)-19e6c1?style=for-the-badge)
![Languages](https://img.shields.io/badge/Dil-TR_%7C_EN_%7C_RU-e8a33d?style=for-the-badge)
![Platform](https://img.shields.io/badge/Platform-Windows_(.exe)_%7C_Linux-2ea44f?style=for-the-badge)

---

## 🎯 Oyun Özeti ve İklim Konusuyla İlişkisi

**AQUASTASIS**, oyuncunun **COP31 Antalya Deniz Koalisyonu** lideri olarak Akdeniz'i 2026–2046 yılları arasında ekolojik çöküşten kurtarmaya çalıştığı gerçek zamanlı bir strateji ve kriz simülasyon oyunudur.

* **Oyuncu Ne Yapar?** Bütçe, Siyasi Destek ve Bilim kaynaklarını yöneterek Akdeniz'in 8 bölgesinde acil deniz temizliği yapar (`[Q]`), deniz koruma devriyeleri kurar (`[W]`), kamuoyu bilinçlendirme kampanyaları yürütür (`[E]`), 24 düğümlü Politika Ağacı'ndan çevre yasaları çıkarır (`[T]`) ve denizdeki veri baloncuklarını toplayarak kriz mutasyonlarına karşı bilimsel çözümler üretir.
* **İklim Kriziyle İlişkisi:** Küresel ısınma (`+1.5°C -> +4.0°C`), deniz suyu asitlenmesi, Marmara müsilaj krizleri, mercan ağarması, *Posidonia* deniz çayırlarının kaybı ve bayrak türlerin (*Caretta caretta* ile *Akdeniz Foku*) neslinin tükenme tehlikesini birbirine bağlı canlı bir ekosistem simülasyonuna dönüştürür. Oyuncuya, iklim krizinin tek tip geçici müdahalelerle değil; **bilim, koruma kalkanları, uluslararası diplomasi ve toplumsal desteğin** dengeli birleşimiyle çözülebileceğini deneyimletir.

---

## 🚀 Kurulumsuz Hemen Oyna (Windows & Godot)

Bilgisayarınızda Godot Engine kurulu olmasına **gerek yoktur**:

1. **Doğrudan Çalıştırma (Windows):**
   * Depoyu indirin (`Code -> Download ZIP`) veya klonlayın.
   * Klasör içindeki **`Aquastasis.exe`** (veya **`oyunu_baslat.bat`**) dosyasına çift tıklayın (`Aquastasis.pck` aynı klasörde bulunmalıdır).
2. **GitHub Releases Üzerinden İndirme:**
   * Sağ taraftaki **[Releases](https://github.com/Ryubio/Aquastasis/releases)** bölümünden hazır paketi indirip tek tıkla başlatabilirsiniz.
3. **Godot 4 Editörü ile Açma:**
   * Godot 4.3+ ile `project.godot` dosyasını içe aktarın ve `F5` tuşuna basın.

---

## 🎮 Temel Mekanikler ve Özellikler

### 1. 🏛️ Antalya COP31 Karargah Kuralı ve DEFCON Barometresi
* **Antalya Körfezi**, koalisyonun komuta merkezidir. Haritada özel altın radar halkalarıyla işaretlenmiştir. Antalya'daki kriz seviyesi kritik eşiği (**%75**) aşarsa koalisyon çöker ve oyun kaybedilir.
* Havzadaki ortalama kirlilik ve ısınmaya göre **DEFCON 5 (Güvenli) -> DEFCON 1 (Ekolojik Çöküş)** alarm sistemi devreye girer.

### 2. ⚡ Taktik Saha Operasyonları (`Q` / `W` / `E`) ve Sinerji
Herhangi bir deniz bölgesi seçildiğinde sağ panelden veya klavye kısayollarıyla 3 anlık operasyon yürütülür:
* **`[Q]` Acil Temizlik Operasyonu (`40 Bütçe`):** Temizlik gemileriyle bölgedeki akut kirliliği anında düşürür.
* **`[W]` Deniz Devriyesi (`12 Siyasi Destek`):** Kaçak deşarjı ve yasa dışı balıkçılığı durdurur (**-%1.5 anlık kirlilik**), **🛡️ Deniz Koruma Kalkanı (+20)** kurarak komşu bölgelerden gelen kriz yayılmasını bloke eder ve balık/fok popülasyonunu iyileştirir.
* **`[E]` Farkındalık Kampanyası (`20 Bütçe + 4 Destek`):** Kıyı halkını temizliğe seferber eder (**-%2.0 anlık kirlilik**), seçili bölgede ve komşularında **📢 Halk Bilinci & Destek** seviyesini artırır, koruma kalkanının aşınmasını önler ve siyasi destek baloncukları üretir.

### 3. 🧬 Kriz DNA Evrimi ("Tersine Plague Inc." Dinamiği)
* Kriz kendi yapay zeka belleğine sahiptir. Oyuncu sürekli sadece tek bir stratejiyi (ör. yalnızca `[Q]` Temizlik) tekrarlarsa, kriz buna karşı **Direnç Mutasyonu** (*İstilacı Tür İstilası, Mikroplastik Direnci, Dezenformasyon Dalgaları* vb.) geliştirir.
* Dirençleri kırmak için **Politika Ağacı (`[T]`)** üzerinden karşı-politikalar benimsenmeli veya Bilim Puanı ile **Karşı-Aşı Sentezi** yapılmalıdır.

### 4. 🌳 Politika Ağacı (4 Dal, 24 Düğüm) & Bilim Projeleri
* **Deniz Koruma:** Deniz Koruma Alanları (MPA), Posidonia Restorasyonu, Mercan Fidanlıkları, Mavi Karbon Borsası, 30x30 Okyanus Ağı.
* **Kirlilik Kaynağı Kesme:** Tek Kullanımlık Plastik Yasağı, Gemi Atık Denetimi, Nehir Ağzı Filtreleri, Sıfır Atık Limanlar.
* **Bilim ve Kamuoyu:** Uydu Takibi, Vatandaş Bilimi, Okul Müfredatı, Dezenformasyonla Mücadele, Biyo-Enzimler.
* **Ekonomi ve Diplomasi:** Sürdürülebilir Balıkçılık Kotaları, Yeşil Turizm Etiketi, Akdeniz Bölgesel Antlaşması, Karbon Fiyatlandırması.

### 5. 🐢 Biyoçeşitlilik ve COP31 Liderler Zirveleri
* **Bayrak Türler:** Antalya ve Ege'de kirlilik düştükçe **Caretta caretta** yuvaları; Marmara ve Adriyatik'te koruma alanları arttıkça **Akdeniz Foku (*Monachus monachus*)** nüfusu çoğalır.
* **5 Yıllık Zirveler (2031, 2036, 2041):** Her 5 yılda bir toplanan COP31 Zirvesi'nde koalisyonun karnesi değerlendirilir; başarı durumunda Yeşil İklim Fonu hibeleri, başarısızlıkta ise endüstriyel lobi baskılarıyla yüzleşilir.

---

## ⌨️ Kontroller ve Kısayollar

| Tuş / Eylem | Açıklama |
| :--- | :--- |
| **Sol Tık (Deniz Bölgesi)** | Bölge seçimi ve Bölge Denetçisi'ni açma |
| **Sol Tık (Baloncuklar)** | Haritada yüzen **Bilim (Camgöbeği)** ve **Siyasi Destek (Kehribar)** balonlarını toplama |
| **`Q` / `W` / `E`** | Seçili bölgede: `[Q]` Acil Temizlik · `[W]` Deniz Devriyesi · `[E]` Farkındalık Kampanyası |
| **`T`** | Politika & Teknoloji Ağacı penceresini aç/kapat |
| **`H` veya `[?]` Butonu** | COP31 Akdeniz Harekat Kılavuzu'nu aç/kapat |
| **`Boşluk (Space)`** | Simülasyonu Duraklat / Devam Ettir |
| **`1` / `2` / `3`** | Zaman akış hızı (`1x` / `2x` / `4x`) |
| **`ESC`** | Açık pencereleri kapat / Duraklatma ve Ses Ayarları menüsü |

---

## 🛠️ Teknik Mimari (%100 Kod Tabanlı / Sıfır Harici Varlık)

Proje, dışarıdan hiçbir görsel (`.png`, `.svg`), ses (`.wav`, `.mp3`) veya 3B model (`.glb`) dosyası kullanmadan **%100 GDScript ve GLSL Shader koduyla** inşa edilmiştir:

* **Prosedürel 3B Akdeniz Haritası (`scripts/map_builder.gd`):** 8 deniz bölgesi çokgen verilerinden `Geometry2D.triangulate_polygon()` ve `SurfaceTool` ile gerçek zamanlı 3B mesh olarak üretilir.
* **Özel Deniz & Atmosfer Shader'ları (`shaders/`):** Her bölgenin kirlilik ve sağlık değerine göre dalga genliği, biyolüminesans parıltısı, kostik su altı ışıkları ve Marmara müsilaj partikülleri gerçek zamanlı hesaplanır.
* **Prosedürel Ses Sentezleyici (`scripts/audio_synth.gd`):** `AudioStreamGenerator` kullanılarak 48 Hz derin okyanus uğultusu, 750 Hz denizaltı sonar pingi, mekanik terminal klikleri, su baloncuğu sesleri, DEFCON sireni ve ekosistem kalp atışı matematiksel dalgalarla sentezlenir.
* **Vektörel İkon Motoru (`scripts/icons.gd`):** Tüm teknoloji ağacı, kaynak, kaplumbağa/fok ve arayüz ikonları `_draw()` API'si ile çizilir.
* **3 Dil Desteği (`scripts/i18n*.gd`):** Türkçe, İngilizce ve Rusça tam yerelleştirme (canlı dil değiştirme destekli).
* **Otomatik Doğrulama ve Monte Carlo Test Süiti:**
  * Derleme ve tip kontrolü: `godot --headless --path . res://tools/check.tscn`
  * Denge testi: `godot --headless --path . -s res://scripts/sim_test.gd`
  * 8 oyuncu arketipi x 10 tohum (80 tam oyun) simülasyonu: `godot --headless --path . -s res://scripts/monte_carlo_50.gd`

---

## 🌍 English Summary (For International Jury)

**AQUASTASIS** is a real-time ecological strategy and reverse-pandemic simulation game built in **Godot 4** for the **GameUP Türkiye Game Hackathon (COP31 Türkiye – Antalya Special)**.

* **Player Role:** As the commander of the **COP31 Mediterranean Marine Coalition** headquartered in Antalya Gulf, you must halt a spreading Marine Health Crisis across 8 Mediterranean regions between 2026 and 2046.
* **Core Loop:** Balance **Budget, Political Support, and Science Points** to execute local field operations (`[Q]` Emergency Cleanup, `[W]` Marine Patrols that build a spread-blocking Protection Shield, `[E]` Civic Awareness Campaigns), adopt 24 structural laws in the **Policy Tree (`[T]`)**, and counter adaptive **Crisis DNA Mutations** before global warming hits `+4.0°C` or Antalya HQ collapses.
* **Zero-Asset Engineering:** 100% of the 3D coastline meshes, spatial sea shaders, vector icons, and real-time synthesized audio (`AudioStreamGenerator`) are generated purely from code with zero external asset files, supporting **Turkish, English, and Russian** out of the box.
