import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

// Écran principal contenant les 2 onglets de gestion des absences
class AbsencesScreen extends StatefulWidget {
  const AbsencesScreen({super.key});

  @override
  State<AbsencesScreen> createState() => _AbsencesScreenState();
}

class _AbsencesScreenState extends State<AbsencesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<ToutesAbsencesTabState> _toutesAbsencesKey =
      GlobalKey<ToutesAbsencesTabState>();

  @override
  void initState() {
    super.initState();
    // Création du contrôleur pour basculer entre les 2 onglets
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Recharge l'onglet 1 automatiquement lors du retour dessus
      if (_tabController.index == 0) {
        _toutesAbsencesKey.currentState?.chargerDonnees();
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
        title: const Text("Gestion des absences"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Toutes les absences", icon: Icon(Icons.list_alt)),
            Tab(text: "Saisie par classe", icon: Icon(Icons.edit_calendar)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ToutesAbsencesTab(key: _toutesAbsencesKey),
          SaisieAbsencesTab(
            onSaved: () {
              _toutesAbsencesKey.currentState?.chargerDonnees();
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ONGLET 1 : TOUTES LES ABSENCES 
// ============================================================================

class ToutesAbsencesTab extends StatefulWidget {
  const ToutesAbsencesTab({super.key});

  @override
  State<ToutesAbsencesTab> createState() => ToutesAbsencesTabState();
}

class ToutesAbsencesTabState extends State<ToutesAbsencesTab>
    with AutomaticKeepAliveClientMixin {
  // Conserve le contenu de l'onglet en mémoire lors du changement d'onglet
  @override
  bool get wantKeepAlive => true;

  // Deux listes pour stocker les données reçues du serveur
  List<Map<String, dynamic>> topMatieres = [];
  List<Map<String, dynamic>> parMatiereList = [];

  // Indicateur de chargement et de gestion d'erreur
  bool chargement = true;
  bool erreur = false;

  @override
  void initState() {
    super.initState();
    // Appel unique pour charger toutes les données au démarrage
    chargerDonnees();
  }

  // Fonction simple pour formater les nombres sans ".0" inutile
  String fmtNum(num? v) {
    if (v == null) return '0';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  // Fonction de chargement HTTP (2 requêtes GET)
  Future<void> chargerDonnees() async {
    setState(() {
      chargement = true;
      erreur = false;
    });

    try {
      // 1. Récupération du Top 3 des matières
      final resTop =
          await http.get(Uri.parse("$baseUrl/absences/top-matieres?limit=3"));
      // 2. Récupération des absences par matière
      final resPar = await http.get(Uri.parse("$baseUrl/absences/par-matiere"));

      if (resTop.statusCode == 200 && resPar.statusCode == 200) {
        final listTop = jsonDecode(utf8.decode(resTop.bodyBytes)) as List;
        final listPar = jsonDecode(utf8.decode(resPar.bodyBytes)) as List;

        setState(() {
          topMatieres = listTop.cast<Map<String, dynamic>>();
          parMatiereList = listPar.cast<Map<String, dynamic>>();
        });
      } else {
        setState(() => erreur = true);
      }
    } catch (e) {
      // Erreur réseau ou serveur injoignable
      setState(() => erreur = true);
    } finally {
      if (mounted) {
        setState(() => chargement = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 1. Affichage pendant le chargement
    if (chargement) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Affichage en cas d'erreur avec bouton Réessayer
    if (erreur) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Erreur : serveur non joignable"),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: chargerDonnees,
              child: const Text("Réessayer"),
            ),
          ],
        ),
      );
    }

    // 3. Affichage principal des données dans une seule ListView
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- BLOC 1 : TOP 3 DES MATIÈRES ---
        const Text(
          "Top 3 des matières (heures d'absence cumulées)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),

        if (topMatieres.isEmpty)
          const Text("Aucune absence enregistrée")
        else
          for (int i = 0; i < topMatieres.length; i++) ...[
            Text(
              "${i + 1}. ${topMatieres[i]['codMat'] ?? ''} - ${topMatieres[i]['intMat'] ?? ''} : ${fmtNum(topMatieres[i]['totalNha'] as num?)} h",
            ),
            const SizedBox(height: 4),
          ],

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),

        // --- BLOC 2 : ABSENCES PAR MATIÈRE ---
        const Text(
          "Absences par matière",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),

        if (parMatiereList.isEmpty)
          const Text("Aucune matière disponible")
        else
          for (final m in parMatiereList) ...[
            // Ligne de titre pour la matière et son total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "${m['codMat'] ?? ''} - ${m['intMat'] ?? ''}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  "Total : ${fmtNum(m['totalNha'] as num?)} h",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Affichage du tableau d'absences ou du texte "Aucune absence"
            if ((m['absences'] as List? ?? []).isEmpty)
              const Text(
                "Aucune absence",
                style: TextStyle(color: Colors.grey),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text("Nom")),
                    DataColumn(label: Text("Prénom")),
                    DataColumn(label: Text("Classe")),
                    DataColumn(label: Text("Date")),
                    DataColumn(label: Text("NHA")),
                  ],
                  rows: [
                    for (final a in (m['absences'] as List))
                      DataRow(cells: [
                        DataCell(Text(a['nom']?.toString() ?? '-')),
                        DataCell(Text(a['prenom']?.toString() ?? '-')),
                        DataCell(Text(a['nomClass']?.toString() ?? '-')),
                        DataCell(Text(a['dateA']?.toString() ?? '-')),
                        DataCell(Text(fmtNum(a['nha'] as num?))),
                      ]),
                  ],
                ),
              ),

            const SizedBox(height: 20),
          ],
      ],
    );
  }
}

// ============================================================================
// ONGLET 2 : SAISIE PAR CLASSE
// ============================================================================

class SaisieAbsencesTab extends StatefulWidget {
  final VoidCallback? onSaved;

  const SaisieAbsencesTab({super.key, this.onSaved});

  @override
  State<SaisieAbsencesTab> createState() => _SaisieAbsencesTabState();
}

class _SaisieAbsencesTabState extends State<SaisieAbsencesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> matieres = [];
  int? codClass;
  String? codMat;
  DateTime date = DateTime.now();

  List<Map<String, dynamic>> lignes = [];
  final Map<int, TextEditingController> ctrls = {};

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
    for (final c in ctrls.values) {
      c.dispose();
    }
    ctrls.clear();
  }

  String iso(DateTime d) => d.toIso8601String().substring(0, 10);

  String fmtDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}";

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

  Map<String, dynamic>? get matiere {
    for (final m in matieres) {
      if (m['codMat'] == codMat) return m;
    }
    return null;
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
      final l = await getList(
          "$baseUrl/absences/classe/$codClass/matiere/$codMat?date=${iso(date)}");
      _clearCtrls();
      for (final e in l) {
        final nha = (e['nha'] as num?)?.toDouble();
        ctrls[e['etudiantId'] as int] = TextEditingController(
            text: (nha == null || nha == 0) ? '' : fmtNum(nha));
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
      final txt = ctrls[id]!.text.trim().replaceAll(',', '.');
      double? nha;
      if (txt.isNotEmpty) {
        nha = double.tryParse(txt);
        if (nha == null || nha < 0) {
          msg("NHA invalide pour ${l['nom']} ${l['prenom']}", error: true);
          return;
        }
      }
      body.add({"etudiantId": id, "nha": nha});
    }

    setState(() => saving = true);
    try {
      final res = await http.put(
        Uri.parse(
            "$baseUrl/absences/classe/$codClass/matiere/$codMat?date=${iso(date)}"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        msg("Absences enregistrées");
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

  Widget entete() {
    const gras = TextStyle(fontWeight: FontWeight.bold, fontSize: 16);
    final dep = (classe?['departement'] ?? '-').toString();
    final chsm = matiere?['chsm'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 32,
              runSpacing: 6,
              children: [
                Text("Classe : ${classe?['nomClass'] ?? '-'}", style: gras),
                Text("Département : $dep", style: gras),
              ],
            ),
            const SizedBox(height: 6),
            Text("Matière : ${codMat ?? '-'}", style: gras),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text("CHSM : ${chsm ?? '-'} heures", style: gras),
                ),
                Text("Date : ${fmtDate(date)}", style: gras),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget filtres() {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
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
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text(fmtDate(date)),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );
            if (d != null) {
              setState(() => date = d);
              loadLignes();
            }
          },
        ),
      ],
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
        columns: const [
          DataColumn(label: Text("Nom")),
          DataColumn(label: Text("Prénom")),
          DataColumn(label: Text("NHA")),
        ],
        rows: lignes.map((l) {
          final id = l['etudiantId'] as int;
          return DataRow(cells: [
            DataCell(Text(l['nom']?.toString() ?? '')),
            DataCell(Text(l['prenom']?.toString() ?? '')),
            DataCell(SizedBox(
              width: 80,
              child: TextField(
                controller: ctrls[id],
                textAlign: TextAlign.center,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: "0",
                  isDense: true,
                ),
              ),
            )),
          ]);
        }).toList(),
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
              const Text("Erreur : serveur non joignable",
                  textAlign: TextAlign.center),
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
            const SizedBox(height: 16),
            if (lignes.isNotEmpty)
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
            const SizedBox(height: 8),
            const Text(
              "NHA = nombre d'heures d'absence à cette date. "
              "Laisser vide ou 0 = présent.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
