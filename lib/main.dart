import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:html/parser.dart' show parse;
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('tr_TR', null).then((_) {
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.amber,
        fontFamily: 'sans-serif',
      ),
      home: SplashEkrani(),
    ));
  });
}

// --- SPLASH EKRANI ---
class SplashEkrani extends StatefulWidget {
  @override
  _SplashEkraniState createState() => _SplashEkraniState();
}

class _SplashEkraniState extends State<SplashEkrani> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => AnaSayfa()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A1A1A),
      body: Stack(
        children: [
          Opacity(
            opacity: 0.2,
            child: Image.asset("assets/splash.jpg", fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                errorBuilder: (c, o, s) => Container(color: Colors.black)),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(color: Color(0xFFD4AF37), shape: BoxShape.circle),
                  child: ClipOval(child: Image.asset("assets/splash.jpg", fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => Icon(Icons.diamond, size: 60, color: Colors.white))),
                ),
                SizedBox(height: 20),
                Text("KARDEŞLER", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2)),
                Text("KUYUMCULUK", style: TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 5)),
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
  @override
  _AnaSayfaState createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final WebViewController _webController;
  List<AltinModel> altinListesi = [];
  
  // Filtreleme için gerekli değişkenler
  List<String> seciliKategoriler = ["GRAM", "ÇEYREK", "YARIM", "TAM", "ATA", "HAS", "ONS", "AYAR", "GÜMÜŞ"];
  final List<String> tumKategoriler = ["GRAM", "ÇEYREK", "YARIM", "TAM", "ATA", "HAS", "ONS", "AYAR", "GÜMÜŞ", "USD", "EUR"];

  double guncelGramAlis = 0.0, guncelGramSatis = 0.0;
  String saat = "00:00:00", tarih = "Yükleniyor...", durumMetni = "BEKLENİYOR...";
  TextEditingController adetController = TextEditingController();
  String toplamAlis = "0.00 ₺", toplamSatis = "0.00 ₺";
  bool veriAlindi = false;

  @override
  void initState() {
    super.initState();
    saatiBaslat();
    
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _htmlKaynaginiCek(); 
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.haremaltin.com'));

    Timer.periodic(Duration(seconds: 2), (timer) {
      _htmlKaynaginiCek();
    });
  }

  void saatiBaslat() {
    Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          saat = DateFormat('HH:mm:ss').format(DateTime.now());
          tarih = DateFormat('d MMMM yyyy, EEEE', 'tr_TR').format(DateTime.now());
        });
      }
    });
  }

  void _htmlKaynaginiCek() async {
    try {
      String htmlContent = await _webController.runJavaScriptReturningResult("document.documentElement.innerHTML") as String;
      htmlContent = htmlContent.replaceAll('\\u003C', '<').replaceAll('\\"', '"').replaceAll('\\n', '');
      verileriIsle(htmlContent);
    } catch (e) {
      print("HTML Alma Hatası: $e");
    }
  }

  void verileriIsle(String html) {
    try {
      var document = parse(html);
      var rows = document.querySelectorAll('tr');
      List<AltinModel> yeniListe = [];

      for (var row in rows) {
        var cells = row.querySelectorAll('td');
        if (cells.length > 3) {
          String hamIsim = cells[0].text.trim();
          
          // --- ÇİFT İSİM TEMİZLEME MANTIĞI (Örn: YENİ ATAYENİ ATA -> YENİ ATA) ---
          String temizIsim = hamIsim;
          int uzunluk = hamIsim.length;
          if (uzunluk > 4 && uzunluk % 2 == 0) {
            String ilkYari = hamIsim.substring(0, uzunluk ~/ 2).trim();
            String ikinciYari = hamIsim.substring(uzunluk ~/ 2).trim();
            if (ilkYari == ikinciYari) {
              temizIsim = ilkYari;
            }
          }

          // FİLTRELEME MANTIĞI
          bool gosterilsinMi = seciliKategoriler.any((kat) => temizIsim.toUpperCase().contains(kat));

          if (gosterilsinMi) {
            String alis = cells[1].text.trim();
            String satis = cells[2].text.trim();
            String farkRaw = cells[3].text.trim();
            
            String fark = farkRaw.split("%").last;
            bool isDusus = farkRaw.contains("-");

            if (temizIsim.contains("GRAM ALTIN")) {
              guncelGramAlis = double.tryParse(alis.replaceAll(".", "").replaceAll(",", ".")) ?? 0.0;
              guncelGramSatis = double.tryParse(satis.replaceAll(".", "").replaceAll(",", ".")) ?? 0.0;
            }
            yeniListe.add(AltinModel(isim: temizIsim, alis: alis, satis: satis, fark: "%$fark", dusus: isDusus));
          }
        }
      }

      if (mounted && yeniListe.isNotEmpty) {
        setState(() {
          altinListesi = yeniListe;
          durumMetni = "CANLI 🟢";
          veriAlindi = true;
        });
        if (adetController.text.isNotEmpty) hesapla(adetController.text);
      }
    } catch (e) {
      print("Veri İşleme Hatası: $e");
    }
  }

  void hesapla(String deger) {
    double adet = double.tryParse(deger) ?? 0.0;
    final format = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    setState(() {
      toplamAlis = format.format(adet * guncelGramAlis);
      toplamSatis = format.format(adet * guncelGramSatis);
    });
  }

  // --- FİLTRELEME POPUP ---
  void showFiltrePopup() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text("GÖRÜNTÜLEME AYARI", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 16, fontWeight: FontWeight.bold)),
              content: Container(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: tumKategoriler.length,
                  itemBuilder: (context, index) {
                    final kat = tumKategoriler[index];
                    return CheckboxListTile(
                      activeColor: Color(0xFFD4AF37),
                      title: Text(kat, style: TextStyle(fontSize: 14)),
                      value: seciliKategoriler.contains(kat),
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            seciliKategoriler.add(kat);
                          } else {
                            seciliKategoriler.remove(kat);
                          }
                        });
                        setState(() {}); // Ana ekranı güncelle
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("TAMAM", style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.bold)),
                )
              ],
            );
          },
        );
      },
    );
  }

  // --- POPUP FONKSİYONLARI ---
  void showBizKimizPopup() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 10,
          backgroundColor: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 200, width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Color(0xFFD4AF37), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset("assets/dukkan.jpg", fit: BoxFit.cover,
                      errorBuilder: (c, o, s) => Container(color: Colors.grey[300], child: Icon(Icons.store, size: 50, color: Colors.grey))),
                  ),
                ),
                SizedBox(height: 20),
                Text("Kardeşler Kuyumcusu", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 22, fontWeight: FontWeight.bold)),
                Container(width: 60, height: 3, color: Color(0xFFD4AF37), margin: EdgeInsets.symmetric(vertical: 12)),
                Text(
                  "Kardeşler Kuyumculuk olarak yılların verdiği tecrübe ve güvenle siz değerli müşterilerimize en kaliteli hizmeti sunmaktayız.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF555555), fontSize: 16, height: 1.5),
                ),
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF333333),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text("ANLADIM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void showZekatPopup() {
    double zekatSonuc = 0.0;
    TextEditingController zekatController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStatePopup) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              elevation: 15,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("ZEKAT HESAPLAMA", style: TextStyle(color: Color(0xFFD4AF37), fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("(80.18 gr. üzeri altınlar için geçerlidir)", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    SizedBox(height: 20),
                    TextField(
                      controller: zekatController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: "Toplam Altın Miktarı (Gram)",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      onChanged: (val) {
                        double gram = double.tryParse(val) ?? 0.0;
                        setStatePopup(() {
                          zekatSonuc = (gram * guncelGramSatis) / 40.0;
                        });
                      },
                    ),
                    Divider(height: 30),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(15),
                      decoration: BoxDecoration(color: Color(0xFFFFF9C4), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Text("ÖDENMESİ GEREKEN ZEKAT", style: TextStyle(fontSize: 12, color: Color(0xFF333333))),
                          Text(
                            NumberFormat.currency(locale: 'tr_TR', symbol: '₺').format(zekatSonuc),
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF333333),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text("KAPAT", style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      print("Link açılamadı: $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Color(0xFFF5F5F5),
      drawer: yanMenu(),
      body: Stack(
        children: [
          Column(
            children: [
              ustPanel(),
              ceviriciKart(),
              // BUTON VE FİLTRE SATIRI (Daraltılmış ve ikon eklenmiş hali)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Container(
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: veriAlindi ? Colors.green : Color(0xFF333333),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                          onPressed: () => _webController.reload(),
                          child: Text(durumMetni, style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFFD4AF37),
                            elevation: 2,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                          ),
                          onPressed: showFiltrePopup,
                          child: Icon(Icons.filter_list, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              baslikSatiri(),
              Expanded(child: altinListView()),
            ],
          ),
          SizedBox(
            height: 1, 
            width: 1,
            child: WebViewWidget(controller: _webController),
          ),
        ],
      ),
    );
  }

  Widget ustPanel() {
    return Container(
      padding: EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Color(0xFFD4AF37), Color(0xFFC59D25)]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
              Text("KARDEŞLER KUYUMCUSU", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(width: 48),
            ],
          ),
          Text(saat, style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
          Text(tarih, style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget ceviriciKart() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text("ALTIN ÇEVİRİCİ (Gram Altın)", style: TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
              TextField(
                controller: adetController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: "Adet Giriniz (Örn: 10)"),
                onChanged: hesapla,
              ),
              Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(children: [Text("TOPLAM ALIŞ", style: TextStyle(fontSize: 10)), Text(toplamAlis, style: TextStyle(fontWeight: FontWeight.bold))]),
                  Column(children: [Text("TOPLAM SATIŞ", style: TextStyle(fontSize: 10)), Text(toplamSatis, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)))]),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget baslikSatiri() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(children: [
        Expanded(flex: 2, child: Text("CİNSİ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Expanded(child: Text("ALIŞ", textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Expanded(child: Text("SATIŞ", textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
        Expanded(child: Text("FARK", textAlign: TextAlign.end, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget altinListView() {
    return ListView.builder(
      itemCount: altinListesi.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        final item = altinListesi[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(children: [
              Expanded(flex: 2, child: Text(item.isim, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
              Expanded(child: Text(item.alis, textAlign: TextAlign.end, style: TextStyle(fontSize: 13))),
              Expanded(child: Text(item.satis, textAlign: TextAlign.end, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
              Expanded(child: Text(item.fark, textAlign: TextAlign.end, style: TextStyle(fontSize: 11, color: item.dusus ? Colors.red : Colors.green, fontWeight: FontWeight.bold))),
            ]),
          ),
        );
      },
    );
  }

  Widget yanMenu() {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 200, width: double.infinity, color: Color(0xFFD4AF37),
            padding: EdgeInsets.all(10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 2),
                image: DecorationImage(image: AssetImage("assets/dukkan.jpg"), fit: BoxFit.cover)
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _menuButton("BİZ KİMİZ?", Color(0xFFD4AF37), () => showBizKimizPopup()),
                  SizedBox(height: 10),
                  _menuButton("DÜKKAN KONUMU", Color(0xFF333333), () {
                    final adres = Uri.encodeComponent("KUYUMCULAR KDZ EREĞLİ, UN PAZARI SOK. No: 8 KDZ, 67300 Ereğli/Zonguldak");
                    _launchURL("geo:0,0?q=$adres");
                  }),
                  SizedBox(height: 10),
                  _menuButton("İŞ YERİ TELEFONU", Color(0xFF333333), () => _launchURL("tel:+903723238888")),
                  SizedBox(height: 10),
                  _menuButton("WHATSAPP DESTEK", Color(0xFF25D366), () => _launchURL("https://api.whatsapp.com/send?phone=905000000000&text=Merhaba bilgi almak istiyorum.")),
                  SizedBox(height: 10),
                  _menuButton("ZEKAT HESAPLA", Color(0xFFD4AF37), () => showZekatPopup()),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _menuButton(String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Text(text, style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}