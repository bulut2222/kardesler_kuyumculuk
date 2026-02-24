import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:developer' as dev;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' show parse;
import 'dart:io' show Platform; // İŞTE iOS'U KURTARACAK SİHİRLİ SATIR BURASI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // EĞER CİHAZ iOS İSE BU BİLGİLERLE BAĞLAN:
  if (Platform.isIOS) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDVBpdZuaEsOBC6W4vFRGUyi8LZb2JgJH8",
        appId: "1:626207190484:ios:d57cba98a6a9a8ce1d3a41",
        messagingSenderId: "626207190484",
        projectId: "kardeslerkuyumcusu-f8428",
        databaseURL: "https://kardeslerkuyumcusu-f8428-default-rtdb.firebaseio.com",
        storageBucket: "kardeslerkuyumcusu-f8428.firebasestorage.app",
        iosBundleId: "com.yourname.kardeslerkuyumcusu",
      ),
    );
  } 
  // EĞER CİHAZ ANDROID İSE SENİN ESKİ BİLGİLERİNLE BAĞLAN:
  else {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDiF13eBZ_my6FAsSYmPsGJSJxFaK6U-SM",
        appId: "1:626207190484:android:f612d2f0dd2176691d3a41",
        messagingSenderId: "626207190484",
        projectId: "kardeslerkuyumcusu-f8428",
        databaseURL: "https://kardeslerkuyumcusu-f8428-default-rtdb.firebaseio.com",
      ),
    );
  }

  await initializeDateFormatting('tr_TR', null);
  runApp(const KardeslerApp());
}

// --- TEMA YÖNETİMİ ---
class KardeslerApp extends StatefulWidget {
  const KardeslerApp({super.key});
  @override
  State<KardeslerApp> createState() => _KardeslerAppState();
}

class _KardeslerAppState extends State<KardeslerApp> {
  ThemeMode _themeMode = ThemeMode.dark;
  void toggleTheme() => setState(() => _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        primaryColor: const Color(0xFFD4AF37),
        cardColor: Colors.white,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020203),
        primaryColor: const Color(0xFFD4AF37),
        cardColor: const Color(0xFF0A0A0D),
      ),
      home: SplashEkrani(onThemeToggle: toggleTheme),
    );
  }
}

// --- SPLASH EKRANI ---
class SplashEkrani extends StatefulWidget {
  final VoidCallback onThemeToggle;
  const SplashEkrani({super.key, required this.onThemeToggle});
  @override
  State<SplashEkrani> createState() => _SplashEkraniState();
}

class _SplashEkraniState extends State<SplashEkrani> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);
    _offsetAnimation = Tween<Offset>(begin: const Offset(-1.5, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
    Timer(const Duration(seconds: 4), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnaSayfa(toggleTheme: widget.onThemeToggle)));
    });
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Opacity(opacity: 0.2, child: Image.asset("assets/splash.jpg", fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (c, o, s) => Container(color: Colors.black))),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle), child: ClipOval(child: Image.asset("assets/splash.jpg", fit: BoxFit.cover, errorBuilder: (c, o, s) => const Icon(Icons.diamond, size: 60, color: Colors.white)))),
                const SizedBox(height: 30),
                SlideTransition(position: _offsetAnimation, child: const Column(children: [
                  Text("KARDEŞLER", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  Text("KUYUMCULUK", style: TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 5)),
                ])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AltinModel {
  final String isim, alis, satis, fark;
  final bool dusus; 
  AltinModel({required this.isim, required this.alis, required this.satis, required this.fark, required this.dusus});
}

class AnaSayfa extends StatefulWidget {
  final VoidCallback toggleTheme;
  const AnaSayfa({super.key, required this.toggleTheme});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final DatabaseReference _dbGecmis = FirebaseDatabase.instance.ref().child('AltinGecmisi');
  final DatabaseReference _dbCanli = FirebaseDatabase.instance.ref().child('AltinGecmisi_Canli').child('veriler');
  
  late final WebViewController _webViewController;
  Timer? _veriCekmeTimer;
  Timer? _tickerTimer;
  final ScrollController _scrollController = ScrollController();
  
  List<AltinModel> altinListesi = [];
  List<String> seciliKategoriler = [];
  
  // GİZLİ MÜDAHALE MAP'İ VE SON HTML HAFIZASI
  final Map<String, double> manipuleOranlari = {}; 
  String _sonCekilenHtml = ""; 
  
  final List<String> tumKategoriler = [
    "HAS ALTIN", "ONS", "USD/KG", "EUR/KG", "22 AYAR", "GRAM ALTIN", "ALTIN GÜMÜŞ", 
    "YENİ ÇEYREK", "ESKİ ÇEYREK", "YENİ YARIM", "ESKİ YARIM", "YENİ TAM", "ESKİ TAM", 
    "YENİ ATA", "ESKİ ATA", "YENİ ATA5", "ESKİ ATA5", "YENİ GREMSE", "ESKİ GREMSE", 
    "14 AYAR", "GÜMÜŞ TL", "GÜMÜŞ ONS", "GÜMÜŞ USD", "PLATİN ONS", "PALADYUM ONS", 
    "PLATİN/USD", "PALADYUM/USD", "USD/TRY", "EUR/TRY", "GBP/TRY"
  ];
  
  double guncelGramAlis = 0.0, guncelGramSatis = 0.0;
  String saat = "00:00:00", tarih = "Yükleniyor...", durumMetni = "BAĞLANILIYOR...";
  int _saatTiklamaSayisi = 0; 

  @override
  void initState() {
    super.initState();
    seciliKategoriler = List.from(tumKategoriler);
    for (var k in tumKategoriler) { manipuleOranlari[k] = 0.0; } // Varsayılan oran %0
    
    saatiBaslat();
    _startTicker();
    _gizliWebViewBaslat();
  }

  void saatiBaslat() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {
        saat = DateFormat('HH:mm:ss').format(DateTime.now());
        tarih = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(DateTime.now());
      });
    });
  }

  void _startTicker() {
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) {
      if (_scrollController.hasClients && altinListesi.isNotEmpty) {
        double maxScroll = _scrollController.position.maxScrollExtent;
        double currentScroll = _scrollController.position.pixels;
        if (currentScroll >= maxScroll) { _scrollController.jumpTo(0.0); } 
        else { _scrollController.jumpTo(currentScroll + 1.5); }
      }
    });
  }

  void _gizliWebViewBaslat() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(onPageFinished: (url) {
        if (mounted) setState(() => durumMetni = "CANLI AKTİF 🟢");
        _otomatikVeriCekmeyiBaslat();
      }))
      ..loadRequest(Uri.parse('https://www.haremaltin.com'));
  }

  void _otomatikVeriCekmeyiBaslat() {
    _veriCekmeTimer = Timer.periodic(const Duration(seconds: 3), (timer) => _htmlYiAlVeIsle());
  } 

  Future<void> _htmlYiAlVeIsle() async {
    try {
      final String html = await _webViewController.runJavaScriptReturningResult("document.getElementsByTagName('html')[0].outerHTML;") as String;
      final temizHtml = html.replaceAll(RegExp(r'^"|"$'), '').replaceAll(r'\"', '"').replaceAll(r'\u003C', '<');
      _sonCekilenHtml = temizHtml; 
      _verileriAyikla(temizHtml);
    } catch (e) { dev.log("Hata: $e"); }
  }

  // --- MERKEZİ MOTOR (VERİ AYIKLAMA, TEMİZLEME VE GİZLİ YÜZDE HESAPLAMA) ---
  void _verileriAyikla(String html) {
    if (html.isEmpty) return;
    var document = parse(html);
    var satirlar = document.querySelectorAll("tr");
    List<AltinModel> yeniListe = [];
    String bugunTarih = DateFormat("yyyy-MM-dd HH:mm:ss", "tr_TR").format(DateTime.now());

    for (var satir in satirlar) {
      var hucreler = satir.querySelectorAll("td");
      if (hucreler.length > 3) {
        
        // 1. KUSURSUZ İSİM TEMİZLİĞİ (Görsellerdeki \n, \N ve tekrarları yok eder)
        String hamIsim = hucreler[0].text.toUpperCase();
        // Literal \n, \N, ters slash ve normal boşlukları söküp atıyoruz:
        hamIsim = hamIsim.replaceAll(r'\N', '').replaceAll(r'\n', '').replaceAll(r'\', '').replaceAll(RegExp(r'[\n\r\t]'), '');
        hamIsim = hamIsim.replaceAll(RegExp(r'\s+'), ' ').trim(); // Fazla boşlukları tek boşluğa indir
        
        // İsim İkilemesini Önleme (HAS ALTINHAS ALTIN -> HAS ALTIN)
        if (hamIsim.isNotEmpty && hamIsim.length % 2 == 0) {
          int yari = hamIsim.length ~/ 2;
          if (hamIsim.substring(0, yari) == hamIsim.substring(yari)) hamIsim = hamIsim.substring(0, yari);
        }
        
        // Boşluklu İkilemeyi Önleme (GRAM ALTIN GRAM ALTIN -> GRAM ALTIN)
        List<String> kelimeler = hamIsim.split(" ");
        if (kelimeler.length >= 2 && kelimeler.length % 2 == 0) {
          int yari = kelimeler.length ~/ 2;
          if (kelimeler.sublist(0, yari).join(" ") == kelimeler.sublist(yari).join(" ")) {
            hamIsim = kelimeler.sublist(0, yari).join(" ");
          }
        }
        hamIsim = hamIsim.trim(); // Tertemiz "HAS ALTIN" elde edildi.

        // 2. RAKAMLARI AL
        String hamAlisTxt = hucreler[1].text.replaceAll(RegExp(r'[\n\r\t]'), '').trim();
        String hamSatisTxt = hucreler[2].text.replaceAll(RegExp(r'[\n\r\t]'), '').trim();
        String farkOrani = hucreler[3].text.replaceAll(RegExp(r'[\n\r\t]'), '').trim();

        double hamAlis = double.tryParse(hamAlisTxt.replaceAll(".", "").replaceAll(",", ".")) ?? 0.0;
        double hamSatis = double.tryParse(hamSatisTxt.replaceAll(".", "").replaceAll(",", ".")) ?? 0.0;

        // 3. GİZLİ PANEL YÜZDE MÜDAHALESİ (Anında Etki Eder)
        double manipuleYuzdesi = manipuleOranlari[hamIsim] ?? 0.0;
        if (manipuleYuzdesi != 0.0) {
          // Örn: hamAlis 5000, Yüzde 100 ise -> 5000 + (5000 * 100/100) = 10000.
          hamAlis = hamAlis + (hamAlis * (manipuleYuzdesi / 100));
          hamSatis = hamSatis + (hamSatis * (manipuleYuzdesi / 100));
        }

        // 4. EKRAN FORMATINA ÇEVİR
        String sonAlis = NumberFormat.currency(locale: 'tr_TR', symbol: '').format(hamAlis).trim();
        String sonSatis = NumberFormat.currency(locale: 'tr_TR', symbol: '').format(hamSatis).trim();
        bool isDusus = farkOrani.contains("-");

        // FİREBASE KAYIT
        String temizDugumIsmi = hamIsim.replaceAll(RegExp(r'[.$#\[\]]'), "_").trim();
        _dbGecmis.child(temizDugumIsmi).child(bugunTarih).set({ "alis": sonAlis, "satis": sonSatis, "fiyat": hamSatis, "oran": farkOrani });
        _dbCanli.child(temizDugumIsmi).set({ "Buying": sonAlis, "Selling": sonSatis, "Change": farkOrani, "Status": isDusus ? "down" : "up" });

        // ÇEVİRİCİ İÇİN KÜRESEL DEĞİŞKENLERİ GÜNCELLE
        if (hamIsim == "GRAM ALTIN") { guncelGramAlis = hamAlis; guncelGramSatis = hamSatis; }

        // FİLTREYE UYUYORSA LİSTEYE EKLE
        if (seciliKategoriler.contains(hamIsim)) {
          yeniListe.add(AltinModel(isim: hamIsim, alis: sonAlis, satis: sonSatis, fark: farkOrani, dusus: isDusus));
        }
      }
    }
    if (mounted && yeniListe.isNotEmpty) setState(() => altinListesi = yeniListe);
  }

  @override
  void dispose() {
    _veriCekmeTimer?.cancel();
    _tickerTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) { dev.log("Bağlantı Hatası: $url"); }
  }
// --- GİZLİ PANEL ŞİFRE EKRANI ---
  void showSifrePopup() {
    TextEditingController sifreController = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.red, width: 2)),
      title: const Row(children: [Icon(Icons.security, color: Colors.red), SizedBox(width: 10), Text("YETKİLİ GİRİŞİ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16))]),
      content: TextField(
        controller: sifreController, obscureText: true,
        decoration: const InputDecoration(hintText: "Şifrenizi girin", border: OutlineInputBorder()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("İPTAL", style: TextStyle(color: Colors.grey))),
        TextButton(
          onPressed: () {
            if (sifreController.text == "kardesler123") {
              Navigator.pop(context); // Şifre kutusunu kapat
              showGizliPanel();       // Asıl paneli aç
            } else {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hatalı Şifre!"), backgroundColor: Colors.red));
            }
          },
          child: const Text("GİRİŞ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
        )
      ],
    ));
  }
  // --- GİZLİ YÖNETİM PANELİ (Saate 5 Kere Tıklayınca Açılır) ---
  void showGizliPanel() {
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setStatePanel) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.red, width: 2)),
      title: const Text("GİZLİ MÜDAHALE PANELİ", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
      content: SizedBox(width: double.maxFinite, child: ListView.builder(shrinkWrap: true, itemCount: tumKategoriler.length, itemBuilder: (context, index) {
        String kat = tumKategoriler[index];
        return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
          Expanded(child: Text(kat, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          SizedBox(width: 80, child: TextField(
            keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            decoration: InputDecoration(hintText: manipuleOranlari[kat]?.toString() ?? "0.0", suffixText: "%", border: const OutlineInputBorder()),
            onChanged: (val) { 
              double oran = double.tryParse(val.replaceAll(",", ".")) ?? 0.0; 
              manipuleOranlari[kat] = oran; 
            },
          )),
        ]));
      })),
      actions: [
        TextButton(
          onPressed: () { 
            Navigator.pop(context); 
            // 3 saniye beklemeden ANINDA ekrana yansıt:
            if (_sonCekilenHtml.isNotEmpty) _verileriAyikla(_sonCekilenHtml);
          }, 
          child: const Text("UYGULA VE ÇIK", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
        )
      ],
    )));
  }

  // --- DİĞER POPUPLAR ---
  void showGramHesaplaPopup() {
    double adet = 0;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setStatePopup) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: Color(0xFFD4AF37), width: 1)),
      title: const Text("HIZLI GRAM HESAPLA", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(hintText: "Gram Miktarı Girin", border: InputBorder.none),
          onChanged: (val) => setStatePopup(() => adet = double.tryParse(val.replaceAll(",", ".")) ?? 0)),
        const Divider(),
        _hesapSatir("ALIŞ:", NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(adet * guncelGramAlis)),
        const SizedBox(height: 10),
        _hesapSatir("SATIŞ:", NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(adet * guncelGramSatis), gold: true),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("KAPAT"))],
    )));
  }

  Widget _hesapSatir(String label, String value, {bool gold = false}) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: gold ? const Color(0xFFD4AF37) : null)),
    ]);
  }

  void showBizKimizPopup() {
    showDialog(context: context, builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: Theme.of(context).cardColor,
      child: Padding(padding: const EdgeInsets.all(15), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(height: 200, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFD4AF37), width: 2)),
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset("assets/dukkan.jpg", fit: BoxFit.cover, errorBuilder: (c, o, s) => Container(color: Colors.grey[900]))),
        ),
        const SizedBox(height: 20),
        const Text("Kardeşler Kuyumculuk", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text("Yılların verdiği tecrübe ve güvenle siz değerli müşterilerimize en kaliteli hizmeti sunmaktayız.", textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87, fontSize: 15, height: 1.5)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)), onPressed: () => Navigator.pop(context), child: const Text("ANLADIM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ])),
    ));
  }

  void showZekatPopup() {
    double zekatSonuc = 0.0;
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setStatePopup) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.5))),
      title: const Text("ZEKAT HESAPLA", style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text("(80.18 gr. üzeri altınlar için)", style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 15),
        TextField(keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(hintText: "Toplam Gram"),
          onChanged: (val) { double gram = double.tryParse(val.replaceAll(",", ".")) ?? 0.0; setStatePopup(() => zekatSonuc = (gram * guncelGramSatis) / 40.0); }),
        const SizedBox(height: 20),
        Text(NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(zekatSonuc), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("KAPAT"))],
    )));
  }

  void showFiltrePopup() {
    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setStateDialog) => AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: const Text("GÖRÜNTÜLEME AYARI", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold)),
      content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: tumKategoriler.map((k) => CheckboxListTile(
        activeColor: const Color(0xFFD4AF37), title: Text(k, style: const TextStyle(fontSize: 13)), value: seciliKategoriler.contains(k),
        onChanged: (v) => setStateDialog(() { v! ? seciliKategoriler.add(k) : seciliKategoriler.remove(k); setState(() {}); }),
      )).toList())),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("TAMAM"))],
    )));
  }

 @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(key: _scaffoldKey, drawer: yanMenu(isDark), body: Column(children: [
      ustPanel(isDark),
      // --- KAYAR BANT (TICKER) YÜKSELİŞ/DÜŞÜŞ RENK KORUMALI ---
      if (altinListesi.isNotEmpty) Container(height: 35, width: double.infinity, decoration: BoxDecoration(color: isDark ? const Color(0xFF16161A) : Colors.white, border: Border.symmetric(horizontal: BorderSide(color: isDark ? Colors.white10 : Colors.black12))),
        child: ListView.builder(controller: _scrollController, scrollDirection: Axis.horizontal, itemCount: altinListesi.length, itemBuilder: (context, index) {
          final item = altinListesi[index];
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8), child: Row(children: [
            Text(item.isim, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(width: 5),
            Text(item.satis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: item.dusus ? Colors.red : Colors.green)),
          ]));
        }),
      ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Row(children: [
        Text("PİYASA DURUMU", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: isDark ? Colors.white30 : Colors.black26, letterSpacing: 1.5)),
        const Spacer(),
        IconButton(icon: const Icon(Icons.filter_list, color: Color(0xFFD4AF37), size: 22), onPressed: showFiltrePopup),
        GestureDetector(onTap: () { setState(() => durumMetni = "YENİLENİYOR..."); _webViewController.reload(); }, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.green)), child: Text(durumMetni, style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)))),
      ])),
      // --- LİSTE BAŞLIKLARI ---
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 5),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text("CİNSİ", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.black54))),
            Expanded(child: Text("ALIŞ", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.black54))),
            Expanded(child: Text("SATIŞ", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.black54))),
            const SizedBox(width: 25),
            SizedBox(width: 50, child: Text("FARK", textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.white54 : Colors.black54))),
          ],
        ),
      ),
     Expanded(child: ListView.builder(itemCount: altinListesi.length, padding: const EdgeInsets.symmetric(horizontal: 15), itemBuilder: (context, index) {
        final item = altinListesi[index];
        
        // --- \n GİBİ ÇÖP KARAKTERLERİ YOK EDEN FİLTRE ---
        String temizFark = item.fark.replaceAll(RegExp(r'[^0-9.,%\-+]'), '');

        return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20), decoration: BoxDecoration(
          color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: item.dusus ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3), width: 1),
          boxShadow: [BoxShadow(color: item.dusus ? Colors.red.withOpacity(0.05) : Colors.green.withOpacity(0.05), blurRadius: 10)],
        ), child: Row(children: [
          // İSİM KISMI
          Expanded(flex: 2, child: Text(item.isim, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
          
          // ALIŞ KISMI (FittedBox ile tek satıra zorlandı)
          Expanded(child: FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.center,
            child: Text(item.alis, maxLines: 1, style: TextStyle(color: item.dusus ? Colors.red : Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
          )),
          
          // SATIŞ KISMI (FittedBox ile tek satıra zorlandı)
          Expanded(child: FittedBox(
            fit: BoxFit.scaleDown, alignment: Alignment.centerRight,
            child: Text(item.satis, maxLines: 1, style: TextStyle(color: item.dusus ? Colors.red : Colors.green, fontWeight: FontWeight.w900, fontSize: 14)),
          )),
          
          const SizedBox(width: 15),
          
          // YÜZDELİK FARK VE İKON KISMI
          SizedBox(
            width: 50,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // FARK YAZISI (FittedBox ile tek satıra zorlandı)
                FittedBox(
                  fit: BoxFit.scaleDown, alignment: Alignment.centerRight,
                  child: Text(temizFark, maxLines: 1, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: item.dusus ? Colors.red : Colors.green)),
                ),
                const SizedBox(height: 2),
                Icon(item.dusus ? Icons.trending_down : Icons.trending_up, color: item.dusus ? Colors.red : Colors.green, size: 14),
              ],
            ),
          ),
        ]));
      })),
    ]));
  }

 Widget ustPanel(bool isDark) {
    return Container(
      padding: const EdgeInsets.only(top: 60, bottom: 30, left: 15, right: 15),
      decoration: BoxDecoration(
        // 1. PREMIUM ARKA PLAN GRADYANI (Mermer Beyazı / Obsidyen Siyahı)
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark 
              ? [const Color(0xFF1A1A20), const Color(0xFF0A0A0D)] // Gece: Antrasit & Siyah
              : [const Color(0xFFFFFFFF), const Color(0xFFF4F4F9)], // Gündüz: İnci Beyazı
        ),
        // 2. İNCE ALTIN ÇİZGİ VE YUVARLAK HATLAR
        border: Border(bottom: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1.5)),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
        // 3. SİNEMATİK GÖLGE EFEKTİ (Gece modunda hafif altın ışıltısı yayar)
        boxShadow: [
          BoxShadow(
            color: isDark ? const Color(0xFFD4AF37).withOpacity(0.08) : Colors.black.withOpacity(0.08), 
            blurRadius: 30, 
            offset: const Offset(0, 15)
          )
        ]
      ),
      child: Column(children: [
       Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(icon: Icon(Icons.notes_rounded, color: isDark ? Colors.white : Colors.black, size: 28), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
          
          // 4. LÜKS MARKA YAZISI (Ekrana sığması için Expanded ve FittedBox eklendi)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5), // Butonlarla arasına nefes payı
              child: FittedBox(
                fit: BoxFit.scaleDown, // Ekrana sığmazsa sadece yazıyı küçült, butonları itme
                child: Text(
                  "KARDEŞLER KUYUMCULUK", 
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 15, 
                    letterSpacing: 3.5, 
                    color: isDark ? Colors.white : const Color(0xFF111115),
                    shadows: [Shadow(color: const Color(0xFFD4AF37).withOpacity(0.5), blurRadius: 15)]
                  )
                ),
              ),
            ),
          ),
          
          IconButton(icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.nightlight_round, color: const Color(0xFFD4AF37)), onPressed: widget.toggleTheme),
        ]),
        
        const SizedBox(height: 25),
        
        // 5. GÖLGELİ VE MODERN SAAT TYPOGRAPHY'Sİ
        GestureDetector(
          onTap: () { _saatTiklamaSayisi++; if (_saatTiklamaSayisi >= 5) { _saatTiklamaSayisi = 0; showSifrePopup(); } },
          child: Text(
            saat, 
            style: TextStyle(
              fontSize: 52, 
              fontWeight: FontWeight.w200, 
              letterSpacing: 2.5,
              color: isDark ? Colors.white : const Color(0xFF111115),
              shadows: [Shadow(color: isDark ? Colors.white24 : Colors.black12, offset: const Offset(0, 6), blurRadius: 20)]
            )
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 6. ALTIN KAPSÜL İÇİNDE TARİH GÖSTERİMİ
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
          ),
          child: Text( 
            tarih.toUpperCase(), 
            style: const TextStyle(
              color: Color(0xFFD4AF37), 
              fontSize: 11, 
              fontWeight: FontWeight.w800, 
              letterSpacing: 2.5
            )
          ),
        ),
      ]),
    );
  }

  Widget yanMenu(bool isDark) {
    return Drawer(backgroundColor: Theme.of(context).scaffoldBackgroundColor, child: Column(children: [
      Container(height: 220, width: double.infinity, padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Color(0xFF0A0A0D)), child: ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.asset("assets/dukkan.jpg", fit: BoxFit.cover, errorBuilder: (c, o, s) => const Center(child: Icon(Icons.diamond, color: Color(0xFFD4AF37), size: 60))))),
      _menuLink("HIZLI GRAM HESAPLA", Icons.calculate_outlined, () { Navigator.pop(context); showGramHesaplaPopup(); }, gold: true),
      _menuLink("BİZ KİMİZ?", Icons.info_outline, () { Navigator.pop(context); showBizKimizPopup(); }),
      
      // 1. DÜKKAN KONUMU GÜNCELLENDİ (Senin verdiğin link eklendi)
      _menuLink("DÜKKAN KONUMU", Icons.location_on_outlined, () => _launchURL("https://maps.app.goo.gl/inxftocvFwagY2HMA")),
      
      // 2. İŞ YERİ TELEFONU GÜNCELLENDİ (Uluslararası arama formatı: tel:+90...)
      _menuLink("İŞ YERİ TELEFONU", Icons.phone_in_talk_outlined, () => _launchURL("tel:+903723238888")),
      
      // 3. WHATSAPP DESTEK GÜNCELLENDİ (WhatsApp API formatı: wa.me/90...)
      _menuLink("WHATSAPP DESTEK", Icons.chat_bubble_outline, () => _launchURL("https://wa.me/903723238888")),
      
      _menuLink("ZEKAT HESAPLA", Icons.monetization_on_outlined, () { Navigator.pop(context); showZekatPopup(); }),
      const Spacer(),
      Padding(padding: const EdgeInsets.all(20), child: Text("v7.0 Ultimate Premium", style: TextStyle(color: isDark ? Colors.white10 : Colors.black12, fontSize: 10))),
    ]));
  }

  Widget _menuLink(String t, IconData i, VoidCallback o, {bool gold = false}) {
    return ListTile(leading: Icon(i, color: gold ? const Color(0xFFD4AF37) : (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black45)), title: Text(t, style: TextStyle(fontWeight: gold ? FontWeight.w900 : FontWeight.w600, fontSize: 13, color: gold ? const Color(0xFFD4AF37) : null)), onTap: o);
  }
}