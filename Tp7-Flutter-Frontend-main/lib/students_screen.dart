import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'classe.dart';
import 'etudiant.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  List<Classe> classes = [];
  List<Etudiant> etudiants = [];
  int? selectedClasse;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadClasses();
  }

  void showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  void showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.green),
    );
  }

  Future<void> loadClasses() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/classes"));
      if (res.statusCode == 200) {
        final List listJson = jsonDecode(res.body);
        final list = listJson
            .map((e) => Classe.fromMap(e as Map<String, dynamic>))
            .toList();
        setState(() {
          classes = list;
          if (classes.isNotEmpty) {
            if (selectedClasse == null ||
                !classes.any((c) => c.codClass == selectedClasse)) {
              selectedClasse = classes.first.codClass;
            }
          } else {
            selectedClasse = null;
            etudiants = [];
          }
        });
        if (selectedClasse != null) {
          await loadEtudiants(selectedClasse!);
        }
      } else {
        final err = res.body.trim().isNotEmpty
            ? res.body.trim()
            : "Erreur ${res.statusCode}";
        showError(err);
      }
    } catch (e) {
      showError("Impossible de joindre le serveur");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> loadEtudiants(int codClass) async {
    try {
      final res =
          await http.get(Uri.parse("$baseUrl/etudiants/classe/$codClass"));
      if (res.statusCode == 200) {
        final List listJson = jsonDecode(res.body);
        setState(() {
          etudiants = listJson
              .map((e) => Etudiant.fromMap(e as Map<String, dynamic>))
              .toList();
        });
      } else {
        final err = res.body.trim().isNotEmpty
            ? res.body.trim()
            : "Erreur ${res.statusCode}";
        showError(err);
      }
    } catch (e) {
      showError("Impossible de joindre le serveur");
    }
  }

  Future<void> showStudentForm({Etudiant? etudiant}) async {
    if (selectedClasse == null) {
      showError("Aucune classe disponible");
      return;
    }

    final nomCtrl = TextEditingController(text: etudiant?.nom ?? '');
    final prenomCtrl = TextEditingController(text: etudiant?.prenom ?? '');
    DateTime? date = etudiant?.dateNais != null && etudiant!.dateNais!.isNotEmpty
        ? DateTime.tryParse(etudiant.dateNais!)
        : null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(etudiant == null ? "Nouvel étudiant" : "Modifier l'étudiant"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomCtrl,
                  decoration: const InputDecoration(labelText: "Nom *"),
                ),
                TextField(
                  controller: prenomCtrl,
                  decoration: const InputDecoration(labelText: "Prénom *"),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(date == null
                      ? "Date de naissance (optionnelle)"
                      : "Date : ${date!.toIso8601String().substring(0, 10)}"),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: date ?? DateTime(2002, 1, 1),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setS(() => date = d);
                  },
                ),
                if (date != null)
                  TextButton(
                    onPressed: () => setS(() => date = null),
                    child: const Text("Effacer la date", style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Enregistrer"),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    if (nomCtrl.text.trim().isEmpty || prenomCtrl.text.trim().isEmpty) {
      showError("Nom et prénom obligatoires");
      return;
    }

    final body = jsonEncode({
      "nom": nomCtrl.text.trim(),
      "prenom": prenomCtrl.text.trim(),
      "dateNais": date?.toIso8601String().substring(0, 10),
      "classe": {"codClass": selectedClasse},
    });

    try {
      final res = etudiant == null
          ? await http.post(
              Uri.parse("$baseUrl/etudiants"),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
          : await http.put(
              Uri.parse("$baseUrl/etudiants/${etudiant.id}"),
              headers: {'Content-Type': 'application/json'},
              body: body,
            );

      if (res.statusCode == 200 || res.statusCode == 201) {
        showSuccess(etudiant == null ? "Étudiant ajouté" : "Étudiant modifié");
        await loadClasses(); // Recharge les étudiants ET les classes pour mettre à jour l'effectif
      } else {
        final err = res.body.trim().isNotEmpty
            ? res.body.trim()
            : "Erreur ${res.statusCode}";
        showError(err);
      }
    } catch (e) {
      showError("Impossible de joindre le serveur");
    }
  }

  Future<void> deleteEtudiant(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirmation"),
        content: const Text("Voulez-vous vraiment supprimer cet étudiant ?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Annuler"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Supprimer", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.delete(Uri.parse("$baseUrl/etudiants/$id"));
      if (res.statusCode == 200 || res.statusCode == 204) {
        showSuccess("Étudiant supprimé");
        await loadClasses(); // Recharge les étudiants ET les classes pour mettre à jour l'effectif
      } else {
        final err = res.body.trim().isNotEmpty
            ? res.body.trim()
            : "Erreur ${res.statusCode}";
        showError(err);
      }
    } catch (e) {
      showError("Impossible de joindre le serveur");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage students")),
      floatingActionButton: selectedClasse == null
          ? null
          : FloatingActionButton(
              onPressed: () => showStudentForm(),
              child: const Icon(Icons.add),
            ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : classes.isEmpty
              ? const Center(
                  child: Text(
                    "Aucune classe disponible.\nCréez d'abord une classe dans 'Manage groups'.",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Text("Classe : ",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: selectedClasse,
                              hint: const Text("Sélectionnez une classe"),
                              items: classes
                                  .map((c) => DropdownMenuItem<int>(
                                        value: c.codClass,
                                        child: Text(
                                            "${c.nomClass} (${c.nbreEtud} étudiant${c.nbreEtud > 1 ? 's' : ''})"),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => selectedClasse = value);
                                loadEtudiants(value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: etudiants.isEmpty
                          ? const Center(child: Text("Aucun étudiant dans cette classe"))
                          : ListView.builder(
                              itemCount: etudiants.length,
                              itemBuilder: (context, i) {
                                final e = etudiants[i];
                                final dateStr = e.dateNais != null && e.dateNais!.isNotEmpty
                                    ? "Né(e) le ${e.dateNais}"
                                    : "";
                                return ListTile(
                                  leading: const Icon(Icons.person, color: Colors.purple),
                                  title: Text("${e.nom} ${e.prenom}"),
                                  subtitle: dateStr.isNotEmpty ? Text(dateStr) : null,
                                  onTap: () => showStudentForm(etudiant: e),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => deleteEtudiant(e.id),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
