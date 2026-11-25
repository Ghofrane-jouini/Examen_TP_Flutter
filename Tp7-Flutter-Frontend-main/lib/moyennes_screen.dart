import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

class MoyennesScreen extends StatefulWidget {
  const MoyennesScreen({super.key});

  @override
  State<MoyennesScreen> createState() => _MoyennesScreenState();
}

class _MoyennesScreenState extends State<MoyennesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<MoyennesClasseTabState> _moyennesClasseKey =
      GlobalKey<MoyennesClasseTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        _moyennesClasseKey.currentState?.loadData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion des moyennes"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (_tabController.index == 0) {
                _moyennesClasseKey.currentState?.loadData();
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Moyennes classe", icon: Icon(Icons.analytics)),
            Tab(text: "Saisie des notes", icon: Icon(Icons.edit_note)),
            Tab(text: "Coefficients", icon: Icon(Icons.functions)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          MoyennesClasseTab(key: _moyennesClasseKey),
          SaisieNotesTab(
            onSaved: () {
              _moyennesClasseKey.currentState?.loadData();
            },
          ),
          CoefficientsTab(
            onSaved: () {
              _moyennesClasseKey.currentState?.loadData();
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ONGLET 1 : MOYENNES DE LA CLASSE (RAPPORT & DÉTAILS)
// ============================================================================

class MoyennesClasseTab extends StatefulWidget {
  const MoyennesClasseTab({super.key});

  @override
  State<MoyennesClasseTab> createState() => MoyennesClasseTabState();
}

class MoyennesClasseTabState extends State<MoyennesClasseTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> classes = [];
  int? codClass;

  Map<String, dynamic>? dataMoyennes;
  bool loading = true;
  bool loadingData = false;
  String? erreur;

  @override
  void initState() {
    super.initState();
    init();
  }

  String get dateAujourdhui {
    final now = DateTime.now();
    return "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
  }

  String fmtDecimal(num? v) {
    if (v == null) return "—";
    return v.toDouble().toStringAsFixed(2);
  }

  String fmtNum(num? v) {
    if (v == null) return '0';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  String messageErreur(http.Response res) {
    final text = utf8.decode(res.bodyBytes).trim();
    return text.isNotEmpty ? text : "Erreur serveur (${res.statusCode})";
  }

  void msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Map<String, dynamic>? get currentClasse {
    for (final c in classes) {
      if (c['codClass'] == codClass) return c;
    }
    return null;
  }

  Future<void> init() async {
    setState(() {
      loading = true;
      erreur = null;
    });
    try {
      final res = await http.get(Uri.parse("$baseUrl/classes"));
      if (res.statusCode == 200) {
        final List cList = jsonDecode(utf8.decode(res.bodyBytes));
        final cMap = cList.cast<Map<String, dynamic>>();
        setState(() {
          classes = cMap;
          if (cMap.isNotEmpty) {
            codClass = cMap.first['codClass'] as int;
          }
        });
        if (codClass != null) {
          await loadData();
        }
      } else {
        setState(() => erreur = messageErreur(res));
      }
    } catch (e) {
      setState(() => erreur = "Impossible de joindre le serveur");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadData() async {
    if (codClass == null) return;
    setState(() => loadingData = true);
    try {
      final res =
          await http.get(Uri.parse("$baseUrl/moyennes/classe/$codClass"));
      if (res.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(utf8.decode(res.bodyBytes));
        setState(() {
          dataMoyennes = data;
          erreur = null;
        });
      } else {
        msg(messageErreur(res), error: true);
      }
    } catch (e) {
      msg("Impossible de joindre le serveur", error: true);
    } finally {
      if (mounted) setState(() => loadingData = false);
    }
  }

  void showDetailDialog(Map<String, dynamic> etudiant) {
    final nom = etudiant['nom']?.toString() ?? '';
    final prenom = etudiant['prenom']?.toString() ?? '';
    final List details = (etudiant['details'] as List?) ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Détail de $nom $prenom"),
        content: SingleChildScrollView(
          child: details.isEmpty
              ? const Text("Aucune matière complète")
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: details.map((d) {
                    final codMat = d['codMat']?.toString() ?? '-';
                    final moy = d['moyenne'] as num?;
                    final coef = d['coef'] as num?;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        "$codMat : ${fmtDecimal(moy)} (coef ${fmtNum(coef)})",
                        style: const TextStyle(fontSize: 15),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  Widget buildHeader() {
    final cName =
        dataMoyennes?['nomClass'] ?? currentClasse?['nomClass'] ?? '-';
    final dep =
        dataMoyennes?['departement'] ?? currentClasse?['departement'] ?? '-';

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 28,
          runSpacing: 8,
          children: [
            Text("Classe : $cName",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text("Département : $dep",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text("Date : $dateAujourdhui",
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: init, child: const Text("Réessayer")),
            ],
          ),
        ),
      );
    }

    final etudiantsList =
        (dataMoyennes?['etudiants'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final moyClasse = dataMoyennes?['moyenneClasse'] as num?;

    return RefreshIndicator(
      onRefresh: loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Text("Classe : ",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: codClass,
                  hint: const Text("Sélectionner une classe"),
                  items: classes
                      .map((c) => DropdownMenuItem<int>(
                            value: c['codClass'] as int,
                            child: Text(c['nomClass'].toString()),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => codClass = v);
                    loadData();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          buildHeader(),
          const SizedBox(height: 16),
          if (loadingData)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (etudiantsList.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text("Aucun étudiant dans cette classe")),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                border: TableBorder.all(color: Colors.grey.shade300),
                columns: const [
                  DataColumn(label: Text("Nom")),
                  DataColumn(label: Text("Prénom")),
                  DataColumn(label: Text("Moyenne")),
                ],
                rows: etudiantsList.map((e) {
                  final nom = e['nom']?.toString() ?? '';
                  final prenom = e['prenom']?.toString() ?? '';
                  final moy = e['moyenne'] as num?;

                  Color textColor = Colors.black;
                  if (moy != null) {
                    textColor =
                        moy >= 10 ? Colors.green.shade700 : Colors.red;
                  }

                  return DataRow(
                    cells: [
                      DataCell(
                        Text(nom,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        onTap: () => showDetailDialog(e),
                      ),
                      DataCell(
                        Text(prenom),
                        onTap: () => showDetailDialog(e),
                      ),
                      DataCell(
                        Text(
                          fmtDecimal(moy),
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: textColor),
                        ),
                        onTap: () => showDetailDialog(e),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.indigo.shade600,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        "Moyenne de la classe :",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      moyClasse != null
                          ? "${fmtDecimal(moyClasse)} / 20"
                          : "—",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// ONGLET 2 : SAISIE DES NOTES (PAR CLASSE ET MATIÈRE)
// ============================================================================

class SaisieNotesTab extends StatefulWidget {
  final VoidCallback? onSaved;

  const SaisieNotesTab({super.key, this.onSaved});

  @override
  State<SaisieNotesTab> createState() => _SaisieNotesTabState();
}

class _SaisieNotesTabState extends State<SaisieNotesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const champs = ['tp1', 'tp2', 'ds', 'dc'];
  static const titres = ['TP1', 'TP2', 'DS', 'DC'];

  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> matieres = [];
  int? codClass;
  String? codMat;

  List<Map<String, dynamic>> lignes = [];
  final Map<int, Map<String, TextEditingController>> ctrls = {};

  bool loading = true;
  bool loadingRows = false;
  bool saving = false;
  String? erreur;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _clearCtrls();
    super.dispose();
  }

  void _clearCtrls() {
    for (final m in ctrls.values) {
      for (final c in m.values) {
        c.dispose();
      }
    }
    ctrls.clear();
  }

  String fmtNum(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  String messageErreur(http.Response res) {
    final text = utf8.decode(res.bodyBytes).trim();
    return text.isNotEmpty ? text : "Erreur serveur (${res.statusCode})";
  }

  void msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  Map<String, dynamic>? get classe {
    for (final c in classes) {
      if (c['codClass'] == codClass) return c;
    }
    return null;
  }

  double? note(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    if (v == null || v < 0 || v > 20) return null;
    return v;
  }

  bool invalide(TextEditingController c) =>
      c.text.trim().isNotEmpty && note(c) == null;

  double? moyenne(int id) {
    final m = ctrls[id];
    if (m == null) return null;
    double somme = 0;
    for (final k in champs) {
      final n = note(m[k]!);
      if (n == null) return null;
      somme += n;
    }
    return somme / 4;
  }

  double? moyenneClasse() {
    final l = <double>[];
    for (final e in lignes) {
      final m = moyenne(e['etudiantId'] as int);
      if (m != null) l.add(m);
    }
    if (l.isEmpty) return null;
    return l.reduce((a, b) => a + b) / l.length;
  }

  Future<List<Map<String, dynamic>>> getList(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) throw Exception(messageErreur(res));
    return (jsonDecode(utf8.decode(res.bodyBytes)) as List)
        .cast<Map<String, dynamic>>();
  }

  Future<void> init() async {
    setState(() {
      loading = true;
      erreur = null;
    });
    try {
      final c = await getList("$baseUrl/classes");
      final m = await getList("$baseUrl/matieres");
      setState(() {
        classes = c;
        matieres = m;
        codClass = c.isNotEmpty ? c.first['codClass'] as int : null;
        codMat = m.isNotEmpty ? m.first['codMat'] as String : null;
      });
      await loadLignes();
    } catch (e) {
      setState(() => erreur = "Impossible de joindre le serveur");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadLignes() async {
    if (codClass == null || codMat == null) return;
    setState(() => loadingRows = true);
    try {
      final l =
          await getList("$baseUrl/notes/classe/$codClass/matiere/$codMat");
      _clearCtrls();
      for (final e in l) {
        ctrls[e['etudiantId'] as int] = {
          for (final k in champs)
            k: TextEditingController(
                text: e[k] == null ? '' : fmtNum(e[k] as num)),
        };
      }
      setState(() => lignes = l);
    } catch (e) {
      msg("Erreur de chargement", error: true);
    } finally {
      if (mounted) setState(() => loadingRows = false);
    }
  }

  Future<void> enregistrer() async {
    final body = <Map<String, dynamic>>[];
    for (final l in lignes) {
      final id = l['etudiantId'] as int;
      final m = ctrls[id]!;
      for (final k in champs) {
        if (invalide(m[k]!)) {
          msg("Note invalide pour ${l['nom']} ${l['prenom']} (0 à 20)",
              error: true);
          return;
        }
      }
      body.add({
        "etudiantId": id,
        for (final k in champs) k: note(m[k]!),
      });
    }

    setState(() => saving = true);
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/notes/classe/$codClass/matiere/$codMat"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        msg("Notes enregistrées");
        await loadLignes();
        widget.onSaved?.call();
      } else {
        msg(messageErreur(res), error: true);
      }
    } catch (e) {
      msg("Impossible de joindre le serveur", error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget filtres() {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: [
        SizedBox(
          width: 190,
          child: DropdownButton<int>(
            isExpanded: true,
            value: codClass,
            hint: const Text("Classe"),
            items: classes
                .map((c) => DropdownMenuItem<int>(
                      value: c['codClass'] as int,
                      child: Text(c['nomClass'].toString()),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => codClass = v);
              loadLignes();
            },
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButton<String>(
            isExpanded: true,
            value: codMat,
            hint: const Text("Matière"),
            items: matieres
                .map((m) => DropdownMenuItem<String>(
                      value: m['codMat'] as String,
                      child: Text(m['codMat'].toString()),
                    ))
                .toList(),
            onChanged: (v) {
              setState(() => codMat = v);
              loadLignes();
            },
          ),
        ),
      ],
    );
  }

  Widget entete() {
    const gras = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 32,
          runSpacing: 6,
          children: [
            Text("Classe : ${classe?['nomClass'] ?? '-'}", style: gras),
            Text("Département : ${classe?['departement'] ?? '-'}",
                style: gras),
            Text("Matière : ${codMat ?? '-'}", style: gras),
          ],
        ),
      ),
    );
  }

  Widget tableau() {
    if (loadingRows) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (lignes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text("Aucun étudiant dans cette classe")),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        border: TableBorder.all(),
        columns: [
          const DataColumn(label: Text("Nom")),
          const DataColumn(label: Text("Prénom")),
          ...titres.map((t) => DataColumn(label: Text(t))),
          const DataColumn(label: Text("Moyenne")),
        ],
        rows: lignes.map((l) {
          final id = l['etudiantId'] as int;
          final m = ctrls[id]!;
          final moy = moyenne(id);
          return DataRow(cells: [
            DataCell(Text(l['nom']?.toString() ?? '')),
            DataCell(Text(l['prenom']?.toString() ?? '')),
            ...champs.map((k) => DataCell(SizedBox(
                  width: 64,
                  child: TextField(
                    controller: m[k],
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: "—",
                      isDense: true,
                      errorText: invalide(m[k]!) ? '' : null,
                      errorStyle: const TextStyle(height: 0),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ))),
            DataCell(Text(
              moy == null ? '—' : moy.toStringAsFixed(2),
              style: const TextStyle(fontWeight: FontWeight.bold),
            )),
          ]);
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final mc = moyenneClasse();

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: init, child: const Text("Réessayer")),
            ],
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            filtres(),
            const SizedBox(height: 8),
            entete(),
            const SizedBox(height: 16),
            tableau(),
            const SizedBox(height: 12),
            if (lignes.isNotEmpty) ...[
              Card(
                color: Colors.indigo.shade600,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text("Moyenne de la classe",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        mc == null ? '—' : "${mc.toStringAsFixed(2)} / 20",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: saving || loadingRows ? null : enregistrer,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: const Text("Enregistrer"),
                ),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              "Notes sur 20. Moyenne = (TP1 + TP2 + DS + DC) / 4, "
              "calculée quand les 4 notes sont saisies.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ONGLET 3 : COEFFICIENTS DES MATIÈRES PAR CLASSE
// ============================================================================

class CoefficientsTab extends StatefulWidget {
  final VoidCallback? onSaved;

  const CoefficientsTab({super.key, this.onSaved});

  @override
  State<CoefficientsTab> createState() => _CoefficientsTabState();
}

class _CoefficientsTabState extends State<CoefficientsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> classes = [];
  int? codClass;

  List<Map<String, dynamic>> classmatList = [];
  final Map<String, TextEditingController> coefCtrls = {};

  bool loading = true;
  bool loadingClassmat = false;
  bool saving = false;
  String? erreur;

  @override
  void initState() {
    super.initState();
    init();
  }

  @override
  void dispose() {
    _clearCtrls();
    super.dispose();
  }

  void _clearCtrls() {
    for (final c in coefCtrls.values) {
      c.dispose();
    }
    coefCtrls.clear();
  }

  String fmtNum(num? v) {
    if (v == null) return '1';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  String messageErreur(http.Response res) {
    final text = utf8.decode(res.bodyBytes).trim();
    return text.isNotEmpty ? text : "Erreur serveur (${res.statusCode})";
  }

  void msg(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  double? parseCoef(TextEditingController c) {
    final clean = c.text.trim().replaceAll(',', '.');
    if (clean.isEmpty) return null;
    final val = double.tryParse(clean);
    if (val == null || val <= 0) return null;
    return val;
  }

  bool isCoefInvalid(TextEditingController c) {
    if (c.text.trim().isEmpty) return true;
    return parseCoef(c) == null;
  }

  Future<void> init() async {
    setState(() {
      loading = true;
      erreur = null;
    });
    try {
      final res = await http.get(Uri.parse("$baseUrl/classes"));
      if (res.statusCode == 200) {
        final List cList = jsonDecode(utf8.decode(res.bodyBytes));
        final cMap = cList.cast<Map<String, dynamic>>();
        setState(() {
          classes = cMap;
          if (cMap.isNotEmpty) {
            codClass = cMap.first['codClass'] as int;
          }
        });
        if (codClass != null) {
          await loadClassMat();
        }
      } else {
        setState(() => erreur = messageErreur(res));
      }
    } catch (e) {
      setState(() => erreur = "Impossible de joindre le serveur");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadClassMat() async {
    if (codClass == null) return;
    setState(() => loadingClassmat = true);
    try {
      final res =
          await http.get(Uri.parse("$baseUrl/classmat/classe/$codClass"));
      if (res.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(res.bodyBytes));
        final items = list.cast<Map<String, dynamic>>();

        _clearCtrls();
        for (final item in items) {
          final codMat = item['codMat']?.toString() ?? '';
          final coef = item['coef'] as num?;
          coefCtrls[codMat] = TextEditingController(text: fmtNum(coef));
        }

        setState(() {
          classmatList = items;
          erreur = null;
        });
      } else {
        msg(messageErreur(res), error: true);
      }
    } catch (e) {
      msg("Impossible de joindre le serveur", error: true);
    } finally {
      if (mounted) setState(() => loadingClassmat = false);
    }
  }

  Future<void> saveCoefficients() async {
    if (codClass == null || classmatList.isEmpty) return;

    final body = <Map<String, dynamic>>[];
    for (final item in classmatList) {
      final codMat = item['codMat']?.toString() ?? '';
      final ctrl = coefCtrls[codMat];
      if (ctrl == null || isCoefInvalid(ctrl)) {
        msg("Coefficient invalide pour $codMat (doit être un nombre > 0)",
            error: true);
        return;
      }
      final coefVal = parseCoef(ctrl)!;
      body.add({
        "codMat": codMat,
        "coef": coefVal,
      });
    }

    setState(() => saving = true);

    try {
      final res = await http.put(
        Uri.parse("$baseUrl/classmat/classe/$codClass"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (res.statusCode == 200) {
        msg("Coefficients enregistrés");
        await loadClassMat();
        widget.onSaved?.call();
      } else {
        msg(messageErreur(res), error: true);
      }
    } catch (e) {
      msg("Impossible de joindre le serveur", error: true);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (erreur != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(erreur!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: init, child: const Text("Réessayer")),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Text("Classe : ",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                value: codClass,
                hint: const Text("Sélectionner une classe"),
                items: classes
                    .map((c) => DropdownMenuItem<int>(
                          value: c['codClass'] as int,
                          child: Text(c['nomClass'].toString()),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => codClass = v);
                  loadClassMat();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (loadingClassmat)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (classmatList.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: Text("Aucune matière pour cette classe")),
          )
        else ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              border: TableBorder.all(color: Colors.grey.shade300),
              columns: const [
                DataColumn(label: Text("Matière")),
                DataColumn(label: Text("Coef")),
              ],
              rows: classmatList.map((item) {
                final codMat = item['codMat']?.toString() ?? '';
                final intMat = item['intMat']?.toString() ?? codMat;
                final ctrl = coefCtrls[codMat];
                final invalid = ctrl != null && isCoefInvalid(ctrl);

                return DataRow(cells: [
                  DataCell(Text("$codMat - $intMat",
                      style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(
                    SizedBox(
                      width: 80,
                      child: TextField(
                        controller: ctrl,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                          isDense: true,
                          errorText: invalid ? '' : null,
                          errorStyle: const TextStyle(height: 0),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: saving || loadingClassmat ? null : saveCoefficients,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text("Enregistrer"),
            ),
          ),
        ],
      ],
    );
  }
}
